//
//  MonthlyRecapHomeSection.swift
//  Chur
//
//  Compact "this month" stats card for Home, styled to match the stat
//  boxes in UserWalletSummaryView (Dashboard tab). Tapping opens the same
//  MonthDetailSheet used from the wallet summary, so the numbers and drill
//  down behavior are identical everywhere they appear.
//

import SwiftUI

struct MonthlyRecapHomeSection: View {
    let cards: [CreditCard]
    @State private var showMonthDetail = false

    private var currentMonth: Int { Calendar.current.component(.month, from: Date.current()) }
    private var currentYear: Int { Calendar.current.component(.year, from: Date.current()) }

    private var redeemedThisMonth: Int {
        cards.reduce(0) { totalSavings, card in
            let cardSavings = card.benefits.reduce(0) { benefitSum, benefit in
                let records = benefit.usageHistory.filter { $0.month == currentMonth && $0.year == currentYear }
                if benefit.usageLimit != nil {
                    return benefitSum + (records.count * benefit.value)
                } else {
                    return benefitSum + records.reduce(0) { $0 + $1.redeemedAmount }
                }
            }
            return totalSavings + cardSavings
        }
    }

    private var annualFeeThisMonth: Int {
        cards
            .filter { $0.approvedMonth == currentMonth && currentYear >= $0.approvedYear }
            .reduce(0) { $0 + $1.annualFee }
    }

    var body: some View {
        if !cards.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                headerView

                HStack(alignment: .center, spacing: 0) {
                    statBox(title: AppLocale.string("Annual Fee"), value: "$\(annualFeeThisMonth)", icon: "banknote.fill", color: .red)
                    separator
                    statBox(title: AppLocale.string("Redeemed"), value: "$\(redeemedThisMonth)", icon: "gift.fill", color: .green)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .contentShape(Rectangle())
                .onTapGesture { showMonthDetail = true }
            }
            .sheet(isPresented: $showMonthDetail) {
                MonthDetailSheet(month: currentMonth, year: currentYear, cards: cards)
            }
        }
    }

    private var headerView: some View {
        Text("💰 THIS MONTH")
            .font(.churHeadline())
            .foregroundStyle(Color.churOlive)
    }

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
}
