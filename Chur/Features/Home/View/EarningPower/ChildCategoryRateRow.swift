//
//  ChildCategoryRateRow.swift
//  Chur
//
//  Created by Pak Ho on 3/29/26.
//

import SwiftUI
import SwiftData

// MARK: - Child Category Rate Row (Aligned for Comparison)
struct ChildCategoryRateRow: View {
    let category: SpendingCategory
    let rate: Double
    let cardName: String?
    var effectiveRate: Double = 0
    var showEffectiveRate: Bool = false

    /// Display text — uses % suffix for effective rate in this row context
    private var displayValue: String {
        if showEffectiveRate && effectiveRate > 0 {
            let pct = effectiveRate * 100
            if pct.truncatingRemainder(dividingBy: 1) == 0 {
                return String(format: "%.0f%%", pct)
            } else if (pct * 10).truncatingRemainder(dividingBy: 1) == 0 {
                return String(format: "%.1f%%", pct)
            } else {
                return String(format: "%.2f%%", pct)
            }
        }
        return rate > 0 ? rate.formatAsRate() : "-"
    }

    private var ratePillMode: RatePill.DisplayMode {
        if rate <= 0 && !(showEffectiveRate && effectiveRate > 0) { return .empty }
        if showEffectiveRate { return effectiveRate < 0 ? .effectiveNegative : .effectivePositive }
        return .points
    }
    
    var body: some View {
        HStack(spacing: 12) {
            CategoryIconView(category: category, font: .system(size: 30))
                .frame(width: 32, height: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(category.displayName)
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
            
            // Fixed-width Rate Container to keep the far-right edge consistent
            RatePill(text: displayValue, displayMode: ratePillMode, size: .large, showBackground: false)
                .frame(minWidth: 60, alignment: .trailing)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: Color.black.opacity(0.02), radius: 2, x: 0, y: 1)
    }
}
