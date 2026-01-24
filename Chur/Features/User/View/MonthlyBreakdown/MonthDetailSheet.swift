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
    let cards: [CreditCard]
    let fees: Int     // Passed from parent (unused for card math to avoid bugs)
    let savings: Int  // Passed from parent (unused for card math to avoid bugs)

    // MARK: - Computed Properties
    
    /// Sums the annual fees for cards approved in this specific month
    private var totalMonthlyFees: Int {
        monthlyFeeItems.reduce(0) { $0 + $1.amount }
    }

    /// Sums the redeemed benefits for the selected month and current year
    private var totalMonthlySavings: Int {
        groupedBenefits.reduce(0) { $0 + $1.totalAmount }
    }
    
    private var formattedDate: String {
        let year = Calendar.current.component(.year, from: Date())
        let monthName = Calendar.current.monthSymbols[month - 1].uppercased()
        return "\(monthName) \(year)"
    }

    private var monthlyFeeItems: [(card: CreditCard, amount: Int)] {
        cards
            .filter { $0.approvedMonth == month && $0.annualFee > 0 }
            .map { (card: $0, amount: $0.annualFee) }
            .sorted { $0.amount > $1.amount }
    }

    private var groupedBenefits: [GroupedBenefit] {
        let year = Calendar.current.component(.year, from: Date())
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
                    // 1. Header Pattern & Title
                    PatternHeaderBanner(imageName: "HeaderPattern5")
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text(formattedDate)
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.churDarkGray)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 12)

                    // 2. Summary Card (Now uses dynamic calculations)
                    summaryCard
                        .padding(24)

                    // 3. Breakdown Sections
                    VStack(spacing: 24) {
                        
                        // --- ANNUAL FEES ---
                        if !monthlyFeeItems.isEmpty {
                            recapSection(title: "ANNUAL FEES", icon: "creditcard.and.123", accentColor: .red) {
                                ForEach(0..<monthlyFeeItems.count, id: \.self) { i in
                                    let item = monthlyFeeItems[i]
                                    rowItem(card: item.card, title: item.card.name, subtitle: item.card.issuer, amount: "-$\(item.amount)", color: .red, trailingPadding: 20)
                                    if i < monthlyFeeItems.count - 1 { divider }
                                }
                            }
                        }

                        // --- BENEFITS REDEEMED ---
                        if !groupedBenefits.isEmpty {
                            recapSection(title: "BENEFITS REDEEMED", icon: "sparkles", accentColor: .green) {
                                ForEach(groupedBenefits) { group in
                                    // Shared component from SharedBenefitModels.swift
                                    BenefitGroupRow(group: group)
                                    
                                    if group.id != groupedBenefits.last?.id { divider }
                                }
                            }
                        }
                        
                        if monthlyFeeItems.isEmpty && groupedBenefits.isEmpty {
                            emptyRecapView
                        }
                    }
                    .padding(.horizontal, 24)

                    Spacer(minLength: 60)
                }
            }
            .background(Color.churOffWhite)
            .ignoresSafeArea()

            SheetDismissButton { dismiss() }
        }
    }

    // MARK: - Components

    private var summaryCard: some View {
        HStack(spacing: 0) {
            // Uses calculated totalMonthlyFees instead of input fees
            summaryStat(label: "Annual Fees", value: "$\(totalMonthlyFees)", icon: "banknote.fill", color: .red)
            Rectangle()
                .fill(Color.red.opacity(0.15))
                .frame(width: 1, height: 40)
            
            // Uses calculated totalMonthlySavings instead of input savings
            summaryStat(label: "Redeemed", value: "$\(totalMonthlySavings)", icon: "gift.fill", color: .green)
        }
        .padding(.vertical, 24)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .green.opacity(0.03), radius: 8, x: 0, y: 4)
    }
    
    private func summaryStat(label: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.churBigTitle4())
                    .foregroundStyle(color.opacity(0.8))

                Text(value)
                    .font(.churTitle())
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
            }
            
            Text(label.uppercased())
                .font(.churBadgeMedium())
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity)
    }
    
    private func recapSection<Content: View>(title: String, icon: String, accentColor: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: icon)
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundStyle(Color.churMediumGray)
                .tracking(1.1)
                .textCase(.uppercase)

            VStack(spacing: 0) {
                content()
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.02), radius: 4, x: 0, y: 2)
        }
    }
    
    private func rowItem(card: CreditCard, title: String, subtitle: String? = nil, amount: String, color: Color, trailingPadding: CGFloat = 0) -> some View {
        HStack(spacing: 12) {
            Image(card.imageName)
                .resizable()
                .scaledToFit()
                .frame(width: 42, height: 28)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.black.opacity(0.06), lineWidth: 0.5))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.churCaption())
                    .foregroundStyle(Color.churDarkGray)
                    .lineLimit(1)
                
                if let subtitle {
                    Text(subtitle)
                        .font(.churSmall())
                        .foregroundStyle(Color.churMediumGray)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text(amount)
                .font(.churRowText())
                .foregroundStyle(color)
                .padding(.trailing, trailingPadding)
        }
        .padding(16)
        .contentShape(Rectangle())
    }

    private var divider: some View {
        Divider().padding(.horizontal, 16).opacity(0.5)
    }

    private var emptyRecapView: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.churBigTitle3())
                .foregroundStyle(Color.churMediumGray.opacity(0.4))
            Text("No transactions found for this month.")
                .font(.churCaptionMedium())
                .foregroundStyle(Color.churMediumGray)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }
}
