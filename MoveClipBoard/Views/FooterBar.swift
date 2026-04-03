import SwiftUI

struct FooterBar: View {
    var body: some View {
        HStack {
            Text("MoveClipBoard")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
            Spacer()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, DS.hPad)
        .padding(.vertical, 8)
    }
}
