import SwiftUI
import AppKit

struct HeaderBar: View {
    @Binding var tab: AppTab
    @Binding var showAdd: Bool
    @Binding var addPrefill: String

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "doc.on.clipboard.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                Text("MoveClipBoard")
                    .font(.system(size: 13, weight: .semibold))
            }

            Spacer()

            Picker("", selection: $tab) {
                Image(systemName: "clock").tag(AppTab.clipboard)
                Image(systemName: "bookmark").tag(AppTab.snippets)
            }
            .pickerStyle(.segmented)
            .frame(width: 72)
            .help("Switch tab")

            if tab == .snippets {
                Button {
                    addPrefill = NSPasteboard.general.string(forType: .string) ?? ""
                    showAdd = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 22, height: 22)
                        .background(Color.accentColor.opacity(0.1),
                                    in: RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
                .help("Add Snippet")
                .transition(.scale(scale: 0.8).combined(with: .opacity))
            }

            Button { NSApplication.shared.terminate(nil) } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(.quaternary)
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.plain)
            .help("Quit MoveClipBoard")
        }
        .padding(.horizontal, DS.hPad)
        .padding(.vertical, 11)
        .animation(.easeInOut(duration: 0.15), value: tab)
    }
}
