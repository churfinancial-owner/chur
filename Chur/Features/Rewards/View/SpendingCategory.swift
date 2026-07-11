//
//  SpendingCategory.swift
//  Chur
//
//  Created by Pak Ho on 1/17/26.
//

import Foundation
import SwiftData
import SwiftUI

// MARK: - Category Level
enum CategoryLevel: String, Codable {
    case parent       // top-level category e.g. "Travel"
    case child        // sub-category e.g. "Flights"
    case groupTarget  // groups targets under a shared umbrella e.g. "SkyTeam Airlines", "Gap Family"
    case target       // specific goal/leaf e.g. "Delta Airline", "Banana Republic"
}

// MARK: - Category Link
/// A cross-link to another category the tree can't express (e.g. costco → wholesale,
/// wholefood → amazon). Encodes as a plain string ID; decodes from either "amazon"
/// or the legacy {"id": "amazon", "weight": 1.0} object form still in older seed files.
struct CategoryLink: Codable {
    var id: String       // references a SpendingCategory.id

    init(id: String) {
        self.id = id
    }

    init(from decoder: Decoder) throws {
        if let single = try? decoder.singleValueContainer(),
           let plainID = try? single.decode(String.self) {
            id = plainID
            return
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(id)
    }

    private enum CodingKeys: String, CodingKey {
        case id
    }
}

// MARK: - Card Filter
/// Defines card filtering rules for specific categories (e.g., Costco = Visa only)
/// Supports both global filters and region-specific filters for merchants with varying acceptance by country
struct CardFilter: Codable {
    // Global filters (legacy, backward compatible)
    var networks: [String]?      // ["Visa", "Mastercard", "American Express", "Discover"]
    var issuers: [String]?       // ["Chase", "American Express", "Citi", "Capital One", "Bank of America"]
    var cardTypes: [String]?     // ["personal", "business"]
    var mode: FilterMode?        // "include" = only these allowed, "exclude" = these NOT allowed
    
    // Regional filters (e.g., Costco USA vs Costco Taiwan)
    var regions: [String: RegionalFilter]?  // Key = region code (US, TW, HK, etc)
    
    enum FilterMode: String, Codable {
        case include  // Allowlist: only cards matching ALL criteria are allowed
        case exclude  // Blocklist: cards matching ANY criteria are excluded
    }

    private static func normalizedNetwork(_ value: String) -> String {
        let normalized = value
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")

        switch normalized {
        case "amex", "americanexpress":
            return "americanexpress"
        case "mastercard", "mc":
            return "mastercard"
        case "visa":
            return "visa"
        case "discover":
            return "discover"
        default:
            return normalized
        }
    }
    
    /// Regional filter definition
    struct RegionalFilter: Codable {
        var networks: [String]?
        var issuers: [String]?
        var cardTypes: [String]?
        var mode: FilterMode
        
        /// Check if a card passes this regional filter
        func allows(_ card: CreditCard) -> Bool {
            var passes = true
            
            // Check network restriction
            if let networks = networks, !networks.isEmpty {
                let cardNetwork = CardFilter.normalizedNetwork(card.network)
                let networkMatches = networks.contains {
                    CardFilter.normalizedNetwork($0) == cardNetwork
                }
                passes = passes && networkMatches
            }
            
            // Check issuer restriction
            if let issuers = issuers, !issuers.isEmpty {
                let issuerMatches = issuers.contains(card.issuer)
                passes = passes && issuerMatches
            }
            
            // Check card type restriction
            if let cardTypes = cardTypes, !cardTypes.isEmpty {
                let typeMatches = cardTypes.contains(card.cardType)
                passes = passes && typeMatches
            }
            
            // Apply mode
            switch mode {
            case .include:
                return passes  // Must match all criteria to be allowed
            case .exclude:
                return !passes  // Must NOT match criteria to be allowed
            }
        }
    }
    
