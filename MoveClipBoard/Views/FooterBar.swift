import SwiftUI

struct FooterBar: View {
    @State private var quitHovered = false

    var body: some View {
        HStack {
            HStack(spacing: 5) {
                Image(systemName: "doc.on.clipboard.fill")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.quaternary)
                Text("MoveClipBoard")
                    .font(.system(size: 11))
                    .foregroundStyle(.quaternary)
            }

            Spacer()

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "power")
                        .font(.system(size: 10, weight: .semibold))
                    Text("Quit")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(quitHovered ? .white : Color.red.opacity(0.85))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    quitHovered ? Color.red : Color.red.opacity(0.1),
                    in: RoundedRectangle(cornerRadius: 6)
                )
            }
            .buttonStyle(.plain)
            .onHover { quitHovered = $0 }
            .animation(.easeInOut(duration: 0.12), value: quitHovered)
        }
        .padding(.horizontal, DS.hPad)
        .padding(.vertical, 9)
    }
}
