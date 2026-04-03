import SwiftUI

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
