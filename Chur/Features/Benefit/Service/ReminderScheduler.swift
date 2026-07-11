//
//  ReminderScheduler.swift
//  Chur
//
//  Schedules all of Chur's local reminder notifications. Categories:
//   • benefit expiry (this file)          — kind "benefitExpiry"
//   • annual fee (…_AnnualFee.swift)      — kind "annualFee"
//   • same-day digest (…_Digest.swift)    — kind "digest"
//
//  Reconciliation model
//  ────────────────────
//  Local notifications are scheduled ahead of time, so any event that changes
//  the outcome (usage logged, benefit muted, card removed, settings changed)
//  can leave stale reminders behind. Instead of scheduling imperatively,
//  `reconcile(context:)` recomputes the full desired set across all enabled
//  categories, collapses same-day pileups into a digest, and diffs against
//  UNUserNotificationCenter: stale requests are cancelled, and every desired
//  reminder is (re-)added — re-adding an existing identifier replaces it,
//  which keeps notification copy (e.g. remaining balance) up to date.
//
//  Call sites: app foreground/background (ContentView), settings toggles
//  and timing pickers (NotificationSettingsView / ReminderScheduleView).
//
//  Timing (days before the deadline, delivered at 9 AM local) is
//  user-configurable per category — see ReminderTiming.
//

import Foundation
import SwiftData
import UserNotifications

@MainActor
final class ReminderScheduler {
    static let shared = ReminderScheduler()
    private init() {}

    /// Per-category master switches, stored in UserDefaults so views can
    /// bind via @AppStorage.
    static let benefitRemindersEnabledKey = "benefitRemindersEnabled"
    static let annualFeeRemindersEnabledKey = "annualFeeRemindersEnabled"

    /// All reminder identifiers carry this prefix so reconciliation never
    /// touches notifications scheduled by other features.
    static let identifierPrefix = "churReminder."

    /// Identifier prefixes from earlier builds, still cleaned up during diffs.
    private static let legacyPrefixes = ["benefitReminder."]

    /// Hour of day (local time) reminders are delivered.
    static let deliveryHour = 9

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

        let benefitsOn = UserDefaults.standard.bool(forKey: Self.benefitRemindersEnabledKey)
        let feesOn = UserDefaults.standard.bool(forKey: Self.annualFeeRemindersEnabledKey)
        guard (benefitsOn || feesOn), await isAuthorized() else {
            await removeAllReminders()
            return
        }

        let cards = (try? context.fetch(FetchDescriptor<CreditCard>())) ?? []

        var desired: [PlannedReminder] = []
        if benefitsOn { desired += benefitReminders(for: cards) }
        if feesOn { desired += annualFeeReminders(for: cards) }
        desired = Self.applyDigest(to: desired)

        // Prioritize the soonest reminders when over the iOS pending cap.
        desired = Array(desired.sorted { $0.fireDate < $1.fireDate }.prefix(Self.maxPendingReminders))

        let pendingIDs = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { Self.isOwnedIdentifier($0) }

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
            .filter { Self.isOwnedIdentifier($0) }
        if !ours.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: ours)
        }
    }

    private static func isOwnedIdentifier(_ id: String) -> Bool {
        id.hasPrefix(identifierPrefix) || legacyPrefixes.contains { id.hasPrefix($0) }
    }

    // MARK: - Benefit expiry planner

    private func benefitReminders(for cards: [CreditCard]) -> [PlannedReminder] {
        let now = Date.current()
        var planned: [PlannedReminder] = []

        for card in cards where card.status == "active" {
            let anniversary = Self.anniversaryDate(for: card)

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
                    guard let fireDate = Self.deliveryDate(daysBefore: lead, deadline: expiry),
                          fireDate > now else { continue }

                    planned.append(PlannedReminder(
                        identifier: "\(Self.identifierPrefix)benefit.\(card.id).\(benefit.id).\(periodKey).\(lead)d",
                        kind: .benefitExpiry,
                        fireDate: fireDate,
                        title: benefit.displayName,
                        subtitle: card.name,
                        body: benefitBody(for: benefit, analyzer: analyzer, leadDays: lead, on: now),
                        threadID: card.id,
                        payload: ["benefitID": benefit.id, "cardID": card.id],
                        digestValue: analyzer.isValueBased ? analyzer.remainingBalance(on: now) : nil,
                        digestCurrency: benefit.valueCurrency
                    ))
                }
            }
        }
        return planned
    }

    private func benefitBody(for benefit: Benefit, analyzer: BenefitUsageAnalyzer, leadDays: Int, on now: Date) -> String {
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

    // MARK: - Shared helpers

    static func deliveryDate(daysBefore: Int, deadline: Date) -> Date? {
        let calendar = Calendar.current
        guard let day = calendar.date(byAdding: .day, value: -daysBefore, to: deadline) else { return nil }
        return calendar.date(bySettingHour: deliveryHour, minute: 0, second: 0, of: day)
    }

    /// Mirrors BenefitRowViewModel.anniversaryDate so both derive the same
    /// period boundaries for card-anniversary benefits.
    static func anniversaryDate(for card: CreditCard) -> Date? {
        let validMonth = max(1, min(12, card.approvedMonth))
        return Calendar.current.date(from: DateComponents(year: card.approvedYear, month: validMonth, day: 1))
    }
}

// MARK: - Planned reminder

enum ReminderKind: String {
    case benefitExpiry
    case annualFee
    case digest
}

struct PlannedReminder {
    let identifier: String
    let kind: ReminderKind
    let fireDate: Date
    let title: String
    let subtitle: String
    let body: String
    let threadID: String
    var payload: [String: String] = [:]

    /// Remaining value/currency carried so the digest can sum totals;
    /// not part of the notification itself.
    var digestValue: Int? = nil
    var digestCurrency: String? = nil

    func request() -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = title
        content.subtitle = subtitle
        content.body = body
        content.sound = .default
        content.threadIdentifier = threadID
        var userInfo: [String: String] = payload
        userInfo["kind"] = kind.rawValue
        content.userInfo = userInfo

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute], from: fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        return UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
    }
}
