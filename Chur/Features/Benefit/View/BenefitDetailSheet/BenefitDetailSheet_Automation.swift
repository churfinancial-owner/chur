//
//  BenefitDetailSheet_Automation.swift
//  Chur
//
//  Created by Pak Ho on 4/13/26.
//

import SwiftUI

extension BenefitDetailSheet {

    @ViewBuilder
    var autoApplySection: some View {
        let showAutoLog = trackingMode == "auto" && autoApplyEnabled != nil
        let showQuickLog = shouldShowQuickLog && !emptyPastPeriods.isEmpty

        if showAutoLog || showQuickLog {
            VStack(alignment: .leading, spacing: 8) {
                Text("AUTOMATION")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundStyle(Color.churMediumGray.opacity(0.6))
                    .padding(.horizontal, 4)

                VStack(spacing: 0) {
                    // --- 1. Auto-Log Toggle ---
                    if showAutoLog, let autoApplyEnabled = autoApplyEnabled {
                        Toggle(isOn: Binding(
                            get: { autoApplyEnabled.wrappedValue },
                            set: { newValue in
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    autoApplyEnabled.wrappedValue = newValue
                                    onAutoApplyToggled?(newValue)
                                }
                            }
                        )) {
                            automationRowLabel(
                                title: "Auto-log future benefits",
                                subtitle: "Logs the full amount for you each period",
                                icon: autoApplyEnabled.wrappedValue ? "bolt.fill" : "bolt.slash.fill",
                                isActive: autoApplyEnabled.wrappedValue
                            )
                        }
                        .tint(Color.churOlive)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        
                        if showQuickLog {
                            Divider().padding(.horizontal, 14).opacity(0.5)
                        }
                    }
                    
                    // --- 2. Enhanced Swipe Row ---
                    if showQuickLog {
                        let catchUpDates = emptyPastPeriods
                        let hasMissingPeriods = !catchUpDates.isEmpty
                        let periodLabel = periodTypeName
                        
                        List {
                            HStack {
                                automationRowLabel(
                                    title: "Quick log",
                                    subtitle: hasMissingPeriods
                                        ? "Swipe to fill \(catchUpDates.count) periods this year"
                                        : "No past periods to fill this year",
                                    icon: "sparkles",
                                    isActive: hasMissingPeriods
                                )
                                
                                Spacer()
                                
                                // --- Swipe Hint Arrows ---
                                if hasMissingPeriods {
                                    HStack(spacing: 2) {
                                        Image(systemName: "chevron.left")
                                        Image(systemName: "chevron.left")
                                        Image(systemName: "chevron.left")
                                    }
                                    .font(.system(size: 10, weight: .black))
                                    .foregroundStyle(Color.churOlive.opacity(0.4))
                                    .offset(x: swipeOffsetHint)
                                }
                            }
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 16, leading: 14, bottom: 16, trailing: 14))
                            .listRowBackground(Color.white)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                if hasMissingPeriods {
                                    Button {
                                        onCatchUp?(catchUpDates)
                                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                                    } label: {
                                        Label("Quick Log", systemImage: "bolt.badge.a.fill")
                                            .font(.system(size: 10, weight: .bold, design: .rounded))
                                            .foregroundStyle(Color.churOlive)
                                    }
                                    .tint(Color.churOlive)
                                }
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .scrollDisabled(true)
                        .frame(height: 72)
                    }
                }
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: .black.opacity(0.03), radius: 10, y: 5)
            }
            .padding(.top, 4)
        }
    }

    // MARK: - Logic Helpers
    
    private var shouldShowQuickLog: Bool {
        let freq = frequency?.lowercased() ?? ""
        
        if freq == "one-time" || freq == "quadrennial" {
            return false
        }
        
        let currentYear = Calendar.current.component(.year, from: Date.current())
        if freq == "annual" && selectedYear < currentYear {
            return false
        }
        
        return true
    }

    @ViewBuilder
    private func automationRowLabel(title: String, subtitle: String, icon: String, isActive: Bool) -> some View {
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
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(isActive ? Color.churDarkGray : Color.churMediumGray)
                
                Text(subtitle)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.churMediumGray)
            }
        }
    }
    
    private var periodTypeName: String {
        switch frequency?.lowercased() {
        case "monthly":     return "month"
        case "quarterly":   return "quarter"
        case "semi-annual": return "half"
        case "annual":      return "year"
        default:            return "period"
        }
    }

    private var emptyPastPeriods: [Date] {
        guard periodsInYear >= 1 else { return [] }
        let calendar = Calendar.current
        let mpp = 12 / max(1, periodsInYear)

        return (1...periodsInYear).compactMap { idx in
            guard BenefitUsageAnalyzer.periodStatusInfo(
                for: idx,
                year: selectedYear,
                frequency: frequency ?? "",
                history: usageHistory,
                budget: periodBudget,
                isValueBased: isValueBased
            ).isEmptyPast else { return nil }

            let startMonth = (idx - 1) * mpp + 1
            let startDate = calendar.date(from: DateComponents(year: selectedYear, month: startMonth, day: 1))!
            let nextStart = calendar.date(byAdding: .month, value: mpp, to: startDate)!
            return calendar.date(byAdding: .day, value: -1, to: nextStart)!
        }
    }
}
