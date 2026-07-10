//
//  Badge.swift
//  Chur
//
//  Created by Pak Ho on 2/2/26.
//

import Foundation
import SwiftUI

// MARK: - Badge Model
struct Badge: Codable, Identifiable, Hashable {
    let id: String
    let nameEN: String
    let nameZH_Hans: String
    let nameZH_HK: String
    let nameZH_TW: String
    let emoji: String
    let icon: String?
    let category: BadgeCategory
    let sortOrder: Int
    let descriptionEN: String
    let descriptionZH_Hans: String
    let descriptionZH_HK: String
    let descriptionZH_TW: String
    let hasTiers: Bool
    let detectionRules: [BadgeRule]
    
    var displayName: String {
        switch localePriority {
        case "HK": return nameZH_HK
        case "TW": return nameZH_TW
        case "zh": return nameZH_Hans
        default:   return nameEN
        }
    }

    var displayDescription: String {
        switch localePriority {
        case "HK": return descriptionZH_HK
        case "TW": return descriptionZH_TW
        case "zh": return descriptionZH_Hans
        default:   return descriptionEN
        }
    }

    private var localePriority: String {
        guard Locale.current.language.languageCode?.identifier == "zh" else { return "en" }
        return Locale.current.region?.identifier ?? "zh"
    }
    
    // Use icon if available, fallback to emoji
    var displayIcon: String {
        return icon ?? emoji
    }
}

// MARK: - Badge Category
enum BadgeCategory: String, Codable {
    case lifestyle = "lifestyle"
    case travelAccess = "travel_access"
    case protections = "protections"
    
    var displayName: String {
        switch self {
        case .lifestyle:
            return "Lifestyle"
        case .travelAccess:
            return "Travel"
        case .protections:
            return "Protections"
        }
    }
}

// MARK: - Badge Detection Rule
struct BadgeRule: Codable, Hashable {
    let type: RuleType
    let value: String
    
    enum RuleType: String, Codable {
        case benefitNameContains = "benefit_name_contains"
        case benefitIDEquals = "benefit_id_equals"
        case issuerEquals = "issuer_equals"
        case cardHasRewardCategory = "card_has_reward_category"
        case hasAnyCard = "has_any_card"
        case benefitTypeCount = "benefit_type_count"
        case cardIdInSeedFile = "card_id_in_seed_file"
    }
}

// MARK: - Badge Tier
enum BadgeTier: Int {
    case locked = 0
    case tier1 = 1
    case tier2 = 2
    case tier3 = 3
    
    var displayName: String {
        switch self {
        case .locked:
            return "Locked"
        case .tier1:
            return "I"
        case .tier2:
            return "II"
        case .tier3:
            return "III"
        }
    }
    
    var color: Color {
        switch self {
        case .locked: return .churLightGray
        case .tier1:  return .churTierBronze
        case .tier2:  return .churTierSilver
        case .tier3:  return .churTierGold
        }
    }
    
    var opacity: Double {
        switch self {
        case .locked:
            return 0.2
        case .tier1:
            return 0.15
        case .tier2:
            return 0.20
        case .tier3:
            return 0.25
        }
    }
}

// MARK: - Badge Status
struct BadgeStatus {
    let badge: Badge
    let tier: BadgeTier
    let matchedRulesCount: Int
    
    var isUnlocked: Bool {
        tier != .locked
    }
}

