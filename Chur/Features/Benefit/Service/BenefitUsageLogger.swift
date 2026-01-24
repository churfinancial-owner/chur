//
//  BenefitUsageLogger.swift
//  Chur
//
//  Centralized helper for creating BenefitUsageRecords.
//
//  Every record is stamped with:
//   • periodKey       – stable string key so history can be grouped without re-running date math
//   • redeemedAmount  – exact amount or count for this event
//   • isFullyRedeemed – snapshot of whether the period budget was fully consumed at log time
//
//  Redemption modes
//  ─────────────────
//  • .count          – increments by 1 (count-based benefits: lounge visits, etc.)
//  • .amount(Int)    – records a specific dollar value (value-based credits)

//
//  BenefitUsageLogger.swift
//  Chur
//
//  Centralized helper for creating BenefitUsageRecords.
//

import Foundation
import SwiftData

struct BenefitUsageLogger {

    // MARK: - Types

    enum Source: String {
        case manual, auto, imported
    }

    enum Mode {
        /// Increment usage by 1 (count-based benefit, usageLimit is set).
        case count
        /// Record a specific dollar amount redeemed (value-based benefit, usageLimit is nil).
        case amount(Int)

        var redeemedAmount: Int {
            switch self {
            case .count:           return 1
            case .amount(let v):   return max(1, v)
            }
        }
    }

    enum LogResult {
        case logged(BenefitUsageRecord)
        case rejected(String)
    }

    // MARK: - Log

    /// Record a redemption event for a benefit.
    @discardableResult
    func logUsage(
        for benefit: Benefit,
        approvedMonth: Int,
        mode: Mode,
        at date: Date = Date.current(),
        notes: String? = nil,
        source: Source = .manual,
        externalID: String? = nil,
        modelContext: ModelContext
    ) -> LogResult {

        // ── Idempotency guard ────────────────────────────────────────────────
        if let externalID,
           benefit.usageHistory.contains(where: { $0.externalID == externalID }) {
            return .rejected("Duplicate: externalID '\(externalID)' already exists")
        }

        let analyzer = BenefitUsageAnalyzer(benefit: benefit, approvedMonth: approvedMonth)
        let key = analyzer.periodKey(for: date)
        let redeemingAmount = mode.redeemedAmount

        // ── Count-based guard (usageLimit set, but not unlimited sentinel) ───
        if let hardLimit = benefit.usageLimit, hardLimit != -1 {
            let currentCount = analyzer.recordsForCurrentPeriod(on: date).count
            if currentCount + 1 > hardLimit {
                return .rejected("Exceeds per-period usage limit (\(hardLimit))")
            }
        }

        // ── Value-based guard (usageLimit nil, dollar credit) ────────────────
        // UPDATED: Added !analyzer.isUnlimited to ensure unlimited perks (-1)
        // are not mistakenly treated as value-based dollar credits.
        if !analyzer.isUnlimited && benefit.usageLimit == nil, case .amount(let dollars) = mode {
            if let budget = analyzer.periodBudget(on: date), budget > 0 {
                let usedSoFar = analyzer.usedThisPeriod(on: date)
                if usedSoFar + dollars > budget {
                    return .rejected("Exceeds per-period budget (\(budget)). Used so far: \(usedSoFar)")
                }
            }
        }

        // ── Compute isFullyRedeemed snapshot ────────────────────────────────
        let usedAfter = analyzer.usedThisPeriod(on: date) + redeemingAmount
        let fullyRedeemed: Bool
        if let budget = analyzer.periodBudget(on: date), budget > 0 {
            fullyRedeemed = usedAfter >= budget
        } else {
            fullyRedeemed = false
        }

        // ── Create and persist record ────────────────────────────────────────
        let record = BenefitUsageRecord(
            redeemedAt: date,
            periodKey: key,
            redeemedAmount: redeemingAmount,
            isFullyRedeemed: fullyRedeemed,
            notes: notes,
            source: source.rawValue,
            externalID: externalID
        )

        modelContext.insert(record)
        benefit.usageHistory.append(record)

        return .logged(record)
    }

    // MARK: - Delete (undo)

    func deleteUsage(_ record: BenefitUsageRecord, from benefit: Benefit, modelContext: ModelContext) {
        if let idx = benefit.usageHistory.firstIndex(where: { $0.id == record.id }) {
            benefit.usageHistory.remove(at: idx)
        }
        modelContext.delete(record)
    }

    func deleteAllUsage(forPeriodKey key: String, from benefit: Benefit, modelContext: ModelContext) {
        let toDelete = benefit.usageHistory.filter { $0.periodKey == key }
        for record in toDelete {
            deleteUsage(record, from: benefit, modelContext: modelContext)
        }
    }
}
