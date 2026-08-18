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
        ScrollView {
            VStack(spacing: 0) {
                header

                VStack(spacing: PopupCardMetrics.stackSpacing) {
                    // Each section is its own card now, rather than three blocks
                    // sharing one 24pt pad — the rhythm between them is what
                    // separates "record", "automate" and "history".
                    PopupSectionCard {
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
                    }

                    PopupSectionCard {
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
                    }

                    PopupSectionCard {
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
                }
                .padding(.horizontal, 16)
                .popupHeroOverlap()

                Spacer(minLength: 40)
            }
        }
        .background(Color.churOffWhite.ignoresSafeArea())
    }

    // MARK: - Header

    /// No NavigationView: the sage hero carries the title, so a nav bar above it
    /// would put a second surface between the sheet edge and the colour — the
    /// same two-layer problem the hero's top bleed exists to avoid.
    private var header: some View {
        PopupHeroHeader {
            VStack(alignment: .leading, spacing: 0) {
                HeaderCapsuleBubble(text: AppLocale.string("MANAGE USAGE"),
                                    icon: "slider.horizontal.3")
                    .popupHeroActionInset()

                Text(name)
                    .popupHeroTitle()
                    .popupHeroActionInset()
                    .padding(.top, 10)
            }
        }
        // Done takes the slot the avatar uses on the other sheets — this screen
        // has no mark, and the save action is what belongs in the corner.
        .overlay(alignment: .topTrailing) { doneButton }
    }

    private var doneButton: some View {
        Button { dismiss() } label: {
            Text("Done")
                .font(.churRowText())
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.churSageDeep, in: Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
        .padding(.trailing, PopupHeroMetrics.avatarTrailing)
        .padding(.top, PopupHeroMetrics.avatarTop)
    }
}
