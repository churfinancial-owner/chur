//
//  NotificationSettingsView.swift
//  Chur
//

import SwiftUI
import SwiftData

struct NotificationSettingsView: View {
    @AppStorage("expiryWarningDays") private var expiryWarningDays: Int = 3
    @AppStorage(BenefitReminderScheduler.remindersEnabledKey) private var remindersEnabled: Bool = false
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CreditCard.dateAdded) private var cards: [CreditCard]

    // Track which cards the user has manually collapsed; all start expanded.
    @State private var collapsedCards: Set<String> = []
    @State private var showingPermissionDeniedAlert = false
    @State private var systemPermissionDenied = false

    private var cardsWithBenefits: [CreditCard] {
        cards.filter { !$0.benefits.filter { $0.isActive && $0.isRemindable }.isEmpty }
    }

    var body: some View {
        List {
            // MARK: - Expiry Reminders (push notifications)
            Section {
                Toggle("Benefit expiry reminders", isOn: $remindersEnabled)
                    .tint(Color.churOlive)

                if remindersEnabled && systemPermissionDenied {
                    Button {
                        openSystemSettings()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text("Notifications are off in iOS Settings — tap to fix")
                                .font(.churFootnote())
                                .foregroundStyle(Color.churDarkGray)
                        }
                    }
                }
            } header: {
                Text("EXPIRY REMINDERS")
            } footer: {
                Text("Timed to each benefit's cycle: monthly benefits 3 days before expiry, quarterly 7 and 1 days before, longer cycles 14 and 3 days before. Delivered at 9 AM. Fully used benefits are never reminded.")
            }

            // MARK: - In-App Warning Timing
            Section {
                Stepper(
                    "Expiry badge: \(expiryWarningDays) day\(expiryWarningDays == 1 ? "" : "s") before",
                    value: $expiryWarningDays,
                    in: 1...30
                )
            } header: {
                Text("IN-APP WARNING TIMING")
            } footer: {
                Text("Controls when the ⏰ badge and the Expiring filter flag a benefit inside the app.")
            }

            // MARK: - Per-Benefit Mute Controls
            if cardsWithBenefits.isEmpty {
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "bell.badge")
                                .font(.churBigTitle3())
                                .foregroundStyle(Color.churMediumGray)
                            Text("Add cards to manage benefit reminders")
                                .font(.churFootnote())
                                .foregroundStyle(Color.churMediumGray)
                                .multilineTextAlignment(.center)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 16)
                    .listRowBackground(Color.clear)
                }
            } else {
                Section {
                    ForEach(cardsWithBenefits) { card in
                        cardDisclosureGroup(card)
                    }
                } header: {
                    Text("BENEFIT REMINDERS")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.churOffWhite)
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .task { await refreshPermissionState() }
        .onChange(of: remindersEnabled) { _, enabled in
            handleRemindersToggle(enabled)
        }
        .onDisappear {
            // Pick up any mute changes made in this screen.
            BenefitReminderScheduler.shared.requestReconcile(context: modelContext)
        }
        .alert("Notifications Disabled", isPresented: $showingPermissionDeniedAlert) {
            Button("Open Settings") { openSystemSettings() }
            Button("Not Now", role: .cancel) { }
        } message: {
            Text("Allow notifications for Chur in iOS Settings to get benefit expiry reminders.")
        }
    }

    // MARK: - Permission handling

    private func handleRemindersToggle(_ enabled: Bool) {
        Task {
            if enabled {
                let granted = await BenefitReminderScheduler.shared.requestAuthorization()
                if granted {
                    systemPermissionDenied = false
                    await BenefitReminderScheduler.shared.reconcile(context: modelContext)
                } else {
                    remindersEnabled = false
                    showingPermissionDeniedAlert = true
                }
            } else {
                await BenefitReminderScheduler.shared.removeAllReminders()
            }
        }
    }

    private func refreshPermissionState() async {
        let authorized = await BenefitReminderScheduler.shared.isAuthorized()
        systemPermissionDenied = remindersEnabled && !authorized
    }

    private func openSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    @ViewBuilder
    private func cardDisclosureGroup(_ card: CreditCard) -> some View {
        let isExpanded = !collapsedCards.contains(card.id)
        let activeBenefits = card.benefits
            .filter { $0.isActive && $0.isRemindable }
            .sorted { $0.displayOrder < $1.displayOrder }

        DisclosureGroup(
            isExpanded: Binding(
                get: { isExpanded },
                set: { expanded in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        if expanded {
                            collapsedCards.remove(card.id)
                        } else {
                            collapsedCards.insert(card.id)
                        }
                    }
                }
            )
        ) {
            ForEach(activeBenefits, id: \.id) { benefit in
                BenefitMuteRow(benefit: benefit)
            }
        } label: {
            Text(card.name)
                .font(.churRowTextMedium())
                .foregroundStyle(Color.churDarkGray)
        }
    }
}

// MARK: - Benefit Mute Row

private struct BenefitMuteRow: View {
    @Bindable var benefit: Benefit

    var body: some View {
        HStack {
            Text(benefit.displayName)
                .font(.churRowText())
                .foregroundStyle(Color.churDarkGray)
                .lineLimit(1)

            Spacer()

            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    benefit.isMuted.toggle()
                }
            } label: {
                Image(systemName: benefit.isMuted ? "bell.slash.fill" : "bell.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(benefit.isMuted ? Color.churMediumGray : Color.churOlive)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
        }
        .listRowBackground(Color.white)
    }
}
