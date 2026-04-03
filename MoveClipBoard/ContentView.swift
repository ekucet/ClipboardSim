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
    if s < 2  { return "now" }
    if s < 60 { return "\(s)s" }
    let m = s / 60
    if m < 60 { return "\(m)m" }
    let h = m / 60
    if h < 24 { return "\(h)h" }
    return "\(h/24)d"
}

// MARK: - App Tab

enum AppTab { case clipboard, snippets }

// MARK: - Design Tokens

private enum DS {
    static let hPad:   CGFloat = 16
    static let rowV:   CGFloat = 5
    static let radius: CGFloat = 8
    static let width:  CGFloat = 380
}

// MARK: - Content View

struct ContentView: View {
    @State private var cm        = ClipboardManager()
    @State private var sm        = SimulatorManager()
    @State private var snm       = SnippetsManager()
    @State private var tab:      AppTab = .clipboard
    @State private var search    = ""
    @State private var showAdd   = false
    @State private var addPrefill = ""

    var body: some View {
        VStack(spacing: 0) {
            HeaderBar(tab: $tab, showAdd: $showAdd, addPrefill: $addPrefill)
            Divider()
            SimulatorBar()
            Divider()
            switch tab {
            case .clipboard: ClipboardTab(search: $search)
            case .snippets:  SnippetsTab()
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

// MARK: - Header Bar

struct HeaderBar: View {
    @Binding var tab: AppTab
    @Binding var showAdd: Bool
    @Binding var addPrefill: String

    var body: some View {
        HStack(spacing: 10) {
            // App identity
            HStack(spacing: 6) {
                Image(systemName: "doc.on.clipboard.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                Text("MoveClipBoard")
                    .font(.system(size: 13, weight: .semibold))
            }

            Spacer()

            // Tab switcher — icon-only segmented control
            Picker("", selection: $tab) {
                Image(systemName: "clock").tag(AppTab.clipboard)
                Image(systemName: "bookmark").tag(AppTab.snippets)
            }
            .pickerStyle(.segmented)
            .frame(width: 72)
            .help("Switch tab")

            // Add button (snippets only)
            if tab == .snippets {
                Button {
                    addPrefill = NSPasteboard.general.string(forType: .string) ?? ""
                    showAdd = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 22, height: 22)
                        .background(Color.accentColor.opacity(0.1),
                                    in: RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
                .help("Add Snippet")
                .transition(.scale(scale: 0.8).combined(with: .opacity))
            }

            // Quit
            Button { NSApplication.shared.terminate(nil) } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(.quaternary)
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.plain)
            .help("Quit MoveClipBoard")
        }
        .padding(.horizontal, DS.hPad)
        .padding(.vertical, 11)
        .animation(.easeInOut(duration: 0.15), value: tab)
    }
}

// MARK: - Simulator Bar

struct SimulatorBar: View {
    @Environment(SimulatorManager.self) private var sm
    @Environment(ClipboardManager.self) private var cm

    var body: some View {
        HStack(spacing: 8) {
            // Device picker
            HStack(spacing: 6) {
                Image(systemName: "iphone")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 16)

                if sm.noSimulatorRunning {
                    Text("No booted simulator")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                } else {
                    @Bindable var b = sm
                    Picker("", selection: $b.selectedID) {
                        ForEach(sm.devices) { d in
                            Text(d.name).tag(d.id)
                        }
                    }
                    .labelsHidden()
                    .font(.system(size: 12))
                    .fixedSize()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Actions
            HStack(spacing: 6) {
                SyncChip(label: "→ Sim", tint: .green, tip: "Send Mac clipboard to Simulator") {
                    let t = NSPasteboard.general.string(forType: .string) ?? ""
                    guard !t.isEmpty else { return }
                    sm.pushToSim(t)
                }
                .disabled(sm.selectedID.isEmpty)

                SyncChip(label: "← Mac", tint: .orange, tip: "Pull Simulator clipboard to Mac") {
                    Task {
                        if let t = await sm.pullFromSim() { cm.copyToMac(t) }
                    }
                }
                .disabled(sm.selectedID.isEmpty)

                Button { sm.refresh() } label: {
                    ZStack {
                        if sm.isRefreshing {
                            ProgressView().scaleEffect(0.5).frame(width: 14, height: 14)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .help("Refresh Simulators")
            }
        }
        .padding(.horizontal, DS.hPad)
        .padding(.vertical, 9)
    }
}

struct SyncChip: View {
    let label: String
    let tint: Color
    let tip: String
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(hovered ? .white : tint)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(
                    hovered ? tint : tint.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 6)
                )
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .help(tip)
        .animation(.easeInOut(duration: 0.1), value: hovered)
    }
}

// MARK: - Clipboard Tab

struct ClipboardTab: View {
    @Environment(ClipboardManager.self) private var cm
    @Binding var search: String

    var filtered: [ClipItem] {
        guard !search.isEmpty else { return Array(cm.history.prefix(10)) }
        return cm.history.filter { $0.content.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        VStack(spacing: 0) {
            if !cm.currentContent.isEmpty && search.isEmpty {
                CurrentClipCard()
                Divider()
            }

            SearchBar(text: $search, placeholder: "Search history…")
            Divider()

            if filtered.isEmpty {
                EmptyPane(
                    icon: search.isEmpty ? "doc.on.clipboard" : "magnifyingglass",
                    title: search.isEmpty ? "Nothing copied yet" : "No results",
                    subtitle: search.isEmpty
                        ? "Items you copy will appear here"
                        : "Try a different search term"
                )
            } else {
                SectionHeader(
                    title: search.isEmpty
                        ? "Recent"
                        : "\(filtered.count) result\(filtered.count == 1 ? "" : "s")"
                ) {
                    if search.isEmpty && !cm.history.isEmpty {
                        Button("Clear All") { cm.clearAll() }
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                            .buttonStyle(.plain)
                    }
                }

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
                .frame(maxHeight: 220)
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
        HStack(alignment: .top, spacing: 12) {
            // Type badge
            Image(systemName: kind.icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(kind.color)
                .frame(width: 30, height: 30)
                .background(kind.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 7))

            VStack(alignment: .leading, spacing: 4) {
                Text("On Clipboard")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .kerning(0.4)

                Text(cm.currentContent)
                    .font(.system(size: 12, design: kind == .text ? .default : .monospaced))
                    .lineLimit(3)
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Action buttons
            VStack(spacing: 4) {
                CardActionButton(
                    icon: copied ? "checkmark" : "doc.on.doc.fill",
                    label: copied ? "Copied!" : "Copy",
                    tint: copied ? .green : Color.accentColor
                ) {
                    cm.copyToMac(cm.currentContent)
                    withAnimation { copied = true }
                    Task { try? await Task.sleep(for: .seconds(1.5)); withAnimation { copied = false } }
                }

                CardActionButton(
                    icon: sent ? "checkmark" : "arrow.right.to.line",
                    label: sent ? "Sent!" : "→ Sim",
                    tint: sent ? .green : .orange
                ) {
                    sm.pushToSim(cm.currentContent)
                    withAnimation { sent = true }
                    Task { try? await Task.sleep(for: .seconds(1.5)); withAnimation { sent = false } }
                }
                .disabled(sm.selectedID.isEmpty)
            }
        }
        .padding(.horizontal, DS.hPad)
        .padding(.vertical, 11)
        .background(Color.accentColor.opacity(0.04))
    }
}

struct CardActionButton: View {
    let icon: String
    let label: String
    let tint: Color
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(label)
                    .font(.system(size: 9, weight: .medium))
            }
            .foregroundStyle(hovered ? tint : tint.opacity(0.75))
            .frame(width: 50)
            .padding(.vertical, 5)
            .background(
                hovered ? tint.opacity(0.1) : Color.primary.opacity(0.04),
                in: RoundedRectangle(cornerRadius: 6)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .animation(.easeInOut(duration: 0.1), value: hovered)
    }
}

// MARK: - Search Bar

struct SearchBar: View {
    @Binding var text: String
    let placeholder: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.quaternary)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 13))

            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.quaternary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, DS.hPad)
        .padding(.vertical, 9)
    }
}

// MARK: - Section Header

struct SectionHeader<T: View>: View {
    let title: String
    @ViewBuilder var trailing: T

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.tertiary)
                .kerning(0.5)
            Spacer()
            trailing
        }
        .padding(.horizontal, DS.hPad)
        .padding(.top, 10)
        .padding(.bottom, 5)
    }
}

// MARK: - Empty Pane

struct EmptyPane: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.quaternary)
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
            Text(subtitle)
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .padding(.horizontal, DS.hPad)
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
            // Type icon badge
            Image(systemName: kind.icon)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(isCurrent ? Color.accentColor : kind.color)
                .frame(width: 14, height: 14)
                .padding(4)
                .background(
                    (isCurrent ? Color.accentColor : kind.color).opacity(0.1),
                    in: RoundedRectangle(cornerRadius: 4)
                )

