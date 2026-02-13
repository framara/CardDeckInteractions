import SwiftUI

/// Stacked card layout with pull-to-fan, long-press + drag to reorder, and tap to select.
///
/// This mirrors ToMe's `CardDeckStackView` — cards overlap in a compact stack, spread apart
/// when the user pulls down (overscroll), and can be reordered with a long-press drag.
struct CardStackView: View {
    let cards: [Card]
    let spreadAmount: CGFloat
    let bounceTrigger: Int
    let animation: Namespace.ID
    let onSelect: (Card) -> Void
    var onReorder: (([Card]) -> Void)?
    @Binding var isReordering: Bool

    private let cardHeight: CGFloat = 220
    private let cardOverlap: CGFloat = -156
    private let cardSlotHeight: CGFloat = 64

    // MARK: - Bounce State
    @State private var cardBounceOffsets: [Int: CGFloat] = [:]

    // MARK: - Drag Reorder State
    @State private var draggingCardID: UUID?
    @State private var dragOffset: CGFloat = 0
    @State private var dragStartIndex: Int?
    @State private var proposedDropIndex: Int?
    @State private var suppressTap: Bool = false

    var body: some View {
        let pullAmount = max(0, spreadAmount)
        let anchorOffset = -pullAmount
        let spreadPerCard = min(pullAmount * 0.8, 150)
        let visiblePerCard: CGFloat = 50
        let stackHeight =
            CGFloat(max(0, cards.count - 1)) * (visiblePerCard + spreadPerCard) + cardHeight

        VStack(spacing: 0) {
            cardsStack(anchorOffset: anchorOffset, spreadPerCard: spreadPerCard)
                .frame(height: stackHeight)
                .padding(.bottom, 40)
                .animation(
                    .interactiveSpring(response: 0.3, dampingFraction: 0.8),
                    value: spreadAmount
                )
        }
        .onChange(of: bounceTrigger) { _, _ in
            triggerCardBounce()
        }
    }

    // MARK: - Card Stack

