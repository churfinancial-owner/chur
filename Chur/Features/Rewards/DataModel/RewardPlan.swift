//
//  RewardPlan.swift
//  Chur
//
//  Created by Pak Ho on 2/23/26.
//

import Foundation
import SwiftData

// MARK: - Reward Plan Model
@Model
class RewardPlan {
    var id: String                    // "csr-current-2024" or "card-uuid-custom-1"
    var name: String                  // "Current Structure (2024+)" or "My Custom Plan"
    var isDefault: Bool               // true for the default/current plan
    var isAvailableForNewUsers: Bool  // false for grandfathered/legacy plans
    var planStartDate: Date?          // When this plan became active
    var planEndDate: Date?            // When this plan ended (nil = current/ongoing)
    var isCustomPlan: Bool            // true if user created this plan
    var isPromo: Bool                 // true for promotional/limited-time plans
    
    var card: CreditCard?             // Back-reference to the card
    @Relationship(deleteRule: .cascade) var rewards: [RewardRate]  // The actual reward rates
    
    init(id: String,
         name: String,
         isDefault: Bool = false,
         isAvailableForNewUsers: Bool = true,
         planStartDate: Date? = nil,
         planEndDate: Date? = nil,
         isCustomPlan: Bool = false,
         isPromo: Bool = false) {
        
        self.id = id
        self.name = name
        self.isDefault = isDefault
        self.isAvailableForNewUsers = isAvailableForNewUsers
        self.planStartDate = planStartDate
        self.planEndDate = planEndDate
        self.isCustomPlan = isCustomPlan
        self.isPromo = isPromo
        self.rewards = []
    }
}

// MARK: - Computed Properties

extension RewardPlan {
    /// Whether this plan is currently active based on date range
    var isActive: Bool {
        let now = Date()
        
        if let startDate = planStartDate, now < startDate {
            return false  // Plan hasn't started yet
        }
        
        if let endDate = planEndDate, now > endDate {
            return false  // Plan has ended
        }
        
        return true
    }
    
    /// Display text for plan date range
    var dateRangeText: String? {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        
        if let start = planStartDate, let end = planEndDate {
            return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
        } else if let start = planStartDate {
            return "From \(formatter.string(from: start))"
        } else if let end = planEndDate {
            return "Until \(formatter.string(from: end))"
        }
        
        return nil
    }
}
