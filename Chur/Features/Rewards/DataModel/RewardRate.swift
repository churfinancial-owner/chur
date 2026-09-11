//
//  RewardRate.swift
//  Chur
//
//  Created by Pak Ho on 1/17/26.
//

import Foundation
import SwiftData

// MARK: - Condition storage
//
// SwiftData persists a plain `String`; the struct is encoded on write and decoded
// on read, the same shape `SpendingCategory.categoryLinksJSON` uses.

enum LayerConditionCoding {
    static func encode(_ condition: LayerCondition?) -> String? {
        guard let condition,
              let data = try? JSONEncoder().encode(condition) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func decode(_ json: String?) -> LayerCondition? {
        guard let json, let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(LayerCondition.self, from: data)
    }
}

// MARK: - Reward Rate Extension

extension RewardRate {
    /// What unlocks this rate. Display only — see `ConditionText`.
    var gate: LayerCondition? {
        get { LayerConditionCoding.decode(gateJSON) }
        set { gateJSON = LayerConditionCoding.encode(newValue) }
    }

    /// Where this rate stops. Display only — see `ConditionText`.
    var cap: LayerCondition? {
        get { LayerConditionCoding.decode(capJSON) }
        set { capJSON = LayerConditionCoding.encode(newValue) }
    }

    /// Effective cash back rate per dollar spent.
    /// e.g. 4x UR at $0.0125/pt = 0.05 (5¢ per dollar)
    var effectiveCashBackRate: Double {
        rate * pointCashValue
    }
}

// MARK: - Reward Rate Model
@Model
class RewardRate {
    // Earning
    var rate: Double // multiplier (3.0 = 3x)
    var rewardProgramName: String // "Ultimate Rewards", "Membership Rewards", "Cash Back"
    var pointCashValue: Double // 0.0125 for UR (base value per point)
    var pointCashValueCurrency: String // "USD", "HKD", "TWD", "CAD"
    
    // Application (where this rate applies)
    var categories: [String]? // ["dining", "groceries"] - nil = everything (was single String)
    var merchantIdentifier: String? // "amazon", "mcdonalds" - nil = all merchants
    var merchantName: String? // "Amazon", "McDonald's" - for display
    
    // Geographic (where rate works)
    var countries: [String]? // ["US", "HK"] - nil = all countries
    
    // Channel (how purchase is made)
    var channels: [String]? // ["online", "in_store", "in_app"] - nil = all channels

    // Transaction dimensions (P1f part 3) — all template-owned, nil = no constraint
    var currencies: [String]?        // ["JPY", "KRW"] — transaction currency, derived from the merchant region
    var excludedCountries: [String]? // ["FR", "DE"] — regions where this rate pays nothing (EEA carve-outs)
    var paymentMethods: [String]?    // ["contactless", "mobile_pay"] — see PaymentMethods

    // Conditions (P1f part 4) — **display only**, rendered by `ConditionText`.
    // The app tracks no spend, so neither ever enters the pricing formula.
    var gateJSON: String?            // LayerCondition: what unlocks this rate
    var capJSON: String?             // LayerCondition: where it stops
    
    // Time constraints
    var rewardStartDate: Date? // When rate starts
    var rewardEndDate: Date? // When rate ends
    var isRotating: Bool // Quarterly rotation flag
    var daysOfWeek: [Int]? // [1, 7] = Sunday & Saturday - nil = all days (1=Sun, 2=Mon...7=Sat)
    
    // Display info
    var rewardNotes: String? // "Up to $25k/year", "First $1k: 5x, then 3x", "Requires $500 min spend"
    var groupLabel: String? // display-only group name for non-configurable grouped rewards, e.g. "Self-Care" — never used for matching

    // User-configurable category selection
    var isUserConfigurable: Bool       // true = user must pick a category for this reward
    var configurableSlot: String?      // e.g. "5pct_slot_1", "2pct_slot_1"
    var configurableOptions: [String]? // display labels the user can pick from
    var configurableIncludes: [String: [String]]? // label → [categoryIDs] e.g. "Utilities" → ["internet","tv_cable"]
    var selectedConfigurableLabel: String? // user's selected label, e.g. "Restaurants" — stored directly for reliable persistence
    var hasCustomPointValue: Bool = false  // true = user set a custom valuation; sync will not overwrite pointCashValue

    init(rate: Double,
         rewardProgramName: String = "Rewards",
         pointCashValue: Double = 0.01,
         pointCashValueCurrency: String = "USD",
         categories: [String]? = nil,
         merchantIdentifier: String? = nil, merchantName: String? = nil,
         countries: [String]? = nil, channels: [String]? = nil,
         currencies: [String]? = nil, excludedCountries: [String]? = nil, paymentMethods: [String]? = nil,
         gate: LayerCondition? = nil, cap: LayerCondition? = nil,
         rewardStartDate: Date? = nil, rewardEndDate: Date? = nil, isRotating: Bool = false, daysOfWeek: [Int]? = nil,
         rewardNotes: String? = nil,
         groupLabel: String? = nil,
         isUserConfigurable: Bool = false,
         configurableSlot: String? = nil,
         configurableOptions: [String]? = nil,
         configurableIncludes: [String: [String]]? = nil) {
        
        self.rate = rate
        self.rewardProgramName = rewardProgramName
        self.pointCashValue = pointCashValue
        self.pointCashValueCurrency = pointCashValueCurrency
        self.categories = categories
        self.merchantIdentifier = merchantIdentifier
        self.merchantName = merchantName
        self.countries = countries
        self.channels = channels
        self.currencies = currencies
        self.excludedCountries = excludedCountries
        self.paymentMethods = paymentMethods
        self.gateJSON = LayerConditionCoding.encode(gate)
        self.capJSON = LayerConditionCoding.encode(cap)
        self.rewardStartDate = rewardStartDate
        self.rewardEndDate = rewardEndDate
        self.isRotating = isRotating
        self.daysOfWeek = daysOfWeek
        self.rewardNotes = rewardNotes
        self.groupLabel = groupLabel
        self.isUserConfigurable = isUserConfigurable
        self.configurableSlot = configurableSlot
        self.configurableOptions = configurableOptions
        self.configurableIncludes = configurableIncludes
    }
}
