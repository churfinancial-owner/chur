import Foundation
import SwiftData

// MARK: - Credit Card Model
@Model
class CreditCard {
    var id: String
    var templateID: String?
    var name: String
    var issuer: String
    var network: String
    var imageName: String
    var hasCustomImage: Bool
    var cardType: String = "personal"
    var isAuthorizedUser: Bool = false
    
    var annualFee: Int
    var approvedMonth: Int = 1
    var approvedDay: Int = 1
    var approvedYear: Int
    var dateAdded: Date
    
    var currency: String = "USD"
    var country: String = "US"
    var status: String = "active"
    
    var hasForeignTransactionFee: Bool
    var foreignTransactionFeeRate: Double?
    
    @Relationship(deleteRule: .cascade) var rewards: [RewardRate]
    @Relationship(deleteRule: .cascade) var rewardPlans: [RewardPlan]
    var selectedPlanID: String?
    
    @Relationship(deleteRule: .cascade) var benefits: [Benefit]
    
    var allowsCategoryChoice: Bool
    var availableCategories: [String]?

    var note: String = ""
    var noteIsVisible: Bool = true
    var noteTextColor: String = "#FFFFFF"
    var noteBgColor: String = "#000000"
    
    var rewardProgramOverride: String?

    var hasCustomAnnualFee: Bool = false
    var hasCustomForeignFee: Bool = false

    /// Maps configurableSlot → selected label (e.g. "5pct_slot_1" → "Groceries").
    /// Single source of truth for configurable category choices. `reward.categories` is
    /// derived from this via `applySlotSelections()` and must never be edited directly.
    var slotSelections: [String: String] = [:]
    
    init(id: String, templateID: String? = nil, name: String, issuer: String, network: String, imageName: String,
         hasCustomImage: Bool = false, cardType: String = "personal", isAuthorizedUser: Bool = false,
         annualFee: Int = 0, approvedMonth: Int = 1, approvedDay: Int = 1, approvedYear: Int? = nil,
         currency: String = "USD", country: String = "US", status: String = "active",
         hasForeignTransactionFee: Bool = false, foreignTransactionFeeRate: Double? = nil,
         allowsCategoryChoice: Bool = false, availableCategories: [String]? = nil,
         note: String = "",
         noteIsVisible: Bool = true,
         noteTextColor: String = "#FFFFFF",
         noteBgColor: String = "#000000") {
        
        self.id = id
        self.templateID = templateID
        self.name = name
        self.issuer = issuer
        self.network = network
        self.imageName = imageName
        self.hasCustomImage = hasCustomImage
        self.cardType = cardType
        self.isAuthorizedUser = isAuthorizedUser
        self.annualFee = annualFee
        self.approvedMonth = approvedMonth
        self.approvedDay = approvedDay
        self.approvedYear = approvedYear ?? Calendar.current.component(.year, from: Date())
        self.dateAdded = Date()
        self.currency = currency
        self.country = country
        self.status = status
        self.hasForeignTransactionFee = hasForeignTransactionFee
        self.foreignTransactionFeeRate = foreignTransactionFeeRate
        self.rewards = []
        self.rewardPlans = []
        self.benefits = []
        self.allowsCategoryChoice = allowsCategoryChoice
        self.availableCategories = availableCategories
        self.note = note
        self.noteIsVisible = noteIsVisible
        self.noteTextColor = noteTextColor
        self.noteBgColor = noteBgColor
    }
}

// MARK: - Reward Plan Support

extension CreditCard {
    /// The currently active reward plan for this card
    var activePlan: RewardPlan? {
        // If user has selected a specific plan, use that
        if let selectedPlanID = selectedPlanID,
           let selectedPlan = rewardPlans.first(where: { $0.id == selectedPlanID }) {
            return selectedPlan
        }
        
        // Otherwise, use the default plan
        return rewardPlans.first(where: { $0.isDefault })
    }
    
    /// The active reward rates based on the selected or default plan
    var activeRewards: [RewardRate] {
        // Try new plan-based system first
        if let plan = activePlan {
            return plan.rewards
        }
        
        // Fall back to legacy direct rewards for backward compatibility
        return rewards
    }
    
    /// Whether this card has multiple plans available
    var hasMultiplePlans: Bool {
        return rewardPlans.count > 1
    }
    
    /// All available plans for new users (used when browsing cards)
    var availablePlansForNewUsers: [RewardPlan] {
        return rewardPlans.filter { $0.isAvailableForNewUsers }
    }
}

// MARK: - Program Override Support

extension CreditCard {
    /// The template's original reward program name (from the seed JSON).
    var templateProgramName: String? {
        guard let templateID = templateID,
              let template = CardDatabase.getCard(id: templateID) else { return nil }
        return template.rewardPlans.first(where: { $0.isDefault })?.rewards.first?.rewardProgramName
    }

    /// Whether the user has manually overridden the reward program.
    var hasManualProgramOverride: Bool {
        rewardProgramOverride != nil
    }
}

// MARK: - Configurable Slot Selections

extension CreditCard {
    /// Re-derives `reward.categories` for every configurable reward across all plans
    /// from `slotSelections` + the CardDatabase template.
    ///
    /// Call after any write to `slotSelections` (user picks a category, restore, sync).
    /// `reward.categories` is a derived cache — never write to it directly for configurable rewards.
    func applySlotSelections() {
        guard let templateID = templateID,
              let template = CardDatabase.getCard(id: templateID) else { return }
        let templateRewards = template.rewardPlans.flatMap { $0.rewards }
        for plan in rewardPlans {
            for reward in plan.rewards {
                guard reward.isUserConfigurable, let slot = reward.configurableSlot else { continue }
                if let label = slotSelections[slot],
                   let templateReward = templateRewards.first(where: { $0.configurableSlot == slot }),
                   let categoryIDs = templateReward.configurableIncludes?[label],
                   !categoryIDs.isEmpty {
                    reward.categories = categoryIDs
                } else {
                    reward.categories = nil
                }
            }
        }
    }
}

// MARK: - Boost

extension CreditCard {
    /// The boost multiplier from a relationship program (e.g. BofA Preferred Rewards, US Bank Smartly).
    /// Requires the User's boostEnrollments to be passed in — defaults to 1.0 (no boost).
    func boostMultiplier(enrollments: [String: String]) -> Double {
        guard let program = BoostProgramDatabase.program(for: templateID),
              let tierName = enrollments[program.id] else { return 1.0 }
        return BoostProgramDatabase.multiplier(programID: program.id, tierName: tierName)
    }

    /// Convenience: the active boost program for this card's template, if any.
    var boostProgram: BoostProgram? {
        BoostProgramDatabase.program(for: templateID)
    }
}

