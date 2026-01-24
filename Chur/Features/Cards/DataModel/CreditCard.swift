import Foundation
import SwiftData

// MARK: - Credit Card Model
@Model // <--- YOU MUST HAVE THIS LINE
class CreditCard {
    var id: String
    var templateID: String? // The CardDatabase template id this card was created from
    var name: String
    var issuer: String
    var network: String
    var imageName: String
    var hasCustomImage: Bool
    var cardType: String = "personal"
    var isAuthorizedUser: Bool = false
    
    var annualFee: Int
    var approvedMonth: Int = 1
    var approvedYear: Int
    var dateAdded: Date
    
    var currency: String = "USD"
    var country: String = "US"
    var status: String = "active"
    
    var hasForeignTransactionFee: Bool
    var foreignTransactionFeeRate: Double?
    
    @Relationship(deleteRule: .cascade) var rewards: [RewardRate]  // LEGACY: kept for backward compatibility during migration
    @Relationship(deleteRule: .cascade) var rewardPlans: [RewardPlan]  // NEW: multiple plans per card
    var selectedPlanID: String?  // Which plan the user has selected (nil = use default)
    
    @Relationship(deleteRule: .cascade) var benefits: [Benefit]
    
    var allowsCategoryChoice: Bool
    var availableCategories: [String]?

    var note: String = "" // This is now correctly tracked by SwiftData
    var rewardProgramOverride: String?  // nil = auto; non-nil = user manually chose this program

    // User override flags — sync will not overwrite these fields from the template when true
    var hasCustomAnnualFee: Bool = false
    var hasCustomForeignFee: Bool = false
    
    init(id: String, templateID: String? = nil, name: String, issuer: String, network: String, imageName: String,
         hasCustomImage: Bool = false, cardType: String = "personal", isAuthorizedUser: Bool = false,
         annualFee: Int = 0, approvedMonth: Int = 1, approvedYear: Int? = nil,
         currency: String = "USD", country: String = "US", status: String = "active",
         hasForeignTransactionFee: Bool = false, foreignTransactionFeeRate: Double? = nil,
         allowsCategoryChoice: Bool = false, availableCategories: [String]? = nil,
         note: String = "") {
        
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

