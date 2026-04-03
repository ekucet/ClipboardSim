//
//  ContentView.swift
//  MoveClipBoard
//
//  Created by Erkam Kucet on 3.04.2026.
//

import SwiftUI
import AppKit

// MARK: - Content Kind

enum ContentKind {
    case url, json, path, text

    static func of(_ s: String) -> ContentKind {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.hasPrefix("http://") || t.hasPrefix("https://") { return .url }
        if (t.hasPrefix("{") || t.hasPrefix("[")) && t.count < 2000 { return .json }
        if t.hasPrefix("/") && !t.contains(" ") && !t.contains("\n") { return .path }
        return .text
    }

    var icon: String {
        switch self {
        case .url:  return "link"
        case .json: return "curlybraces"
        case .path: return "folder"
        case .text: return "doc.text"
        }
    }

    var color: Color {
        switch self {
        case .url:  return .blue
        case .json: return .orange
        case .path: return .purple
        case .text: return .secondary
        }
    }
}

// MARK: - Models

struct ClipItem: Identifiable, Codable {
    let id: UUID
    let content: String
    let date: Date
    init(_ content: String) { id = UUID(); self.content = content; date = Date() }
}

struct SimDevice: Identifiable {
    let id: String
    let name: String
    let runtime: String
    var label: String { "\(name) · \(runtime)" }
}

// MARK: - ClipboardManager

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

    func clearAll() { history.removeAll(); save() }

    private func save() {
        if let d = try? JSONEncoder().encode(history) { UserDefaults.standard.set(d, forKey: "clipHistory") }
    }
    private func load() {
        guard let d = UserDefaults.standard.data(forKey: "clipHistory"),
              let arr = try? JSONDecoder().decode([ClipItem].self, from: d) else { return }
        history = arr
    }
}

// MARK: - SimulatorManager

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

    func pullFromSim() async -> String? {
        let id = selectedID
        guard !id.isEmpty else { return nil }
        return await Task.detached {
            let out = mcbShell("/usr/bin/xcrun", ["simctl", "pbpaste", id])
            let t = out.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? nil : t
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
            if rt.hasPrefix("iOS-") { rt = "iOS " + rt.dropFirst(4).replacingOccurrences(of: "-", with: ".") }
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

nonisolated func mcbShell(_ path: String, _ args: [String]) -> String {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: path)
    p.arguments = args
    let pipe = Pipe()
    p.standardOutput = pipe
    p.standardError = Pipe()
    try? p.run()
    p.waitUntilExit()
    return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
}

// MARK: - SnippetsManager

@MainActor @Observable
class SnippetsManager {
    var items: [ClipItem] = []

    init() { load() }

    func add(_ content: String) {
        let t = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        items.removeAll { $0.content == t }
        items.insert(ClipItem(t), at: 0)
        save()
    }

    func remove(_ item: ClipItem) { items.removeAll { $0.id == item.id }; save() }

    private func save() {
        if let d = try? JSONEncoder().encode(items) { UserDefaults.standard.set(d, forKey: "snippetsV2") }
    }
    private func load() {
        guard let d = UserDefaults.standard.data(forKey: "snippetsV2"),
              let arr = try? JSONDecoder().decode([ClipItem].self, from: d) else { return }
        items = arr
    }
}

// MARK: - Helpers

func mcbAgo(_ date: Date) -> String {
    let s = Int(-date.timeIntervalSinceNow)
    if s < 2  { return "şimdi" }
    if s < 60 { return "\(s)sn" }
    let m = s / 60
    if m < 60 { return "\(m)dk" }
    let h = m / 60
    if h < 24 { return "\(h)sa" }
    return "\(h/24)g"
}

// MARK: - App Tab

enum AppTab { case clipboard, snippets }

// MARK: - Design Tokens

private enum DS {
    static let hPad:    CGFloat = 14
    static let rowV:    CGFloat = 3
    static let radius:  CGFloat = 6
    static let width:   CGFloat = 360
}

// MARK: - Content View

struct ContentView: View {
    @State private var cm      = ClipboardManager()
    @State private var sm      = SimulatorManager()
    @State private var snm     = SnippetsManager()
    @State private var tab:    AppTab = .clipboard
    @State private var search  = ""
    @State private var showAdd = false
    @State private var addPrefill = ""

    var body: some View {
        VStack(spacing: 0) {
            ToolbarSection(tab: $tab, showAdd: $showAdd, addPrefill: $addPrefill)
            Divider()
            DeviceSection()
            Divider()

            switch tab {
            case .clipboard: ClipboardContent(search: $search)
            case .snippets:  SnippetsContent(showAdd: $showAdd, addPrefill: $addPrefill)
            }
        }
        .environment(cm)
        .environment(sm)
        .environment(snm)
        .frame(width: DS.width)
        .sheet(isPresented: $showAdd) {
            AddSnippetSheet(isPresented: $showAdd, initialText: addPrefill)
                .environment(snm)
        }
    }
}

// MARK: - Toolbar

struct ToolbarSection: View {
    @Binding var tab: AppTab
    @Binding var showAdd: Bool
    @Binding var addPrefill: String

    var body: some View {
        HStack(spacing: 10) {
            // Tab control
            Picker("", selection: $tab) {
                Label("Clipboard", systemImage: "clock.fill").tag(AppTab.clipboard)
                Label("Snippets",  systemImage: "bookmark.fill").tag(AppTab.snippets)
            }
            .pickerStyle(.segmented)
            .frame(width: 120)

            Spacer()

            if tab == .snippets {
                Button {
                    addPrefill = NSPasteboard.general.string(forType: .string) ?? ""
                    showAdd = true
                } label: {
                    Label("Yeni", systemImage: "plus")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
                .help("Snippet Ekle")
            }

            Button { NSApplication.shared.terminate(nil) } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.tertiary)
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.plain)
            .help("Uygulamayı Kapat")
        }
        .padding(.horizontal, DS.hPad)
        .padding(.vertical, 10)
    }
}

