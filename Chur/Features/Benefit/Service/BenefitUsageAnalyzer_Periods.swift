//
//  BenefitUsageAnalyzer_Periods.swift
//  Chur
//
//  Created by Pak Ho on 3/9/26.
//
//  Extension for period-key generation. Maps dates to stable
//  string identifiers (e.g., "2025-Q2") for history grouping.

import Foundation

extension BenefitUsageAnalyzer {
    
    /// Returns the period key for a given date (e.g., "2025-Q2" or "ANN-2024-03").
    ///   monthly      → "2025-06"
    ///   quarterly    → "2025-Q2"
    ///   semi-annual  → "2025-H1"
    ///   annual+      → "2025"   (calendar) or "ANN-2024-03" (anniversary, cycle starting Mar 2024)

    func periodKey(for date: Date = Date.current()) -> String {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)

        switch benefit.frequency.lowercased() {
        case "monthly":
            return String(format: "%04d-%02d", year, month)

        case "quarterly":
            if benefit.resetType == "card_anniversary" {
                let cycleStart = currentCycleStart(now: date, calendar: calendar)
                let monthsIn = calendar.dateComponents([.month], from: cycleStart, to: date).month ?? 0
                let q = monthsIn / 3 + 1
                let cycleYear = calendar.component(.year, from: cycleStart)
                let cycleMonth = calendar.component(.month, from: cycleStart)
                return String(format: "ANN-%04d-%02d-Q%d", cycleYear, cycleMonth, q)
            } else {
                let q = (month - 1) / 3 + 1
                return "\(year)-Q\(q)"
            }

        case "semi-annual":
            if benefit.resetType == "card_anniversary" {
                let cycleStart = currentCycleStart(now: date, calendar: calendar)
                let monthsIn = calendar.dateComponents([.month], from: cycleStart, to: date).month ?? 0
                let h = monthsIn / 6 + 1
                let cycleYear = calendar.component(.year, from: cycleStart)
                let cycleMonth = calendar.component(.month, from: cycleStart)
                return String(format: "ANN-%04d-%02d-H%d", cycleYear, cycleMonth, h)
            } else {
                let h = month <= 6 ? 1 : 2
                return "\(year)-H\(h)"
            }

        case "quadrennial":
            if benefit.resetType == "card_anniversary" {
                let cycleStart = currentCycleStart(now: date, calendar: calendar)
                let cycleYear = calendar.component(.year, from: cycleStart)
                let cycleMonth = calendar.component(.month, from: cycleStart)
                return String(format: "ANN-%04d-%02d-4Y", cycleYear, cycleMonth)
            } else {
                // Calendar-aligned: 4-year blocks starting from a base year (2000)
                let baseYear = 2000
                let blockIndex = (year - baseYear) / 4
                let blockStart = baseYear + blockIndex * 4
                return "\(blockStart)-\(blockStart + 4)"
            }

        default: // annual / one-time / ongoing
            if benefit.resetType == "card_anniversary" {
                let cycleStart = currentCycleStart(now: date, calendar: calendar)
                let cycleYear = calendar.component(.year, from: cycleStart)
                let cycleMonth = calendar.component(.month, from: cycleStart)
                return String(format: "ANN-%04d-%02d", cycleYear, cycleMonth)
            } else {
                return "\(year)"
            }
        }
    }

    func recordsForCurrentPeriod(on date: Date = Date.current()) -> [BenefitUsageRecord] {
        let key = periodKey(for: date)
        return benefit.usageHistory.filter { $0.periodKey == key }
    }

    func recordsGroupedByPeriod() -> [(periodKey: String, records: [BenefitUsageRecord])] {
        let grouped = Dictionary(grouping: benefit.usageHistory, by: { $0.periodKey })
        return grouped
            .map { (periodKey: $0.key, records: $0.value.sorted { $0.redeemedAt > $1.redeemedAt }) }
            .sorted { $0.periodKey > $1.periodKey }
    }
}
