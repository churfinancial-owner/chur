//
//  AccountSettingsView.swift
//  Chur
//

import SwiftUI
import SwiftData
import AuthenticationServices
import GoogleSignIn

struct AccountSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var user: User
    @Query private var cards: [CreditCard]

    @State private var signInError: String?
    @State private var showSignOutConfirmation = false
    @State private var showDeleteAccountConfirmation = false
    @State private var showResetAllDataConfirmation = false
    @State private var pendingBackup: ChurBackup?
    @State private var showRestoreConflictSheet = false

    private var isSignedIn: Bool {
        user.authProvider == "apple" || user.authProvider == "google"
    }

    var body: some View {
        List {
            // MARK: - Profile Info
            Section("Profile") {
                HStack {
                    Text("Name")
                    Spacer()
                    Text(user.firstName.isEmpty ? "Not set" : user.firstName)
                        .foregroundStyle(Color.churMediumGray)
                }
                HStack {
                    Text("Email")
                    Spacer()
                    Text(user.email.isEmpty ? "Not set" : user.email)
                        .foregroundStyle(Color.churMediumGray)
                }
                if isSignedIn {
                    HStack {
                        Text("Signed in with")
                        Spacer()
                        HStack(spacing: 5) {
                            Image(systemName: user.authProvider == "apple" ? "apple.logo" : "person.crop.circle.fill")
                                .font(.churFootnote())
                            Text(user.authProvider == "apple" ? "Apple" : "Google")
                        }
                        .foregroundStyle(Color.churMediumGray)
                    }

                    Button("Sign Out") {
                        showSignOutConfirmation = true
                    }
                    .foregroundStyle(Color.churError)
                    .alert("Sign Out", isPresented: $showSignOutConfirmation) {
                        Button("Cancel", role: .cancel) {}
                        Button("Sign Out", role: .destructive) { performSignOut() }
                    } message: {
                        Text("All local data will be cleared and you'll be returned to the start. Your cloud backup will be preserved and can be restored when you sign in again.")
                    }
                }
            }

            // MARK: - Sign In (if anonymous)
            if !isSignedIn {
                Section("Sign In") {
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        handleSignInResult(result)
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

                    GoogleSignInButtonWrapper {
                        performGoogleSignIn()
                    }
                    .frame(height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 8, trailing: 16))

                    if let error = signInError {
                        Text(error)
                            .font(.churSmall())
                            .foregroundStyle(Color.churError)
                    }
                }
            }

            // MARK: - Backup (Google only)
            if user.authProvider == "google" {
                Section {
                    NavigationLink {
                        BackupSettingsView(user: user)
                    } label: {
                        Label("Backup & Sync", systemImage: "icloud.and.arrow.up")
                    }
                }
            }

            // MARK: - Danger Zone
            Section {
                if isSignedIn {
                    Button("Delete Account", role: .destructive) {
                        showDeleteAccountConfirmation = true
                    }
                } else {
                    Button("Reset Account", role: .destructive) {
                        showResetAllDataConfirmation = true
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.churOffWhite)
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showDeleteAccountConfirmation) {
            DeleteAccountConfirmationSheet(
                title: "Delete Account",
                message: "This will permanently delete all your cards, benefits, and cloud backup. This cannot be undone.",
                confirmWord: "DELETE",
                buttonLabel: "Delete Account & All Data",
                onConfirm: performDeleteAccount
            )
        }
        .sheet(isPresented: $showResetAllDataConfirmation) {
            DeleteAccountConfirmationSheet(
                title: "Reset Account",
                message: "This will delete all your cards and preferences on this device and return you to the start. This cannot be undone.",
                confirmWord: "RESET",
                buttonLabel: "Reset Account",
                onConfirm: performResetAllData
            )
        }
        .sheet(isPresented: $showRestoreConflictSheet) {
            if let backup = pendingBackup {
                RestoreConflictSheet(
                    backup: backup,
                    localCardCount: cards.count,
                    onRestore: { restoreFromBackup(backup) },
                    onKeepLocal: {}
                )
            }
        }
    }

    // MARK: - Account Actions

    private func performSignOut() {
        if user.authProvider == "google" {
            GIDSignIn.sharedInstance.signOut()
        }
        for card in cards {
            modelContext.delete(card)
        }
        user.appleUserID = ""
        user.googleUserID = ""
        user.email = ""
        user.firstName = ""
        user.authProvider = "anonymous"
        user.cardDisplayOrder = []
        user.selectedCategories = []
        user.deselectedCategories = []
        user.boostEnrollments = [:]
        user.strategyPreferences = []
        user.profilePhotoData = nil
        user.profileEmoji = "😊"
        user.onboardingCompleted = false
    }

    private func performResetAllData() {
        for card in cards {
            modelContext.delete(card)
        }
        user.email = ""
        user.firstName = ""
        user.cardDisplayOrder = []
        user.selectedCategories = []
        user.deselectedCategories = []
        user.boostEnrollments = [:]
        user.strategyPreferences = []
        user.profilePhotoData = nil
        user.profileEmoji = "😊"
        user.onboardingCompleted = false
    }

    private func restoreFromBackup(_ backup: ChurBackup) {
        for card in cards {
            modelContext.delete(card)
        }
        BackupRestoreService.restore(backup: backup, user: user, modelContext: modelContext)
    }

    private func performDeleteAccount() {
        Task {
            // 1. Delete cloud backup FIRST while still authenticated.
            //    Signing out before this call invalidates the token and causes
            //    the deletion to silently fail, leaving the backup on Drive.
            if user.authProvider == "google" {
                try? await CloudSyncManager.shared.deleteBackup()
                GIDSignIn.sharedInstance.signOut()
            }

            // 2. Reset all local data on the main actor
            await MainActor.run {
                for card in cards {
                    modelContext.delete(card)
                }
                user.appleUserID = ""
                user.googleUserID = ""
                user.email = ""
                user.firstName = ""
                user.authProvider = "anonymous"
                user.cardDisplayOrder = []
                user.selectedCategories = []
                user.deselectedCategories = []
                user.boostEnrollments = [:]
                user.strategyPreferences = []
                user.profilePhotoData = nil
                user.profileEmoji = "😊"

                // 3. Tell onboarding to skip the backup restore for this one sign-in.
                //    This guards against Drive propagation delay or silent deletion failures
                //    causing a "Welcome back" message after the user chose to delete everything.
                UserDefaults.standard.set(true, forKey: "chur.skipNextRestore")

                // 4. Route back to onboarding — RootView observes this flag
                user.onboardingCompleted = false
            }
        }
    }

    // MARK: - Auth Handlers

    private func handleSignInResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                signInError = "Unexpected credential type"
                return
            }
            user.appleUserID = credential.user
            if let name = credential.fullName?.givenName, !name.isEmpty { user.firstName = name }
            if let email = credential.email, !email.isEmpty { user.email = email }
            user.authProvider = "apple"
            signInError = nil
        case .failure(let error):
            if (error as? ASAuthorizationError)?.code == .canceled { return }
            signInError = "Sign in failed. Please try again."
        }
    }

    private func performGoogleSignIn() {
        if GIDSignIn.sharedInstance.configuration == nil {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(
                clientID: Config.googleClientID
            )
        }

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else {
            signInError = "Unable to present sign in"
            return
        }

        var presentingVC = rootVC
        while let presented = presentingVC.presentedViewController {
            presentingVC = presented
        }

        GIDSignIn.sharedInstance.signIn(
            withPresenting: presentingVC,
            hint: nil,
            additionalScopes: ["https://www.googleapis.com/auth/drive.appdata"]
        ) { result, error in
            if let error = error {
                if (error as NSError).code == GIDSignInError.canceled.rawValue { return }
                signInError = "Google sign in failed. Please try again."
                return
            }
            guard let googleUser = result?.user, let profile = googleUser.profile else {
                signInError = "Unable to get user profile"
                return
            }
            user.googleUserID = googleUser.userID ?? ""
            if let name = profile.givenName, !name.isEmpty { user.firstName = name }
            if !profile.email.isEmpty { user.email = profile.email }
            user.authProvider = "google"
            signInError = nil

            if cards.isEmpty {
                // Silent restore — no local data to conflict with
                let u = user
                let ctx = modelContext
                let existingCards = cards
                Task {
                    await BackupRestoreService.checkAndRestore(
                        user: u,
                        existingCards: existingCards,
                        modelContext: ctx
                    )
                }
            } else {
                // Local cards exist — check if a backup is on Drive and let the user decide
                Task {
                    if let backup = try? await CloudSyncManager.shared.downloadBackup() {
                        await MainActor.run {
                            pendingBackup = backup
                            showRestoreConflictSheet = true
                        }
                    }
                    // No backup on Drive → local data wins, nothing to do
                }
            }
        }
    }
}