// MARK: - Badge Detector
struct BadgeDetector {
    /// Check badge status including tier level
    static func getBadgeStatus(badge: Badge, cards: [CreditCard]) -> BadgeStatus {
        // Empty cards = locked
        guard !cards.isEmpty else {
            return BadgeStatus(badge: badge, tier: .locked, matchedRulesCount: 0)
        }
        
        // If no rules defined, badge is unlocked at tier 1 (if user has cards)
        guard !badge.detectionRules.isEmpty else {
            return BadgeStatus(badge: badge, tier: .tier1, matchedRulesCount: 1)
        }
        
        // Check for benefit_type_count rules — these use count-based tier determination
        if let countRule = badge.detectionRules.first(where: { $0.type == .benefitTypeCount }) {
            let count = countBenefitsByType(type: countRule.value, cards: cards)
            let tier = determineTierByCount(count: count)
            return BadgeStatus(badge: badge, tier: tier, matchedRulesCount: count)
        }
        
        // Check for card_id_in_seed_file rules — match card templateIDs against a seed JSON file
        if let seedFileRule = badge.detectionRules.first(where: { $0.type == .cardIdInSeedFile }) {
            let count = countCardsInSeedFile(fileName: seedFileRule.value, cards: cards)
            let tier = determineSeedFileTier(fileName: seedFileRule.value, cards: cards, hasTiers: badge.hasTiers)
            return BadgeStatus(badge: badge, tier: tier, matchedRulesCount: count)
        }
        
        // Count how many rules match
        let matchedCount = badge.detectionRules.filter { rule in
            checkRule(rule: rule, cards: cards)
        }.count
        
        // Determine tier based on matched rules
        let tier = determineTier(matchedCount: matchedCount, hasTiers: badge.hasTiers)
        
        return BadgeStatus(badge: badge, tier: tier, matchedRulesCount: matchedCount)
    }
    
    /// Legacy method for backwards compatibility
    static func isUnlocked(badge: Badge, cards: [CreditCard]) -> Bool {
        let status = getBadgeStatus(badge: badge, cards: cards)
        return status.isUnlocked
    }
    
    /// Determine tier based on matched rules count
    private static func determineTier(matchedCount: Int, hasTiers: Bool) -> BadgeTier {
        guard matchedCount > 0 else { return .locked }
        
        // If badge doesn't have tiers, just return tier1 when unlocked
        guard hasTiers else {
            return .tier1
        }
        
        // Tier system: 1 match = tier1, 2 matches = tier2, 3+ matches = tier3
        switch matchedCount {
        case 1:
            return .tier1
        case 2:
            return .tier2
        case 3...:
            return .tier3
        default:
            return .locked
        }
    }
    
    /// Count benefits across all cards matching a given benefitType
    private static func countBenefitsByType(type: String, cards: [CreditCard]) -> Int {
        cards.reduce(0) { total, card in
            total + card.benefits.filter { $0.benefitType.lowercased() == type.lowercased() }.count
        }
    }
    
    /// Determine tier based on total count (1-5 = tier1, 6-10 = tier2, 11+ = tier3)
    private static func determineTierByCount(count: Int) -> BadgeTier {
        switch count {
        case 0:
            return .locked
        case 1...5:
            return .tier1
        case 6...10:
            return .tier2
        case 11...:
            return .tier3
        default:
            return .locked
        }
    }
    
    /// Check if a specific rule is satisfied
    private static func checkRule(rule: BadgeRule, cards: [CreditCard]) -> Bool {
        switch rule.type {
        case .benefitNameContains:
            return cards.contains { card in
                card.benefits.contains { (benefit: Benefit) in
                    // Check the display name (uses current locale)
                    if benefit.displayName.lowercased().contains(rule.value.lowercased()) {
                        return true
                    }
                    // Also check all localized names for broader matching
                    return benefit.localized.values.contains { localizedString in
                        localizedString.name.lowercased().contains(rule.value.lowercased())
                    }
                }
            }
            
        case .benefitIDEquals:
            return cards.contains { card in
                card.benefits.contains { (benefit: Benefit) in
                    benefit.id == rule.value
                }
            }
            
        case .issuerEquals:
            return cards.contains { card in
                card.issuer.lowercased() == rule.value.lowercased()
            }
            
        case .cardHasRewardCategory:
            return cards.contains { card in
                card.rewards.contains { reward in
                    reward.categories?.contains { $0.lowercased() == rule.value.lowercased() } ?? false
                }
            }
            
        case .hasAnyCard:
            return !cards.isEmpty
            
        case .benefitTypeCount:
            // Handled separately in getBadgeStatus; treat as matched if any exist
            return countBenefitsByType(type: rule.value, cards: cards) > 0
            
        case .cardIdInSeedFile:
            // Handled separately in getBadgeStatus; treat as matched if any exist
            return countCardsInSeedFile(fileName: rule.value, cards: cards) > 0
        }
    }
    
