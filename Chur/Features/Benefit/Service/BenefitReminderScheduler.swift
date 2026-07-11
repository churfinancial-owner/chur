//
//  BenefitReminderScheduler.swift
//  Chur
//
//  Schedules local notifications for expiring card benefits.
//
//  Reconciliation model
//  ────────────────────
//  Local notifications are scheduled ahead of time, so any event that changes
//  the outcome (usage logged, benefit muted, card removed, settings changed)
//  can leave stale reminders behind. Instead of scheduling imperatively,
//  `reconcile(context:)` recomputes the full desired set of reminders from
//  current SwiftData state and diffs it against UNUserNotificationCenter:
//  stale requests are cancelled, and every desired reminder is (re-)added —
//  re-adding an existing identifier replaces it, which keeps notification
//  copy (e.g. remaining balance) up to date.
//
//  Call sites: app foreground/background (ContentView), settings toggles
//  (NotificationSettingsView).
//
//  Reminder timing (days before period end, delivered at 9 AM local) is
//  user-configurable per benefit cycle — see ReminderTiming.
//

import Foundation
import SwiftData
import UserNotifications

@MainActor
final class BenefitReminderScheduler {
    static let shared = BenefitReminderScheduler()
    private init() {}

    /// Master switch, stored in UserDefaults so views can bind via @AppStorage.
    static let remindersEnabledKey = "benefitRemindersEnabled"

    /// All reminder identifiers carry this prefix so reconciliation never
    /// touches notifications scheduled by other features.
    private static let identifierPrefix = "benefitReminder."

    /// Hour of day (local time) reminders are delivered.
    private static let deliveryHour = 9

    /// iOS caps pending local notifications at 64 per app; leave headroom.
    private static let maxPendingReminders = 60

    // MARK: - Authorization

    func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func isAuthorized() async -> Bool {
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        return status == .authorized || status == .provisional
    }

    // MARK: - Reconciliation

    /// Fire-and-forget wrapper for synchronous call sites.
    func requestReconcile(context: ModelContext) {
        Task { await reconcile(context: context) }
    }

    func reconcile(context: ModelContext) async {
        let center = UNUserNotificationCenter.current()

        let enabled = UserDefaults.standard.bool(forKey: Self.remindersEnabledKey)
        guard enabled, await isAuthorized() else {
            await removeAllReminders()
            return
        }

        let cards = (try? context.fetch(FetchDescriptor<CreditCard>())) ?? []
        let desired = desiredReminders(for: cards)

        let pendingIDs = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(Self.identifierPrefix) }

        let desiredIDs = Set(desired.map(\.identifier))
        let staleIDs = pendingIDs.filter { !desiredIDs.contains($0) }
        if !staleIDs.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: staleIDs)
        }

        // Re-adding an existing identifier replaces it, refreshing the copy.
        for reminder in desired {
            try? await center.add(reminder.request())
        }
    }

    func removeAllReminders() async {
        let center = UNUserNotificationCenter.current()
        let ours = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(Self.identifierPrefix) }
        if !ours.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: ours)
        }
    }

    // MARK: - Desired set

    private func desiredReminders(for cards: [CreditCard]) -> [PlannedReminder] {
        let now = Date.current()
        var planned: [PlannedReminder] = []

        for card in cards where card.status == "active" {
            let anniversary = anniversaryDate(for: card)

            for benefit in card.benefits {
                guard benefit.isCurrentlyActive,
                      benefit.isRemindable,
                      !benefit.isMuted,
                      !benefit.isLocked(approvedMonth: card.approvedMonth, approvedYear: card.approvedYear)
                else { continue }

                // One-time benefits are spent forever once any record exists.
                if benefit.frequency.lowercased() == "one-time", !benefit.usageHistory.isEmpty { continue }

                let analyzer = BenefitUsageAnalyzer(benefit: benefit, approvedMonth: card.approvedMonth)
                guard !analyzer.isFullyRedeemedThisPeriod() else { continue }

                guard let expiry = benefit.effectiveExpiryDate(cardAnniversaryDate: anniversary),
                      expiry > now else { continue }

                let periodKey = analyzer.periodKey()
                for lead in ReminderTiming.reminderDays(forFrequency: benefit.frequency) {
                    guard let fireDate = deliveryDate(daysBefore: lead, expiry: expiry),
                          fireDate > now else { continue }

                    planned.append(PlannedReminder(
                        identifier: "\(Self.identifierPrefix)\(card.id).\(benefit.id).\(periodKey).\(lead)d",
                        fireDate: fireDate,
                        title: benefit.displayName,
                        subtitle: card.name,
                        body: reminderBody(for: benefit, analyzer: analyzer, leadDays: lead, on: now),
                        benefitID: benefit.id,
                        cardID: card.id
                    ))
                }
            }
        }

        // Prioritize the soonest reminders when over the iOS pending cap.
        return Array(planned.sorted { $0.fireDate < $1.fireDate }.prefix(Self.maxPendingReminders))
    }

    private func deliveryDate(daysBefore: Int, expiry: Date) -> Date? {
        let calendar = Calendar.current
        guard let day = calendar.date(byAdding: .day, value: -daysBefore, to: expiry) else { return nil }
        return calendar.date(bySettingHour: Self.deliveryHour, minute: 0, second: 0, of: day)
    }

    private func reminderBody(for benefit: Benefit, analyzer: BenefitUsageAnalyzer, leadDays: Int, on now: Date) -> String {
        let when = leadDays == 1 ? "tomorrow" : "in \(leadDays) days"

        if analyzer.isValueBased, let remaining = analyzer.remainingBalance(on: now), remaining > 0 {
            let symbol = benefit.valueCurrency.currencySymbol
            return "\(symbol)\(remaining) left — expires \(when)."
        }
        if analyzer.isCountLimited, let limit = benefit.usageLimit {
            let remaining = max(0, limit - analyzer.usedThisPeriod(on: now))
            return "\(remaining) of \(limit) uses left — expires \(when)."
        }
        return "Expires \(when)."
    }

    /// Mirrors BenefitRowViewModel.anniversaryDate so both derive the same
    /// period boundaries for card-anniversary benefits.
    private func anniversaryDate(for card: CreditCard) -> Date? {
        let validMonth = max(1, min(12, card.approvedMonth))
        return Calendar.current.date(from: DateComponents(year: card.approvedYear, month: validMonth, day: 1))
    }
}

// MARK: - Planned reminder

private struct PlannedReminder {
    let identifier: String
    let fireDate: Date
    let title: String
    let subtitle: String
    let body: String
    let benefitID: String
    let cardID: String

    func request() -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = title
        content.subtitle = subtitle
        content.body = body
        content.sound = .default
        content.threadIdentifier = cardID // group reminders per card
        content.userInfo = ["benefitID": benefitID, "cardID": cardID]

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute], from: fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        return UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
    }
}
