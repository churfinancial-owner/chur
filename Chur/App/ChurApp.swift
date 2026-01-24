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
            clientID: "72421479384-khfht84hnp48i7svdvce61d06511eepu.apps.googleusercontent.com"
        )
        TransferPartnerDatabase.loadFromBundle(region: RegionDatabase.detectUserRegion())
    }
    
    let modelContainer: ModelContainer = {
        let schema = Schema(
            [CreditCard.self, User.self, RewardRate.self, Benefit.self, SpendingCategory.self],
            version: Schema.Version(1, 8, 0) // Updated to 1.8.0 for user override flags (hasCustomAnnualFee, hasCustomForeignFee, hasCustomPointValue)
        )
        let config = ModelConfiguration(
            "Chur",
            schema: schema,
            isStoredInMemoryOnly: false
        )
        do {
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            #if DEBUG
            fatalError("❌ ModelContainer failed to initialise: \(error)\n\nTip: If you changed the schema, delete the app from the simulator to reset the store.")
            #else
            fatalError("Failed to create ModelContainer: \(error)")
            #endif
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .task { DateRefreshObserver.shared.start() }
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
        .modelContainer(modelContainer)
    }
}
