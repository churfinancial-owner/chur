//
//  CardItemCompact.swift (IMPROVED)
//  Chur
//
//  Created by Pak Ho on 1/26/26.
//

import SwiftUI

struct CardItemCompact: View {
    let card: CreditCard
    let isExpanded: Bool
    
    // MARK: - Computed Properties
    
    private var totalBenefitsCount: Int {
        card.benefits.count
    }
    
    private var cardColor: Color {
        .cardColor(for: card.issuer)
    }
    
    // MARK: - Body
    
    var body: some View {
        HStack(spacing: 12) {
            cardIcon
            
            cardInfo
            
            Spacer()
            
            expansionIndicator
        }
        .padding()
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Subviews

private extension CardItemCompact {
    var cardIcon: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(cardColor)
            .frame(width: 70, height: 44)
            .overlay {
                VStack(spacing: 2) {
                    Text(card.issuer)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                    Text(card.network)
                        .font(.churBadge())
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
    }
    
    var cardInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(card.name)
                .font(.churHeadline())
                .foregroundStyle(Color.churDarkGray)
            
            if totalBenefitsCount > 0 {
                Text("\(totalBenefitsCount) benefit\(totalBenefitsCount == 1 ? "" : "s")")
                    .font(.churCaptionRegular())
                    .foregroundStyle(Color.churMediumGray)
            }
        }
    }
    
    var expansionIndicator: some View {
        Image(systemName: "chevron.down")
            .font(.caption)
            .foregroundStyle(Color.churMediumGray)
            .rotationEffect(.degrees(isExpanded ? 180 : 0))
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isExpanded)
    }
}
