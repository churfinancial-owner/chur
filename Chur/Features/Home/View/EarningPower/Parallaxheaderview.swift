import SwiftUI

struct ParallaxHeaderView: View {
    let category: SpendingCategory
    let parentCategory: SpendingCategory?
    let rate: Double
    let bestCard: CardRateSummary?
    let bestCards: [CardRateSummary]
    let nextCards: [CardRateSummary]
    
    @State private var hasAppeared = false
    
    var body: some View {
        GeometryReader { geo in
            let minY = geo.frame(in: .global).minY
            let parallaxOffset: CGFloat = minY < 0 ? -minY / 2 : 0
            // Clamp the scale: only grow when pulling down (minY > 0), and start small when sheet opens
            let emojiScale: CGFloat = hasAppeared ? max(1.0, min(1.0 + max(0, minY) / 300, 1.5)) : 1.0

            ZStack(alignment: .topLeading) {
                VStack(spacing: 16) {
                    // MARK: - Category Header
                    VStack(spacing: 4) {
                        Text(category.emoji)
                            .font(.system(size: 80))
                            .scaleEffect(emojiScale)
                            .frame(height: 100)
                        
                        Text(category.displayName)
                            .font(.churTitle2())
                            .foregroundStyle(Color.churDarkGray)
                    }

                    // MARK: - Cards Section
                    if rate > 0 {
                        VStack(spacing: 8) {
                            // If multiple cards are tied for best, show them all as primary
                            if bestCards.count > 1 {
                                ForEach(bestCards, id: \.name) { card in
                                    cardPill(summary: card, isPrimary: true)
                                }
                            } else {
                                // Single best card + up to 2 next cards
                                if let card = bestCard {
                                    cardPill(summary: card, isPrimary: true)
                                }
                                
                                ForEach(nextCards.prefix(2), id: \.name) { card in
                                    cardPill(summary: card, isPrimary: false)
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .padding(.top, parentCategory != nil ? 20 : 0)

                // Parent Category Badge
                if let parent = parentCategory {
                    parentBadge(parent: parent)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 300)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
            .offset(y: parallaxOffset)
        }
        .frame(height: 300)
        .padding(.horizontal)
        .onAppear {
            // Enable parallax after a tiny delay to avoid initial geometry jank
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                hasAppeared = true
            }
        }
    }

    // MARK: - Subviews
    
    @ViewBuilder
    private func cardPill(summary: CardRateSummary, isPrimary: Bool) -> some View {
        let cardTemplate = CardDatabase.getAllCards().first(where: { $0.name == summary.name })

        // Use GeometryReader to enforce a strict 6-2-2 column ratio across all rows.
        // All rows — best and next — are identical in height and sizing.
        GeometryReader { geo in
            let totalSpacing: CGFloat = 6 * 2   // 2 gaps of 6pt each
            let unitWidth = max(0, (geo.size.width - totalSpacing) / 10)  // 10 total parts

            HStack(spacing: 6) {
                // MARK: - Name Pill (6 parts)
                HStack(spacing: 8) {
                    if let imageName = cardTemplate?.imageName, !imageName.isEmpty, UIImage(named: imageName) != nil {
                        Image(imageName)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 24)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                            .shadow(color: .black.opacity(0.1), radius: 1)
                    } else {
                        Text("💳")
                            .font(.churBody())
                            .frame(width: 24)
                    }

                    Text(summary.name)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .font(.churCaption())
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .frame(width: unitWidth * 6)
                .foregroundStyle(isPrimary ? .white : Color.churOlive)
                .background(isPrimary ? Color.churOlive : Color.churOlive.opacity(0.1))
                .clipShape(Capsule())
                .shadow(color: isPrimary ? Color.churOlive.opacity(0.25) : .clear, radius: 4, y: 2)

                // MARK: - Rate Pill — olive (2 parts)
                Text(summary.rate.formatAsRate())
                    .font(.churFootnoteBold())
                    .lineLimit(1)
                    .frame(width: unitWidth * 2)
                    .padding(.vertical, 8)
                    .foregroundStyle(isPrimary ? .white : Color.churOlive)
                    .background(isPrimary ? Color.churOlive : Color.churOlive.opacity(0.1))
                    .clipShape(Capsule())
                    .shadow(color: isPrimary ? Color.churOlive.opacity(0.25) : .clear, radius: 4, y: 2)

                // MARK: - Effective Rate Pill — blue (2 parts)
                Text(summary.effectiveRateDisplayString)
                    .font(.churFootnoteBold())
                    .lineLimit(1)
                    .frame(width: unitWidth * 2)
                    .padding(.vertical, 8)
                    .foregroundStyle(summary.effectiveCashBackRate < 0
                                     ? (isPrimary ? Color(hex: "B03A5B") : Color(hex: "B03A5B").opacity(0.65))
                                     : (isPrimary ? Color(hex: "4A90B8") : Color(hex: "4A90B8").opacity(0.5)))
                    .background(summary.effectiveCashBackRate < 0
                                ? (isPrimary ? Color(hex: "F5C3D2").opacity(0.75) : Color(hex: "F5C3D2").opacity(0.3))
                                : (isPrimary ? Color(hex: "BFD9ED").opacity(0.6) : Color(hex: "BFD9ED").opacity(0.2)))
                    .clipShape(Capsule())
            }
        }
        // Fixed row height — same for best card and next cards
        .frame(height: 40)
    }
    
    @ViewBuilder
    private func parentBadge(parent: SpendingCategory) -> some View {
        Text(parent.emoji)
            .font(.churBigTitle4())
            .frame(width: 44, height: 44)
            .background(Color.white)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.churOlive.opacity(0.2), lineWidth: 1))
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            .offset(x: 12, y: 12)
    }
}
