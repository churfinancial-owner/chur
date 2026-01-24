//
//  BenefitUsageHistoryView.swift
//  Chur
//
//  Created by Pak Ho on 4/12/26.
//

import SwiftUI

struct BenefitUsageHistoryView: View {
    let usageHistory: [BenefitUsageRecord]
    let frequency: String?
    let periodBudget: Int?
    let valueCurrency: String?
    let isCountLimited: Bool
    let isUnlimited: Bool
    @Binding var selectedYear: Int
    @Binding var selectedPeriodIndex: Int
    var onDeleteRecord: ((BenefitUsageRecord) -> Void)?

    private let calendar = Calendar.current
    private var freq: String { frequency?.lowercased() ?? "" }
    private var isValueBased: Bool { valueCurrency != nil && !isCountLimited && !isUnlimited }
    
    private var periodsInYear: Int {
        switch freq {
        case "monthly":     return 12
        case "quarterly":   return 4
        case "semi-annual": return 2
        default:            return 0
        }
    }

    private var recordsForSelectedPeriod: [BenefitUsageRecord] {
        let year = selectedYear
        let idx = selectedPeriodIndex
        guard periodsInYear > 0 else {
            return freq == "one-time" ? usageHistory : usageHistory.filter { calendar.component(.year, from: $0.redeemedAt) == year }
        }
        let mpp = 12 / periodsInYear
        let startMonth = (idx - 1) * mpp + 1
        let startDate = calendar.date(from: DateComponents(year: year, month: startMonth, day: 1))!
        let endDate = calendar.date(byAdding: .month, value: mpp, to: startDate)!
        return usageHistory.filter { $0.redeemedAt >= startDate && $0.redeemedAt < endDate }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header aligned with the Log Card
            Divider().padding(.bottom, 8)

            HStack {
                Text("LOG HISTORY")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .kerning(1.2)
                    .foregroundStyle(Color.churMediumGray)
                
                Spacer()
                
                Text("\(recordsForSelectedPeriod.count) Total")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.churMediumGray.opacity(0.1))
                    .clipShape(Capsule())
                    .foregroundStyle(Color.churMediumGray)
            }
            .padding(.horizontal, 4)
            
            recordList
        }
        .padding(.top, 12)
    }

    @ViewBuilder
    private var recordList: some View {
        let records = recordsForSelectedPeriod.sorted { $0.redeemedAt > $1.redeemedAt }

        VStack(spacing: 8) {
            if records.isEmpty {
                emptyState
            } else {
                ForEach(records, id: \.id) { record in
                    recordRow(record: record)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 4)
        )
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.system(size: 24))
                .foregroundStyle(Color.churMediumGray.opacity(0.4))
            Text("No records for this period")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Color.churMediumGray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
    
    @ViewBuilder
    private func recordRow(record: BenefitUsageRecord) -> some View {
        HStack(spacing: 12) {
            // Date Pill
            VStack(alignment: .center, spacing: 0) {
                Text(record.redeemedAt.formatted(.dateTime.day()))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                Text(record.redeemedAt.formatted(.dateTime.month(.abbreviated)).uppercased())
                    .font(.system(size: 9, weight: .black))
            }
            .foregroundStyle(Color.churDarkGray)
            .frame(width: 44, height: 44)
            .background(Color.churLightGray.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: .black.opacity(0.03), radius: 2, x: 0, y: 1)
            
            VStack(alignment: .leading, spacing: 2) {
                let amountText = isValueBased ?
                    "\(valueCurrency!.currencySymbol)\(record.redeemedAmount)" :
                    "\(record.redeemedAmount) \(record.redeemedAmount == 1 ? "use" : "uses")"
                
                Text(amountText)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.churOlive)
                
                HStack(spacing: 4) {
                    let isManual = record.source == nil || record.source == "manual"
                    Image(systemName: isManual ? "person.fill" : "sparkles")
                        .font(.system(size: 8))
                    Text(isManual ? "Manual Entry" : record.source!.capitalized)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                }
                .foregroundStyle(Color.churMediumGray)
            }
            
            Spacer()
            
            // Subtle Delete Button
            Button {
                onDeleteRecord?(record)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(Color.red.opacity(0.4))
                    .frame(width: 28, height: 28)
                    .background(Color.red.opacity(0.05))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(Color.white.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
