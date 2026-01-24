//
//  BenefitUsageAnalyzer_PeriodStatus.swift
//  Chur
//
//  Centralised period-status calculation used by both the progress bar
//  and the log-usage period picker. Single source of truth for determining
//  whether a period slot is Full, Partial, Empty Past, Current, or Future.

import Foundation

struct PeriodStatusInfo {
    let label: String
    let index: Int
    let usedAmount: Int
    let isFull: Bool
    let isPartial: Bool
    let isCurrent: Bool
    let isFuture: Bool
    let isEmptyPast: Bool
}

extension BenefitUsageAnalyzer {

    /// Returns display and status metadata for a single period slot.
    /// - Parameters:
    ///   - index: 1-based period index within the year (e.g. Q2 → 2).
    ///   - year: Calendar year being displayed.
    ///   - frequency: Benefit frequency string (e.g. "quarterly").
    ///   - history: All usage records for this benefit.
    ///   - budget: Per-period budget cap, or nil for unlimited/count-less benefits.
    ///   - isValueBased: True when the benefit tracks a dollar value rather than use-count.
    static func periodStatusInfo(
        for index: Int,
        year: Int,
        frequency: String,
        history: [BenefitUsageRecord],
        budget: Int?,
        isValueBased: Bool
    ) -> PeriodStatusInfo {
        let calendar = Calendar.current
        let now = Date.current()
        let currentMonth = calendar.component(.month, from: now)
        let currentYear = calendar.component(.year, from: now)

        // One-time benefits have a single global slot.
        if frequency.lowercased() == "one-time" {
            let usedAmount = history.reduce(0) { $0 + $1.redeemedAmount }
            return PeriodStatusInfo(
                label: "Once", index: 1, usedAmount: usedAmount,
                isFull: !history.isEmpty, isPartial: false,
                isCurrent: true, isFuture: false, isEmptyPast: false
            )
        }

        let periodsCount: Int
        switch frequency.lowercased() {
        case "monthly":     periodsCount = 12
        case "quarterly":   periodsCount = 4
        case "semi-annual": periodsCount = 2
        default:            periodsCount = 1
        }

        let monthsPerPeriod = 12 / max(1, periodsCount)
        let startMonth = (index - 1) * monthsPerPeriod + 1
        let monthRange = startMonth..<(startMonth + monthsPerPeriod)

        let usedAmount = history.filter { record in
            let recordYear = calendar.component(.year, from: record.redeemedAt)
            let recordMonth = calendar.component(.month, from: record.redeemedAt)
            return recordYear == year && monthRange.contains(recordMonth)
        }.reduce(0) { $0 + $1.redeemedAmount }

        let realCurrentPeriodIdx = (currentMonth - 1) / monthsPerPeriod + 1
        let isCurrent = year == currentYear && index == realCurrentPeriodIdx
        let isFuture = year > currentYear || (year == currentYear && index > realCurrentPeriodIdx)
        let isFull = usedAmount > 0 && (!isValueBased || usedAmount >= (budget ?? 0))
        let isPartial = usedAmount > 0 && !isFull
        let isEmptyPast = usedAmount == 0 && !isFuture && !isCurrent

        let label: String
        switch periodsCount {
        case 4:  label = "Q\(index)"
        case 2:  label = "H\(index)"
        case 12: label = calendar.shortMonthSymbols[index - 1]
        default: label = "\(index)"
        }

        return PeriodStatusInfo(
            label: label, index: index, usedAmount: usedAmount,
            isFull: isFull, isPartial: isPartial,
            isCurrent: isCurrent, isFuture: isFuture, isEmptyPast: isEmptyPast
        )
    }
}
