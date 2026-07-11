//
//  NotificationSettingsView.swift
//  Chur
//

import SwiftUI
import SwiftData

struct NotificationSettingsView: View {
    @AppStorage(BenefitReminderScheduler.remindersEnabledKey) private var remindersEnabled: Bool = false
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CreditCard.dateAdded) private var cards: [CreditCard]

    // Cards start collapsed; track the ones the user has expanded.
    @State private var expandedCards: Set<String> = []
    @State private var showingPermissionDeniedAlert = false
    @State private var systemPermissionDenied = false
    @State private var scheduleIsRecommended = ReminderTiming.isRecommended

    private var cardsWithBenefits: [CreditCard] {
        cards.filter { !$0.benefits.filter { $0.isActive && $0.isRemindable }.isEmpty }
    }

    var body: some View {
        List {
            // MARK: - Master Toggle
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
            }

            // MARK: - Timing Subpage
            Section {
                NavigationLink {
                    ReminderScheduleView()
                } label: {
                    HStack {
                        Text("Reminder Schedule")
                            .font(.churRowText())
                            .foregroundStyle(Color.churDarkGray)
                        Spacer()
                        Text(scheduleIsRecommended ? "Recommended" : "Custom")
                            .font(.churRowText())
                            .foregroundStyle(Color.churMediumGray)
                    }
                }
            } header: {
                Text("REMINDER TIMING")
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
        .onAppear {
            // Refresh the detail label when returning from the schedule subpage.
            scheduleIsRecommended = ReminderTiming.isRecommended
        }
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
        let isExpanded = expandedCards.contains(card.id)
        let activeBenefits = card.benefits
            .filter { $0.isActive && $0.isRemindable }
            .sorted { $0.displayOrder < $1.displayOrder }

        DisclosureGroup(
            isExpanded: Binding(
                get: { isExpanded },
                set: { expanded in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        if expanded {
                            expandedCards.insert(card.id)
                        } else {
                            expandedCards.remove(card.id)
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
