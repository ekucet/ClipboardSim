import Foundation

struct ClipItem: Identifiable, Codable {
    let id: UUID
    let content: String
    let date: Date

    init(_ content: String) {
        id = UUID()
        self.content = content
        date = Date()
    }
}
