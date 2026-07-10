//
//  UserWalletSummaryView.swift
//  Chur
//
//  Created by Pak Ho on 2/2/26.
//

import SwiftUI
import SwiftData

struct UserWalletSummaryView: View {
    let cards: [CreditCard]
    @State private var selectedMonth: Int? = nil
    @State private var showYearSummary = false
    @Binding var selectedYear: Int
    
    // MARK: - Computed Properties
    
    var totalAnnualFees: Int {
        // Only count fees for cards that were active during the selected year
        (1...12).reduce(0) { $0 + feesForMonth($1, year: selectedYear) }
    }
    
    var totalAnnualSavings: Int {
        (1...12).reduce(0) { $0 + savingsForMonth($1, year: selectedYear) }
    }
    
    
    // MARK: - Body
    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            
            // 1. Stats Row
            HStack(alignment: .center, spacing: 0) {
                statBox(title: "Annual Fees", value: "$\(totalAnnualFees)", icon: "banknote.fill", color: .red)
                separator
                statBox(title: "Cards", value: "\(cards.filter { $0.approvedYear <= selectedYear }.count)", icon: "creditcard.fill", color: .blue)
                separator
                statBox(title: "Redeemed", value: "$\(totalAnnualSavings)", icon: "gift.fill", color: .green)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color("churOffWhite"))
            .contentShape(Rectangle())
            .onTapGesture { showYearSummary = true }
            
            // 2. 12-Month Timeline Section
            VStack(alignment: .leading, spacing: 16) {
                MonthlyTimelineView(
                    cards: cards,
                    feesForMonth: feesForMonth,
                    savingsForMonth: savingsForMonth,
                    selectedMonth: $selectedMonth,
                    selectedYear: $selectedYear // 3. Pass the year binding
                )
            }
        }
        .sheet(item: Binding(
            get: { selectedMonth.map { MonthDetail(month: $0, cards: cards) } },
            set: { selectedMonth = $0?.month }
        )) { detail in
            MonthDetailSheet(
                month: detail.month,
                year: selectedYear,
                cards: detail.cards
            )
        }
        .sheet(isPresented: $showYearSummary) {
            YearDetailSheet(
                year: selectedYear,
                cards: cards,
                fees: totalAnnualFees,
                savings: totalAnnualSavings
            )
        }

    }
}
// MARK: - Subviews

@ViewBuilder
private func statBox(title: String, value: String, icon: String, color: Color) -> some View {
    VStack(spacing: 8) {
        Image(systemName: icon)
            .font(.churBigTitle4())
            .foregroundStyle(color.opacity(0.8))
        
        VStack(spacing: 2) {
            Text(value)
                .font(.churTitle())
                .minimumScaleFactor(0.8)
                .lineLimit(1)
            
            Text(title)
                .font(.churBadgeMedium())
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
        }
    }
    .frame(maxWidth: .infinity)
}

private var separator: some View {
    Capsule()
        .fill(Color.primary.opacity(0.08))
        .frame(width: 1, height: 30)
}

// MARK: - Helper Structs
// This must exist for the .sheet(item:) logic to work!
struct MonthDetail: Identifiable {
    let id = UUID()
    let month: Int
    let cards: [CreditCard]
}

// MARK: - Helper Functions

extension UserWalletSummaryView {
    
    func feesForMonth(_ month: Int, year: Int) -> Int {
        // 'cards' is now in scope here
        cards.filter { card in
            card.approvedMonth == month && year >= card.approvedYear
        }
        .reduce(0) { $0 + $1.annualFee }
    }
    
    func savingsForMonth(_ month: Int, year: Int) -> Int {
        cards.reduce(0) { totalSavings, card in
            let cardSavings = card.benefits.reduce(0) { benefitSum, benefit in
                let records = benefit.usageHistory.filter { $0.month == month && $0.year == year }
                if benefit.usageLimit != nil {
                    return benefitSum + (records.count * benefit.value)
                } else {
                    return benefitSum + records.reduce(0) { $0 + $1.redeemedAmount }
                }
            }
            return totalSavings + cardSavings
        }
    }
}

