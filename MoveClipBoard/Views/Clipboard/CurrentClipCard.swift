import SwiftUI

struct CurrentClipCard: View {
    @Environment(ClipboardManager.self) private var cm
    @Environment(SimulatorManager.self) private var sm
    @State private var copied = false
    @State private var sent   = false

    var kind: ContentKind { ContentKind.of(cm.currentContent) }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: kind.icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(kind.color)
                .frame(width: 30, height: 30)
                .background(kind.color.opacity(0.14), in: RoundedRectangle(cornerRadius: 7))

            VStack(alignment: .leading, spacing: 4) {
                Text("ON CLIPBOARD")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .kerning(0.8)

                Text(cm.currentContent)
                    .font(.system(size: 12, design: kind == .text ? .default : .monospaced))
                    .lineLimit(3)
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

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
