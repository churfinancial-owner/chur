//
//  Benefit_logics.swift
//  Chur
//
//  Created by Pak Ho on 3/10/26.
//
//  Description: Business logic extension for the Benefit model to handle
//               activation states and time-based locking.

import Foundation

extension Benefit {
    /// Checks if a benefit is currently waiting for its time-based activation delay.
    func isDelayed(approvedMonth: Int, approvedYear: Int) -> Bool {
        // Logic: Is the benefit generally active, but specifically 'locked'
        // because the card is too new?
        return self.isCurrentlyActive && !self.isActiveForCard(approvedMonth: approvedMonth, approvedYear: approvedYear)
    }

    /// Checks if a benefit requires manual user intervention (activation) to start.
    /// - `"unlock"`: never needs activation
    /// - `"lockonce"`: needs activation once; stays unlocked permanently via `isActivatedByUser`
    /// - `"lockbyfrequency"`: needs re-activation each period; checks `activatedAt` against current period
    func needsActivation(approvedMonth: Int) -> Bool {
        switch self.activationMode {
        case "lockonce":
            return !self.isActivatedByUser
        case "lockbyfrequency":
            guard let activated = self.activatedAt else { return true }
            let analyzer = BenefitUsageAnalyzer(benefit: self, approvedMonth: approvedMonth)
            return analyzer.periodKey(for: activated) != analyzer.periodKey()
        default: // "unlock"
            return false
        }
    }

    /// Combined check: Should the benefit appear grayed out/locked in the UI?
    func isLocked(approvedMonth: Int, approvedYear: Int) -> Bool {
        return isDelayed(approvedMonth: approvedMonth, approvedYear: approvedYear) || needsActivation(approvedMonth: approvedMonth)
    }
}
