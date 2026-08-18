import SwiftUI

struct BenefitDetailSheet_LogUsage_Content: View {
    // MARK: - Bindings
    @Binding var selectedYear: Int
    @Binding var selectedPeriodIndex: Int
    @Binding var localRemainingBalance: Int?
    @Binding var localIsFullyRedeemed: Bool
    
    // MARK: - Properties
    let usageHistory: [BenefitUsageRecord]
    let frequency: String?
    let periodBudget: Int?
    let valueCurrency: String?
    let isCountLimited: Bool
    let isUnlimited: Bool
    let remainingBalance: Int?
    let isFullyRedeemed: Bool
    
    // MARK: - Actions
    var onLogUsage: ((Int) -> Void)?
    var onLogUsageAt: ((Int, Date) -> Void)?
    
    // MARK: - Internal State
    @State private var sliderAmount: Double = 0
    @State private var countToLog: Int = 1
    
    // MARK: - Body
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            headerSection
            
            VStack(spacing: 12) {
                yearPicker
                if periodsInYear > 1 {
                    periodPicker
                }
            }
            .padding(12)
            .background(Color.churLightGray.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            
            VStack(spacing: 24) {
                inputConsole
            }
            .padding(.horizontal, 20)
            // Top padding was missing entirely, so "AMOUNT TO RECORD" sat on
            // the card's edge while the bottom had 20pt.
            .padding(.top, 20)
            .padding(.bottom, 20)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.06), radius: 15, x: 0, y: 10)
            )
        }
        .padding(.vertical, 10)
        // Start at the full remaining balance rather than at zero: logging the
        // whole thing is the common case, and dragging down from the top is
        // less work than dragging up from nothing. Re-seeds whenever the
        // ceiling moves — a year change, a period change, or a log that just
        // reduced the balance — which is why the three manual resets to 0 are
        // gone. `initial: true` covers first appearance.
        .onChange(of: maxLoggableAmount, initial: true) { _, newMax in
            sliderAmount = newMax
        }
    }
}

// MARK: - Logic & Calculations
extension BenefitDetailSheet_LogUsage_Content {
    var currentCalendarYear: Int { Calendar.current.component(.year, from: Date()) }
    
    var periodsInYear: Int {
        switch frequency?.lowercased() {
        case "monthly": return 12
        case "quarterly": return 4
        case "semi-annual": return 2
        default: return 1
        }
    }
    
    var currentPeriodIndex: Int {
        let month = Calendar.current.component(.month, from: Date())
        if periodsInYear <= 1 { return 1 }
        return (month - 1) / (12 / periodsInYear) + 1
    }
    
    var isCurrentPeriod: Bool {
        selectedYear == currentCalendarYear && selectedPeriodIndex == currentPeriodIndex
    }
    
    var isValueBased: Bool {
        valueCurrency != nil && !isCountLimited && !isUnlimited
    }
    
    /// Calculates the date to log against if the user is picking a past/future period.
    /// Defaults to the last day of the selected period.
    var selectedPeriodDate: Date {
        if isCurrentPeriod { return Date() }
        let cal = Calendar.current
        let mpp = periodsInYear <= 1 ? 12 : 12 / periodsInYear
        let startMonth = (selectedPeriodIndex - 1) * mpp + 1
        let startDate = cal.date(from: DateComponents(year: selectedYear, month: startMonth, day: 1))!
        let nextStart = cal.date(byAdding: .month, value: mpp, to: startDate)!
        return cal.date(byAdding: .day, value: -1, to: nextStart)!
    }
    
    /// The most that can be logged into the selected period.
    var maxLoggableAmount: Double {
        isCurrentPeriod
            ? Double(localRemainingBalance ?? remainingBalance ?? 0)
            : Double(max(0, (periodBudget ?? 0) - selectedPeriodUsedAmount))
    }

    var selectedPeriodUsedAmount: Int {
        BenefitUsageAnalyzer.periodStatusInfo(
            for: selectedPeriodIndex,
            year: selectedYear,
            frequency: frequency ?? "",
            history: usageHistory,
            budget: periodBudget,
            isValueBased: isValueBased
        ).usedAmount
    }
}

// MARK: - Subviews
private extension BenefitDetailSheet_LogUsage_Content {
    
    var headerSection: some View {
        HStack {
            Text("RECORD USAGE")
                .font(.churMicroBold())
                .kerning(1.2)
                .foregroundStyle(Color.churMediumGray)
            Spacer()
        }
        .padding(.horizontal, 4)
    }

    private var earliestSelectableYear: Int { currentCalendarYear - 2 }

    /// Year stepper: `‹ 2026 ›`.
    ///
    /// Replaced three capsules ("CURRENT", "2025", "2024") with one control.
    /// The capsules spent a full row to show three fixed choices and named the
    /// present one "CURRENT" rather than by its year, which is the one label
    /// that goes stale.
    var yearPicker: some View {
        HStack(spacing: 0) {
            yearStep(icon: "chevron.left",
                     enabled: selectedYear > earliestSelectableYear,
                     delta: -1)

            Text(String(selectedYear))
                .font(.churHeadline())
                .monospacedDigit()
                .foregroundStyle(Color.churDarkGray)
                .frame(maxWidth: .infinity)

            yearStep(icon: "chevron.right",
                     enabled: selectedYear < currentCalendarYear,
                     delta: 1)
        }
        .frame(height: 40)
        .background(Color.churOffWhite)
        .clipShape(Capsule())
    }

