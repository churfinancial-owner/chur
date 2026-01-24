//
//  BenefitDetailSheet.swift
//  Chur
//
//  Created by Pak Ho on 4/13/26.
//


import SwiftUI

struct BenefitDetailSheet: View {
    let name: String
    let description: String
    let value: String?
    let frequency: String?
    let partnerName: String?
    let limitDescription: String?
    let benefitNotes: String?
    let remainingBalance: Int?
    let periodBudget: Int?
    let isFullyRedeemed: Bool
    let expiryDate: Date?
    let valueCurrency: String?
    let isUnlimited: Bool
    let isCountLimited: Bool
    let currentPeriodUsageCount: Int
    let resetType: String
    let trackingMode: String
    let autoApplyEnabled: Binding<Bool>?
    let usageHistory: [BenefitUsageRecord]

    var onLogUsage: ((Int) -> Void)?
    var onClearUsage: (() -> Void)?
    var onUndoLastUse: (() -> Void)?
    var onAutoApplyToggled: ((Bool) -> Void)?
    var onLogUsageAt: ((Int, Date) -> Void)?
    var onDeleteRecord: ((BenefitUsageRecord) -> Void)?
    var onCatchUp: (([Date]) -> Void)?

    // MARK: - State
    @State var sliderAmount: Double = 0
    @State var localRemainingBalance: Int? = nil
    @State var localIsFullyRedeemed: Bool = false
    @State var countToLog: Int = 1
    @AppStorage("expiryWarningDays") var expiryWarningDays: Int = 3

    @State var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State var selectedPeriodIndex: Int = 1
    @State var swipeOffset: CGFloat = 0.0
    @State var swipeOffsetHint: CGFloat = 0
    @State var isExpanded: Bool = false

    var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    // --- 1. Header & Description ---
                    VStack(alignment: .leading, spacing: 12) {
                        heroHeader
                        
                        Text(description)
                            .font(.churSmallBold())
                            .foregroundStyle(Color.churMediumGray)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    // --- 2. Progress Visualization ---
                    BenefitProgressBar(
                        usageHistory: usageHistory,
                        frequency: frequency,
                        periodBudget: periodBudget,
                        valueCurrency: valueCurrency,
                        isCountLimited: isCountLimited,
                        isUnlimited: isUnlimited,
                        expiryDate: expiryDate,
                        selectedYear: $selectedYear,
                        selectedPeriodIndex: $selectedPeriodIndex,
                    )
                    
                    // --- 3. The Action Card (Recording) ---
                    logUsageSection
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .bottom)),
                            removal: .opacity
                        ))
                    
                    // --- 4. Historical Activity ---
                    BenefitUsageHistoryView(
                        usageHistory: usageHistory,
                        frequency: frequency,
                        periodBudget: periodBudget,
                        valueCurrency: valueCurrency,
                        isCountLimited: isCountLimited,
                        isUnlimited: isUnlimited,
                        selectedYear: $selectedYear,
                        selectedPeriodIndex: $selectedPeriodIndex,
                        onDeleteRecord: onDeleteRecord
                    )
                }
                .padding(24)
                .padding(.bottom, 30)
            }
            .background(Color.churOffWhite.ignoresSafeArea())
            .onAppear {
                setupInitialState()
                
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    swipeOffsetHint = -6
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: selectedYear)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: selectedPeriodIndex)
            // When a history record is deleted the parent recomputes remainingBalance/isFullyRedeemed
            // and passes new values in. Sync the optimistic locals so the slider/counter reflects
            // the restored balance immediately.
            .onChange(of: remainingBalance) { _, newValue in
                localRemainingBalance = newValue
            }
            .onChange(of: isFullyRedeemed) { _, newValue in
                localIsFullyRedeemed = newValue
            }
        }
    
    private func setupInitialState() {
        localRemainingBalance = remainingBalance
        localIsFullyRedeemed = isFullyRedeemed
        
        // Auto-select the current period when the sheet opens
        selectedYear = currentCalendarYear
        selectedPeriodIndex = currentPeriodIndex
    }
}

// MARK: - SHARED HELPERS
extension BenefitDetailSheet {
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

    var isValueBased: Bool { valueCurrency != nil && !isCountLimited && !isUnlimited }

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
    
    var selectedPeriodDate: Date {
        if isCurrentPeriod { return Date() }
        let cal = Calendar.current
        if periodsInYear <= 1 {
            return cal.date(from: DateComponents(year: selectedYear, month: 12, day: 31)) ?? Date()
        }
        let mpp = 12 / periodsInYear
        let startMonth = (selectedPeriodIndex - 1) * mpp + 1
        let startDate = cal.date(from: DateComponents(year: selectedYear, month: startMonth, day: 1))!
        let nextStart = cal.date(byAdding: .month, value: mpp, to: startDate)!
        return cal.date(byAdding: .day, value: -1, to: nextStart)!
    }
}
