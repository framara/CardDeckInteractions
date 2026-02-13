import UIKit

@MainActor
final class HapticManager {
    static let shared = HapticManager()
    private init() {}

    func impact(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    func notification(type: UINotificationFeedbackGenerator.FeedbackType) {
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }

    func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}
