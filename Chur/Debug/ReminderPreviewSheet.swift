//
//  ReminderPreviewSheet.swift
//  Chur
//
//  DEBUG tool: lists the app's actual pending reminder notifications
//  (churReminder.*) with their real copy and fire dates, and can fire any
//  of them in 2 seconds as a live banner — payload and routing included.
//  Combine with Time Travel: jump near a month end or card anniversary,
//  tap Reconcile, then inspect/fire what the scheduler really built.
//

#if DEBUG
import SwiftUI
import SwiftData
import UserNotifications

struct ReminderPreviewSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var requests: [UNNotificationRequest] = []
    @State private var isLoading = true
    @State private var firedIdentifier: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        Task { await reconcileAndReload() }
                    } label: {
                        Label("Reconcile now", systemImage: "arrow.triangle.2.circlepath")
                    }
                } footer: {
                    Text("Re-plans reminders from the current (possibly time-traveled) date, then reloads this list.")
                }

                Section("Pending reminders (\(requests.count))") {
                    if isLoading {
                        ProgressView()
                    } else if requests.isEmpty {
                        Text("Nothing scheduled. Enable reminders in Notification settings and make sure a benefit or fee is inside its lead window.")
                            .font(.churSmall())
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(requests, id: \.identifier) { request in
                            requestRow(request)
                        }
                    }
                }
            }
            .navigationTitle("Reminder Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task { await reload() }
        }
    }

    private func requestRow(_ request: UNNotificationRequest) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(request.content.title)
                .font(.churSmallBold())
            Text(request.content.body)
                .font(.churSmall())
                .foregroundStyle(.secondary)
            HStack {
                Text(fireDateLabel(request))
                    .font(.churSmall())
                    .foregroundStyle(Color.churOlive)
                Spacer()
                Button(firedIdentifier == request.identifier ? "Fired ✓" : "Fire in 2s") {
                    fireNow(request)
                }
                .font(.churSmallBold())
                .buttonStyle(.bordered)
            }
            Text(request.identifier)
                .font(.churSmall())
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .padding(.vertical, 2)
    }

    private func fireDateLabel(_ request: UNNotificationRequest) -> String {
        guard let trigger = request.trigger as? UNCalendarNotificationTrigger,
              let date = trigger.nextTriggerDate() else { return "—" }
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    /// Re-schedules a copy of the request to pop in 2 seconds. The content
    /// (copy + kind/cardID/benefitID payload) is untouched, so the banner and
    /// its tap routing behave exactly like the real reminder would.
    private func fireNow(_ request: UNNotificationRequest) {
        guard let content = request.content.mutableCopy() as? UNMutableNotificationContent else { return }
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let clone = UNNotificationRequest(
            identifier: "debugFire.\(request.identifier)",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(clone)
        firedIdentifier = request.identifier
    }

    private func reconcileAndReload() async {
        isLoading = true
        await ReminderScheduler.shared.reconcile(context: modelContext)
        await reload()
    }

    private func reload() async {
        let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
        requests = pending
            .filter { $0.identifier.hasPrefix("churReminder.") }
            .sorted { a, b in
                let aDate = (a.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate() ?? .distantFuture
                let bDate = (b.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate() ?? .distantFuture
                return aDate < bDate
            }
        isLoading = false
    }
}
#endif
