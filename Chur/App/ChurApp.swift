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
    
    init() {
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(
            clientID: Config.googleClientID
        )
        TransferPartnerDatabase.loadFromBundle(region: RegionDatabase.detectUserRegion())
    }
    
    let modelContainer: ModelContainer = {
        let schema = Schema(ChurSchemaV1_10.models, version: ChurSchemaV1_10.versionIdentifier)
        let config = ModelConfiguration("Chur", schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, migrationPlan: ChurMigrationPlan.self, configurations: [config])
        } catch {
            #if DEBUG
            fatalError("❌ ModelContainer failed to initialise: \(error)\n\nTip: If you changed the schema, delete the app from the simulator to reset the store.")
            #else
            fatalError("Failed to create ModelContainer: \(error)")
            #endif
        }
    }()

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
                .task { DateRefreshObserver.shared.start() }
                .task { restoreGoogleSignIn() }
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
        .modelContainer(modelContainer)
    }
}
