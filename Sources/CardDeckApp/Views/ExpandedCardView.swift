import SwiftUI

/// Full-screen expanded card with scroll-driven header fade and drag-down-to-dismiss.
///
/// Mirrors ToMe's `BoxExpandedContentViewWithAnimation`:
/// - `matchedGeometryEffect` on the card header for hero transition
/// - Scroll offset drives card opacity + scale (tracks finger directly, no animation)
/// - Drag-down gesture with rubber-band resistance dismisses the view
struct ExpandedCardView: View {
    let card: Card
    let animation: Namespace.ID
    let onDismiss: () -> Void

    @State private var scrollOffset: CGFloat = 0
    @State private var dragDownOffset: CGFloat = 0
    @GestureState private var isDragging: Bool = false

    /// Content scroll position — when near top, drag-to-dismiss is allowed.
    @State private var contentScrollOffset: CGFloat = 0

    private var canDragDownToDismiss: Bool {
        contentScrollOffset >= -10
    }

    private let dragDownThreshold: CGFloat = 120

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                // Background tint
                card.color.opacity(0.1)
                    .ignoresSafeArea()

                // Scrollable content
                ScrollViewReader { scrollProxy in
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {
                            Color.clear.frame(height: 0).id("cardTop")

                            // The card with matchedGeometryEffect
                            DeckCardView(card: card)
                                .frame(height: 220)
                                .matchedGeometryEffect(id: card.id, in: animation)
                                .padding(.horizontal)
                                .opacity(max(0.0, 1.0 - (scrollOffset / 200.0)))
                                .scaleEffect(max(0.85, 1.0 - (scrollOffset / 800.0)))
                                // Scroll-driven: track finger directly, no animation
                                .animation(nil, value: scrollOffset)
                                .padding(.bottom, 30)

                            // Placeholder content
                            VStack(alignment: .leading, spacing: 20) {
                                ForEach(0..<8, id: \.self) { index in
                                    placeholderRow(index: index)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 100)
                        }
                        .background(
                            GeometryReader { proxy in
                                let offset = proxy.frame(in: .named("expandedScroll")).minY
                                Color.clear
                                    .onChange(of: offset) { _, newValue in
                                        withTransaction(Transaction(animation: nil)) {
                                            scrollOffset = min(max(0, -newValue), 220)
                                            contentScrollOffset = newValue
                                        }
                                    }
                            }
                        )
                    }
                    .coordinateSpace(name: "expandedScroll")
                }

                // Dismiss button
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 20)
                .padding(.top, 8)
            }
            .offset(y: dragDownOffset)
            .opacity(1.0 - (dragDownOffset / geometry.size.height) * 0.3)
            .scaleEffect(
                1.0 - (dragDownOffset / geometry.size.height) * 0.1,
                anchor: .top
            )
            .simultaneousGesture(
                DragGesture(minimumDistance: 20)
                    .updating($isDragging) { _, state, _ in
                        state = true
                    }
                    .onChanged { value in
                        let verticalAmount = value.translation.height
                        // Only drag down, and only when at top of scroll
                        if verticalAmount > 0 && canDragDownToDismiss {
                            let resistance: CGFloat = 0.6
                            dragDownOffset = verticalAmount * resistance
                        }
                    }
                    .onEnded { value in
                        let verticalAmount = value.translation.height

                        if verticalAmount > 0 && dragDownOffset > 0 {
                            let velocity =
                                value.predictedEndTranslation.height
                                / max(value.translation.height, 1)

                            if dragDownOffset > dragDownThreshold
                                || (velocity > 1.5 && dragDownOffset > 60)
                            {
                                // Dismiss
                                withAnimation(CardAnimations.dismiss) {
                                    dragDownOffset = geometry.size.height
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                                    onDismiss()
                                }
                                HapticManager.shared.impact(style: .light)
                            } else {
                                // Snap back
                                withAnimation(CardAnimations.dismiss) {
                                    dragDownOffset = 0
                                }
                            }
                        } else {
                            withAnimation(CardAnimations.dismiss) {
                                dragDownOffset = 0
                            }
                        }
                    }
            )
        }
    }

    // MARK: - Placeholder Content

    @ViewBuilder
    private func placeholderRow(index: Int) -> some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(card.color.opacity(0.15))
                .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(.secondary.opacity(0.2))
                    .frame(width: CGFloat.random(in: 120...200), height: 14)

                RoundedRectangle(cornerRadius: 4)
                    .fill(.secondary.opacity(0.12))
                    .frame(width: CGFloat.random(in: 80...160), height: 10)
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }
}
