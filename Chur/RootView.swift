//
//  RootView.swift
//  Chur
//
//  Gate view that shows onboarding or the main app based on user state.
//

import SwiftUI
import SwiftData

struct RootView: View {
    @Query private var users: [User]

    /// Seeded once at view creation — `ChurStoreRecovery` finishes before the
    /// view tree is built, so there is nothing to observe after this point.
    @State private var showRecoveryNotice = ChurStoreRecovery.didResetStore

    var body: some View {
        Group {
            if let user = users.first, user.onboardingCompleted {
                ContentView()
                    .environment(\.rewardDisplay, RewardDisplayPreference(
                        showEffectiveRate: user.showEffectiveRate
                    ))
            } else {
                OnboardingContainerView()
            }
        }
        .fullScreenCover(isPresented: $showRecoveryNotice) {
            StoreRecoveryNoticeView { showRecoveryNotice = false }
        }
    }
}
