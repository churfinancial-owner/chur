//
//  BenefitDetailSheetHost.swift
//  Chur
//
//  Single place that assembles BenefitDetailSheet from a Benefit and its
//  row view model, so both entry points share identical behavior:
//   • BenefitCheckboxRow (tapping a benefit in the list)
//   • BenefitReminderDeepLinkSheet (tapping an expiry reminder notification)
//

import SwiftUI
import SwiftData

struct BenefitDetailSheetHost: View {
    @Bindable var benefit: Benefit
    let vm: BenefitRowViewModel
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        BenefitDetailSheet(
            name: benefit.displayName,
            description: benefit.displayDescription,
            value: benefit.value > 0 ? "\(benefit.valueCurrency) \(benefit.value)" : nil,
            frequency: benefit.frequency,
            partnerName: benefit.partnerName,
            limitDescription: benefit.limitDescription,
            benefitNotes: benefit.benefitNotes,
            remainingBalance: vm.analyzer.remainingBalance(),
            periodBudget: vm.analyzer.periodBudget(),
            isFullyRedeemed: vm.analyzer.isFullyRedeemedThisPeriod(),
            expiryDate: benefit.effectiveExpiryDate(cardAnniversaryDate: vm.anniversaryDate),
            valueCurrency: benefit.valueCurrency,
            isUnlimited: vm.analyzer.isUnlimited,
            isCountLimited: vm.analyzer.isCountLimited,
            currentPeriodUsageCount: vm.analyzer.usedThisPeriod(),
            resetType: benefit.resetType,
            trackingMode: benefit.trackingMode,
            autoApplyEnabled: $benefit.autoApplyEnabled,
            isMuted: benefit.isRemindable ? $benefit.isMuted : nil,
            usageHistory: benefit.usageHistory,
            onLogUsage: { vm.logCustomAmount($0) },
            onClearUsage: { vm.reverseUsage() },
            onUndoLastUse: {
                if let latest = vm.analyzer.recordsForCurrentPeriod().sorted(by: { $0.redeemedAt > $1.redeemedAt }).first {
                    BenefitUsageLogger().deleteUsage(latest, from: benefit, modelContext: modelContext)
                }
            },
            onAutoApplyToggled: { enabled, amount in
                // Just store/clear the amount — the user's manual log for the current period
                // stays untouched. Auto-apply fires from the next period onwards.
                benefit.autoApplyAmount = enabled ? amount : nil
            },
            onLogUsageAt: { amount, date in
                let logger = BenefitUsageLogger()
                if vm.analyzer.isUnlimited || benefit.usageLimit != nil {
                    for _ in 0..<amount {
                        logger.logUsage(for: benefit, approvedMonth: vm.approvedMonth, mode: .count, at: date, notes: "Past record", source: .manual, modelContext: modelContext)
                    }
                } else {
                    logger.logUsage(for: benefit, approvedMonth: vm.approvedMonth, mode: .amount(amount), at: date, notes: "Past record", source: .manual, modelContext: modelContext)
                }
            },
            onDeleteRecord: { record in
                BenefitUsageLogger().deleteUsage(record, from: benefit, modelContext: modelContext)
            },
            onCatchUp: { dates in
                let logger = BenefitUsageLogger()
                let analyzer = vm.analyzer
                for date in dates {
                    if analyzer.isUnlimited {
                        logger.logUsage(for: benefit, approvedMonth: vm.approvedMonth, mode: .count, at: date, notes: "Catch up", source: .manual, modelContext: modelContext)
                    } else if let limit = benefit.usageLimit, limit != -1 {
                        for _ in 0..<limit {
                            _ = logger.logUsage(for: benefit, approvedMonth: vm.approvedMonth, mode: .count, at: date, notes: "Catch up", source: .manual, modelContext: modelContext)
                        }
                    } else {
                        let budget = analyzer.budget(for: date)
                        if budget > 0 {
                            logger.logUsage(for: benefit, approvedMonth: vm.approvedMonth, mode: .amount(budget), at: date, notes: "Catch up", source: .manual, modelContext: modelContext)
                        }
                    }
                }
            }
        )
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Deep-link entry point

/// Presented from ContentView when the user taps an expiry reminder
/// notification. Builds its own row view model since there is no
/// BenefitCheckboxRow in this path.
struct BenefitReminderDeepLinkSheet: View {
    @Bindable var benefit: Benefit
    let card: CreditCard
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: BenefitRowViewModel?

    var body: some View {
        Group {
            if let vm = viewModel {
                BenefitDetailSheetHost(benefit: benefit, vm: vm)
            } else {
                Color.clear
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = BenefitRowViewModel(
                    benefit: benefit,
                    approvedMonth: card.approvedMonth,
                    approvedYear: card.approvedYear,
                    modelContext: modelContext
                )
            }
        }
    }
}
