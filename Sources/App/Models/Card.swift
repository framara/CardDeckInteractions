import SwiftUI

struct Card: Identifiable {
    let id: UUID
    var color: Color
    var title: String
    var sortOrder: Int

    init(id: UUID = UUID(), color: Color, title: String, sortOrder: Int) {
        self.id = id
        self.color = color
        self.title = title
        self.sortOrder = sortOrder
    }

    static let samples: [Card] = [
        Card(color: Color(red: 0.15, green: 0.15, blue: 0.15), title: "Obsidian", sortOrder: 0),
        Card(color: Color(red: 0.83, green: 0.18, blue: 0.18), title: "Crimson", sortOrder: 1),
        Card(color: Color(red: 0.20, green: 0.45, blue: 0.85), title: "Cobalt", sortOrder: 2),
        Card(color: Color(red: 0.96, green: 0.65, blue: 0.14), title: "Amber", sortOrder: 3),
        Card(color: Color(red: 0.18, green: 0.62, blue: 0.52), title: "Teal", sortOrder: 4),
        Card(color: Color(red: 0.55, green: 0.35, blue: 0.75), title: "Violet", sortOrder: 5),
    ]
}
