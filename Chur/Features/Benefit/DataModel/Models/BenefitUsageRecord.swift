//
//  BenefitUsageRecord.swift
//  Chur
//
//  One entry per redemption event against a benefit.
//
//  Schema overview
//  ───────────────
//  • redeemedAt        – wall-clock timestamp of the redemption
//  • periodKey         – stable string key for the period this redemption belongs to,
//                        e.g. "2025-Q2", "2025-06", "2025-H1", "2025" — used for
//                        grouping / filtering without re-running date math on every read
//  • redeemedAmount    – how much the user redeemed this event
//                          - dollar value  (e.g. 120) for value-based benefits
//                          - count         (e.g. 1)   for count-based benefits (usageLimit set)
//  • isFullyRedeemed   – true when the cumulative redemption for this period has
//                        reached (or exceeded) the period budget at the time of logging.
//                        Stored so history stays accurate even if benefit values change later.
//  • notes             – optional free-text the user can attach
//  • source            – "manual" | "auto" | "imported"
//  • externalID        – optional stable ID for idempotent import / future iCloud sync

import Foundation
import SwiftData

@Model
class BenefitUsageRecord {
    /// Unique identifier for this redemption event.
    @Attribute(.unique) var id: String

    /// When the user tapped "used".
    var redeemedAt: Date

    /// Stable string key for the period this redemption belongs to
    /// (e.g. "2025-Q2", "2025-06", "2025-H1", "2025").
    /// Stored so grouping/filtering never needs to re-run date math.
    var periodKey: String

    /// How much was redeemed in this event.
    /// - Dollar value (e.g. 120) for value-based benefits.
    /// - Count        (e.g. 1)   for count-based benefits (usageLimit set).
    var redeemedAmount: Int

    /// Snapshot of whether the period budget was fully consumed at log time.
    /// Stored so history stays accurate even if benefit values change later.
    var isFullyRedeemed: Bool

    /// Back-reference to the owning Benefit (set automatically by SwiftData
    /// when the record is appended to `Benefit.usageHistory`).
    var benefit: Benefit?

    var notes: String?
    var source: String?
    var externalID: String?

    init(
        id: String = UUID().uuidString,
        redeemedAt: Date = Date.current(),
        periodKey: String,
        redeemedAmount: Int,
        isFullyRedeemed: Bool = false,
        notes: String? = nil,
        source: String? = nil,
        externalID: String? = nil
    ) {
        self.id = id
        self.redeemedAt = redeemedAt
        self.periodKey = periodKey
        self.redeemedAmount = redeemedAmount
        self.isFullyRedeemed = isFullyRedeemed
        self.notes = notes
        self.source = source
        self.externalID = externalID
    }
}

// MARK: - Period helpers

extension BenefitUsageRecord {

    /// The 1-based month (1 = Jan … 12 = Dec) of this record.
    var month: Int {
        Calendar.current.component(.month, from: redeemedAt)
    }

    /// The calendar year of this record.
    var year: Int {
        Calendar.current.component(.year, from: redeemedAt)
    }
}
