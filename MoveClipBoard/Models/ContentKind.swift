import SwiftUI

enum ContentKind {
    case url, json, path, text

    static func of(_ s: String) -> ContentKind {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.hasPrefix("http://") || t.hasPrefix("https://") { return .url }
        if (t.hasPrefix("{") || t.hasPrefix("[")) && t.count < 2000 { return .json }
        if t.hasPrefix("/") && !t.contains(" ") && !t.contains("\n") { return .path }
        return .text
    }

    var icon: String {
        switch self {
        case .url:  return "link"
        case .json: return "curlybraces"
        case .path: return "folder"
        case .text: return "doc.text"
        }
    }

    var color: Color {
        switch self {
        case .url:  return .blue
        case .json: return .orange
        case .path: return .purple
        case .text: return .secondary
        }
    }
}
