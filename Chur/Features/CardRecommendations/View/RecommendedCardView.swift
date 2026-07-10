//
//  RecommendedCardView.swift
//  Chur
//
//  Created by Pak Ho on 1/29/26.
//

import SwiftUI

// MARK: - Recommendation Card View
struct RecommendedCardView: View {
    let recommendation: ScoredRecommendation
    let allCategories: [SpendingCategory]

    private var categoryRates: [(emoji: String, rateLabel: String, name: String)] {
        recommendation.topCategoryRates(from: allCategories)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            
            // --- TOP GOLD BANNER (Enhanced with Sheen) ---
            if !recommendation.bestCategoryHighlight.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.churCaption())
                        .symbolEffect(.pulse, options: .repeating)

                    Text(recommendation.bestCategoryHighlight.uppercased())
                        .font(.churMicroBold())
                        .tracking(1.2)
                        .lineLimit(1)

                    Image(systemName: "sparkles")
                        .font(.churCaption())
                        .symbolEffect(.pulse, options: .repeating)
                }
                .foregroundStyle(.white)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
                .background(Color.churGoldGradient)
                .overlay(alignment: .top) {
                    Color.white.opacity(0.15).frame(height: 1) // Top "shimmer" line
                }
            }

            // --- HERO SECTION (Card & Title) ---
            VStack(spacing: 16) {
                Image(recommendation.imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 140)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 8)
                
                VStack(spacing: 4) {
                    Text(recommendation.cardName)
                        .font(.churHeadline())
                        .foregroundStyle(Color.churDarkGray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                    
                    Text(recommendation.issuer)
                        .font(.churMicroBold())
                        .foregroundStyle(Color.churMediumGray.opacity(0.8))
                        .textCase(.uppercase)
                        .tracking(2.0)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 24)
            .padding(.bottom, 20)
            
            Divider().background(Color.churOffWhite).padding(.horizontal, 24)

            // --- INFO SECTION ---
            VStack(alignment: .leading, spacing: 20) {
                
                // Sign-up Bonus
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("SIGN-UP BONUS")
                            .font(.churNanoBold())
                            .foregroundStyle(Color.churMediumGray)
                            .tracking(1.0)
                        
                        Text(recommendation.template.signUpBonus)
                            .font(.churFootnoteBold())
                            .foregroundStyle(Color.churDarkGray)
                            .lineLimit(2)
                    }
                    
                    Spacer()
                    bonusBadge
                }
                
                // Top Earning Categories (Enhanced Pills)
                VStack(alignment: .leading, spacing: 10) {
                    Text("TOP EARNING")
                        .font(.churNanoBold())
                        .foregroundStyle(Color.churMediumGray)
                        .tracking(1.0)
                    
                    HStack(spacing: 8) {
                        ForEach(categoryRates.prefix(3), id: \.name) { item in
                            HStack(spacing: 4) {
                                Text(item.emoji)
                                    .font(.churBadge())
                                    .padding(5)
                                    .background(.white)
                                    .clipShape(Circle())
                                
                                Text(item.rateLabel)
                                    .font(.churSmallBold())
                                    .foregroundStyle(Color.churDarkGray)
                            }
                            .padding(.leading, 3)
                            .padding(.trailing, 10)
                            .padding(.vertical, 3)
                            .background(Color.churOlive.opacity(0.12))
                            .clipShape(Capsule())
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)

            Spacer()

            // --- ACTION BUTTON ---
            applyButton
                .padding([.horizontal, .bottom], 24)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .shadow(color: Color.black.opacity(0.06), radius: 25, x: 0, y: 15)
    }

    // MARK: - Subviews
    private var bonusBadge: some View {
        Group {
            if let rating = recommendation.template.bonusRating {
                VStack(spacing: 2) {
                    Text(rating.displayText)
                        .font(.churSmallBold())
                        .multilineTextAlignment(.center)
                        .foregroundStyle(rating.textColor)
                    
                    Text("VALUE")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(rating.textColor.opacity(0.7))
                }
                .frame(width: 48, height: 48)
                .background(rating.backgroundColor.opacity(0.9))
                .clipShape(Circle())
                // Subtle outer glow
                .shadow(color: rating.backgroundColor.opacity(0.3), radius: 4, x: 0, y: 2)
            }
        }
    }
    
    private var applyButton: some View {
        Button {
            if let url = URL(string: recommendation.template.affiliateURL) {
                UIApplication.shared.open(url)
            }
        } label: {
            Text("View Offer")
                .font(.churSectionHeader())
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color.churGoldGradient)
                .clipShape(Capsule())
                .shadow(color: Color.churGold.opacity(0.35), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(SquishyButtonStyle()) // Adds that "cute" tactile response
    }
}
