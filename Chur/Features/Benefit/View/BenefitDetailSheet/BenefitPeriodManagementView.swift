import SwiftUI

struct BenefitPeriodManagementView: View {
    // Data passed from parent
    let name: String
    let usageHistory: [BenefitUsageRecord]
    let frequency: String?
    let periodBudget: Int?
    let valueCurrency: String?
    let isCountLimited: Bool
    let isUnlimited: Bool
    let trackingMode: String
    
    // Parent Bindings
    @Binding var selectedYear: Int
    @Binding var selectedPeriodIndex: Int
    var autoApplyEnabled: Binding<Bool>?
    
    // Optimistic UI State (moved from parent)
    @Binding var localRemainingBalance: Int?
    @Binding var localIsFullyRedeemed: Bool
    
    // Static Parent Data
    let remainingBalance: Int?
    let isFullyRedeemed: Bool
    
    // Actions
    var onLogUsage: ((Int) -> Void)?
    var onLogUsageAt: ((Int, Date) -> Void)?
    var onDeleteRecord: ((BenefitUsageRecord) -> Void)?
    var onAutoApplyToggled: ((Bool, Int) -> Void)?
    var onCatchUp: (([Date]) -> Void)?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // We reuse the components logic from the parent sheet
                    // but they are now isolated here.
                    VStack(alignment: .leading, spacing: 32) {
                        // 1. Record Usage UI
                        BenefitDetailSheet_LogUsage_Content(
                            selectedYear: $selectedYear,
                            selectedPeriodIndex: $selectedPeriodIndex,
                            localRemainingBalance: $localRemainingBalance,
                            localIsFullyRedeemed: $localIsFullyRedeemed,
                            usageHistory: usageHistory,
                            frequency: frequency,
                            periodBudget: periodBudget,
                            valueCurrency: valueCurrency,
                            isCountLimited: isCountLimited,
                            isUnlimited: isUnlimited,
                            remainingBalance: remainingBalance,
                            isFullyRedeemed: isFullyRedeemed,
                            onLogUsage: onLogUsage,
                            onLogUsageAt: onLogUsageAt
                        )

                        // 2. Automation UI
                        BenefitDetailSheet_Automation_Content(
                            trackingMode: trackingMode,
                            autoApplyEnabled: autoApplyEnabled,
                            usageHistory: usageHistory,
                            frequency: frequency,
                            periodBudget: periodBudget,
                            valueCurrency: valueCurrency,
                            isCountLimited: isCountLimited,
                            isUnlimited: isUnlimited,
                            selectedYear: selectedYear,
                            onAutoApplyToggled: onAutoApplyToggled,
                            onCatchUp: onCatchUp
                        )

                        // 3. History UI
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
                }
            }
            .navigationTitle(name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.churRowText())
                        .fontWeight(.bold)
                        .foregroundStyle(Color.churOlive)
                }
            }
            .background(Color.churOffWhite.ignoresSafeArea())
        }
    }
}
