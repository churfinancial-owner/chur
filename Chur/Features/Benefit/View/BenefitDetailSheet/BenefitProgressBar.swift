//
//  BenefitProgressBar.swift
//  Chur
//
//  Created by Pak Ho on 4/12/26.
//

import SwiftUI

struct BenefitProgressBar: View {
    let usageHistory: [BenefitUsageRecord]
    let frequency: String?
    let periodBudget: Int?
    let valueCurrency: String?
    let isCountLimited: Bool
    let isUnlimited: Bool
    let expiryDate: Date?
    
    @Binding var selectedYear: Int
    @Binding var selectedPeriodIndex: Int

    private let calendar = Calendar.current
    private var currentYear: Int { calendar.component(.year, from: Date()) }
    private var currentMonth: Int { calendar.component(.month, from: Date()) }
    
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
    
    var body: some View {
        if freq != "one-time" && freq != "quadrennial" {
            VStack(alignment: .leading, spacing: 16) {
                Divider()
                
                Text("PROGRESS")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .kerning(1.2)
                    .foregroundStyle(Color.churMediumGray)
                progressBar
                periodSummaryChip
            }
        }
    }

    @ViewBuilder
    private var periodSummaryChip: some View {
        let info = selectedPeriodInfo
        HStack {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill((info.usedAmount > 0 ? Color.churOlive : Color.churMediumGray).opacity(0.15))
                        .frame(width: 24, height: 24)
                    
                    Image(systemName: info.isFull ? "checkmark" : "circle.badge.exclamationmark")
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(info.usedAmount > 0 ? Color.churOlive : Color.churMediumGray)
                }
                
                VStack(alignment: .leading, spacing: 0) {
                    Text(info.label.uppercased())
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.churMediumGray)
                    
                    Text(usageSummaryText(used: info.usedAmount))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.churDarkGray)
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    @ViewBuilder
    private var progressBar: some View {
        let r: CGFloat = periodsInYear >= 12 ? 3 : periodsInYear >= 4 ? 5 : 7
        HStack(spacing: 3) {
            if periodsInYear > 0 {
                ForEach(1...periodsInYear, id: \.self) { index in
                    let data = BenefitUsageAnalyzer.periodStatusInfo(
                        for: index,
                        year: selectedYear,
                        frequency: frequency ?? "",
                        history: usageHistory,
                        budget: periodBudget,
                        isValueBased: isValueBased
                    )
                    let isSelected = selectedPeriodIndex == data.index
                    let fillColor: Color =
                    data.isFull    ? Color.churstatusgreen :
                    data.isPartial ? Color.churstatusgreen.opacity(0.4) :
                    data.isEmptyPast ? Color.churstatuspink.opacity(0.6) :
                    data.isFuture  ? Color.churLightGray.opacity(0.2) :
                    data.isCurrent ? Color.churLightGray.opacity(0.5) :
                    Color.churLightGray.opacity(0.35)
                    
                    RoundedRectangle(cornerRadius: r)
                        .fill(fillColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: r)
                                .stroke(Color.white.opacity(0.6), lineWidth: 1)
                                .offset(y: -0.5)
                                .mask(RoundedRectangle(cornerRadius: r))
                        )
                        .shadow(color: Color.black.opacity(isSelected ? 0.3 : 0), radius: 2, x: 0, y: 1)
                        .frame(maxWidth: .infinity, maxHeight: isSelected ? 16 : 12)
                        .animation(.interactiveSpring(), value: isSelected)
                }
            } else {
                // ALIGNED ANNUAL/ONE-TIME STYLE
                let yearUsage = usageHistory.filter { calendar.component(.year, from: $0.redeemedAt) == selectedYear }.reduce(0) { $0 + $1.redeemedAmount }
                let isFull = yearUsage > 0 && (!isValueBased || yearUsage >= (periodBudget ?? 0))
                let isPartial = yearUsage > 0 && !isFull
                let isEmptyPast = yearUsage == 0 && selectedYear < currentYear
                let isFuture = selectedYear > currentYear
                
                let fillColor: Color = isFull ? Color.churstatusgreen : isPartial ? Color.churstatusgreen.opacity(0.4) : isEmptyPast ? Color.churstatuspink.opacity(0.6) : isFuture ? Color.churLightGray.opacity(0.2) : Color.churLightGray.opacity(0.35)
                
                RoundedRectangle(cornerRadius: 7)
                    .fill(fillColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(Color.white.opacity(0.6), lineWidth: 1)
                            .offset(y: -0.5)
                            .mask(RoundedRectangle(cornerRadius: 7))
                    )
                    .frame(maxWidth: .infinity, maxHeight: 12) // Matches standard non-selected height
            }
        }
        .frame(height: 13)
    }
    
    private var selectedPeriodInfo: (label: String, usedAmount: Int, isFull: Bool) {
        if periodsInYear > 0 {
            let data = BenefitUsageAnalyzer.periodStatusInfo(
                for: selectedPeriodIndex,
                year: selectedYear,
                frequency: frequency ?? "",
                history: usageHistory,
                budget: periodBudget,
                isValueBased: isValueBased
            )
            return ("\(data.label) \(selectedYear)", data.usedAmount, data.isFull)
        } else {
            let yearUsage = usageHistory.filter { calendar.component(.year, from: $0.redeemedAt) == selectedYear }.reduce(0) { $0 + $1.redeemedAmount }
            let isFull = yearUsage > 0 && (!isValueBased || yearUsage >= (periodBudget ?? 0))
            return (freq == "one-time" ? "One-Time" : String(selectedYear), yearUsage, isFull)
        }
    }
    
    private func usageSummaryText(used: Int) -> String {
        if isValueBased, let currency = valueCurrency, let budget = periodBudget {
            return "\(currency.currencySymbol)\(used) of \(currency.currencySymbol)\(budget)"
        } else if let budget = periodBudget {
            return "\(used) of \(budget)"
        } else {
            return used > 0 ? "\(used) use\(used == 1 ? "" : "s")" : "No Records"
        }
    }
    
}
