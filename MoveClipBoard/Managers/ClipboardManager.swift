import AppKit
import SwiftUI

@MainActor @Observable
class ClipboardManager {
    var history: [ClipItem] = []
    var currentContent: String = ""

    private var monitorTask: Task<Void, Never>?
    private var lastChangeCount = 0
    private let maxHistory = 100

    init() {
        load()
        currentContent = NSPasteboard.general.string(forType: .string) ?? ""
        startMonitor()
    }

    func startMonitor() {
        lastChangeCount = NSPasteboard.general.changeCount
        monitorTask = Task { @MainActor in
            while !Task.isCancelled {
                let c = NSPasteboard.general.changeCount
                if c != lastChangeCount {
                    lastChangeCount = c
                    if let s = NSPasteboard.general.string(forType: .string), !s.isEmpty {
                        currentContent = s
                        addItem(s)
                    }
                }
                try? await Task.sleep(for: .milliseconds(400))
            }
        }
    }

    func addItem(_ content: String) {
        let t = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        if history.first?.content == t { return }
        history.removeAll { $0.content == t }
        history.insert(ClipItem(t), at: 0)
        if history.count > maxHistory { history = Array(history.prefix(maxHistory)) }
        save()
    }

    func copyToMac(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        lastChangeCount = NSPasteboard.general.changeCount
        currentContent = text
        addItem(text)
    }

    func remove(_ item: ClipItem) {
        history.removeAll { $0.id == item.id }
        save()
    }

    func clearAll() {
        history.removeAll()
        save()
    }

    private func save() {
        if let d = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(d, forKey: "clipHistory")
        }
    }

    private func load() {
        guard let d = UserDefaults.standard.data(forKey: "clipHistory"),
              let arr = try? JSONDecoder().decode([ClipItem].self, from: d) else { return }
        history = arr
    }
}
