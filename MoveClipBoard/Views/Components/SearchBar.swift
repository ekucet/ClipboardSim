import SwiftUI

struct SearchBar: View {
    @Binding var text: String
    let placeholder: String
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isFocused ? Color.accentColor.opacity(0.7) : Color.primary.opacity(0.35))

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .focused($isFocused)

            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(isFocused ? 0.07 : 0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(isFocused ? Color.accentColor.opacity(0.35) : Color.clear, lineWidth: 1)
                )
        )
        .padding(.horizontal, DS.hPad)
        .padding(.vertical, 8)
        .animation(.easeInOut(duration: 0.15), value: isFocused)
    }
}
