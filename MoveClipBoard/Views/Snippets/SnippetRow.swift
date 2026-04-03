import SwiftUI

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
