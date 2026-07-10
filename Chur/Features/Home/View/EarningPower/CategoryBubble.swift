//
//  CategoryBubble.swift
//  Chur
//
//  Created by Pak Ho on 1/25/26.
//

import SwiftUI
import SwiftData

// MARK: - Category Bubble
struct CategoryBubble: View {
    let category: SpendingCategory
    let rate: Double
    let effectiveRate: Double
    let cards: [CreditCard]
    let allCategories: [SpendingCategory]
    let currentRegionCodeOverride: String?
    var bestCardName: String? = nil

    @Environment(\.rewardDisplay) private var rewardDisplay
    @State private var showingDetails = false

    // Resolve the best card object for the thumbnail
    private var bestCard: CreditCard? {
        guard let name = bestCardName else { return nil }
        return cards.first { $0.name == name }
    }

    private var badgeTintColor: Color { .categoryBadgeTint(for: category.id) }

    var body: some View {
        Button {
            showingDetails = true
        } label: {
            VStack(spacing: 0) {
                // Top: tinted emoji badge (left) + category name + rate pill (right)
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(badgeTintColor)
                            .frame(width: 48, height: 48)
                        CategoryIconView(category: category, font: .system(size: 26))
                            .frame(width: 48, height: 48)
                    }

                    VStack(alignment: .center, spacing: 4) {
                        Text(category.displayName)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.churDarkGray)
                            .lineLimit(1)

                        RatePill(
                            rate: rate,
                            effectiveRate: effectiveRate,
                            showEffectiveRate: rewardDisplay.showEffectiveRate,
                            size: .large,
                            showBackground: false
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .padding(.horizontal, 12)
                .padding(.top, 14)
                .padding(.bottom, 12)

                // Hairline divider
                Rectangle()
                    .fill(Color.black.opacity(0.06))
                    .frame(height: 1)

                // Footer: card thumbnail + card name
                HStack(spacing: 7) {
                    CardThumbnailView(card: bestCard, width: 30, height: 20)
                        .shadow(color: .black.opacity(0.10), radius: 3, x: 0, y: 1)

                    Text(bestCardName ?? "–")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.churMediumGray)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
            }
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(ScaleButtonStyle())
        .sheet(isPresented: $showingDetails) {
            ParentCategoryParallaxSheet(
                category: category,
                rate: rate,
                cards: cards,
                allCategories: allCategories,
                currentRegionCodeOverride: currentRegionCodeOverride
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }
}