            Text(item.content)
                .font(.system(size: 12, design: kind == .text ? .default : .monospaced))
                .lineLimit(1)
                .foregroundStyle(isCurrent ? .primary : .secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Action buttons — visible on hover or when current
            HStack(spacing: 1) {
                RowIconBtn(
                    icon: copied ? "checkmark" : "doc.on.doc",
                    tint: copied ? .green : .secondary
                ) {
                    cm.copyToMac(item.content)
                    copied = true
                    Task { try? await Task.sleep(for: .seconds(1.5)); copied = false }
                }
                .help("Copy")

                RowIconBtn(
                    icon: sent ? "checkmark" : "arrow.right.to.line",
                    tint: sent ? .green : .secondary
                ) {
                    sm.pushToSim(item.content)
                    sent = true
                    Task { try? await Task.sleep(for: .seconds(1.5)); sent = false }
                }
                .disabled(sm.selectedID.isEmpty)
                .help("Send to Simulator")
            }
            .opacity(hovered || isCurrent ? 1 : 0)
        }
        .padding(.horizontal, DS.hPad)
        .padding(.vertical, DS.rowV)
        .background(
            isCurrent ? Color.accentColor.opacity(0.06) :
            hovered   ? Color.primary.opacity(0.04) : .clear
        )
        .contentShape(Rectangle())
        .onHover { hovered = $0 }
        .onTapGesture { cm.copyToMac(item.content) }
        .contextMenu {
            Button("Copy")                       { cm.copyToMac(item.content) }
            Button("Send to Simulator")          { sm.pushToSim(item.content) }
            Button("Save as Snippet")            { snm.add(item.content) }
            Divider()
            Button("Delete", role: .destructive) { cm.remove(item) }
        }
        .animation(.easeInOut(duration: 0.1), value: hovered)
    }
}

