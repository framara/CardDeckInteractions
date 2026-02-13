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
        Card(color: .red, title: "Red", sortOrder: 0),
        Card(color: .orange, title: "Orange", sortOrder: 1),
        Card(color: .yellow, title: "Yellow", sortOrder: 2),
        Card(color: .green, title: "Green", sortOrder: 3),
        Card(color: .blue, title: "Blue", sortOrder: 4),
        Card(color: .purple, title: "Purple", sortOrder: 5),
    ]
}
