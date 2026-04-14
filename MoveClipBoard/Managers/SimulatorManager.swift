import Foundation

enum PullResult {
    case ok(String)
    case empty
    case error
}

@MainActor @Observable
class SimulatorManager {
    var devices: [SimDevice] = []
    var selectedID: String = ""
    var isRefreshing = false
    var noSimulatorRunning = false

    var selected: SimDevice? { devices.first { $0.id == selectedID } }

    init() { refresh() }

    func refresh() {
        isRefreshing = true
        noSimulatorRunning = false
        Task.detached { [weak self] in
            let devs = SimulatorManager.fetchDevices()
            await self?.apply(devs)
        }
    }

    private func apply(_ devs: [SimDevice]) {
        devices = devs
        noSimulatorRunning = devs.isEmpty
        if selectedID.isEmpty || !devs.contains(where: { $0.id == selectedID }) {
            selectedID = devs.first?.id ?? ""
        }
        isRefreshing = false
    }

    func pullFromSim() async -> PullResult {
        let id = selectedID
        guard !id.isEmpty else { return .error }
        return await Task.detached {
            let out = mcbShell("/usr/bin/xcrun", ["simctl", "pbpaste", id])
            let t = out.trimmingCharacters(in: .whitespacesAndNewlines)
            if t.isEmpty { return PullResult.empty }
            return PullResult.ok(t)
        }.value
    }

    func pushToSim(_ text: String) {
        let id = selectedID
        guard !id.isEmpty else { return }
        Task.detached { SimulatorManager.pushText(text, to: id) }
    }

    nonisolated static func fetchDevices() -> [SimDevice] {
        let out = mcbShell("/usr/bin/xcrun", ["simctl", "list", "devices", "booted", "--json"])
        guard let data = out.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dict = json["devices"] as? [String: [[String: Any]]] else { return [] }
        var result: [SimDevice] = []
        for (runtime, list) in dict {
            var rt = runtime.replacingOccurrences(of: "com.apple.CoreSimulator.SimRuntime.", with: "")
            if rt.hasPrefix("iOS-") {
                rt = "iOS " + rt.dropFirst(4).replacingOccurrences(of: "-", with: ".")
            }
            for d in list {
                guard let udid = d["udid"] as? String,
                      let name = d["name"] as? String,
                      (d["state"] as? String) == "Booted" else { continue }
                result.append(SimDevice(id: udid, name: name, runtime: String(rt)))
            }
        }
        return result.sorted { $0.name < $1.name }
    }

    nonisolated static func pushText(_ text: String, to id: String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        p.arguments = ["simctl", "pbcopy", id]
        let pipe = Pipe()
        p.standardInput = pipe
        p.standardError = Pipe()
        try? p.run()
        if let d = text.data(using: .utf8) { pipe.fileHandleForWriting.write(d) }
        pipe.fileHandleForWriting.closeFile()
        p.waitUntilExit()
    }
}