    private func yearStep(icon: String, enabled: Bool, delta: Int) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                let target = selectedYear + delta
                selectedYear = target
                selectedPeriodIndex = target == currentCalendarYear ? currentPeriodIndex : 1
                countToLog = 1
            }
        } label: {
            Image(systemName: icon)
                .font(.churBadgeBold())
                .foregroundStyle(enabled ? Color.churOliveDark : Color.churLightGray)
                .frame(width: 44, height: 40)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

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
                        
                        // --- COLOR LOGIC: Always show status, even if selected ---
                        let statusColor: Color = data.isFull ? Color.churstatusgreen :
                                               data.isPartial ? Color.churstatusgreen :
                                               data.isEmptyPast ? Color.churstatuspink :
                                               Color.churMediumGray
                        
                        let bgColor: Color = data.isFull || data.isPartial ? statusColor.opacity(0.15) :
                                           data.isEmptyPast ? statusColor.opacity(0.12) :
                                           Color.white

                        Button {
                            if !data.isFuture {
                                withAnimation(.snappy) {
                                    selectedPeriodIndex = index
                                    countToLog = 1
                                }
                            }
                        } label: {
                            VStack(spacing: 0) {
                                HStack(spacing: 5) {
                                    Text(data.label.uppercased())

                                    // Status Icons
                                    if data.isFull {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.churBadgeBold())
                                    } else if data.isPartial {
                                        Image(systemName: "circle.bottomrighthalf.pattern.checkered")
                                            .font(.churBadgeBold())
                                    }
                                }
                                .font(.churBadgeBold())
                                .foregroundStyle(statusColor)
                                .padding(.horizontal, 14)
                                .frame(height: 32)
                            }
                            .background(bgColor)
                            .clipShape(Capsule())
                            .overlay {
                                // --- THE SELECTION INDICATOR ---
                                // Instead of changing the background, we add a bold stroke or underline
                                if isSelected {
                                    Capsule()
                                        .stroke(Color.churOliveDark, lineWidth: 2.5)
                                } else {
                                    Capsule()
                                        .stroke(statusColor.opacity(0.2), lineWidth: (data.isPartial || data.isFull) ? 1 : 0)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(data.isFuture)
                        .opacity(data.isFuture ? 0.3 : 1.0)
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 4) // Space for the selection stroke
            }
        }
    
    @ViewBuilder
    var inputConsole: some View {
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

    var unlimitedEntry: some View {
        VStack(spacing: 20) {
            headerValueView(value: "\(countToLog)", suffix: countToLog == 1 ? AppLocale.string("use") : AppLocale.string("uses"))
            Stepper("", value: $countToLog, in: 1...99).labelsHidden()
            actionButton(label: AppLocale.string("Log Usage")) {
                if isCurrentPeriod { onLogUsage?(countToLog) }
                else { onLogUsageAt?(countToLog, selectedPeriodDate) }
            }
        }
    }

    func valueBasedEntry(currency: String) -> some View {
        let maxAmount = maxLoggableAmount
        return VStack(spacing: 20) {
            headerValueView(value: "\(Int(sliderAmount))", prefix: currency)
            Slider(value: $sliderAmount, in: 0...max(1, maxAmount), step: 1).tint(Color.churOlive)
            actionButton(label: AppLocale.string("Log \(currency)\(Int(sliderAmount))"), isActive: sliderAmount > 0) {
                if isCurrentPeriod { onLogUsage?(Int(sliderAmount)) }
                else { onLogUsageAt?(Int(sliderAmount), selectedPeriodDate) }
            }
        }
    }

    var countBasedEntry: some View {
        let localRemaining = localRemainingBalance ?? remainingBalance ?? 0
        let isExhausted = localRemaining == 0
        return VStack(spacing: 20) {
            headerValueView(value: "\(countToLog)", suffix: AppLocale.string("uses"), isExhausted: isExhausted)
            Stepper("", value: $countToLog, in: 1...max(1, localRemaining)).labelsHidden().disabled(isExhausted)
            actionButton(label: isExhausted ? AppLocale.string("Fully Redeemed") : AppLocale.string("Log \(countToLog) Uses"), isActive: !isExhausted) {
                if isCurrentPeriod { onLogUsage?(countToLog) }
                else { onLogUsageAt?(countToLog, selectedPeriodDate) }
            }
        }
    }

    func headerValueView(value: String, prefix: String = "", suffix: String = "", isExhausted: Bool = false) -> some View {
        VStack(spacing: 4) {
            Text("AMOUNT TO RECORD").font(.churNanoBold()).kerning(1.0).foregroundStyle(Color.churMediumGray.opacity(0.6))
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                if !prefix.isEmpty { Text(prefix).font(.churTitle2()).foregroundStyle(Color.churMediumGray) }
                Text(value).font(.churBigTitle1()).contentTransition(.numericText())
                if !suffix.isEmpty { Text(suffix).font(.churSubheadline()).foregroundStyle(Color.churMediumGray) }
            }
            .foregroundStyle(isExhausted ? Color.churMediumGray : Color.churOlive)
        }
    }

    func actionButton(label: String, isActive: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            action()
        }) {
            HStack {
                Spacer(); Text(label); Spacer()
                Image(systemName: "arrow.right.circle.fill").font(.system(size: 20))
            }
            .font(.churRowText())
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 20)
            .background(Capsule().fill(isActive ? Color.churOlive : Color.churLightGray.opacity(0.5)))
            .shadow(color: isActive ? Color.churOlive.opacity(0.3) : .clear, radius: 10, y: 5)
        }
        .disabled(!isActive)
    }
}
