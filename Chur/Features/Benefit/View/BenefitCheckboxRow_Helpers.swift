//
//  BenefitCheckboxRow_Helpers.swift
//  Chur
//
//  Created by Pak Ho on 3/10/26.
//
//  Description: Extension for BenefitCheckboxRow containing complex
//               ViewBuilders for the title button and detail sheet.
//  



import SwiftUI

extension BenefitCheckboxRow {
    @ViewBuilder
    func titleButton(_ vm: BenefitRowViewModel) -> some View {
        Button {
            if vm.needsActivation { showingActivationConfirmation = true }
            else if !vm.isLocked { showingDetail = true }
        } label: {
            HStack(spacing: 4) {
                if let prefix = vm.valuePrefixLabel, !vm.isLocked {
                    Text(prefix)
                        .font(.churRowText())
                        .foregroundStyle(vm.isUsedInPeriod ? Color.churMediumGray : Color.churDarkGray)
                }
                Text(benefit.displayName)
                    .font(.churRowText())
                    .foregroundStyle(vm.isLocked || vm.isUsedInPeriod ? Color.churMediumGray : Color.churDarkGray)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    func detailView(_ vm: BenefitRowViewModel) -> some View {
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
