//
//  BenefitRowModel.swift
//  Chur
//
//  Updated to handle global usage for one-time and multi-year quadrennial benefits.
//

import SwiftUI
import SwiftData
import Observation

@Observable
final class BenefitRowViewModel {
    var benefit: Benefit
    let approvedMonth: Int
    let approvedYear: Int
    var modelContext: ModelContext
    
    @ObservationIgnored
    @AppStorage("expiryWarningDays") var expiryWarningDays: Int = 3
    
    var didAutoApplyThisSession = false
    private let haptic = UIImpactFeedbackGenerator(style: .light)

    var dateRefreshTrigger: Int = 0

    init(benefit: Benefit, approvedMonth: Int, approvedYear: Int, modelContext: ModelContext) {
        self.benefit = benefit
        self.approvedMonth = approvedMonth
        self.approvedYear = approvedYear
        self.modelContext = modelContext
        haptic.prepare()
        
        #if DEBUG
        NotificationCenter.default.addObserver(
            forName: .timeTravelDateChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.dateRefreshTrigger += 1
            self?.didAutoApplyThisSession = false
            self?.attemptAutoApply()
        }
        #endif
    }
    
    // MARK: - State Properties
    
    var isLocked: Bool { benefit.isLocked(approvedMonth: approvedMonth, approvedYear: approvedYear) }
    var needsActivation: Bool { benefit.needsActivation(approvedMonth: approvedMonth) }
    var isUnlimited: Bool { analyzer.isUnlimited }
    var isCountLimited: Bool { analyzer.isCountLimited }
    
    /// UPDATED: Determines if the benefit should be visually "checked" or "dimmed"
    var isUsedInPeriod: Bool {
        let freq = benefit.frequency.lowercased()
        
        // One-time benefits are "used" if any record exists in history
        if freq == "one-time" {
            return !benefit.usageHistory.isEmpty
        }
        
        // Quadrennial relies on the 4-year stable period key
        if freq == "quadrennial" {
            return analyzer.isFullyRedeemedThisPeriod()
        }
        
        // For standard recurring benefits, check the current period budget/limit
        return (analyzer.isUnlimited || analyzer.isCountLimited) ? false : analyzer.isFullyRedeemedThisPeriod()
    }
    
    /// UPDATED: Checks if the budget for the applicable period is exhausted
    var isFullyRedeemed: Bool {
        if benefit.frequency.lowercased() == "one-time" {
            return !benefit.usageHistory.isEmpty
        }
        return analyzer.isFullyRedeemedThisPeriod()
    }
    
    var usageCountThisPeriod: Int { analyzer.usedThisPeriod() }

    var analyzer: BenefitUsageAnalyzer { BenefitUsageAnalyzer(benefit: benefit, approvedMonth: approvedMonth) }
    
    var anniversaryDate: Date? {
        let calendar = Calendar.current
        let validMonth = max(1, min(12, approvedMonth))
        return calendar.date(from: DateComponents(year: approvedYear, month: validMonth, day: 1))
    }

    // MARK: - Display Helpers

    var valuePrefixLabel: String? {
        guard analyzer.isValueBased else { return nil }
        let symbol = benefit.valueCurrency.currencySymbol
        if isUsedInPeriod { return "\(symbol)0" }
        if let remaining = analyzer.remainingBalance() { return "\(symbol)\(remaining)" }
        return nil
    }
    
    var unlockLabel: String? {
        guard isLocked else { return nil }
        if needsActivation {
            return benefit.activationMode == "lockbyfrequency" ? "Tap to activate (resets each period)" : "Tap to activate"
        }
        guard let date = benefit.estimatedActivationDate(approvedMonth: approvedMonth, approvedYear: approvedYear) else { return nil }
        let months = Calendar.current.dateComponents([.month], from: Date.current(), to: date).month ?? 0
        return months <= 0 ? "Unlocks soon" : "Unlocks in \(months) mo"
    }

    var isWithinExpiryWarning: Bool {
        let now = Date.current()
        guard let expiry = benefit.effectiveExpiryDate(cardAnniversaryDate: anniversaryDate),
              (analyzer.remainingBalance(on: now) ?? 0) > 0 else { return false }
        let warningDate = Calendar.current.date(byAdding: .day, value: expiryWarningDays, to: now) ?? now
        return expiry > now && expiry < warningDate
    }

    // MARK: - Actions
    
    func handleToggle(onConfirmWipe: @escaping () -> Void) {
        haptic.impactOccurred()
        if isUnlimited {
            logSingleUse()
        } else if isCountLimited {
            if isFullyRedeemed {
                onConfirmWipe()
            } else {
                logSingleUse()
            }
        } else if isUsedInPeriod {
            // For one-time, if used, we offer to wipe all records
            analyzer.recordsForCurrentPeriod().count > 1 || benefit.autoApplyEnabled || benefit.frequency.lowercased() == "one-time"
                ? onConfirmWipe()
                : reverseUsage()
        } else {
            applyUsage()
        }
    }
    
    func logSingleUse() {
        let logger = BenefitUsageLogger()
        logger.logUsage(for: benefit, approvedMonth: approvedMonth, mode: .count, notes: "Logged", source: .manual, modelContext: modelContext)
    }

    func applyUsage(source: BenefitUsageLogger.Source = .manual) {
        guard !isFullyRedeemed else { return } // Use updated property
        
        let logger = BenefitUsageLogger()
        let notes = source == .auto ? "Auto-applied" : "Logged"
        
        if analyzer.isUnlimited {
            logger.logUsage(for: benefit, approvedMonth: approvedMonth, mode: .count, notes: notes, source: source, modelContext: modelContext)
        } else if analyzer.isValueBased, let budget = analyzer.periodBudget(), budget > 0 {
            let remaining = budget - analyzer.usedThisPeriod()
            guard remaining > 0 else { return }
            logger.logUsage(for: benefit, approvedMonth: approvedMonth, mode: .amount(remaining), notes: notes, source: source, modelContext: modelContext)
        } else if let limit = benefit.usageLimit {
            let remaining = limit - analyzer.usedThisPeriod()
            guard remaining > 0 else { return }
            for _ in 0..<remaining {
                _ = logger.logUsage(for: benefit, approvedMonth: approvedMonth, mode: .count, notes: notes, source: source, modelContext: modelContext)
            }
        }
        if source == .auto { didAutoApplyThisSession = true }
    }

    func reverseUsage() {
        let logger = BenefitUsageLogger()
        // For one-time, we wipe the entire history; for others, just current period
        let records = benefit.frequency.lowercased() == "one-time" ? benefit.usageHistory : analyzer.recordsForCurrentPeriod()
        for record in records {
            logger.deleteUsage(record, from: benefit, modelContext: modelContext)
        }
        didAutoApplyThisSession = false
    }

    func logCustomAmount(_ amount: Int) {
        let logger = BenefitUsageLogger()
        if !analyzer.isValueBased {
            for _ in 0..<amount {
                logger.logUsage(for: benefit, approvedMonth: approvedMonth, mode: .count, notes: "Logged from detail", source: .manual, modelContext: modelContext)
            }
        } else {
            logger.logUsage(for: benefit, approvedMonth: approvedMonth, mode: .amount(amount), notes: "Logged from detail", source: .manual, modelContext: modelContext)
        }
    }

    func attemptAutoApply() {
        guard !didAutoApplyThisSession, benefit.autoApplyEnabled,
              benefit.trackingMode == "auto", !isUsedInPeriod else { return }
        applyUsage(source: .auto)
    }
}
