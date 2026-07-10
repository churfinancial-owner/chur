//
//  BenefitDetailSheet_Automation.swift
//  Chur
//
//  Created by Pak Ho on 4/13/26.
//

import SwiftUI

struct BenefitDetailSheet_Automation_Content: View {
    // Shared Data
    let trackingMode: String
    var autoApplyEnabled: Binding<Bool>?
    let usageHistory: [BenefitUsageRecord]
    let frequency: String?
    let periodBudget: Int?
    let valueCurrency: String?
    let isCountLimited: Bool
    let isUnlimited: Bool
    let selectedYear: Int
    
    // Actions
    var onAutoApplyToggled: ((Bool, Int) -> Void)?
    var onCatchUp: (([Date]) -> Void)?

    @State private var swipeOffsetHint: CGFloat = 0

    var body: some View {
        let showAutoLog = trackingMode == "auto" && autoApplyEnabled != nil
        let showQuickLog = shouldShowQuickLog && !emptyPastPeriods.isEmpty

        if showAutoLog || showQuickLog {
            VStack(alignment: .leading, spacing: 8) {
                Text("AUTOMATION")
                    .font(.churBadgeBold())
                    .foregroundStyle(Color.churMediumGray.opacity(0.6))
                    .padding(.horizontal, 4)

                VStack(spacing: 0) {
                    // --- 1. Auto-Log Toggle ---
                    if showAutoLog, let autoApplyEnabled = autoApplyEnabled {
                        let canEnable = autoApplyEnabled.wrappedValue || currentPeriodUsedAmount > 0
                        
                        Toggle(isOn: Binding(
                            get: { autoApplyEnabled.wrappedValue },
                            set: { newValue in
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    autoApplyEnabled.wrappedValue = newValue
                                    onAutoApplyToggled?(newValue, currentPeriodUsedAmount)
                                }
                            }
                        )) {
                            automationRowLabel(
                                title: "Auto-log future benefits",
                                subtitle: autoLogSubtitle,
                                icon: autoApplyEnabled.wrappedValue ? "bolt.fill" : "bolt.slash.fill",
                                isActive: autoApplyEnabled.wrappedValue && canEnable
                            )
                        }
                        .tint(Color.churOlive)
                        .disabled(!canEnable)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        
                        if showQuickLog {
                            Divider().padding(.horizontal, 14).opacity(0.5)
                        }
                    }
                    
                    // --- 2. Quick Log Row ---
                    // Hosted in a non-scrolling List so .swipeActions work inside the outer ScrollView
                    if showQuickLog {
                        let catchUpDates = emptyPastPeriods
                        let hasMissingPeriods = !catchUpDates.isEmpty

                        List {
                            HStack {
                                automationRowLabel(
                                    title: "Quick log prior periods",
                                    subtitle: hasMissingPeriods
                                        ? "Swipe to fill \(catchUpDates.count) periods this year"
                                        : "No past periods to fill this year",
                                    icon: "sparkles",
                                    isActive: hasMissingPeriods
                                )

                                Spacer()

                                if hasMissingPeriods {
                                    HStack(spacing: 2) {
                                        Image(systemName: "chevron.left")
                                        Image(systemName: "chevron.left")
                                    }
                                    .font(.churBadgeBold())
                                    .foregroundStyle(Color.churOlive.opacity(0.4))
                                    .offset(x: swipeOffsetHint)
                                }
                            }
                            .padding(.vertical, 16)
                            .listRowInsets(EdgeInsets(top: 0, leading: 14, bottom: 0, trailing: 14))
                            .listRowBackground(Color.white)
                            .listRowSeparator(.hidden)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                if hasMissingPeriods {
                                    Button {
                                        onCatchUp?(catchUpDates)
                                    } label: {
                                        Label("Quick Log", systemImage: "sparkles")
                                    }
                                    .tint(Color.churOlive)
                                }
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .scrollDisabled(true)
                        .frame(height: 68)
                    }
                }
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: .black.opacity(0.03), radius: 10, y: 5)
            }
            .padding(.top, 4)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    swipeOffsetHint = -6
                }
            }
        }
    }
}

// MARK: - Logic & UI Helpers
private extension BenefitDetailSheet_Automation_Content {
    var currentCalendarYear: Int { Calendar.current.component(.year, from: Date()) }
    var currentPeriodIndex: Int {
        let month = Calendar.current.component(.month, from: Date())
        let pInYear = periodsInYear
        if pInYear <= 1 { return 1 }
        return (month - 1) / (12 / pInYear) + 1
    }
    
    var periodsInYear: Int {
        switch frequency?.lowercased() {
        case "monthly": return 12
        case "quarterly": return 4
        case "semi-annual": return 2
        default: return 1
        }
    }

    var isValueBased: Bool { valueCurrency != nil && !isCountLimited && !isUnlimited }

    var currentPeriodUsedAmount: Int {
        BenefitUsageAnalyzer.periodStatusInfo(
            for: currentPeriodIndex,
            year: currentCalendarYear,
            frequency: frequency ?? "",
            history: usageHistory,
            budget: periodBudget,
            isValueBased: isValueBased
        ).usedAmount
    }

    var autoLogSubtitle: String {
        let isOn = autoApplyEnabled?.wrappedValue ?? false
        let amount = currentPeriodUsedAmount
        guard amount > 0 else {
            return isOn ? "Auto-logging each period" : "Log a usage in the latest period to enable"
        }
        let symbol = valueCurrency ?? ""
        if isValueBased {
            return isOn ? "Auto-logging \(symbol)\(amount) each period" : "Will log \(symbol)\(amount) each period"
        } else {
            let uses = "\(amount) use\(amount == 1 ? "" : "s")"
            return isOn ? "Auto-logging \(uses) each period" : "Will log \(uses) each period"
        }
    }

    var shouldShowQuickLog: Bool {
        let freq = frequency?.lowercased() ?? ""
        if freq == "one-time" || freq == "quadrennial" { return false }
        if freq == "annual" && selectedYear < currentCalendarYear { return false }
        return true
    }

    var emptyPastPeriods: [Date] {
        guard periodsInYear >= 1 else { return [] }
        let calendar = Calendar.current
        let mpp = 12 / max(1, periodsInYear)
        return (1...periodsInYear).compactMap { idx in
            guard BenefitUsageAnalyzer.periodStatusInfo(
                for: idx, year: selectedYear, frequency: frequency ?? "",
                history: usageHistory, budget: periodBudget, isValueBased: isValueBased
            ).isEmptyPast else { return nil }

            let startMonth = (idx - 1) * mpp + 1
            let startDate = calendar.date(from: DateComponents(year: selectedYear, month: startMonth, day: 1))!
            let nextStart = calendar.date(byAdding: .month, value: mpp, to: startDate)!
            return calendar.date(byAdding: .day, value: -1, to: nextStart)!
        }
    }

    @ViewBuilder
    func automationRowLabel(title: String, subtitle: String, icon: String, isActive: Bool) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(isActive ? Color.churOlive.opacity(0.15) : Color.churLightGray.opacity(0.3))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(isActive ? Color.churOlive : Color.churMediumGray)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.churCaption())
                    .foregroundStyle(isActive ? Color.churDarkGray : Color.churMediumGray)
                Text(subtitle)
                    .font(.churMicroMedium())
                    .foregroundStyle(Color.churMediumGray)
            }
        }
    }
}
