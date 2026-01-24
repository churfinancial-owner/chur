//
//  CardViewToggle.swift
//  Chur
//
//  Created by Pak Ho on 1/29/26.
//

import SwiftUI

struct CardViewToggle: View {
    let card: CreditCard
    @Binding var selectedTab: CardViewTab
    
    /// Sourced from Settings — how many days before expiry a benefit should be flagged.
    @AppStorage("expiryWarningDays") private var expiryWarningDays: Int = 3
    
    // MARK: - Computed Properties
    
    /// Count of credit-type benefits that still have remaining balance (available for redemption)
    private var benefitsRemainingCount: Int {
        card.benefits.filter { benefit in
            guard benefit.benefitType.lowercased() == "credit",
                  benefit.isCurrentlyActive else { return false }
            let analyzer = BenefitUsageAnalyzer(benefit: benefit, approvedMonth: card.approvedMonth)
            if analyzer.isUnlimited { return true }
            if benefit.isLocked(approvedMonth: card.approvedMonth, approvedYear: card.approvedYear) { return false }
            return !analyzer.isFullyRedeemedThisPeriod()
        }.count
    }
    
    /// Check if any credit-type benefits are expiring soon (within warning window)
    private var hasExpiringBenefits: Bool {
        let calendar = Calendar.current
        let now = Date.current()
        let validMonth = max(1, min(12, card.approvedMonth))
        let anniversaryDate = calendar.date(
            from: DateComponents(year: card.approvedYear, month: validMonth, day: 1)
        )
        
        return card.benefits.contains { benefit in
            guard benefit.benefitType.lowercased() == "credit" else { return false }
            
            let analyzer = BenefitUsageAnalyzer(benefit: benefit, approvedMonth: card.approvedMonth)
            
            // Must have remaining balance
            guard let remainingBalance = analyzer.remainingBalance(on: now), remainingBalance > 0 else { return false }
            
            // Must have expiry date
            guard let expiryDate = benefit.effectiveExpiryDate(cardAnniversaryDate: anniversaryDate) else { return false }
            
            // Check if expiring within warning window
            let timeUntilExpiry = expiryDate.timeIntervalSince(now)
            return timeUntilExpiry > 0 && timeUntilExpiry < 60 * 60 * 24 * Double(expiryWarningDays)
        }
    }
    
    /// Helper to create a label with an optional floating count badge
    @ViewBuilder
    private func labelWithBubble(text: String, count: Int, showAlarm: Bool = false) -> some View {
        HStack(spacing: 4) {
            if showAlarm {
                Text("⏰")
                    .font(.churFootnote())
            }
            Text(text)
                .font(.churRowText())
        }
        .overlay(alignment: .topTrailing) {
            if count > 0 {
                Text("\(count)")
                    .font(.churBadgeBold())
                    .foregroundStyle(Color.churOlive)
                    .frame(minWidth: 18, minHeight: 18)
                    .background(Color.white)
                    .clipShape(Circle())
                    .offset(x: 18, y: -6)
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Benefits Button
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    selectedTab = .benefits
                }
            } label: {
                labelWithBubble(text: "Benefits", count: benefitsRemainingCount, showAlarm: hasExpiringBenefits)
                    .foregroundStyle(selectedTab == .benefits ? .white : Color.churMediumGray)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        selectedTab == .benefits ?
                            Color.churOlive : Color.clear
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            // Card Info Button
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    selectedTab = .cardInfo
                }
            } label: {
                Text("Info")
                    .font(.churRowText())
                    .foregroundStyle(selectedTab == .cardInfo ? .white : Color.churMediumGray)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        selectedTab == .cardInfo ?
                            Color.churOlive : Color.clear
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            // Features Button
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    selectedTab = .features
                }
            } label: {
                Text("Features")
                    .font(.churRowText())
                    .foregroundStyle(selectedTab == .features ? .white : Color.churMediumGray)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        selectedTab == .features ?
                            Color.churOlive : Color.clear
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(4)
        .background(Color.churLightGray.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal)
        .padding(.vertical, 2)
    }
}

enum CardViewTab {
    case benefits
    case cardInfo
    case features
}
