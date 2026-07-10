//
//  MonthDetailSheet.swift
//  Chur
//
//  Created by Pak Ho on 2/2/26.
//

import SwiftUI
import SwiftData

struct MonthDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    // Inputs
    let month: Int
    let year: Int
    let cards: [CreditCard]

    // MARK: - Computed Properties
    
    private var totalMonthlyFees: Int {
        monthlyFeeItems.reduce(0) { $0 + $1.amount }
    }

    private var totalMonthlySavings: Int {
        groupedBenefits.reduce(0) { $0 + $1.totalAmount }
    }
    
    private var formattedDate: String {
        let monthName = Calendar.current.monthSymbols[month - 1].uppercased()
        return "\(monthName) \(year)"
    }

    private var monthlyFeeItems: [(card: CreditCard, amount: Int)] {
        cards
            .filter { $0.approvedMonth == month && $0.annualFee > 0 && year >= $0.approvedYear }
            .map { (card: $0, amount: $0.annualFee) }
            .sorted { $0.amount > $1.amount }
    }

    private var groupedBenefits: [GroupedBenefit] {
        var results: [GroupedBenefit] = []
        
        for card in cards {
            var cardDetails: [BenefitDetail] = []
            var cardTotal = 0
            
            for benefit in card.benefits {
                let records = benefit.usageHistory.filter { $0.month == month && $0.year == year }
                if !records.isEmpty {
                    let totalValue = benefit.usageLimit != nil
                        ? records.count * benefit.value
                        : records.reduce(0) { $0 + $1.redeemedAmount }
                    
                    if totalValue > 0 {
                        cardDetails.append(BenefitDetail(name: benefit.displayName, amount: totalValue))
                        cardTotal += totalValue
                    }
                }
            }
            
            if cardTotal > 0 {
                results.append(GroupedBenefit(card: card, totalAmount: cardTotal, details: cardDetails))
            }
        }
        return results.sorted { $0.totalAmount > $1.totalAmount }
    }

    // MARK: - Body
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView {
                VStack(spacing: 0) {
                    PatternHeaderBanner(imageName: "HeaderPattern5")
                    
                    // 1. Header & Title
                    DetailSheetTitleBlock(title: formattedDate, subtitle: "MONTHLY ACTIVITY")

                    // 2. Summary Dashboard
                    summaryDashboard
                        .padding(24)

                    // 3. Breakdown Sections
                    VStack(spacing: 28) {
                        
                        // --- ANNUAL FEES ---
                        if !monthlyFeeItems.isEmpty {
                            enhancedSection(title: "Upcoming Fees", icon: "creditcard.and.123", color: .red) {
                                ForEach(0..<monthlyFeeItems.count, id: \.self) { i in
                                    let item = monthlyFeeItems[i]
                                    enhancedRow(card: item.card, title: item.card.name, amount: "-$\(item.amount)", color: .red)
                                    if i < monthlyFeeItems.count - 1 { thinDivider }
                                }
                            }
                        }

                        // --- BENEFITS REDEEMED ---
                        if !groupedBenefits.isEmpty {
                            enhancedSection(title: "Redeemed Benefits", icon: "sparkles", color: .green) {
                                ForEach(groupedBenefits) { group in
                                    BenefitGroupRow(group: group)
                                    if group.id != groupedBenefits.last?.id { thinDivider }
                                }
                            }
                        }
                        
                        if monthlyFeeItems.isEmpty && groupedBenefits.isEmpty {
                            emptyRecapView
                        }
                    }
                    .padding(.horizontal, 24)

                    Spacer(minLength: 100)
                }
            }
            .background(Color.churOffWhite)
            .ignoresSafeArea()

            SheetDismissButton { dismiss() }
        }
    }

    // MARK: - Components

    private var summaryDashboard: some View {
        HStack(spacing: 16) {
            summaryStatPill(label: "Fees", value: "$\(totalMonthlyFees)", color: .red)
            summaryStatPill(label: "Redeemed", value: "$\(totalMonthlySavings)", color: Color.churOlive)
        }
    }
    
    private func summaryStatPill(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.churTitle2())
                .foregroundStyle(color)

            Text(label.uppercased())
                .font(.churNanoBold())
                .foregroundStyle(.secondary)
                .tracking(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.white)
                .shadow(color: .black.opacity(0.03), radius: 10, y: 5)
        )
    }
    
    private func enhancedSection<Content: View>(title: String, icon: String, color: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.churBadgeBold())
                Text(title.uppercased())
                    .font(.churBadgeBold())
                    .tracking(1)
            }
            .foregroundStyle(Color.churMediumGray.opacity(0.8))
            .padding(.leading, 8)

            VStack(spacing: 0) {
                content()
            }
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 28))
            .shadow(color: .black.opacity(0.02), radius: 8, y: 4)
        }
    }
    
    private func enhancedRow(card: CreditCard, title: String, amount: String, color: Color) -> some View {
        HStack(spacing: 14) {
            Image(card.imageName)
                .resizable()
                .scaledToFit()
                .frame(width: 44, height: 28)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .shadow(color: .black.opacity(0.05), radius: 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.churCaption())
                    .foregroundStyle(Color.churDarkGray)

                Text(card.issuer)
                    .font(.churBadgeMedium())
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(amount)
                .font(.churCaption())
                .foregroundStyle(color)
        }
        .padding(20)
    }

    private var thinDivider: some View {
        Divider().padding(.horizontal, 20).opacity(0.3)
    }

    private var emptyRecapView: some View {
        VStack(spacing: 16) {
            Image(systemName: "cup.and.saucer")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(Color.churMediumGray.opacity(0.3))
            Text("Nothing tracked for this month yet.")
                .font(.churFootnoteMedium())
                .foregroundStyle(Color.churMediumGray)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
}