// MARK: - Device Section

struct DeviceSection: View {
    @Environment(SimulatorManager.self) private var sm
    @Environment(ClipboardManager.self) private var cm

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "iphone")
                .font(.callout)
                .foregroundStyle(.secondary)

            Group {
                if sm.noSimulatorRunning {
                    Text("Booted simülatör yok")
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                } else {
                    @Bindable var b = sm
                    Picker("", selection: $b.selectedID) {
                        ForEach(sm.devices) { d in
                            Text(d.name).tag(d.id)
                        }
                    }
                    .labelsHidden()
                    .font(.callout)
                }
            }

            Spacer()

            // Mac → Sim
            ActionChip(label: "→ Sim", tint: .green, tip: "Mac clipboard'ını simülatöre gönder") {
                let t = NSPasteboard.general.string(forType: .string) ?? ""
                guard !t.isEmpty else { return }
                sm.pushToSim(t)
            }
            .disabled(sm.selectedID.isEmpty)

            // Sim → Mac
            ActionChip(label: "← Mac", tint: .orange, tip: "Simülatör clipboard'ını Mac'e al") {
                Task {
                    if let t = await sm.pullFromSim() { cm.copyToMac(t) }
                }
            }
            .disabled(sm.selectedID.isEmpty)

            // Refresh
            Button { sm.refresh() } label: {
                Group {
                    if sm.isRefreshing {
                        ProgressView().scaleEffect(0.55).frame(width: 13, height: 13)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.callout)
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .help("Simülatörleri Yenile")
        }
        .padding(.horizontal, DS.hPad)
        .padding(.vertical, 9)
    }
}

struct ActionChip: View {
    let label: String
    let tint: Color
    let tip: String
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(hovered ? .white : tint)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(hovered ? tint : tint.opacity(0.12),
                            in: RoundedRectangle(cornerRadius: DS.radius))
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .help(tip)
        .animation(.easeInOut(duration: 0.12), value: hovered)
    }
}

// MARK: - Clipboard Content

struct ClipboardContent: View {
    @Environment(ClipboardManager.self) private var cm
    @Environment(SimulatorManager.self) private var sm
    @Binding var search: String

    var filtered: [ClipItem] {
        guard !search.isEmpty else { return Array(cm.history.prefix(10)) }
        return cm.history.filter { $0.content.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        VStack(spacing: 0) {

            // ── Aktif clipboard ────────────────────────────────
            if !cm.currentContent.isEmpty && search.isEmpty {
                CurrentClipCard()
                Divider()
            }

            // ── Arama ──────────────────────────────────────────
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.callout)
                    .foregroundStyle(.quaternary)
                TextField("Geçmişte ara…", text: $search)
                    .textFieldStyle(.plain)
                    .font(.callout)
                if !search.isEmpty {
                    Button { search = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.callout)
                            .foregroundStyle(.quaternary)
                    }.buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DS.hPad)
            .padding(.vertical, 8)

            Divider()

            // ── Liste ──────────────────────────────────────────
            if filtered.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: search.isEmpty ? "doc.on.clipboard" : "magnifyingglass")
                        .font(.system(size: 24))
                        .foregroundStyle(.quaternary)
                    Text(search.isEmpty ? "Henüz bir şey kopyalamadın" : "Sonuç bulunamadı")
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                // Section header
                HStack {
                    Text(search.isEmpty ? "Son 10 kopyalama" : "\(filtered.count) sonuç")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.tertiary)
                        .textCase(.uppercase)
                    Spacer()
                    if search.isEmpty && !cm.history.isEmpty {
                        Button("Temizle") { cm.clearAll() }
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, DS.hPad)
                .padding(.top, 8)
                .padding(.bottom, 4)

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filtered) { item in
                            ClipRow(item: item, isCurrent: item.content == cm.currentContent)
                            if item.id != filtered.last?.id {
                                Divider().padding(.leading, DS.hPad + 22)
                            }
                        }
                    }
                }
                .frame(maxHeight: 185)
                .padding(.bottom, 4)
            }
        }
    }
}

