//
//  ChurApp.swift
//  Chur
//
//  Created by Pak Ho on 1/17/26.
//

import SwiftUI
import SwiftData
import GoogleSignIn

@main
struct ChurApp: App {
    // Mirrors User.languagePreference (see AppLocale.swift) so a language change made
    // in Settings updates this view's environment locale immediately, without waiting
    // on a ModelContext round-trip.
    @AppStorage("appLanguage") private var appLanguageRaw: String = AppLanguage.system.rawValue

    init() {
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(
            clientID: Config.googleClientID
        )
        TransferPartnerDatabase.loadFromBundle(region: RegionDatabase.detectUserRegion())
        // Must happen before launch finishes so a notification tap that
        // cold-starts the app is still routed to its destination.
        ChurNotificationDelegate.shared.install()
        // Must also happen before launch finishes (BGTaskScheduler requirement).
        ReminderBackgroundRefresh.register(container: modelContainer)
        ReminderBackgroundRefresh.schedule()
        #if DEBUG
        // First line in the console on purpose — everything below it is only
        // trustworthy if this build is the one you just changed.
        BuildStamp.log()
        SeedDataValidator.run()
        #endif
    }

    /// Built by `ChurStoreRecovery`, which quarantines an unreadable store and
    /// starts fresh rather than crashing on launch. See that file for why.
    let modelContainer: ModelContainer = ChurStoreRecovery.makeContainer()

    /// Restores the previous Google Sign-In session on launch.
    /// Without this, GIDSignIn.sharedInstance.currentUser is nil after every app restart,
    /// causing CloudSyncManager to throw SyncError.notSignedIn even for returning users.
    private func restoreGoogleSignIn() {
        GIDSignIn.sharedInstance.restorePreviousSignIn { _, _ in
            // No action needed — on success, currentUser is repopulated automatically.
            // On failure (e.g. revoked token), currentUser stays nil and the user
            // will be prompted to sign in again from Settings.
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.locale, AppLocale.resolve(AppLanguage(rawValue: appLanguageRaw) ?? .system))
                .task { DateRefreshObserver.shared.start() }
                .task { restoreGoogleSignIn() }
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
        .modelContainer(modelContainer)
    }
}
