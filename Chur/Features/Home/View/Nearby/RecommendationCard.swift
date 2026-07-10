//
//  RecommendationCard.swift
//  Chur
//
//  Created by Pak Ho on 4/8/26.
//

import SwiftUI
import SwiftData

struct RecommendationCard: View {
    let recommendation: NearbyRecommendation
    
    @State private var showDetailPopup = false
    @Query private var cards: [CreditCard]
    @Query private var users: [User]
    @Query private var categories: [SpendingCategory]
    
    @Environment(\.rewardDisplay) private var rewardDisplay
    private var boostEnrollments: [String: String] { users.first?.boostEnrollments ?? [:] }

    private var categoryEmoji: String {
        categories.first(where: { $0.id == recommendation.merchant.categoryID })?.emoji ?? "📍"
    }

    private var rateDisplayText: String {
        rewardDisplay.showEffectiveRate
            ? (recommendation.bestCard?.effectiveRateDisplayString ?? "-")
            : recommendation.pointsDisplay
    }

    private var ratePillMode: RatePill.DisplayMode {
        guard rewardDisplay.showEffectiveRate else { return .points }
        let rate = recommendation.bestCard?.effectiveCashBackRate ?? 0
        if rate == 0 { return .empty }
        return rate < 0 ? .effectiveNegative : .effectivePositive
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Text(recommendation.merchant.name)
                    .font(.churSectionHeader())
                    .foregroundStyle(Color.churDarkGray)
                    .lineLimit(1)
                
                Spacer(minLength: 4)
                
                VStack(alignment: .trailing, spacing: 1) {
                    Text(categoryEmoji)
                        .font(.churBigTitle4())
                    
                    Text(String(format: "%.2f mi", recommendation.merchant.distance))
                        .font(.churBadgeMedium())
                        .foregroundStyle(Color.churDarkGray)
                }
            }
            
            HStack(spacing: 12) {
                if let card = recommendation.card {
                    Image(card.imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 60, height: 38)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .shadow(color: .black.opacity(0.1), radius: 2)
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.churLightGray.opacity(0.2))
                        .frame(width: 60, height: 38)
                        .overlay(Image(systemName: "creditcard").font(.churCaptionRegular()).foregroundStyle(.gray))
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(recommendation.card?.name ?? "No card found")
                        .font(.churCaption())
                        .foregroundStyle(Color.churDarkGray)
                        .lineLimit(1)
                    
                    RatePill(text: rateDisplayText, displayMode: ratePillMode, size: .large)
                }
                
                Spacer(minLength: 0)
                
                Image(systemName: "chevron.right")
                    .font(.churSmallBold())
                    .foregroundStyle(Color.churMediumGray.opacity(0.5))
            }
        }
        .padding(16)
        .frame(width: 280, height: 110)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
        )
        .onTapGesture {
            showDetailPopup = true
        }
        .sheet(isPresented: $showDetailPopup) {
            if let category = categories.first(where: { $0.id == recommendation.merchant.categoryID }) {
                MerchantDetailSheet(
                    merchant: recommendation.merchant,
                    category: category,
                    cards: cards,
                    allCategories: categories,
                    boostEnrollments: boostEnrollments
                )
            }
        }
    }
}
