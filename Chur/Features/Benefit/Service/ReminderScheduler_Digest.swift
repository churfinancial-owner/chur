//
//  ReminderScheduler_Digest.swift
//  Chur
//
//  Anti-spam digest. Calendar pileups are built in: at month end every
//  monthly benefit hits its warning window on the same morning, and
//  quarter/year ends stack monthly + quarterly + annual last-calls. With
//  a few cards that is 10+ banners at 9 AM — uninstall territory.
//
//  Rule: if 3 or more BENEFIT reminders would fire on the same day, they
//  are replaced by a single summary notification. Annual fee reminders
//  are never digested — rare and high-stakes, they always arrive
//  individually.
//

import Foundation

extension ReminderScheduler {

    /// Same-day benefit reminders at or above this count collapse into one digest.
    static let digestThreshold = 3

    static func applyDigest(to reminders: [PlannedReminder], cards: [CreditCard]) -> [PlannedReminder] {
        let calendar = Calendar.current
        let benefitReminders = reminders.filter { $0.kind == .benefitExpiry }
        let untouched = reminders.filter { $0.kind != .benefitExpiry }

        let byDay = Dictionary(grouping: benefitReminders) { calendar.startOfDay(for: $0.fireDate) }

        var result = untouched
        for (day, group) in byDay {
            if group.count >= digestThreshold {
                result.append(digest(for: group, on: day, cards: cards))
            } else {
                result.append(contentsOf: group)
            }
        }
        return result
    }

    /// The body quotes the FULL in-window picture at the digest's fire date
    /// (via ExpiringBenefits, the same query the Expiring Soon sheet runs),
    /// not just this day's batch — so the notification's numbers match the
    /// sheet the tap opens. Only the 3+-per-day trigger uses the day's group.
    private static func digest(for group: [PlannedReminder], on day: Date, cards: [CreditCard]) -> PlannedReminder {
        let dayKey = day.formatted(.iso8601.year().month().day())
        // Digest fires at the same hour the individual reminders would have.
        let fireDate = group.map(\.fireDate).min() ?? day

        let summary = ExpiringBenefits.summary(cards: cards, on: fireDate)
        let benefitText = summary.benefits == 1 ? "1 benefit" : "\(summary.benefits) benefits"
        let cardText = summary.cards == 1 ? "1 card" : "\(summary.cards) cards"

        return PlannedReminder(
            identifier: "\(identifierPrefix)digest.\(dayKey)",
            kind: .digest,
            fireDate: fireDate,
            title: "Benefits expiring soon",
            subtitle: "",
            body: "\(benefitText) expiring soon\(summary.totalText) across \(cardText). Tap to review.",
            threadID: "digest"
        )
    }
}
