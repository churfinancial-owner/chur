//
//  BenefitUsageAnalyzer_Balance.swift
//  Chur
//
//  Created by Pak Ho on 3/9/26.
//
//  Extension for balance calculations. Determines used amounts,
//  remaining budgets, and redemption status for the current period.


// MARK: - Balance

/// True when this benefit tracks usage freely with no cap (usageLimit == -1).


import Foundation

extension BenefitUsageAnalyzer {
    
    /// True when this benefit tracks usage freely with no cap (usageLimit == -1).
    var isUnlimited: Bool { benefit.usageLimit == -1 }
    
    /// True when this benefit has a finite count-based cap (usageLimit > 0).
    /// Each use is logged individually; the benefit completes when the cap is reached.
    var isCountLimited: Bool { (benefit.usageLimit ?? 0) > 0 }

    /// True when this benefit tracks a redeemable dollar value (not a use-count and not unlimited).
    /// This is the single source of truth for "should we show a currency symbol?"
    var isValueBased: Bool { !isUnlimited && !isCountLimited && benefit.value > 0 }
  
    /// How much has been used in the current period.
    /// - Unlimited (usageLimit == -1): returns number of records (count-based, no cap).
    /// - Count-based (usageLimit > 0): returns number of records.
    /// - Value-based: returns sum of `redeemedAmount` across records.
    func usedThisPeriod(on date: Date = Date.current()) -> Int {
        let records = recordsForCurrentPeriod(on: date)
        if benefit.usageLimit != nil {
            return records.count
        } else {
            return records.map(\.redeemedAmount).reduce(0, +)
        }
    }

    /// The starting budget for the current period.
    /// - Unlimited (usageLimit == -1): returns nil (no cap to display).
    /// - Count-based (usageLimit > 0): returns `usageLimit`.
    /// - Value-based: `budget(for:)` (honors monthly overrides).
    /// Returns nil for benefits with no trackable budget (value == 0 and no usageLimit).
    func periodBudget(on date: Date = Date.current()) -> Int? {
        if isUnlimited { return nil }
        if let limit = benefit.usageLimit { return limit }
        let b = budget(for: date)
        return b > 0 ? b : nil
    }

    /// Remaining balance for the current period.
    /// Returns nil for unlimited benefits (no cap) and non-trackable benefits.

    func remainingBalance(on date: Date = Date.current()) -> Int? {
        if isUnlimited { return nil }
        guard let total = periodBudget(on: date) else { return nil }
        return max(0, total - usedThisPeriod(on: date))
    }

    /// True when the user has fully redeemed the period's budget.
    /// Always false for unlimited benefits — they can never be "fully redeemed".

    func isFullyRedeemedThisPeriod(on date: Date = Date.current()) -> Bool {
        if isUnlimited { return false }
        guard let total = periodBudget(on: date), total > 0 else { return false }
        return usedThisPeriod(on: date) >= total
    }
}

