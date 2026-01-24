//
//  BenefitUsageAnalyzer.swift
//  Chur
//
//  Main entry point for benefit analysis. Handles basic
//  period counts and core budget/value definitions.

import Foundation
import SwiftData

struct BenefitUsageAnalyzer {
    let benefit: Benefit
    let approvedMonth: Int

    // MARK: - Period Configuration
    
    /// Number of discrete tracking periods per benefit cycle.
    var periodCount: Int {
        switch benefit.frequency.lowercased() {
        case "monthly":     return 12
        case "quarterly":   return 4
        case "semi-annual": return 2
        default:            return 1   // annual / quadrennial / one-time / ongoing
        }
    }

    /// Dollar value allocated to each period.
    var valuePerPeriod: Int {
        guard benefit.value > 0 else { return 0 }
        // Note: Currently returns benefit.value for all cases per original logic
        return benefit.value
    }

    /// Per-period budget at a specific date, honoring calendar-month overrides.
    func budget(for date: Date = Date.current()) -> Int {
        guard benefit.value > 0 else { return 0 }
        let month = Calendar.current.component(.month, from: date)
        if let overrides = benefit.calendarMonthOverrides,
           let override = overrides[month] {
            return override
        }
        return valuePerPeriod
    }
}
