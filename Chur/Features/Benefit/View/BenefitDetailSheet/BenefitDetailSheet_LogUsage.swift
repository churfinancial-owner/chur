//
//  BenefitDetailSheet_LogUsage.swift
//  Chur
//
//
//  Created by Pak Ho on 4/13/26.
//

import SwiftUI

// MARK: - Log Usage UI

extension BenefitDetailSheet {

    @ViewBuilder
    var logUsageSection: some View {
        if onLogUsage != nil || onClearUsage != nil || onUndoLastUse != nil {
            VStack(alignment: .leading, spacing: 16) { // Reduced spacing
                Divider().padding(.bottom, 4)
                
                // --- Refined Header (Static) ---
                HStack {
                    Text("RECORD USAGE")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .kerning(1.2)
                        .foregroundStyle(Color.churMediumGray)
                    
                    Spacer()
                    
                    Text("\(String(selectedYear))")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.churMediumGray.opacity(0.1))
                        .clipShape(Capsule())
                        .foregroundStyle(Color.churMediumGray)
                }
                .padding(.horizontal, 4)

                // --- Main Logging Card ---
                VStack(spacing: 20) { // Reduced spacing
                    VStack(spacing: 10) {
                        yearPicker
                        
                        if periodsInYear > 1 {
                            periodPicker
                        }
                    }

                    ZStack {
                        if isUnlimited {
                            unlimitedEntry
                        } else if isCountLimited {
                            countBasedEntry
                        } else if let currency = valueCurrency {
                            valueBasedEntry(currency: currency)
                        } else {
                            countBasedEntry
                        }
                    }
                }
                .padding(14) // Slightly tighter padding
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)
                )