// MARK: - Current Clip Card

struct CurrentClipCard: View {
    @Environment(ClipboardManager.self) private var cm
    @Environment(SimulatorManager.self) private var sm
    @State private var copied = false
    @State private var sent   = false

    var kind: ContentKind { ContentKind.of(cm.currentContent) }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Label("Panoda", systemImage: kind.icon)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(kind.color)

                Text(cm.currentContent)
                    .font(.system(size: 13, design: kind == .text ? .default : .monospaced))
                    .lineLimit(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .foregroundStyle(.primary)
            }

            Divider()

            VStack(spacing: 6) {
                SmallIconButton(
                    icon: copied ? "checkmark" : "doc.on.doc",
                    label: copied ? "Kopyalandı" : "Kopyala",
                    tint: copied ? .green : .secondary
                ) {
                    cm.copyToMac(cm.currentContent)
                    copied = true
                    Task { try? await Task.sleep(for: .seconds(1.5)); copied = false }
                }

                SmallIconButton(
                    icon: sent ? "checkmark" : "iphone.and.arrow.forward",
                    label: sent ? "Gönderildi" : "Sim'e",
                    tint: sent ? .green : .secondary
                ) {
                    sm.pushToSim(cm.currentContent)
                    sent = true
                    Task { try? await Task.sleep(for: .seconds(1.5)); sent = false }
                }
                .disabled(sm.selectedID.isEmpty)
            }
            .frame(width: 52)
        }
        .padding(.horizontal, DS.hPad)
        .padding(.vertical, 10)
        .background(Color.accentColor.opacity(0.05))
    }
}

struct SmallIconButton: View {
    let icon: String
    let label: String
    let tint: Color
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(hovered ? tint : tint.opacity(0.8))
                Text(label)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 5)
            .background(hovered ? tint.opacity(0.1) : .clear,
                        in: RoundedRectangle(cornerRadius: DS.radius))
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .animation(.easeInOut(duration: 0.1), value: hovered)
    }
}

// MARK: - Clip Row

struct ClipRow: View {
    @Environment(ClipboardManager.self) private var cm
    @Environment(SimulatorManager.self) private var sm
    @Environment(SnippetsManager.self)  private var snm
    let item: ClipItem
    let isCurrent: Bool

    @State private var hovered = false
    @State private var copied  = false
    @State private var sent    = false

    var kind: ContentKind { ContentKind.of(item.content) }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: kind.icon)
                .font(.system(size: 10))
                .foregroundStyle(kind.color)
                .frame(width: 12)

            Text(item.content)
                .font(.system(size: 13, design: kind == .text ? .default : .monospaced))
                .lineLimit(1)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 2) {
                RowBtn(icon: copied ? "checkmark" : "doc.on.doc", tint: copied ? .green : .secondary) {
                    cm.copyToMac(item.content)
                    copied = true
                    Task { try? await Task.sleep(for: .seconds(1.5)); copied = false }
                }.help("Kopyala")

                RowBtn(icon: sent ? "checkmark" : "iphone.and.arrow.forward", tint: sent ? .green : .secondary) {
                    sm.pushToSim(item.content)
                    sent = true
                    Task { try? await Task.sleep(for: .seconds(1.5)); sent = false }
                }
                .disabled(sm.selectedID.isEmpty)
                .help("Simülatöre Gönder")
            }
            .opacity(hovered || isCurrent ? 1 : 0.15)
        }
        .padding(.leading, DS.hPad + 6)
        .padding(.trailing, DS.hPad)
        .padding(.vertical, DS.rowV)
        .background(
            isCurrent ? Color.accentColor.opacity(0.07) :
            hovered   ? Color.primary.opacity(0.05) : .clear
        )
        .animation(.easeInOut(duration: 0.1), value: hovered)
        .contentShape(Rectangle())
        .onHover { hovered = $0 }
        .onTapGesture {
            cm.copyToMac(item.content)
            copied = true
            Task { try? await Task.sleep(for: .seconds(1.5)); copied = false }
        }
        .contextMenu {
            Button("Kopyala")                { cm.copyToMac(item.content) }
            Button("Simülatöre Gönder")      { sm.pushToSim(item.content) }
            Button("Snippet Olarak Kaydet")  { snm.add(item.content) }
            Divider()
            Button("Sil", role: .destructive){ cm.remove(item) }
        }
    }
}

