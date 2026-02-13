# Card Deck Interactions

A standalone SwiftUI demo showcasing wallet-style card deck interactions — the kind Apple uses but barely documents.

Built as a focused reference project extracted from [ToMe](https://apps.apple.com/app/tome-organize-everything/id6738030824).

https://github.com/user-attachments/assets/placeholder-video.mp4

## Interactions

| Interaction | Description |
|-------------|-------------|
| **Stacked Layout** | Cards overlap in a compact stack with depth shadows |
| **Pull to Fan** | Overscroll pulls cards apart with resistance-based spreading |
| **Tap to Expand** | Hero animation transitions card to full-screen detail view |
| **Long-Press Drag to Reorder** | Hold a card, then drag to rearrange — other cards shift with spring animations |
| **Drag Down to Dismiss** | In expanded view, drag down with rubber-band resistance to close |
| **Bounce Animation** | Fast scroll-to-top triggers a staggered card bounce |
| **Haptic Feedback** | Every interaction is paired with appropriate haptic feedback |

## Architecture

```
Sources/CardDeckApp/
├── CardDeckApp.swift           # @main entry point
├── Models/
│   └── Card.swift              # Simple model: id, color, title, sortOrder
├── Views/
│   ├── DeckView.swift          # Orchestrator: hero animation + pull-to-fan
│   ├── CardStackView.swift     # Stacked layout + reorder + bounce
│   ├── ExpandedCardView.swift  # Full-screen card + drag-to-dismiss
│   └── DeckCardView.swift      # Single card visual (color + corner radius)
├── Gestures/
│   └── LongPressDragGesture.swift  # UIKit gesture wrapper for long-press + drag
└── Helpers/
    ├── Animations.swift        # Spring presets
    └── HapticManager.swift     # Simple haptic feedback
```

## Key Patterns

### Hero Transition with matchedGeometryEffect

```swift
// DeckView owns the namespace
@Namespace private var animation

// CardStackView tags each card
.matchedGeometryEffect(id: card.id, in: animation)

// ExpandedCardView uses the same ID
.matchedGeometryEffect(id: card.id, in: animation)

// Toggle with spring animation
withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
    selectedCard = card  // or nil to dismiss
}
```

### Pull-to-Fan via Overscroll

```swift
.onScrollGeometryChange(for: CGFloat.self) { geometry in
    geometry.contentOffset.y
} action: { _, newValue in
    let baseline = initialContentOffset ?? newValue
    let overscrollRaw = max(0, baseline - newValue)
    let resistanceFactor: CGFloat = 0.25
    stackedScrollOffset = overscrollRaw * resistanceFactor
}
```

The `stackedScrollOffset` is passed to `CardStackView` which spreads cards apart proportionally.

### Long-Press + Drag Reorder

Uses a `UIViewRepresentable` wrapping `UILongPressGestureRecognizer` because SwiftUI's gesture system can't handle long-press-then-drag on a single gesture surface covering overlapping cards. The wrapper:

1. Resolves which card is under the finger using coordinate math
2. Disables the parent `ScrollView` during drag
3. Reports tap, began, changed, ended, and cancelled events

### Drag-Down-to-Dismiss

```swift
.simultaneousGesture(
    DragGesture(minimumDistance: 20)
        .onChanged { value in
            if verticalAmount > 0 && canDragDownToDismiss {
                dragDownOffset = verticalAmount * 0.6  // resistance
            }
        }
        .onEnded { value in
            if dragDownOffset > 120 || (velocity > 1.5 && dragDownOffset > 60) {
                // Dismiss
            }
        }
)
```

## Requirements

- iOS 18.0+
- Swift 6
- Xcode 16+

## Run

```bash
open Package.swift  # Opens in Xcode
# Select an iOS Simulator target, then Build & Run (⌘R)
```

Or from the command line:

```bash
xcodebuild -scheme CardDeckInteractions \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build
```

## Related

- [SwiftDataSharing](https://github.com/paco-gg/SwiftDataSharing) — SwiftData + CloudKit sharing demo
- [CloudKitSharing](https://github.com/paco-gg/CloudKitSharing) — CloudKit collaboration demo

## License

MIT