                autoApplySection
                    .padding(.horizontal, 8)
            }
        }
    }

    // MARK: - Year Picker
    @ViewBuilder
    var yearPicker: some View {
        HStack(spacing: 6) {
            let years = Array(((currentCalendarYear - 2)...currentCalendarYear).reversed())
            ForEach(years, id: \.self) { year in
                let isSelected = year == selectedYear
                
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedYear = year
                        selectedPeriodIndex = year == currentCalendarYear ? currentPeriodIndex : 1
                        sliderAmount = 0
                        countToLog = 1
                    }
                } label: {
                    Text(year == currentCalendarYear ? "THIS YEAR" : String(year))
                        .font(.system(size: 10, weight: .black, design: .rounded)) // Reduced font
                        .kerning(0.5)
                        .foregroundStyle(isSelected ? Color.churOlive : Color.churMediumGray)
                        .frame(maxWidth: .infinity)
                        .frame(height: 32) // Reduced height
                        .background(Color.churLightGray.opacity(0.12))
                        .clipShape(Capsule())
                        .overlay {
                            Capsule()
                                .stroke(Color.churOlive, lineWidth: isSelected ? 3 : 0)
                        }
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - Period Picker
    @ViewBuilder
    var periodPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(1...periodsInYear, id: \.self) { index in
                    let data = BenefitUsageAnalyzer.periodStatusInfo(
                        for: index,
                        year: selectedYear,
                        frequency: frequency ?? "",
                        history: usageHistory,
                        budget: periodBudget,
                        isValueBased: isValueBased
                    )
                    let isSelected = selectedPeriodIndex == index
                    
                    let statusColor: Color =
                        data.isFull      ? Color.churstatusgreen :
                        data.isPartial   ? Color.churstatusgreen.opacity(0.4) :
                        data.isEmptyPast ? Color.churstatuspink.opacity(0.6) :
                        data.isFuture    ? Color.churLightGray.opacity(0.1) :
                        Color.churLightGray.opacity(0.2)

                    Button {
                        guard !data.isFuture else { return }
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedPeriodIndex = index
                            sliderAmount = 0
                            countToLog = 1
                        }
                    } label: {
                        Text(data.label.uppercased())
                            .font(.system(size: 10, weight: .black, design: .rounded)) // Reduced font
                            .kerning(0.5)
                            .foregroundStyle(isSelected ? (data.isFull || data.isEmptyPast ? .white : Color.churOlive) : (data.isFull || data.isEmptyPast ? .white : Color.churDarkGray))
                            .frame(minWidth: 44)
                            .frame(height: 32)
                            .padding(.horizontal, 10)
                            .background {
                                Capsule()
                                    .fill(isSelected ? statusColor : statusColor)
                            }
                            .overlay {
                                Capsule()
                                    .stroke(Color.churOlive, lineWidth: isSelected ? 3 : 0)
                            }
                    }
                    .buttonStyle(.plain)
                    .disabled(data.isFuture)
                }
            }
            .padding(.vertical, 2)
            .padding(.horizontal, 2)
        }
    }
    
    // MARK: - Entry Forms

    @ViewBuilder
    var unlimitedEntry: some View {
        VStack(spacing: 16) {
            headerValueView(value: "\(countToLog)", suffix: countToLog == 1 ? "use" : "uses")
            Stepper("", value: $countToLog, in: 1...999).labelsHidden().scaleEffect(1.0)
            actionButton(label: "Log \(countToLog) \(countToLog == 1 ? "use" : "uses")") {
                if isCurrentPeriod { onLogUsage?(countToLog) }
                else { onLogUsageAt?(countToLog, selectedPeriodDate) }
                countToLog = 1
            }
        }
    }

    @ViewBuilder
    func valueBasedEntry(currency: String) -> some View {
        let maxAmount = isCurrentPeriod
            ? Double(localRemainingBalance ?? remainingBalance ?? 0)
            : Double(max(0, (periodBudget ?? 0) - selectedPeriodUsedAmount))

        VStack(spacing: 16) {
            headerValueView(value: "\(Int(sliderAmount))", prefix: currency.currencySymbol)
            VStack(spacing: 8) {
                Slider(value: $sliderAmount, in: 0...max(1, maxAmount), step: 1).tint(Color.churOlive)
                HStack {
                    Text("\(currency.currencySymbol)0")
                    Spacer()
                    Text("\(currency.currencySymbol)\(Int(maxAmount)) left")
                }.font(.system(size: 9, weight: .bold, design: .rounded)).foregroundStyle(Color.churMediumGray)
            }.padding(.horizontal, 8)

            actionButton(label: maxAmount > 0 ? "Log \(currency.currencySymbol)\(Int(sliderAmount))" : "Fully Redeemed", isActive: sliderAmount > 0 && maxAmount > 0) {
                let amount = Int(sliderAmount)
                if isCurrentPeriod {
                    onLogUsage?(amount)
                    let newBalance = max(0, (localRemainingBalance ?? remainingBalance ?? 0) - amount)
                    localRemainingBalance = newBalance
                    localIsFullyRedeemed = newBalance == 0
                } else { onLogUsageAt?(amount, selectedPeriodDate) }
                sliderAmount = 0
            }
        }
    }

    @ViewBuilder
    var countBasedEntry: some View {
        let isOneTime = frequency?.lowercased() == "one-time"
        let isQuad = frequency?.lowercased() == "quadrennial"
        let hasOneTimeUsage = isOneTime && !usageHistory.isEmpty
        let localRemaining = localRemainingBalance ?? remainingBalance ?? 99
        
        let isGlobalExhausted: Bool = {
            if hasOneTimeUsage { return true }
            if isQuad {
                let analyzer = BenefitUsageAnalyzer(benefit: Benefit(id: "", benefitType: "", displayGroup: "", localized: [:], frequency: "quadrennial", isRecurring: true), approvedMonth: 1)
                return !usageHistory.filter { analyzer.periodKey(for: $0.redeemedAt) == analyzer.periodKey(for: selectedPeriodDate) }.isEmpty
            }
            return false
        }()
        
        let isExhausted = (isCurrentPeriod && (localIsFullyRedeemed || localRemaining == 0)) || isGlobalExhausted
        
        VStack(spacing: 16) {
            headerValueView(value: "\(countToLog)", suffix: countToLog == 1 ? "use" : "uses", isExhausted: isExhausted)
            Stepper("", value: $countToLog, in: 1...max(1, localRemaining)).labelsHidden().scaleEffect(1.0).disabled(isExhausted)
            
            let btnLabel = hasOneTimeUsage ? "Already Used" : (isExhausted ? "Fully Redeemed" : "Log \(countToLog) \(countToLog == 1 ? "use" : "uses")")
            
            actionButton(label: btnLabel, isActive: !isExhausted) {
                if isCurrentPeriod {
                    let newBalance = max(0, localRemaining - countToLog)
                    onLogUsage?(countToLog)
                    localRemainingBalance = newBalance
                    localIsFullyRedeemed = newBalance == 0
                } else { onLogUsageAt?(countToLog, selectedPeriodDate) }
                countToLog = 1
            }
        }
    }

    // MARK: - UI Sub-components
    
    @ViewBuilder
    private func headerValueView(value: String, prefix: String = "", suffix: String = "", isExhausted: Bool = false) -> some View {
        VStack(spacing: 2) {
            Text("TO RECORD")
                .font(.system(size: 9, weight: .black))
                .foregroundStyle(Color.churMediumGray.opacity(0.6))
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                if !prefix.isEmpty { Text(prefix).font(.system(size: 20, weight: .bold, design: .rounded)) }
                Text(value).font(.system(size: 40, weight: .bold, design: .rounded)).contentTransition(.numericText())
                if !suffix.isEmpty { Text(suffix).font(.system(size: 14, weight: .bold, design: .rounded)).padding(.leading, 2) }
            }.foregroundStyle(isExhausted ? Color.churMediumGray : Color.churOlive)
        }
    }

    @ViewBuilder
    private func actionButton(label: String, isActive: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isActive { Image(systemName: "sparkles") }
                Text(label)
            }
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(isActive ? Color.churOlive : Color.churLightGray)
            .clipShape(Capsule())
            .shadow(color: Color.churOlive.opacity(isActive ? 0.15 : 0), radius: 6, y: 3)
        }
        .disabled(!isActive)
    }
}
