import SwiftUI

enum CardAnimations {

    // MARK: - General Purpose

    /// Responsive spring for immediate feedback
    static let responsive = Animation.spring(duration: 0.3, bounce: 0.3)

    /// Extra bouncy for celebratory/emphasis moments
    static let extraBouncy = Animation.spring(duration: 0.4, bounce: 0.65)

    /// Interactive spring for gesture-driven animations
    static let interactive = Animation.interactiveSpring(response: 0.35, dampingFraction: 0.7)

    // MARK: - Hero Transitions

    /// Hero open/close transition
    static let heroTransition = Animation.spring(response: 0.35, dampingFraction: 0.85)

    // MARK: - Reorder

    /// Card reorder shift animation
    static let reorderShift = Animation.spring(response: 0.25, dampingFraction: 0.7)

    // MARK: - Dismiss

    /// Drag-to-dismiss spring
    static let dismiss = Animation.spring(response: 0.3, dampingFraction: 0.85)

    // MARK: - Staggered

    /// Quick stagger for list items based on index
    static func quickStagger(index: Int) -> Animation {
        responsive.delay(Double(index) * 0.04)
    }
}