    /// Get the appropriate filter for a specific region
    /// - Parameter region: Region code (e.g., "US", "TW", "HK") or nil for unknown
    /// - Returns: Regional filter for the specified region, falling back to "default" or global filter
    func filterFor(region: String?) -> RegionalFilter? {
        // If regions are defined, use region-specific filtering
        if let regions = regions {
            // Try exact region match first
            if let region = region, let filter = regions[region] {
                return filter
            }
            
            // Fallback to "default" region
            if let defaultFilter = regions["default"] {
                return defaultFilter
            }
            
            // No match and no default - no filtering
            return nil
        }
        
        // Legacy global filter - convert to RegionalFilter
        if let mode = mode {
            return RegionalFilter(
                networks: networks,
                issuers: issuers,
                cardTypes: cardTypes,
                mode: mode
            )
        }
        
        // No filtering defined
        return nil
    }
    
    /// Check if a card passes this filter (legacy, non-regional)
    /// Returns true if the card is ALLOWED, false if it should be EXCLUDED
    func allows(_ card: CreditCard) -> Bool {
        // Use filterFor with nil region (global filter)
        return filterFor(region: nil)?.allows(card) ?? true
    }
}


// MARK: - Spending Category Model
@Model
class SpendingCategory {
    var id: String // "dining", "travel", "flights" (stable identifier)
    var nameEN: String // "Dining"
    var nameZH_Hans: String // "餐饮" (Simplified Chinese - Mainland)
    var nameZH_HK: String // "餐飲" (Traditional Chinese - Hong Kong)
    var nameZH_TW: String // "餐飲" (Traditional Chinese - Taiwan)
    var emoji: String // "🍽️"
    var iconName: String? // asset catalog name e.g. "hilton", "mcdonalds" — falls back to emoji if nil
    var sortOrder: Int // for consistent display ordering
    var isActive: Bool // hide deprecated categories
    var isDefault: Bool // include in default user selections
    var excludeFromParent: Bool // if true, only exact-match rewards apply — no ancestor cascade
    var parentCategoryID: String? // links child to parent (e.g., "flights" → "travel")
    var level: CategoryLevel? // parent, child, or target
    /// Raw JSON storage — SwiftData persists this as a plain String, no transformer needed.
    var categoryLinksJSON: String?
    /// Raw JSON storage for card filtering rules
    var cardFilterJSON: String?
    /// Optional channel constraints for this category (e.g. ["online"] for paypal_pay)
    var channels: [String]?
    /// Payment methods that do NOT work at this merchant (e.g. ["apple_pay", "mobile_pay"] for Walmart)
    var excludedPaymentMethods: [String]?
    /// Optional display hint for picker visibility. "hidden" hides this category in picker.
    var visibility: String?

    // MARK: - Cached decoded properties (non-persisted)
    @Transient private var _cachedCategoryLinks: [CategoryLink]??
    @Transient private var _cachedCategoryLinksJSON: String?
    @Transient private var _cachedCardFilter: CardFilter??
    @Transient private var _cachedCardFilterJSON: String?

    /// Typed access to the category links. Decoded once and cached until the JSON changes.
    var categoryLinks: [CategoryLink]? {
        get {
            // Return cache if the underlying JSON hasn't changed
            if _cachedCategoryLinksJSON == categoryLinksJSON, let cached = _cachedCategoryLinks {
                return cached
            }
            // Decode and cache
            let decoded: [CategoryLink]?
            if let json = categoryLinksJSON, let data = json.data(using: .utf8) {
                decoded = try? JSONDecoder().decode([CategoryLink].self, from: data)
            } else {
                decoded = nil
            }
            _cachedCategoryLinks = .some(decoded)
            _cachedCategoryLinksJSON = categoryLinksJSON
            return decoded
        }
        set {
            _cachedCategoryLinks = nil
            _cachedCategoryLinksJSON = nil
            guard let newValue,
                  let data = try? JSONEncoder().encode(newValue) else {
                categoryLinksJSON = nil
                return
            }
            categoryLinksJSON = String(data: data, encoding: .utf8)
        }
    }
    
