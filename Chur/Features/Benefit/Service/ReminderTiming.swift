//
//  ReminderTiming.swift
//  Chur
//
//  Single source of truth for expiry warning timing, shared by:
//   • the in-app ⏰ badge, red expiry highlight, and "Expiring" filter
//     (via isInWarningWindow)
//   • BenefitReminderScheduler's notification schedule (via reminderDays)
//
//  One user-configurable lead time per benefit cycle, stored in
//  UserDefaults (device-local, no schema impact). Cycles longer than
//  monthly also get a fixed, non-configurable "last call" reminder close
//  to expiry. This replaces the old global "expiryWarningDays" setting.
//

import Foundation

enum ReminderTiming {

    enum Cycle: String, CaseIterable, Identifiable {
        case monthly
        case quarterly
        case semiAnnual
        case catchAll // annual, quadrennial, one-time with a hard expiry

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .monthly:    return "Monthly benefits"
            case .quarterly:  return "Quarterly benefits"
            case .semiAnnual: return "Semi-annual benefits"
            case .catchAll:   return "Annual & one-time"
            }
        }

        /// Selectable lead times (days before expiry), bounded so a lead
        /// can never exceed the cycle length.
        var options: [Int] {
            switch self {
            case .monthly:    return [1, 3, 5, 7]
            case .quarterly:  return [3, 7, 14]
            case .semiAnnual: return [7, 14, 30]
            case .catchAll:   return [7, 14, 30]
            }
        }

        var defaultLeadDays: Int {
            switch self {
            case .monthly:              return 3
            case .quarterly:            return 7
            case .semiAnnual, .catchAll: return 14
            }
        }

        /// Fixed final reminder near expiry; not user-configurable.
        /// Monthly has none — two pings per month would be spammy.
        var lastCallDays: Int? {
            switch self {
            case .monthly:              return nil
            case .quarterly:            return 1
            case .semiAnnual, .catchAll: return 3
            }
        }

        var storageKey: String { "reminderLead.\(rawValue)" }
    }

    static func cycle(forFrequency frequency: String) -> Cycle {
        switch Benefit.BenefitFrequency(rawValue: frequency.lowercased()) {
        case .monthly:    return .monthly
        case .quarterly:  return .quarterly
        case .semiAnnual: return .semiAnnual
        default:          return .catchAll
        }
    }

    // MARK: - Stored lead times

    static func leadDays(for cycle: Cycle) -> Int {
        UserDefaults.standard.object(forKey: cycle.storageKey) as? Int ?? cycle.defaultLeadDays
    }

    static func setLeadDays(_ days: Int, for cycle: Cycle) {
        UserDefaults.standard.set(days, forKey: cycle.storageKey)
    }

    static func leadDays(forFrequency frequency: String) -> Int {
        leadDays(for: cycle(forFrequency: frequency))
    }

    // MARK: - Derived schedules

    /// Days-before-expiry at which notifications fire: the user's lead time
    /// plus the cycle's fixed last call (when distinct).
    static func reminderDays(forFrequency frequency: String) -> [Int] {
        let cycle = cycle(forFrequency: frequency)
        let lead = leadDays(for: cycle)
        if let lastCall = cycle.lastCallDays, lastCall < lead {
            return [lead, lastCall]
        }
        return [lead]
    }

    /// Whether a benefit expiring at `expiry` is inside its warning window.
    /// The window opens at the cycle's lead time — the same moment the first
    /// notification fires — and stays open until expiry.
    static func isInWarningWindow(expiry: Date, frequency: String, now: Date = Date.current()) -> Bool {
        let lead = leadDays(forFrequency: frequency)
        let remaining = expiry.timeIntervalSince(now)
        return remaining > 0 && remaining < Double(lead) * 86_400
    }
}
