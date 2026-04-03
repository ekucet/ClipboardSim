import Foundation

struct SimDevice: Identifiable {
    let id: String
    let name: String
    let runtime: String
    var label: String { "\(name) · \(runtime)" }
}
