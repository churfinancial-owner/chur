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
    let isMuted: Binding<Bool>?
    let usageHistory: [BenefitUsageRecord]

    var onLogUsage: ((Int) -> Void)?
    var onClearUsage: (() -> Void)?
    var onUndoLastUse: (() -> Void)?
    var onAutoApplyToggled: ((Bool, Int) -> Void)?
    var onLogUsageAt: ((Int, Date) -> Void)?
    var onDeleteRecord: ((BenefitUsageRecord) -> Void)?
    var onCatchUp: (([Date]) -> Void)?

    // MARK: - State
    @State var localRemainingBalance: Int? = nil
    @State var localIsFullyRedeemed: Bool = false

    @State var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State var selectedPeriodIndex: Int = 1

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                // --- 1. Header & Description ---
                VStack(alignment: .leading, spacing: 12) {
                    heroHeader // Defined in BenefitDetailSheet_Header.swift
                    
                    Text(description)
                        .font(.churSmallBold())
                        .foregroundStyle(Color.churMediumGray)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                // --- 2. Interactive Progress Visualization ---
                // This component now acts as the trigger for the management sub-view
                BenefitProgressBar(
                    name: name,
                    usageHistory: usageHistory,
                    frequency: frequency,
                    periodBudget: periodBudget,
                    valueCurrency: valueCurrency,
                    isCountLimited: isCountLimited,
                    isUnlimited: isUnlimited,
                    trackingMode: trackingMode,
                    expiryDate: expiryDate,
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
                
                // --- 3. Preferences ---
                preferencesSection
            }
            .padding(24)
            .padding(.bottom, 30)
        }
        .background(Color.churOffWhite.ignoresSafeArea())
        .onAppear {
            setupInitialState()
        }
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

    var isValueBased: Bool { valueCurrency != nil && !isCountLimited && !isUnlimited }

    @ViewBuilder
    var preferencesSection: some View {
        if let isMuted = isMuted {
            VStack(alignment: .leading, spacing: 8) {
                Text("PREFERENCES")
                    .font(.churMicroBold())
                    .kerning(1.2)
                    .foregroundStyle(Color.churMediumGray)

                Toggle(isOn: Binding(get: { !isMuted.wrappedValue }, set: { isMuted.wrappedValue = !$0 })) {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(isMuted.wrappedValue
                                    ? Color.churLightGray.opacity(0.3)
                                    : Color.churOlive.opacity(0.15))
                                .frame(width: 36, height: 36)
                            Image(systemName: isMuted.wrappedValue ? "bell.slash.fill" : "bell.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(isMuted.wrappedValue ? Color.churMediumGray : Color.churOlive)
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Reminders")
                                .font(.churCaption())
                                .foregroundStyle(isMuted.wrappedValue ? Color.churMediumGray : Color.churDarkGray)
                            Text(isMuted.wrappedValue
                                ? "Reminders silenced"
                                : "You'll be reminded before this expires")
                                .font(.churMicroMedium())
                                .foregroundStyle(Color.churMediumGray)
                        }
                    }
                }
                .tint(Color.churOlive)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: .black.opacity(0.03), radius: 10, y: 5)
            }
        }
    }
}
