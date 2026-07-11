//
//  NotificationSettingsView.swift
//  Chur
//

import SwiftUI
import SwiftData

struct NotificationSettingsView: View {
    @AppStorage(ReminderScheduler.benefitRemindersEnabledKey) private var benefitRemindersEnabled: Bool = false
    @AppStorage(ReminderScheduler.annualFeeRemindersEnabledKey) private var feeRemindersEnabled: Bool = false
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
            // MARK: - Category Toggles
            Section {
                Toggle("Benefit expiry reminders", isOn: $benefitRemindersEnabled)
                    .tint(Color.churOlive)
                Toggle("Annual fee reminders", isOn: $feeRemindersEnabled)
                    .tint(Color.churOlive)

                if (benefitRemindersEnabled || feeRemindersEnabled) && systemPermissionDenied {
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
                Text("REMINDERS")
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
        .onChange(of: benefitRemindersEnabled) { _, enabled in
            handleToggle(enabled) { benefitRemindersEnabled = false }
        }
        .onChange(of: feeRemindersEnabled) { _, enabled in
            handleToggle(enabled) { feeRemindersEnabled = false }
        }
        .onDisappear {
            // Pick up any mute changes made in this screen.
            ReminderScheduler.shared.requestReconcile(context: modelContext)
        }
        .alert("Notifications Disabled", isPresented: $showingPermissionDeniedAlert) {
            Button("Open Settings") { openSystemSettings() }
            Button("Not Now", role: .cancel) { }
        } message: {
            Text("Allow notifications for Chur in iOS Settings to get benefit expiry reminders.")
        }
    }

    // MARK: - Permission handling

    /// Shared handler for both category toggles: enabling requests
    /// permission (reverting the toggle if denied); any change reconciles,
    /// which drops the disabled category's reminders as stale.
    private func handleToggle(_ enabled: Bool, revert: @escaping () -> Void) {
        Task {
            if enabled {
                let granted = await ReminderScheduler.shared.requestAuthorization()
                if granted {
                    systemPermissionDenied = false
                } else {
                    revert()
                    showingPermissionDeniedAlert = true
                    return
                }
            }
            await ReminderScheduler.shared.reconcile(context: modelContext)
        }
    }

    private func refreshPermissionState() async {
        let authorized = await ReminderScheduler.shared.isAuthorized()
        systemPermissionDenied = (benefitRemindersEnabled || feeRemindersEnabled) && !authorized
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
