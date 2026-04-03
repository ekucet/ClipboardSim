import Foundation

@MainActor @Observable
class SnippetsManager {
    var items: [ClipItem] = []

    init() { load() }

    func add(_ content: String) {
        let t = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        items.removeAll { $0.content == t }
        items.insert(ClipItem(t), at: 0)
        save()
    }

    func remove(_ item: ClipItem) {
        items.removeAll { $0.id == item.id }
        save()
    }

    private func save() {
        if let d = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(d, forKey: "snippetsV2")
        }
    }

    private func load() {
        guard let d = UserDefaults.standard.data(forKey: "snippetsV2"),
              let arr = try? JSONDecoder().decode([ClipItem].self, from: d) else { return }
        items = arr
    }
}
