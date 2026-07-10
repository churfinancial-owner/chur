//
//  BenefitProgressBar.swift
//  Chur
//
//  Created by Pak Ho on 4/12/26.
//

import SwiftUI

struct BenefitProgressBar: View {
    let name: String
    let usageHistory: [BenefitUsageRecord]
    let frequency: String?
    let periodBudget: Int?
    let valueCurrency: String?
    let isCountLimited: Bool
    let isUnlimited: Bool
    let trackingMode: String
    let expiryDate: Date?
    
    @Binding var selectedYear: Int
    @Binding var selectedPeriodIndex: Int
    var autoApplyEnabled: Binding<Bool>?
    @Binding var localRemainingBalance: Int?
    @Binding var localIsFullyRedeemed: Bool
    
    let remainingBalance: Int?
    let isFullyRedeemed: Bool
    
    var onLogUsage: ((Int) -> Void)?
    var onLogUsageAt: ((Int, Date) -> Void)?
    var onDeleteRecord: ((BenefitUsageRecord) -> Void)?
    var onAutoApplyToggled: ((Bool, Int) -> Void)?
    var onCatchUp: (([Date]) -> Void)?

    @State private var showingManagementSheet = false
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
    
    var body: some View {
        if freq != "one-time" && freq != "quadrennial" {
            VStack(alignment: .leading, spacing: 16) {
                Divider()
                
                HStack {
                    Text("PROGRESS")
                        .font(.churMicroBold())
                        .kerning(1.2)
                        .foregroundStyle(Color.churMediumGray)
                    Spacer()
                }
                
                progressBar
                    .padding(.top, 8) // Space for the floating indicator
                
                Button {
                    showingManagementSheet = true
                } label: {
                    periodSummaryChip
                }
                .buttonStyle(.plain)
            }
            .sheet(isPresented: $showingManagementSheet) {
                BenefitPeriodManagementView(
                    name: name,
                    usageHistory: usageHistory,
                    frequency: frequency,
                    periodBudget: periodBudget,
                    valueCurrency: valueCurrency,
                    isCountLimited: isCountLimited,
                    isUnlimited: isUnlimited,
                    trackingMode: trackingMode,
                    selectedYear: $selectedYear,
                    selectedPeriodIndex: $selectedPeriodIndex,
                    autoApplyEnabled: autoApplyEnabled,
                    localRemainingBalance: $localRemainingBalance,
                    localIsFullyRedeemed: $localIsFullyRedeemed,
                    remainingBalance: remainingBalance,
                    isFullyRedeemed: isFullyRedeemed,
                    onLogUsage: onLogUsage,
                    onLogUsageAt: onLogUsageAt,
                    onDeleteRecord: onDeleteRecord,
                    onAutoApplyToggled: onAutoApplyToggled,
                    onCatchUp: onCatchUp
                )
            }
        }
    }

    @ViewBuilder
    private var progressBar: some View {
        let r: CGFloat = periodsInYear >= 12 ? 4 : 8
        
        ZStack(alignment: .topLeading) {
            // Background Track
            Capsule()
                .fill(Color.churLightGray.opacity(0.15))
                .frame(height: 12)
                .padding(.top, 12)

            HStack(spacing: 4) {
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
                            data.isFull      ? Color.churstatusgreen :
                            data.isPartial   ? Color.churstatusgreen.opacity(0.4) :
                            data.isEmptyPast ? Color.churstatuspink.opacity(0.5) :
                            data.isCurrent   ? Color.churOlive.opacity(0.3) :
                            Color.churLightGray.opacity(0.2)

                        VStack(spacing: 6) {
                            // Floating Indicator Dot
                            Circle()
                                .fill(Color.churOlive)
                                .frame(width: 5, height: 5)
                                .opacity(isSelected ? 1 : 0)
                                .scaleEffect(isSelected ? 1 : 0.5)

                            let bar = RoundedRectangle(cornerRadius: r)
                                .fill(fillColor)
                                .overlay(
                                    RoundedRectangle(cornerRadius: r)
                                        .stroke(Color.white.opacity(0.5), lineWidth: 1)
                                        .mask(RoundedRectangle(cornerRadius: r))
                                )
                                .frame(maxWidth: .infinity)
                                .frame(height: isSelected ? 16 : 12)
                                .offset(y: isSelected ? -2 : 0)

                            if data.isFuture {
                                bar
                            } else {
                                Button {
                                    selectedPeriodIndex = data.index
                                } label: {
                                    bar
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.6), value: selectedPeriodIndex)
                    }
                }
            }
        }
        .sensoryFeedback(.selection, trigger: selectedPeriodIndex)
        .frame(height: 24)
    }

    @ViewBuilder
    private var periodSummaryChip: some View {
        let info = selectedPeriodInfo
        HStack {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill((info.usedAmount > 0 ? Color.churOlive : Color.churMediumGray).opacity(0.12))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: info.isFull ? "checkmark.seal.fill" : "exclamationmark.circle")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(info.usedAmount > 0 ? Color.churOlive : Color.churstatuspink)
                }
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(usageSummaryText(used: info.usedAmount))
                        .font(.churCaption())
                        .foregroundStyle(Color.churDarkGray)

                    Text(info.label.uppercased())
                        .font(.churMicroMedium())
                        .foregroundStyle(Color.churMediumGray)
                }
            }
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.churCaption())
                .foregroundStyle(Color.churLightGray)
                .padding(.trailing, 4)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
        )
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
