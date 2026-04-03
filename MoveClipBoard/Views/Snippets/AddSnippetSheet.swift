import SwiftUI

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