    // MARK: - Seed File Matching
    
    /// Count how many of the user's cards appear in a seed JSON file (matched by templateID)
    private static func countCardsInSeedFile(fileName: String, cards: [CreditCard]) -> Int {
        let cardIds = loadSeedFileCardIds(fileName: fileName)
        return cards.filter { card in
            guard let templateID = card.templateID else { return false }
            return cardIds.contains(templateID)
        }.count
    }
    
    /// Determine tier using full seed file entries (supports coverageType-aware logic)
    private static func determineSeedFileTier(fileName: String, cards: [CreditCard], hasTiers: Bool) -> BadgeTier {
        let entries = loadSeedFileEntries(fileName: fileName)
        guard !entries.isEmpty else { return .locked }
        
        let userTemplateIDs = Set(cards.compactMap { $0.templateID })
        let matched = entries.filter { $0.isEligible && userTemplateIDs.contains($0.cardId) }
        guard !matched.isEmpty else { return .locked }
        guard hasTiers else { return .tier1 }
        
        // If entries have coverageType, use primary/secondary tier logic
        let hasCoverageTypes = matched.contains { $0.coverageType != nil }
        if hasCoverageTypes {
            let primaryCount = matched.filter { $0.coverageType == "primary" }.count
            let totalCount = matched.count
            
            // Tier 3: 1 primary + additional cards
            if primaryCount >= 1 && totalCount >= 2 {
                return .tier3
            }
            // Tier 2: at least 1 primary
            if primaryCount >= 1 {
                return .tier2
            }
            // Tier 1: has secondary only
            return .tier1
        }
        
        // Default: simple count-based tiers (cell phone protection, etc.)
        return determineTier(matchedCount: matched.count, hasTiers: hasTiers)
    }
    
    /// Cache for seed file card IDs keyed by file name
    private static var seedFileCache: [String: Set<String>] = [:]
    
    /// Cache for full seed file entries keyed by file name
    private static var seedFileEntriesCache: [String: [SeedFileCardEntry]] = [:]
    
    private static func loadSeedFileCardIds(fileName: String) -> Set<String> {
        if let cached = seedFileCache[fileName] {
            return cached
        }
        let entries = loadSeedFileEntries(fileName: fileName)
        let ids = Set(entries.filter { $0.isEligible }.map { $0.cardId })
        seedFileCache[fileName] = ids
        return ids
    }
    
    private static func loadSeedFileEntries(fileName: String) -> [SeedFileCardEntry] {
        if let cached = seedFileEntriesCache[fileName] {
            return cached
        }
        guard let url = Bundle.main.url(forResource: fileName, withExtension: "json") else {
            return []
        }
        do {
            let data = try Data(contentsOf: url)
            let entries = try JSONDecoder().decode([SeedFileCardEntry].self, from: data)
            seedFileEntriesCache[fileName] = entries
            return entries
        } catch {
            return []
        }
    }
}

/// Lightweight model for decoding seed file entries used by card_id_in_seed_file rule.
/// Supports both "hasProtection" (cell phone) and "hasCoverage" (auto rental) field names.
private struct SeedFileCardEntry: Codable {
    let cardId: String
    let hasProtection: Bool?
    let hasCoverage: Bool?
    let coverageType: String?
    
    /// Returns true if any eligibility flag is set
    var isEligible: Bool {
        (hasProtection ?? false) || (hasCoverage ?? false)
    }
}
