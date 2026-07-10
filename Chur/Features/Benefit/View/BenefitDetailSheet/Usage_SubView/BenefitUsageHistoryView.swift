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
            Divider().padding(.bottom, 8)

            HStack {
                Text("LOG HISTORY")
                    .font(.churMicroBold())
                    .kerning(1.2)
                    .foregroundStyle(Color.churMediumGray)
                
                Spacer()
                
                Text("\(recordsForSelectedPeriod.count) \(recordsForSelectedPeriod.count == 1 ? "Entry" : "Entries")")
                    .font(.churBadgeBold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.churLightGray.opacity(0.15))
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

        VStack(spacing: 0) {
            if records.isEmpty {
                emptyState
            } else {
                ForEach(Array(records.enumerated()), id: \.element.id) { index, record in
                    recordRow(record: record, isLast: index == records.count - 1)
                }
            }
        }
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.03), radius: 15, x: 0, y: 10)
        )
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.badge.questionmark")
                .font(.churBigTitle3())
                .foregroundStyle(Color.churLightGray)
            
            Text("No activity for this period")
                .font(.churCaption())
                .foregroundStyle(Color.churMediumGray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    @ViewBuilder
    private func recordRow(record: BenefitUsageRecord, isLast: Bool) -> some View {
        HStack(alignment: .center, spacing: 16) {
            // Timeline Date Block
            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    Text(record.redeemedAt.formatted(.dateTime.day()))
                        .font(.churRowText())
                        .foregroundStyle(Color.churDarkGray)
                    
                    Text(record.redeemedAt.formatted(.dateTime.month(.abbreviated)).uppercased())
                        .font(.system(size: 8, weight: .black))
                        .foregroundStyle(Color.churMediumGray)
                }
                .frame(width: 44, height: 44)
                .background(Color.churLightGray.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                
                // Timeline Connector Line
                if !isLast {
                    Rectangle()
                        .fill(Color.churLightGray.opacity(0.2))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                        .padding(.vertical, 4)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                let amountText = isValueBased ?
                    "\(valueCurrency!.currencySymbol)\(record.redeemedAmount)" :
                    "\(record.redeemedAmount) \(record.redeemedAmount == 1 ? "use" : "uses")"
                
                Text(amountText)
                    .font(.churSubheadline())
                    .foregroundStyle(Color.churDarkGray)
                
                // Source Badge
                HStack(spacing: 4) {
                    let isManual = record.source == nil || record.source == "manual"
                    
                    Text(isManual ? "MANUAL" : (record.source?.uppercased() ?? "AUTO"))
                        .font(.system(size: 8, weight: .black, design: .rounded))
                        .kerning(0.5)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.churOlive.opacity(0.1))
                .foregroundStyle(Color.churOlive)
                .clipShape(Capsule())
            }
            
            Spacer()
            
            // Refined Delete Trigger
            Button {
                withAnimation { onDeleteRecord?(record) }
            } label: {
                Image(systemName: "trash.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.churMediumGray.opacity(0.8))
                    .frame(width: 32, height: 32)
                    .background(Color.churLightGray.opacity(0.1))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}