struct RowBtn: View {
    let icon: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Snippets Content

struct SnippetsContent: View {
    @Environment(SnippetsManager.self)  private var snm
    @Environment(ClipboardManager.self) private var cm
    @Binding var showAdd: Bool
    @Binding var addPrefill: String

    var body: some View {
        VStack(spacing: 0) {
            if snm.items.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "bookmark")
                        .font(.system(size: 28))
                        .foregroundStyle(.quaternary)
                    Text("Snippet yok")
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                    Text("Sık kullandığın metinleri\n+ butonu ile kaydet")
                        .font(.caption)
                        .foregroundStyle(.quaternary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 50)
            } else {
                HStack {
                    Text("\(snm.items.count) snippet")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.tertiary)
                        .textCase(.uppercase)
                    Spacer()
                }
                .padding(.horizontal, DS.hPad)
                .padding(.top, 8)
                .padding(.bottom, 4)

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(snm.items) { item in
                            SnippetRow(item: item)
                            if item.id != snm.items.last?.id {
                                Divider().padding(.leading, DS.hPad + 22)
                            }
                        }
                    }
                }
                .frame(maxHeight: 420)
                .padding(.bottom, 4)
            }
        }
    }
}

struct SnippetRow: View {
    @Environment(SnippetsManager.self)  private var snm
    @Environment(SimulatorManager.self) private var sm
    @Environment(ClipboardManager.self) private var cm
    let item: ClipItem

    @State private var hovered = false
    @State private var copied  = false
    @State private var sent    = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "bookmark.fill")
                .font(.system(size: 10))
                .foregroundStyle(Color.accentColor.opacity(0.6))
                .frame(width: 12)

            Text(item.content)
                .font(.system(size: 13))
                .lineLimit(2)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 2) {
                RowBtn(icon: copied ? "checkmark" : "doc.on.doc", tint: copied ? .green : .secondary) {
                    cm.copyToMac(item.content)
                    copied = true
                    Task { try? await Task.sleep(for: .seconds(1.5)); copied = false }
                }.help("Kopyala")

                RowBtn(icon: sent ? "checkmark" : "iphone.and.arrow.forward", tint: sent ? .green : .secondary) {
                    sm.pushToSim(item.content)
                    sent = true
                    Task { try? await Task.sleep(for: .seconds(1.5)); sent = false }
                }
                .disabled(sm.selectedID.isEmpty)
                .help("Simülatöre Gönder")
            }
            .opacity(hovered ? 1 : 0.15)
        }
        .padding(.leading, DS.hPad + 6)
        .padding(.trailing, DS.hPad)
        .padding(.vertical, DS.rowV)
        .background(hovered ? Color.primary.opacity(0.05) : .clear)
        .animation(.easeInOut(duration: 0.1), value: hovered)
        .contentShape(Rectangle())
        .onHover { hovered = $0 }
        .onTapGesture {
            cm.copyToMac(item.content)
            copied = true
            Task { try? await Task.sleep(for: .seconds(1.5)); copied = false }
        }
        .contextMenu {
            Button("Kopyala")                 { cm.copyToMac(item.content) }
            Button("Simülatöre Gönder")       { sm.pushToSim(item.content) }
            Divider()
            Button("Sil", role: .destructive) { snm.remove(item) }
        }
    }
}

// MARK: - Add Snippet Sheet

struct AddSnippetSheet: View {
    @Environment(SnippetsManager.self) private var snm
    @Binding var isPresented: Bool
    var initialText: String
    @State private var text = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Yeni Snippet")
                .font(.headline)

            TextEditor(text: $text)
                .font(.system(.body, design: .monospaced))
                .frame(height: 120)
                .scrollContentBackground(.hidden)
                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: DS.radius))
                .overlay(RoundedRectangle(cornerRadius: DS.radius)
                    .stroke(Color.primary.opacity(0.08)))

            HStack {
                Button("İptal") { isPresented = false }
                    .keyboardShortcut(.cancelAction)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Kaydet") { snm.add(text); isPresented = false }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(18)
        .frame(width: 320)
        .onAppear { text = initialText }
    }
}

#Preview {
    ContentView()
}

