import SwiftUI

struct SnippetsTab: View {
    @Environment(SnippetsManager.self) private var snm

    var body: some View {
        VStack(spacing: 0) {
            if snm.items.isEmpty {
                EmptyPane(
                    icon: "bookmark",
                    title: "No Snippets",
                    subtitle: "Save frequently used text\nfor quick access"
                )
            } else {
                SectionHeader(
                    title: "\(snm.items.count) snippet\(snm.items.count == 1 ? "" : "s")"
                ) { EmptyView() }

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(snm.items) { item in
                            SnippetRow(item: item)
                            if item.id != snm.items.last?.id {
                                Divider().padding(.leading, DS.hPad + 22)
                            }
                        }
                    }
                }
                .frame(maxHeight: 400)
                .padding(.bottom, 4)
            }
        }
    }
}
