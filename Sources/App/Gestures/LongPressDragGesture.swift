import SwiftUI
import UIKit

/// A UIKit gesture wrapper that combines tap recognition with long-press-then-drag.
///
/// The long press disables the parent ScrollView during the drag so reorder gestures
/// don't fight with scrolling. Once the gesture ends, scroll is restored.
struct LongPressDragGestureView: UIViewRepresentable {
    var minimumPressDuration: TimeInterval = 0.4
    var allowableMovement: CGFloat = 12

    /// Locations are reported in this view's local coordinate space.
    var onTapAt: ((CGPoint) -> Void)?
    var onBeganAt: ((CGPoint) -> Void)?
    var onChanged: ((CGFloat) -> Void)?
    var onEnded: (() -> Void)?
    var onCancelled: (() -> Void)?

    func makeUIView(context: Context) -> UIView {
        let view = TouchPassthroughView()
        view.backgroundColor = .clear

        let tapRecognizer = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        tapRecognizer.cancelsTouchesInView = false
        tapRecognizer.delegate = context.coordinator

        let recognizer = UILongPressGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleLongPress(_:))
        )
        recognizer.minimumPressDuration = minimumPressDuration
        recognizer.allowableMovement = allowableMovement
        recognizer.cancelsTouchesInView = false
        recognizer.delegate = context.coordinator

        // If the long-press succeeds, a tap should not fire.
        tapRecognizer.require(toFail: recognizer)

        context.coordinator.longPressRecognizer = recognizer
        context.coordinator.tapRecognizer = tapRecognizer

        view.addGestureRecognizer(tapRecognizer)
        view.addGestureRecognizer(recognizer)

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.longPressRecognizer?.minimumPressDuration = minimumPressDuration
        context.coordinator.longPressRecognizer?.allowableMovement = allowableMovement
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var parent: LongPressDragGestureView
        weak var longPressRecognizer: UILongPressGestureRecognizer?
        weak var tapRecognizer: UITapGestureRecognizer?

        private var startLocationInWindow: CGPoint?
        private weak var activeScrollView: UIScrollView?
        private var activeScrollWasEnabled: Bool?

        init(parent: LongPressDragGestureView) {
            self.parent = parent
        }

        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard recognizer.state == .ended else { return }
            let location = recognizer.location(in: recognizer.view)
            parent.onTapAt?(location)
        }

        @objc func handleLongPress(_ recognizer: UILongPressGestureRecognizer) {
            switch recognizer.state {
            case .began:
                startLocationInWindow = recognizer.location(in: recognizer.view?.window)

                if let scrollView = findNearestScrollView(from: recognizer.view) {
                    activeScrollView = scrollView
                    activeScrollWasEnabled = scrollView.isScrollEnabled

                    // Make reorder fully exclusive by cancelling the scroll pan.
                    scrollView.isScrollEnabled = false
                    scrollView.panGestureRecognizer.isEnabled = false
                    scrollView.panGestureRecognizer.isEnabled = true
                }

                let localLocation = recognizer.location(in: recognizer.view)
                parent.onBeganAt?(localLocation)

            case .changed:
                guard let start = startLocationInWindow else { return }
                let current = recognizer.location(in: recognizer.view?.window)
                parent.onChanged?(current.y - start.y)

            case .ended:
                startLocationInWindow = nil
                restoreScrollIfNeeded()
                parent.onEnded?()

            case .cancelled, .failed:
                startLocationInWindow = nil
                restoreScrollIfNeeded()
                parent.onCancelled?()

            default:
                break
            }
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            // If the user is already scrolling, don't begin the long-press.
            if let longPress = longPressRecognizer, gestureRecognizer === longPress {
                if let scrollView = findNearestScrollView(from: longPress.view) {
                    let panState = scrollView.panGestureRecognizer.state
                    if panState == .began || panState == .changed {
                        return false
                    }
                }
            }
            return true
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            // Let the ScrollView pan gesture work normally until the long-press has actually begun.
            if let longPress = longPressRecognizer, gestureRecognizer === longPress {
                switch longPress.state {
                case .began, .changed:
                    return false
                default:
                    return true
                }
            }
            return true
        }

        private func findNearestScrollView(from view: UIView?) -> UIScrollView? {
            var current = view?.superview
            while let v = current {
                if let scroll = v as? UIScrollView {
                    return scroll
                }
                current = v.superview
            }
            return nil
        }

        private func restoreScrollIfNeeded() {
            if let scrollView = activeScrollView, let wasEnabled = activeScrollWasEnabled {
                scrollView.isScrollEnabled = wasEnabled
            }
            activeScrollView = nil
            activeScrollWasEnabled = nil
        }
    }

    /// A view that doesn't intercept hit-testing; it only observes touches via the gesture recognizer.
    private final class TouchPassthroughView: UIView {
        override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
            true
        }
    }
}
