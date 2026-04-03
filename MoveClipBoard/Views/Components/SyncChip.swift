import SwiftUI

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
