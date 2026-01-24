//
//  Benefit_datelogics.swift
//  Chur
//
//  Created by Pak Ho on 3/13/26.
//
/// Returns the effective expiry date for this benefit, following this priority:
///
/// 1. `expirationDate` — a hard deadline set explicitly on the benefit always wins.
/// 2. If `isRecurring` is `true`, derive the next end-of-period date from:
///    - `frequency`  → determines the period length (monthly, quarterly, semi-annual, annual)
///    - `resetType`  → `"card_anniversary"` anchors the period to the card's approval
///                     month/year; anything else (incl. `"calendar"`) uses calendar boundaries.
///    - `cardAnniversaryDate` must be supplied by the caller for `card_anniversary` resets;
///      if it is `nil` the method falls back to calendar-based calculation.
/// 3. Returns `nil` for non-recurring benefits with no explicit expiration date
///    (e.g. `"ongoing"` perks that never expire).
///
/// - Parameter cardAnniversaryDate: The card's approval date, used only when
///   `resetType == "card_anniversary"`. Pass `nil` to force the calendar fallback.


import Foundation

extension Benefit {
    
    func effectiveExpiryDate(cardAnniversaryDate: Date? = nil) -> Date? {
        // 1. Hard expiration wins unconditionally.
        if let hardExpiry = expirationDate {
            return hardExpiry
        }
        
        // 2. Non-recurring benefits have no rolling expiry,
        //    unless they use card_anniversary reset — those always have a defined period end.
        let hasAnniversaryReset = resetType == "card_anniversary" && cardAnniversaryDate != nil
        guard isRecurring || hasAnniversaryReset else { return nil }
        
        let calendar = Calendar.current
        let now = Date.current()
        
        // Determine the anchor: card-anniversary date when available, calendar otherwise.
        let useAnniversary = resetType == "card_anniversary" && cardAnniversaryDate != nil
        let anchor = useAnniversary ? cardAnniversaryDate! : now
        
        switch BenefitFrequency(rawValue: frequency) {
        case .monthly:
            if useAnniversary {
                // Period runs from the anniversary day of this month to the same day next month.
                let anniversaryDay = calendar.component(.day, from: anchor)
                var components = calendar.dateComponents([.year, .month], from: now)
                components.day = anniversaryDay
                let periodStart = calendar.date(from: components) ?? now
                // If we're already past the anniversary day this month, the period end is next month.
                let periodEnd = periodStart <= now
                ? calendar.date(byAdding: .month, value: 1, to: periodStart) ?? now
                : periodStart
                return periodEnd
            } else {
                // Calendar month: last moment of the current month.
                let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
                return calendar.date(byAdding: DateComponents(month: 1, second: -1), to: startOfMonth)
            }
            
        case .quarterly:
            return endOfPeriod(months: 3, anchor: anchor, useAnniversary: useAnniversary, now: now, calendar: calendar)
            
        case .semiAnnual:
            return endOfPeriod(months: 6, anchor: anchor, useAnniversary: useAnniversary, now: now, calendar: calendar)
            
        case .annual:
            if useAnniversary {
                // Period ends on the same month/day next anniversary year.
                var components = calendar.dateComponents([.month, .day], from: anchor)
                components.year = calendar.component(.year, from: now)
                let anniversaryThisYear = calendar.date(from: components) ?? now
                let nextAnniversary = anniversaryThisYear <= now
                ? calendar.date(byAdding: .year, value: 1, to: anniversaryThisYear) ?? now
                : anniversaryThisYear
                return calendar.date(byAdding: .second, value: -1, to: nextAnniversary)
            } else {
                // Calendar year: last moment of December 31st this year.
                var components = DateComponents()
                components.year = calendar.component(.year, from: now)
                components.month = 12
                components.day = 31
                components.hour = 23; components.minute = 59; components.second = 59
                return calendar.date(from: components)
            }
            
        case .quadrennial:
            return endOfPeriod(months: 48, anchor: anchor, useAnniversary: useAnniversary, now: now, calendar: calendar)
            
        default:
            // "one-time" and "ongoing" — no rolling expiry.
            return nil
        }
    }
    
    /// Shared helper: given a multi-month period length, find the end of the current period
    /// anchored either to the card-anniversary date or to calendar quarter/half-year boundaries.
    private func endOfPeriod(months: Int, anchor: Date, useAnniversary: Bool, now: Date, calendar: Calendar) -> Date? {
        if useAnniversary {
            // Find how many complete periods have elapsed since the anchor.
            let monthsSinceAnchor = calendar.dateComponents([.month], from: anchor, to: now).month ?? 0
            let completedPeriods = monthsSinceAnchor / months
            let currentPeriodStart = calendar.date(byAdding: .month, value: completedPeriods * months, to: anchor) ?? now
            let nextPeriodStart = calendar.date(byAdding: .month, value: months, to: currentPeriodStart) ?? now
            return calendar.date(byAdding: .second, value: -1, to: nextPeriodStart)
        } else {
            // Calendar-aligned: divide the year into periods of `months` length.
            let currentMonth = calendar.component(.month, from: now) // 1-based
            let currentYear = calendar.component(.year, from: now)
            // Which period slot are we in? (0-based)
            let periodIndex = (currentMonth - 1) / months
            let periodEndMonth = (periodIndex + 1) * months  // 1-based end month of this period
            let overflows = periodEndMonth > 12
            let endMonth = overflows ? periodEndMonth - 12 : periodEndMonth
            let endYear = overflows ? currentYear + 1 : currentYear
            var components = DateComponents()
            components.year = endYear
            components.month = endMonth
            components.day = calendar.range(of: .day, in: .month, for: calendar.date(from: DateComponents(year: endYear, month: endMonth))!)!.count
            components.hour = 23; components.minute = 59; components.second = 59
            return calendar.date(from: components)
        }
    }
}