    /// Typed access to card filter. Decoded once and cached until the JSON changes.
    var cardFilter: CardFilter? {
        get {
            if _cachedCardFilterJSON == cardFilterJSON, let cached = _cachedCardFilter {
                return cached
            }
            let decoded: CardFilter?
            if let json = cardFilterJSON, let data = json.data(using: .utf8) {
                decoded = try? JSONDecoder().decode(CardFilter.self, from: data)
            } else {
                decoded = nil
            }
            _cachedCardFilter = .some(decoded)
            _cachedCardFilterJSON = cardFilterJSON
            return decoded
        }
        set {
            _cachedCardFilter = nil
            _cachedCardFilterJSON = nil
            guard let newValue,
                  let data = try? JSONEncoder().encode(newValue) else {
                cardFilterJSON = nil
                return
            }
            cardFilterJSON = String(data: data, encoding: .utf8)
        }
    }

    var displayName: String {
        let languageCode = Locale.current.language.languageCode?.identifier
        let regionCode = Locale.current.region?.identifier
        
        // Check for Chinese variants
        if languageCode == "zh" {
            // Hong Kong
            if regionCode == "HK" {
                return nameZH_HK
            }
            // Taiwan
            else if regionCode == "TW" {
                return nameZH_TW
            }
            // Mainland China (default for other Chinese locales)
            else {
                return nameZH_Hans
            }
        }
        
        return nameEN
    }
    
    init(id: String, nameEN: String, nameZH_Hans: String, nameZH_HK: String, nameZH_TW: String,
         emoji: String, iconName: String? = nil, sortOrder: Int, isDefault: Bool = true,
         parentCategoryID: String? = nil, level: CategoryLevel? = nil,
         categoryLinks: [CategoryLink]? = nil, excludeFromParent: Bool = false,
         cardFilter: CardFilter? = nil, excludedPaymentMethods: [String]? = nil,
         channels: [String]? = nil, visibility: String? = nil) {
        self.id = id
        self.nameEN = nameEN
        self.nameZH_Hans = nameZH_Hans
        self.nameZH_HK = nameZH_HK
        self.nameZH_TW = nameZH_TW
        self.emoji = emoji
        self.iconName = iconName
        self.sortOrder = sortOrder
        self.isActive = true
        self.isDefault = isDefault
        self.excludeFromParent = excludeFromParent
        self.parentCategoryID = parentCategoryID
        self.level = level
        self.categoryLinks = categoryLinks
        self.cardFilter = cardFilter
        self.excludedPaymentMethods = excludedPaymentMethods
        self.channels = channels
        self.visibility = visibility
    }
}

// MARK: - Helper Methods
extension SpendingCategory {
    // Get all categories at a given level
    static func categories(for level: CategoryLevel, from allCategories: [SpendingCategory]) -> [SpendingCategory] {
        return allCategories
            .filter { $0.level == level }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    // Get all categories that link to a given ID (e.g. children of a parent).
    // Hierarchy comes from parentCategoryID; categoryLinks are additive cross-links.
    static func categories(linkedTo parentID: String, from allCategories: [SpendingCategory]) -> [SpendingCategory] {
        return allCategories
            .filter { $0.parentCategoryID == parentID || $0.categoryLinks?.contains { $0.id == parentID } == true }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    // Legacy helpers — kept for backward compatibility during migration
    static func getSubcategories(for parentID: String, from allCategories: [SpendingCategory]) -> [SpendingCategory] {
        return allCategories
            .filter { $0.parentCategoryID == parentID }
            .sorted { $0.sortOrder < $1.sortOrder }
    }
    
    static func getParentCategories(from allCategories: [SpendingCategory]) -> [SpendingCategory] {
        return allCategories
            .filter { $0.level == .parent }
            .sorted { $0.sortOrder < $1.sortOrder }
    }
}