struct RowIconBtn: View {
    let icon: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 26, height: 26)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Snippets Tab

struct SnippetsTab: View {
    @Environment(SnippetsManager.self) private var snm

    var body: some View {
        VStack(spacing: 0) {
            if snm.items.isEmpty {
                EmptyPane(
                    icon: "bookmark",
                    title: "No Snippets",
                    subtitle: "Save frequently used text\nfor quick access"
                )
            } else {
                SectionHeader(
                    title: "\(snm.items.count) snippet\(snm.items.count == 1 ? "" : "s")"
                ) { EmptyView() }

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
                .frame(maxHeight: 400)
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
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.accentColor.opacity(0.7))
                .frame(width: 14, height: 14)
                .padding(4)
                .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 4))

            Text(item.content)
                .font(.system(size: 12))
                .lineLimit(2)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 1) {
                RowIconBtn(
                    icon: copied ? "checkmark" : "doc.on.doc",
                    tint: copied ? .green : .secondary
                ) {
                    cm.copyToMac(item.content)
                    copied = true
                    Task { try? await Task.sleep(for: .seconds(1.5)); copied = false }
                }
                .help("Copy")

                RowIconBtn(
                    icon: sent ? "checkmark" : "arrow.right.to.line",
                    tint: sent ? .green : .secondary
                ) {
                    sm.pushToSim(item.content)
                    sent = true
                    Task { try? await Task.sleep(for: .seconds(1.5)); sent = false }
                }
                .disabled(sm.selectedID.isEmpty)
                .help("Send to Simulator")
            }
            .opacity(hovered ? 1 : 0)
        }
        .padding(.horizontal, DS.hPad)
        .padding(.vertical, DS.rowV)
        .background(hovered ? Color.primary.opacity(0.04) : .clear)
        .contentShape(Rectangle())
        .onHover { hovered = $0 }
        .onTapGesture {
            cm.copyToMac(item.content)
            copied = true
            Task { try? await Task.sleep(for: .seconds(1.5)); copied = false }
        }
        .contextMenu {
            Button("Copy")                       { cm.copyToMac(item.content) }
            Button("Send to Simulator")          { sm.pushToSim(item.content) }
            Divider()
            Button("Delete", role: .destructive) { snm.remove(item) }
        }
        .animation(.easeInOut(duration: 0.1), value: hovered)
    }
}

// MARK: - Add Snippet Sheet

struct AddSnippetSheet: View {
    @Environment(SnippetsManager.self) private var snm
    @Binding var isPresented: Bool
    var initialText: String
    @State private var text = ""

    var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label("New Snippet", systemImage: "bookmark.fill")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 14)

            Divider()

            TextEditor(text: $text)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: DS.radius)
                        .fill(Color.primary.opacity(0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.radius)
                                .stroke(Color.primary.opacity(0.08))
                        )
                )
                .frame(height: 130)
                .padding(.horizontal, 20)
                .padding(.top, 16)

            HStack {
                Button("Cancel") { isPresented = false }
                    .keyboardShortcut(.cancelAction)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Save") { snm.add(text); isPresented = false }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(trimmed.isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 18)
        }
        .frame(width: 340)
        .onAppear { text = initialText }
    }
}

#Preview {
    ContentView()
}

