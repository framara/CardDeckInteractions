# Card Deck Interactions

A minimal, working reference project showing how to build **wallet-style card deck interactions in SwiftUI** — stacked layout, pull-to-fan, hero transitions, long-press reorder, and drag-to-dismiss.

This is the animation pattern Apple uses in Wallet but barely documents. There is no clean, end-to-end example showing how to combine `matchedGeometryEffect`, `UILongPressGestureRecognizer`, scroll geometry tracking, and spring animations into a cohesive card deck. This repo is that example.

> Extracted from [ToMe](https://framara.net/projects/ToMe), an iOS app for saving and organizing content from anywhere.

https://github.com/user-attachments/assets/placeholder-video.mp4

## The Problem

You want a card deck UI with these interactions:

| Interaction | Challenge |
|-------------|-----------|
| Stacked cards with overlap | Negative spacing + z-index management for correct tap targeting |
| Pull down to fan cards apart | Must capture overscroll from `ScrollView` with resistance factor |
| Tap to expand with hero animation | `matchedGeometryEffect` across two different view hierarchies |
| Long-press + drag to reorder | SwiftUI gestures can't handle this on overlapping views inside a `ScrollView` |
| Drag down to dismiss | Must coexist with scroll content and use velocity-based thresholds |
| Haptic feedback | Paired with every interaction for tactile polish |

SwiftUI provides the building blocks but no guidance on combining them. The gesture system in particular falls apart when you need long-press-then-drag on overlapping cards inside a scroll view.

## The Solution

### 1. UIKit Gesture Wrapper

SwiftUI's gesture system can't resolve which overlapping card is under the finger, or handle long-press-then-drag while coexisting with a parent `ScrollView`. The solution is a `UIViewRepresentable` wrapping `UILongPressGestureRecognizer`:

```swift
LongPressDragGestureView(
    minimumPressDuration: 0.4,
    onTapAt: { location in /* resolve card via coordinate math */ },
    onBeganAt: { location in /* start reorder */ },
    onChanged: { translationY in /* update drag offset */ },
    onEnded: { /* commit reorder */ }
)
```

It disables the parent `ScrollView` during drag and resolves card identity using `pickCard(at:)` coordinate math.

### 2. Pull-to-Fan via Overscroll

```swift
.onScrollGeometryChange(for: CGFloat.self) { geometry in
    geometry.contentOffset.y
} action: { _, newValue in
    let baseline = initialContentOffset ?? newValue
    let overscrollRaw = max(0, baseline - newValue)
    stackedScrollOffset = overscrollRaw * 0.25  // resistance factor
}
```

The `stackedScrollOffset` is passed to `CardStackView` which spreads cards apart proportionally:

```swift
let spreadPerCard = min(pullAmount * 0.8, 150)
// Each card offsets by: anchorOffset + (spreadPerCard * index)
```

### 3. Hero Transition

```swift
// DeckView owns the namespace
@Namespace private var animation

// Both CardStackView and ExpandedCardView tag the same card ID
.matchedGeometryEffect(id: card.id, in: animation)

// Toggle with spring animation
withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
    selectedCard = card  // or nil to dismiss
}
```

### 4. Drag-Down-to-Dismiss

```swift
.simultaneousGesture(
    DragGesture(minimumDistance: 20)
        .onChanged { value in
            if verticalAmount > 0 && canDragDownToDismiss {
                dragDownOffset = verticalAmount * 0.6  // rubber-band resistance
            }
        }
        .onEnded { value in
            // Dismiss if offset > 120pt OR velocity > 1.5 && offset > 60pt
        }
)
```

Visual feedback during drag: `.offset(y:)`, `.opacity(1 - progress*0.3)`, `.scaleEffect(1 - progress*0.1, anchor: .top)`.

### 5. Scroll-Driven Card Fade

The expanded card header fades and scales as you scroll down, tracking the finger directly (no animation):

```swift
.opacity(max(0.0, 1.0 - (scrollOffset / 200.0)))
.scaleEffect(max(0.85, 1.0 - (scrollOffset / 800.0)))
.animation(nil, value: scrollOffset)  // Track finger, don't animate
```

## Project Structure

```
CardDeckInteractions/
├── project.yml                         # XcodeGen project definition
└── Sources/
    └── App/
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
            ├── Animations.swift        # Spring presets (hero, reorder, dismiss, bounce)
            └── HapticManager.swift     # Simple haptic feedback
```

## Quick Start

The project uses [XcodeGen](https://github.com/yonaskolb/XcodeGen) to generate the `.xcodeproj` from `project.yml`. This avoids `.pbxproj` merge conflicts and keeps the setup reproducible.

```bash
# 1. Install XcodeGen (if you don't have it)
brew install xcodegen

# 2. Generate the Xcode project
xcodegen generate

# 3. Open and run
open CardDeckInteractions.xcodeproj
```

Select an iOS Simulator target and press **Cmd+R**.

## Key Patterns

### Staggered Card Bounce

A two-stage animation triggered by fast scroll-to-top or shake:

```swift
for index in cards.indices {
    // Stage 1: Jump up with quick stagger
    withAnimation(.spring(duration: 0.3, bounce: 0.3).delay(Double(index) * 0.04)) {
        cardBounceOffsets[index] = -CGFloat.random(in: 15...30)
    }

    // Stage 2: Fall back with extra bouncy settle
    DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.04 + 0.15) {
        withAnimation(.spring(duration: 0.4, bounce: 0.65)) {
            cardBounceOffsets[index] = 0
        }
    }
}
```

### Reorder Card Shifting

Non-dragged cards shift with spring animations to make room:

```swift
// Cards between start and drop index shift by ±64pt
.animation(.spring(response: 0.25, dampingFraction: 0.7), value: reorderOffset)
```

### Spring Presets

All animations use curated spring presets for consistency:

| Preset | Usage | Parameters |
|--------|-------|------------|
| `heroTransition` | Card open/close | `response: 0.35, damping: 0.85` |
| `reorderShift` | Card shifting during drag | `response: 0.25, damping: 0.7` |
| `dismiss` | Drag-to-dismiss | `response: 0.3, damping: 0.85` |
| `extraBouncy` | Bounce settle | `duration: 0.4, bounce: 0.65` |
| `responsive` | Quick feedback | `duration: 0.3, bounce: 0.3` |

## Common Pitfalls

| Pitfall | Solution |
|---------|----------|
| Taps register on wrong overlapping card | Use coordinate-based `pickCard(at:)` on a single gesture surface, not per-card gestures |
| Long-press fights with ScrollView | Disable `ScrollView.isScrollEnabled` when drag begins, restore on end |
| `matchedGeometryEffect` flickers | Ensure the same `id` and `Namespace` are used in both stacked and expanded states |
| Scroll-driven effects animate instead of tracking | Use `.animation(nil, value: scrollOffset)` to suppress interpolation |
| Overscroll keeps spreading cards | Capture a baseline offset once and measure relative to it, not the current offset |
| Cards jitter during reorder | Use `zIndex` to keep the dragged card above all others |

## Requirements

- iOS 18.0+
- Xcode 16+
- Swift 6
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

## Related

- [SwiftDataSharing](https://github.com/paco-gg/SwiftDataSharing) — SwiftData + App Group sharing across app, extension, and widget
- [CloudKitSharing](https://github.com/paco-gg/CloudKitSharing) — CloudKit sharing + SwiftData with permission management

## Credits

Extracted from [ToMe](https://framara.net/projects/ToMe) by [framara](https://framara.net).

## License

MIT
