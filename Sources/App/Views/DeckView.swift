import SwiftUI

/// Main orchestrator view — manages the card deck, hero transitions, and pull-to-fan.
///
/// Mirrors ToMe's `WalletView`:
/// - Owns `@Namespace` for matchedGeometryEffect hero transitions
/// - `@State var selectedCard` toggles between stacked and expanded states
/// - `onScrollGeometryChange` captures overscroll for the pull-to-fan effect
struct DeckView: View {
    @Namespace private var animation
    @State private var selectedCard: Card?
    @State private var cards: [Card] = Card.samples
    @State private var scrollOffset: CGFloat = 0
    @State private var stackedScrollOffset: CGFloat = 0
    @State private var initialContentOffset: CGFloat?
    @State private var cardBounceTrigger: Int = 0
    @State private var isReorderingCards: Bool = false

    // Increments on each open to force a fresh ExpandedCardView instance on rapid close/open.
    @State private var presentationToken: Int = 0

    // Fast-scroll bounce detection
    @State private var lastScrollOffset: CGFloat = 0
    @State private var lastScrollTime: Date = .now
    @State private var canTriggerScrollBounce: Bool = false

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                // Background
                if let selectedCard {
                    selectedCard.color.opacity(0.1)
                        .ignoresSafeArea()
                        .transition(.opacity)
                }

                if selectedCard == nil {
                    // MARK: - Stacked View
                    stackedView(geometry: geometry)
                        .transition(.opacity)
                } else if let card = selectedCard {
                    // MARK: - Expanded View
                    ExpandedCardView(
                        card: card,
                        animation: animation,
                        onDismiss: {
                            withAnimation(CardAnimations.heroTransition) {
                                selectedCard = nil
                                scrollOffset = 0
                            }
                        }
                    )
                    .id("expanded-\(card.id)-\(presentationToken)")
                    .transition(.opacity)
                }
            }
        }
    }

    // MARK: - Stacked Scroll View

    @ViewBuilder
    private func stackedView(geometry: GeometryProxy) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                // Header spacer
                Color.clear.frame(height: 20)

                // Title
                Text("Card Deck")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)

                CardStackView(
                    cards: cards,
                    spreadAmount: stackedScrollOffset,
                    bounceTrigger: cardBounceTrigger,
                    animation: animation,
                    onSelect: { card in
                        presentationToken &+= 1
                        scrollOffset = 0
                        withAnimation(CardAnimations.heroTransition) {
                            selectedCard = card
                        }
                    },
                    onReorder: { reordered in
                        cards = reordered
                        for (index, _) in cards.enumerated() {
                            cards[index].sortOrder = index
                        }
                    },
                    isReordering: $isReorderingCards
                )

                // Bottom padding
                Color.clear.frame(height: 200)
            }
        }
        .scrollClipDisabled()
        .scrollDisabled(isReorderingCards)
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentOffset.y
        } action: { _, newValue in
            // Capture the baseline offset once (the "rest" position near the top)
            // and then measure elastic overscroll relative to that fixed point.
            if initialContentOffset == nil {
                initialContentOffset = newValue
            }

            let baseline = initialContentOffset ?? newValue
            // Raw overscroll: positive only when pulling down past the baseline.
            let overscrollRaw = max(0, baseline - newValue)
            // Resistance factor: lower = stronger resistance
            let resistanceFactor: CGFloat = 0.25
            let effectiveOverscroll = overscrollRaw * resistanceFactor

            detectFastScroll(newOffset: overscrollRaw)
            stackedScrollOffset = effectiveOverscroll
        }
    }

    // MARK: - Fast Scroll Bounce Detection

    private func detectFastScroll(newOffset: CGFloat) {
        let now = Date()
        let timeDelta = now.timeIntervalSince(lastScrollTime)
        guard timeDelta > 0.01 else { return }

        let offsetDelta = newOffset - lastScrollOffset
        let velocity = offsetDelta / timeDelta

        if lastScrollOffset < -50 {
            canTriggerScrollBounce = true
        }

        // Trigger on fast upward scroll
        if velocity > 800 && canTriggerScrollBounce && newOffset > -30 {
            canTriggerScrollBounce = false
            cardBounceTrigger += 1
        }

        if newOffset >= 0 {
            canTriggerScrollBounce = false
        }

        lastScrollOffset = newOffset
        lastScrollTime = now
    }
}

#Preview {
    DeckView()
}
