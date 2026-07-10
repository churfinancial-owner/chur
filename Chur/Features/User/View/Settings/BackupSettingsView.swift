//
//  BackupSettingsView.swift
//  Chur
//

import SwiftUI
import SwiftData

struct BackupSettingsView: View {
    @Bindable var user: User
    @Query private var cards: [CreditCard]

    @State private var isSyncing = false
    @State private var syncError: String?
    @State private var lastSyncedAt: Date? = CloudSyncManager.shared.lastSyncedAt
    @State private var showDeleteBackupConfirmation = false

    var body: some View {
        List {
            Section {
                HStack {
                    Text("Last Backed Up")
                    Spacer()
                    Text(lastSyncedAtText)
                        .foregroundStyle(Color.churMediumGray)
                }

                Button {
                    performBackup()
                } label: {
                    HStack {
                        Text(isSyncing ? "Backing Up…" : "Back Up Now")
                        Spacer()
                        if isSyncing { ProgressView() }
                    }
                }
                .disabled(isSyncing)

                if let error = syncError {
                    Text(error)
                        .font(.churFootnote())
                        .foregroundStyle(Color.churError)
                        .onTapGesture { syncError = nil }
                }

                Button("Delete Backup", role: .destructive) {
                    showDeleteBackupConfirmation = true
                }
                .confirmationDialog(
                    "Delete Backup?",
                    isPresented: $showDeleteBackupConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Delete Backup", role: .destructive) { performDeleteBackup() }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Your backup will be permanently removed from your Google Drive. Your local data on this device will not be affected.")
                }
            } header: {
                Text("Google Drive")
            } footer: {
                Text("Backed up privately to your Google Drive. Only you can access it.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.churOffWhite)
        .navigationTitle("Backup & Sync")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Actions

    private func performBackup() {
        let backup = ChurBackup.snapshot(of: user, cards: cards)
        isSyncing = true
        syncError = nil
        Task {
            defer { isSyncing = false }
            do {
                try await CloudSyncManager.shared.uploadBackup(backup)
                lastSyncedAt = CloudSyncManager.shared.lastSyncedAt
            } catch {
                syncError = error.localizedDescription
            }
        }
    }

    private func performDeleteBackup() {
        Task {
            do {
                try await CloudSyncManager.shared.deleteBackup()
                lastSyncedAt = nil
            } catch {
                syncError = error.localizedDescription
            }
        }
    }

    // MARK: - Helpers

    private var lastSyncedAtText: String {
        guard let date = lastSyncedAt else { return "Never" }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        let time = formatter.string(from: date)
        if Calendar.current.isDateInToday(date)     { return "Today at \(time)" }
        if Calendar.current.isDateInYesterday(date) { return "Yesterday at \(time)" }
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
