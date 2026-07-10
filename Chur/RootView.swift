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

    var body: some View {
        if let user = users.first, user.onboardingCompleted {
            ContentView()
                .environment(\.rewardDisplay, RewardDisplayPreference(
                    showEffectiveRate: user.showEffectiveRate
                ))
        } else {
            OnboardingContainerView()
        }
    }
}
