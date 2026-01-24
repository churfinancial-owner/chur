//
//  RewardRate_Logic.swift
//  Chur
//
//  Created by Pak Ho on 3/18/26.
//

import Foundation

// MARK: - RewardRate Extension
extension RewardRate {
    /// Returns whether this reward is currently active based on its date range.
    /// If no dates are set, the reward is always active.
    func isActive(on date: Date = Date.current()) -> Bool {
        guard let start = rewardStartDate, let end = rewardEndDate else {
            return true // No date constraints = always active
        }
        return date >= start && date <= end
    }
}
