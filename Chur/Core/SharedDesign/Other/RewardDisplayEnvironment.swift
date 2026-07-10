//
//  RewardDisplayEnvironment.swift
//  Chur
//
//  Single source of truth for how reward rates are displayed across the app.
//  Injected once from RootView; any descendant can read it via @Environment.
//

import SwiftUI

struct RewardDisplayPreference {
    var showEffectiveRate: Bool = false
}

private struct RewardDisplayKey: EnvironmentKey {
    static let defaultValue = RewardDisplayPreference()
}

extension EnvironmentValues {
    var rewardDisplay: RewardDisplayPreference {
        get { self[RewardDisplayKey.self] }
        set { self[RewardDisplayKey.self] = newValue }
    }
}
