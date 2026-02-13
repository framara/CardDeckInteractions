import SwiftUI

/// A single card visual — just a color fill with rounded corners and a highlight border.
struct DeckCardView: View {
    let card: Card

    var body: some View {
        ZStack {
            // Background color
            card.color

            // Content overlay
            VStack(alignment: .leading) {
                HStack(alignment: .top) {
                    Text(card.title)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)

                    Spacer()
                }
                .padding(20)

                Spacer()
            }
        }
        // Top highlight border gradient
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.4), .clear],
                        startPoint: .top,
                        endPoint: .center
                    ),
                    lineWidth: 1
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
    }
}

#Preview {
    DeckCardView(card: Card(color: Color(red: 0.20, green: 0.45, blue: 0.85), title: "Cobalt", sortOrder: 0))
        .frame(height: 220)
        .padding()
}
