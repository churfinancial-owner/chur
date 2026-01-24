//
//  DateRefreshObserver.swift
//  Chur
//
//  Fires a notification at midnight each day so views that depend on Date.current()
//  re-evaluate expiry and date-range logic without requiring user interaction.
//

import Foundation

@MainActor
final class DateRefreshObserver {
    static let shared = DateRefreshObserver()

    private var timer: Timer?

    private init() {
        scheduleNextMidnight()
    }

    private func scheduleNextMidnight() {
        timer?.invalidate()

        let now = Date()
        let nextMidnight = Calendar.current.nextDate(
            after: now,
            matching: DateComponents(hour: 0, minute: 0, second: 0),
            matchingPolicy: .nextTime
        ) ?? now.addingTimeInterval(86400)

        let interval = nextMidnight.timeIntervalSince(now)

        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                NotificationCenter.default.post(name: .currentDateDidChange, object: nil)
                self?.scheduleNextMidnight() // reschedule for the following midnight
            }
        }
    }

    /// Call once at app startup to activate the observer.
    func start() {}
}

extension Notification.Name {
    static let currentDateDidChange = Notification.Name("currentDateDidChange")
}
