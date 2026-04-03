import SwiftUI

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
