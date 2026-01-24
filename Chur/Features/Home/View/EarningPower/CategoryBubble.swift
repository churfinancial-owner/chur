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
    let showEffectiveRate: Bool
    let cards: [CreditCard]
    let allCategories: [SpendingCategory]
    let currentRegionCodeOverride: String?

    @State private var showingDetails = false

    var body: some View {
        Button {
            showingDetails = true
        } label: {
            VStack(spacing: 0) {
                // Top row: emoji + rate pill
                HStack {
                    CategoryIconView(category: category, font: .system(size: 36))
                        .frame(width: 44, height: 44)

                    Spacer()

                    RatePill(
                        rate: rate,
                        effectiveRate: effectiveRate,
                        showEffectiveRate: showEffectiveRate,
                        size: .large,
                        filledStyle: false
                    )
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)

                Spacer(minLength: 4)

                // Bottom: category name
                Text(category.displayName)
                    .font(.churFootnoteMedium())
                    .foregroundStyle(Color.churDarkGray)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
            }
            .frame(height: 90)
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
