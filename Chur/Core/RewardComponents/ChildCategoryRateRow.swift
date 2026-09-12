//
//  ChildCategoryRateRow.swift
//  Chur
//
//  Shared reward rate row used across Cards, Home, and News features.
//

import SwiftUI
import SwiftData

// MARK: - Child Category Rate Row (Aligned for Comparison)
struct ChildCategoryRateRow: View {
    let category: SpendingCategory
    let rate: Double
    let cardName: String?
    var effectiveRate: Double = 0
    var titleOverride: String? = nil // e.g. a reward's groupLabel ("Self-Care") shown instead of the category name
    /// Reward program name, so the rate reads the way the program quotes it (P1f part 4).
    var rewardProgramName: String? = nil

    @Environment(\.rewardDisplay) private var rewardDisplay

    private var displayValue: String {
        RateDisplay.preferred(
            rate: rate,
            effectiveRate: effectiveRate,
            program: rewardProgramName,
            showEffectiveRate: rewardDisplay.showEffectiveRate
        )
    }

    private var ratePillMode: RatePill.DisplayMode {
        RateDisplay.pillMode(rate: rate, effectiveRate: effectiveRate, showEffectiveRate: rewardDisplay.showEffectiveRate)
    }

    var body: some View {
        HStack(spacing: 12) {
            CategoryIconView(category: category, font: .system(size: 30))
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(titleOverride ?? category.displayName)
                    .font(.churRowText())
                    .foregroundStyle(Color.churDarkGray)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                if let card = cardName {
                    Text(card)
                        .font(.churRowText())
                        .foregroundStyle(Color.churOlive)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }

            Spacer()

            RatePill(text: displayValue, displayMode: ratePillMode, size: .large, showBackground: false)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: Color.black.opacity(0.02), radius: 2, x: 0, y: 1)
    }
}