    private func cardsStack(anchorOffset: CGFloat, spreadPerCard: CGFloat) -> some View {
        let stepHeight = cardHeight + cardOverlap

        // Hit-test resolution: given a local Y coordinate, find which card is under it.
        func pickCard(at location: CGPoint) -> (Card, Int)? {
            let candidates: [(Card, Int)] = cards.enumerated().compactMap { index, card in
                let baseY = CGFloat(index) * stepHeight
                let spreadOffset = anchorOffset + (spreadPerCard * CGFloat(index))
                let bounceOffset = cardBounceOffsets[index] ?? 0
                let topY = baseY + spreadOffset + bounceOffset
                if location.y >= topY, location.y <= (topY + cardHeight) {
                    return (card, index)
                }
                return nil
            }
            // Higher indices render above lower ones due to overlap + zIndex.
            return candidates.max(by: { $0.1 < $1.1 })
        }

        return VStack(spacing: cardOverlap) {
            ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                let totalOffset = anchorOffset + (spreadPerCard * CGFloat(index))
                cardView(for: card, at: index, spreadOffset: totalOffset)
            }
        }
        .padding(.horizontal, 16)
        // Single gesture surface for the whole stack
        .overlay(
            LongPressDragGestureView(
                minimumPressDuration: 0.4,
                allowableMovement: 12,
                onTapAt: { location in
                    guard draggingCardID == nil, !suppressTap else { return }
                    guard let (card, _) = pickCard(at: location) else { return }
                    HapticManager.shared.selection()
                    onSelect(card)
                },
                onBeganAt: { location in
                    guard cards.count > 1 else { return }
                    guard let (card, index) = pickCard(at: location) else { return }
                    startReorder(for: card, at: index)
                },
                onChanged: { translationY in
                    guard let draggingCardID else { return }
                    guard let draggingIndex = cards.firstIndex(where: { $0.id == draggingCardID })
                    else { return }
                    updateReorderDrag(translation: translationY, fallbackIndex: draggingIndex)
                },
                onEnded: {
                    guard draggingCardID != nil else { return }
                    finishReorder()
                },
                onCancelled: {
                    guard draggingCardID != nil else { return }
                    finishReorder()
                }
            )
        )
    }

    // MARK: - Individual Card

    @ViewBuilder
    private func cardView(for card: Card, at index: Int, spreadOffset: CGFloat) -> some View {
        let bounceOffset = cardBounceOffsets[index] ?? 0
        let isBeingDragged = draggingCardID == card.id
        let isDragActive = draggingCardID != nil

        // Reorder offset for non-dragged cards
        let reorderOffset: CGFloat = {
            guard isDragActive, !isBeingDragged,
                let startIdx = dragStartIndex,
                let dropIdx = proposedDropIndex
            else { return 0 }

            if startIdx < dropIdx {
                if index > startIdx && index <= dropIdx {
                    return -cardSlotHeight
                }
            } else if startIdx > dropIdx {
                if index >= dropIdx && index < startIdx {
                    return cardSlotHeight
                }
            }
            return 0
        }()

        DeckCardView(card: card)
            .frame(height: cardHeight)
            .scaleEffect(isBeingDragged ? 1.03 : 1.0, anchor: .center)
            .shadow(
                color: .black.opacity(isBeingDragged ? 0.3 : 0.15),
                radius: isBeingDragged ? 20 : 4,
                y: isBeingDragged ? 10 : -2
            )
            .compositingGroup()
            .allowsHitTesting(false)
            .offset(
                y: bounceOffset + spreadOffset + (isBeingDragged ? dragOffset : reorderOffset)
            )
            .scaleEffect(isBeingDragged ? 0.98 : 1.0)
            .zIndex(isBeingDragged ? 1000 : Double(index))
            .animation(CardAnimations.reorderShift, value: reorderOffset)
            .animation(CardAnimations.reorderShift, value: isBeingDragged)
            .matchedGeometryEffect(id: card.id, in: animation)
            .transition(.scale.combined(with: .opacity))
    }

    // MARK: - Reorder Logic

    private func startReorder(for card: Card, at index: Int) {
        guard draggingCardID == nil else { return }
        suppressTap = true
        HapticManager.shared.impact(style: .medium)
        withAnimation(CardAnimations.reorderShift) {
            draggingCardID = card.id
            dragStartIndex = index
            proposedDropIndex = index
            isReordering = true
        }
    }

    private func updateReorderDrag(translation: CGFloat, fallbackIndex: Int) {
        dragOffset = translation

        let baseIndex = dragStartIndex ?? fallbackIndex
        let rawProposed = baseIndex + Int(round(translation / cardSlotHeight))
        let clampedProposed = max(0, min(cards.count - 1, rawProposed))

        if clampedProposed != proposedDropIndex {
            HapticManager.shared.impact(style: .light)
            withAnimation(CardAnimations.reorderShift) {
                proposedDropIndex = clampedProposed
            }
        }
    }

    private func finishReorder() {
        func releaseTapSuppressionSoon() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                suppressTap = false
            }
        }

        guard let startIdx = dragStartIndex,
            let dropIdx = proposedDropIndex,
            startIdx != dropIdx
        else {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                draggingCardID = nil
                dragOffset = 0
                dragStartIndex = nil
                proposedDropIndex = nil
                isReordering = false
            }
            releaseTapSuppressionSoon()
            return
        }

        var reordered = cards
        let moved = reordered.remove(at: startIdx)
        reordered.insert(moved, at: dropIdx)

        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            draggingCardID = nil
            dragOffset = 0
            dragStartIndex = nil
            proposedDropIndex = nil
            isReordering = false
        }

        suppressTap = true
        releaseTapSuppressionSoon()

        HapticManager.shared.notification(type: .success)
        onReorder?(reordered)
    }

    // MARK: - Bounce Animation

    private func triggerCardBounce() {
        HapticManager.shared.notification(type: .success)

        for index in cards.indices {
            // Stage 1: Jump up with quick stagger
            withAnimation(CardAnimations.quickStagger(index: index)) {
                cardBounceOffsets[index] = -CGFloat.random(in: 15...30)
            }

            // Stage 2: Fall back with extra bouncy settle
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.04 + 0.15) {
                withAnimation(CardAnimations.extraBouncy) {
                    cardBounceOffsets[index] = 0
                }
            }
        }
    }
}
