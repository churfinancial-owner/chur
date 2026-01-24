//
//  BenefitUsageAnalyzer_LegacyHelper.swift
//  Chur
//
//  Created by Pak Ho on 3/9/26.
//
//  Extension for legacy UI support and internal date math.
//  Contains helpers for index-based usage and cycle-start logic.


/// Returns the usage count for a specific 0-based period index within the current cycle.


import Foundation

extension BenefitUsageAnalyzer {
    
    // MARK: - Legacy Helpers (Checkbox Logic)

    /// Returns the usage count for a specific 0-based period index within the current cycle.
    func usageForPeriod(_ periodIndex: Int) -> Int {
        let now = Date.current()
        let calendar = Calendar.current
        let cycleStart = currentCycleStart(now: now, calendar: calendar)

        let relevantRecords = benefit.usageHistory.filter { record in
            guard record.redeemedAt >= cycleStart && record.redeemedAt <= now else { return false }
            let idx = periodIndexForDate(record.redeemedAt, cycleStart: cycleStart, calendar: calendar)
            return idx == periodIndex
        }
        return relevantRecords.count
    }

    /// Whether the benefit has been used in the current period.
    func isUsedInCurrentPeriod() -> Bool {
        guard benefit.isRecurring else { return !benefit.usageHistory.isEmpty }
        return usedThisPeriod() > 0
    }

    /// 0-based period indices that have at least one record in the current cycle.
    func usedPeriodIndices() -> Set<Int> {
        let now = Date.current()
        let calendar = Calendar.current
        let cycleStart = currentCycleStart(now: now, calendar: calendar)

        var indices = Set<Int>()
        for record in benefit.usageHistory {
            guard record.redeemedAt >= cycleStart && record.redeemedAt <= now else { continue }
            indices.insert(periodIndexForDate(record.redeemedAt, cycleStart: cycleStart, calendar: calendar))
        }
        return indices
    }

    // MARK: - Internal Cycle Math

    /// Start of the current benefit cycle, respecting resetType.
    func currentCycleStart(now: Date = Date.current(), calendar: Calendar = .current) -> Date {
        if benefit.resetType == "card_anniversary" {
            let thisYear = calendar.component(.year, from: now)
            let currentMonth = calendar.component(.month, from: now)
            let validMonth = max(1, min(12, approvedMonth))
            let startYear = currentMonth < validMonth ? thisYear - 1 : thisYear
            return calendar.date(from: DateComponents(year: startYear, month: validMonth, day: 1))!
        } else {
            return calendar.date(from: DateComponents(year: calendar.component(.year, from: now), month: 1, day: 1))!
        }
    }

    private func periodIndexForDate(_ date: Date, cycleStart: Date, calendar: Calendar) -> Int {
        let monthsIn = calendar.dateComponents([.month], from: cycleStart, to: date).month ?? 0
        switch benefit.frequency.lowercased() {
        case "monthly":      return max(0, min(11, monthsIn))
        case "quarterly":    return max(0, min(3,  monthsIn / 3))
        case "semi-annual":  return max(0, min(1,  monthsIn / 6))
        case "quadrennial":  return max(0, monthsIn / 48)
        default:             return 0
        }
    }
}
