//
//  ReminderTiming.swift
//  Chur
//
//  Single source of truth for expiry warning timing, shared by:
//   • the in-app ⏰ badge, red expiry highlight, "Expiring" filter, and
//     the Expiring Soon sheet (via isInWarningWindow)
//   • ReminderScheduler's notification schedule
//
//  One lead time for ALL benefit frequencies and one for the annual fee,
//  stored in UserDefaults (device-local, no schema impact). Each reminder
//  fires exactly once per period — no last calls.
//

import Foundation

enum ReminderTiming {

    // MARK: - Benefit lead time (one schedule for every cycle)

    /// Days before expiry that the warning window opens, the ⏰ badge shows,
    /// and the (single) notification fires — identical for monthly,
    /// quarterly, semi-annual, annual, and one-time benefits.
    static let benefitOptions = [1, 3, 7]
    static let defaultBenefitLeadDays = 7
    static let benefitStorageKey = "reminderLead.benefits"

    static var benefitLeadDays: Int {
        UserDefaults.standard.object(forKey: benefitStorageKey) as? Int ?? defaultBenefitLeadDays
    }

    static func setBenefitLeadDays(_ days: Int) {
        UserDefaults.standard.set(days, forKey: benefitStorageKey)
    }

    // MARK: - Annual fee lead time

    /// Single notice; 0 = the morning the fee posts.
    enum AnnualFee {
        static let options = [0, 7, 14]
        static let defaultLeadDays = 0
        static let storageKey = "reminderLead.annualFee"
    }

    static var annualFeeLeadDays: Int {
        UserDefaults.standard.object(forKey: AnnualFee.storageKey) as? Int ?? AnnualFee.defaultLeadDays
    }

    static func setAnnualFeeLeadDays(_ days: Int) {
        UserDefaults.standard.set(days, forKey: AnnualFee.storageKey)
    }

    // MARK: - Recommended defaults

    static var isRecommended: Bool {
        benefitLeadDays == defaultBenefitLeadDays
            && annualFeeLeadDays == AnnualFee.defaultLeadDays
    }

    static func resetToRecommended() {
        UserDefaults.standard.removeObject(forKey: benefitStorageKey)
        UserDefaults.standard.removeObject(forKey: AnnualFee.storageKey)
    }

    // MARK: - Warning window

    /// Whether a benefit expiring at `expiry` is inside its warning window.
    /// The window opens `benefitLeadDays` before expiry — the same moment
    /// the notification fires — and stays open until expiry.
    ///
    /// Compares calendar days, not elapsed seconds: `expiry` almost always
    /// resolves to 23:59:59 (calendar month/quarter/year ends, most
    /// anniversary cycles), while reminders fire at a fixed 9 AM. Elapsed-
    /// seconds math would put the notification's own fire moment outside
    /// the window it's supposed to represent — day-granularity avoids that
    /// entirely, matching what "N days before expiry" actually means.
    static func isInWarningWindow(expiry: Date, now: Date = Date.current()) -> Bool {
        guard expiry > now else { return false }
        let calendar = Calendar.current
        let daysUntil = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: now),
            to: calendar.startOfDay(for: expiry)
        ).day ?? 0
        return daysUntil <= benefitLeadDays
    }
}
