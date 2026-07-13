//
//  ReminderBackgroundRefresh.swift
//  Chur
//
//  Opportunistic background reconciliation so reminders can be (re)computed
//  without the user opening the app. iOS never guarantees when — or
//  whether — a BGAppRefreshTask actually runs; ReminderScheduler's
//  fireDate(daysBefore:deadline:now:) catch-up logic is what actually
//  guarantees a missed reminder still fires, this is just a best-effort
//  layer on top that shrinks how often catch-up is needed.
//

import BackgroundTasks
import SwiftData

enum ReminderBackgroundRefresh {
    static let identifier = "ChurFinancial.reminderRefresh"

    /// Registered once at launch, before the app finishes launching
    /// (ChurApp.init), same requirement as the notification delegate.
    static func register(container: ModelContainer) {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: nil) { task in
            handle(task as! BGAppRefreshTask, container: container)
        }
    }

    /// Submits (or resubmits) the next opportunistic run. Safe to call
    /// repeatedly — the system coalesces/ignores redundant submissions for
    /// the same identifier. Call after every reconcile so a request is
    /// always pending while the app isn't in the foreground.
    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = Date().addingTimeInterval(4 * 60 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    private static func handle(_ task: BGAppRefreshTask, container: ModelContainer) {
        schedule() // Queue the next run regardless of how this one ends.

        let refreshTask = Task { @MainActor in
            let context = ModelContext(container)
            await ReminderScheduler.shared.reconcile(context: context)
            task.setTaskCompleted(success: true)
        }

        task.expirationHandler = {
            refreshTask.cancel()
            task.setTaskCompleted(success: false)
        }
    }
}
