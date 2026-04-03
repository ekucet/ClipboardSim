import SwiftUI

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
