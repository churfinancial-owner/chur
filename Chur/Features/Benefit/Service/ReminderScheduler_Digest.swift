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

    static func applyDigest(to reminders: [PlannedReminder]) -> [PlannedReminder] {
        let calendar = Calendar.current
        let benefitReminders = reminders.filter { $0.kind == .benefitExpiry }
        let untouched = reminders.filter { $0.kind != .benefitExpiry }

        let byDay = Dictionary(grouping: benefitReminders) { calendar.startOfDay(for: $0.fireDate) }

        var result = untouched
        for (day, group) in byDay {
            if group.count >= digestThreshold {
                result.append(digest(for: group, on: day))
            } else {
                result.append(contentsOf: group)
            }
        }
        return result
    }

    private static func digest(for group: [PlannedReminder], on day: Date) -> PlannedReminder {
        let cardCount = Set(group.map(\.threadID)).count
        let cardText = cardCount == 1 ? "1 card" : "\(cardCount) cards"

        // Only quote a total when every value shares one currency.
        let currencies = Set(group.compactMap { $0.digestValue != nil ? $0.digestCurrency : nil })
        var totalText = ""
        if currencies.count == 1, let currency = currencies.first {
            let total = group.compactMap(\.digestValue).reduce(0, +)
            if total > 0 {
                totalText = " — \(currency.currencySymbol)\(total) unused"
            }
        }

        let dayKey = day.formatted(.iso8601.year().month().day())
        // Digest fires at the same hour the individual reminders would have.
        let fireDate = group.map(\.fireDate).min() ?? day

        return PlannedReminder(
            identifier: "\(identifierPrefix)digest.\(dayKey)",
            kind: .digest,
            fireDate: fireDate,
            title: "Benefits expiring soon",
            subtitle: "",
            body: "\(group.count) benefits expiring soon\(totalText) across \(cardText). Tap to review.",
            threadID: "digest"
        )
    }
}
