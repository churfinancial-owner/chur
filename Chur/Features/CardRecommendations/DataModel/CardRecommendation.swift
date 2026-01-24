//
//  CardRecommendation.swift
//  Chur
//
//  Created by Pak Ho on 1/29/26.
//
// Score: Strategy Match  How well the card fits the user's "Financial Aura"
// Synergy   If the card pairs well with cards the user already owns.
// Priority    Editorial "importance" set by the app creators.
// SUB Value    The raw numeric value of the Sign-Up Bonus.
// Diversity     Encourages getting cards from different issuers.
// Bonus Rating    How good the current bonus is vs. history (All-time high, etc).
//

import Foundation
import SwiftUI

// MARK: - Bonus Rating

/// How strong the current sign-up bonus offer is relative to historical norms.
enum BonusRating: String, Codable {
    case best = "best"
    case great = "great"
    case good = "good"
    
    var displayText: String {
        switch self {
        case .best: return "⭐️⭐️⭐️"
        case .great: return "⭐️⭐️"
        case .good: return "⭐️"
        }
    }
    
    
    var textColor: Color {
        switch self {
        case .best: return .black
        case .great: return .brown
        case .good: return Color.churOlive
        }
    }
    
    var backgroundColor: Color {
        switch self {
        case .best: return Color.red.opacity(0.5)
        case .great: return Color.yellow.opacity(0.5)
        case .good: return Color.churOlive.opacity(0.12)
        }
    }
}

// MARK: - Recommendation Template (loaded from JSON)

/// A curated card recommendation entry loaded from bundle JSON.
/// Links to CardDatabase via `cardTemplateID` for full card details.
struct RecommendationTemplate: Codable, Identifiable {
    let cardTemplateID: String
    let affiliateURL: String
    let signUpBonus: String               // "60,000 points after $4,000 spend in 3 months"
    let signUpBonusValue: Int             // 750 (numeric, for sorting)
    let bonusRating: BonusRating?         // "best", "great", "good", or null
    let expirationDate: String?           // ISO 8601 date (e.g. "2026-06-30"), auto-filter expired
    let annualFeeWaived: Bool?            // First year annual fee waived
    let requiredCreditScore: String?      // "excellent", "good", "fair"
    let strategyTags: [String]            // ["jetsetter", "foodie"] — matches FinancialStrategy.rawValue
    let categories: [String]              // ["travel", "dining"] — what the card fundamentally IS
    let categoryHighlights: [String: String] // Punchline per category + "default" fallback
    let complementaryCardIDs: [String]    // Cards this pairs well with (boost score if user owns any)
    let avoidWithCardIDs: [String]        // Cards that conflict (exclude if user owns any)
    let highlights: [String]              // Short bullet points for "Why this card"
    let priority: Int                     // Editorial base priority (1 = highest)
    let isActive: Bool
    
    var id: String { cardTemplateID }
    
    /// Check if this recommendation has expired
    var isExpired: Bool {
        guard let expirationDate else { return false }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        guard let date = formatter.date(from: expirationDate) else { return false }
        return date < Date()
    }
}

// MARK: - Scored Recommendation (computed output)

/// A recommendation that has been scored against the user's profile.
/// This is the type consumed by views.
struct ScoredRecommendation: Identifiable {
    let template: RecommendationTemplate
    let cardTemplate: CardTemplate?       // Resolved from CardDatabase
    let score: Double                     // Composite score (higher = better)
    let reasonTags: [String]              // e.g. ["Matches your Jetsetter style", "Pairs with your Sapphire Reserve"]
    let bestCategoryHighlight: String     // The most relevant punchline for this user
    let matchedCategory: String?          // Which category was matched (for display styling)
    
    var id: String { template.cardTemplateID }
    
    // Convenience accessors pulling from CardTemplate (with fallbacks)
    var cardName: String { cardTemplate?.name ?? template.cardTemplateID }
    var issuer: String { cardTemplate?.issuer ?? "" }
    var imageName: String { cardTemplate?.imageName ?? "" }
    var annualFee: Int { cardTemplate?.annualFee ?? 0 }
    var network: String { cardTemplate?.network ?? "" }
    
    /// Top earning category IDs from the card's default reward plan.
    /// Sorted by rate descending, "everything" excluded, deduplicated, max 3.
    var topCategoryIDs: [String] {
        guard let cardTemplate else { return [] }
        
        // Find the default plan (or first available)
        let plan = cardTemplate.rewardPlans.first { $0.isDefault }
            ?? cardTemplate.rewardPlans.first
        guard let rewards = plan?.rewards else { return [] }
        
        // Sort by rate descending, collect unique parent categories
        var seen = Set<String>()
        var result: [String] = []
        
        for reward in rewards.sorted(by: { $0.rate > $1.rate }) {
            guard let categories = reward.categories else { continue }
            for cat in categories {
                guard cat != "everything" else { continue }
                if seen.insert(cat).inserted {
                    result.append(cat)
                    if result.count >= 3 { return result }
                }
            }
        }
        
        return result
    }
    
    /// Resolve top category IDs to their emojis using SpendingCategory data.
    func topCategoryEmojis(from allCategories: [SpendingCategory]) -> [String] {
        topCategoryIDs.compactMap { categoryID in
            allCategories.first(where: { $0.id == categoryID })?.emoji
        }
    }
    
    /// Top earning categories with their rate and emoji, for badge display.
    /// Returns (emoji, rateLabel, categoryName) tuples, max 3, sorted by rate descending.
    func topCategoryRates(from allCategories: [SpendingCategory]) -> [(emoji: String, rateLabel: String, name: String)] {
        guard let cardTemplate else { return [] }
        
        let plan = cardTemplate.rewardPlans.first { $0.isDefault }
            ?? cardTemplate.rewardPlans.first
        guard let rewards = plan?.rewards else { return [] }
        
        var seen = Set<String>()
        var result: [(emoji: String, rateLabel: String, name: String)] = []
        
        for reward in rewards.sorted(by: { $0.rate > $1.rate }) {
            guard let categories = reward.categories else { continue }
            for cat in categories {
                guard cat != "everything" else { continue }
                guard seen.insert(cat).inserted else { continue }
                
                if let spendCat = allCategories.first(where: { $0.id == cat }) {
                    let rateLabel = reward.rate.truncatingRemainder(dividingBy: 1) == 0
                        ? "\(Int(reward.rate))x"
                        : String(format: "%.1fx", reward.rate)
                    result.append((emoji: spendCat.emoji, rateLabel: rateLabel, name: spendCat.displayName))
                }
                if result.count >= 3 { return result }
            }
        }
        
        return result
    }
}

// MARK: - Card Recommendation Engine

/// Stateless scoring engine that computes personalized card recommendations.
/// All inputs are passed in — no global state dependency.
struct CardRecommendationEngine {
    
    // MARK: - Weights
    
    private static let weightStrategy: Double = 0.45
    private static let weightSynergy: Double = 0.15
    private static let weightPriority: Double = 0.15
    private static let weightSUB: Double = 0.10
    private static let weightDiversity: Double = 0.5
    private static let weightBonusRating: Double = 0.10
    
    // MARK: - Public API
    
    /// Compute personalized recommendations for the user.
    /// - Parameters:
    ///   - allTemplates: All recommendation templates loaded from JSON
    ///   - userCards: User's current card holdings (from SwiftData)
    ///   - userStrategies: User's selected Financial Aura tags (e.g. ["jetsetter", "foodie"])
    ///   - userCountry: User's region code (e.g. "US", "HK")
    ///   - limit: Max number of recommendations to return
    /// - Returns: Scored and sorted recommendations, best first
    static func recommend(
        allTemplates: [RecommendationTemplate],
        userCards: [CreditCard],
        userStrategies: [String],
        userCountry: String,
        limit: Int = 5
    ) -> [ScoredRecommendation] {
        
        let ownedTemplateIDs = Set(userCards.compactMap { $0.templateID })
        let ownedIssuers = Set(userCards.map { $0.issuer })
        
        // Build user's card categories from their strategies
        let userCategories = Set(
            userStrategies.compactMap { FinancialStrategy(rawValue: $0)?.cardCategory }
        )
        
        // Step 1: Filter
        let candidates = allTemplates.filter { template in
            // Must be active
            guard template.isActive else { return false }
            
            // Must not be expired
            guard !template.isExpired else { return false }
            
            // Must not already own this card
            guard !ownedTemplateIDs.contains(template.cardTemplateID) else { return false }
            
            // Must not conflict with owned cards
            let hasConflict = template.avoidWithCardIDs.contains { ownedTemplateIDs.contains($0) }
            guard !hasConflict else { return false }
            
            // Card must exist in CardDatabase and match user's country
            guard let cardTemplate = CardDatabase.getCard(id: template.cardTemplateID) else { return false }
            guard cardTemplate.country == userCountry else { return false }
            
            return true
        }
        
        guard !candidates.isEmpty else { return [] }
        
        // Pre-compute normalization values
        let maxSUB = Double(candidates.map { $0.signUpBonusValue }.max() ?? 1)
        let maxPriority = Double(candidates.map { $0.priority }.max() ?? 1)
        
        // Step 2: Score
        let scored = candidates.compactMap { template -> ScoredRecommendation? in
            guard let cardTemplate = CardDatabase.getCard(id: template.cardTemplateID) else { return nil }
            
            var reasons: [String] = []
            
            // Factor 1: Strategy match
            let strategyScore: Double
            if userStrategies.isEmpty {
                strategyScore = 0.0
            } else {
                let matchCount = template.strategyTags.filter { userStrategies.contains($0) }.count
                strategyScore = Double(matchCount) / Double(userStrategies.count)
                
                if matchCount > 0 {
                    let matchedNames = template.strategyTags
                        .filter { userStrategies.contains($0) }
                        .compactMap { FinancialStrategy(rawValue: $0)?.displayName }
                    if let first = matchedNames.first {
                        reasons.append("Matches your \(first) style")
                    }
                }
            }
            
            // Factor 2: Complementary synergy
            let synergyScore: Double
            if template.complementaryCardIDs.isEmpty {
                synergyScore = 0.0
            } else {
                let matchCount = template.complementaryCardIDs.filter { ownedTemplateIDs.contains($0) }.count
                synergyScore = Double(matchCount) / Double(template.complementaryCardIDs.count)
                
                if matchCount > 0 {
                    if let matchedID = template.complementaryCardIDs.first(where: { ownedTemplateIDs.contains($0) }),
                       let matchedCard = userCards.first(where: { $0.templateID == matchedID }) {
                        reasons.append("Pairs with your \(matchedCard.name)")
                    }
                }
            }
            
            // Factor 3: Editorial priority (inverted — lower priority number = higher score)
            let priorityScore = maxPriority > 0 ? 1.0 - (Double(template.priority - 1) / maxPriority) : 0.5
            
            // Factor 4: Sign-up bonus value (normalized)
            let subScore = maxSUB > 0 ? Double(template.signUpBonusValue) / maxSUB : 0.0
            if template.signUpBonusValue > 0 {
                reasons.append("\(template.signUpBonus)")
            }
            
            // Factor 5: Issuer diversity
            let diversityScore: Double = ownedIssuers.contains(cardTemplate.issuer) ? 0.0 : 1.0
            if diversityScore > 0 {
                reasons.append("Adds \(cardTemplate.issuer) to your wallet")
            }
            
            // Factor 6: Bonus rating
            let bonusRatingScore: Double
            switch template.bonusRating {
            case .best:
                bonusRatingScore = 1.0
                reasons.append("All-time high bonus")
            case .great:
                bonusRatingScore = 0.7
            case .good:
                bonusRatingScore = 0.4
            case nil:
                bonusRatingScore = 0.0
            }
            
            // Composite score
            let totalScore =
                strategyScore * weightStrategy +
                synergyScore * weightSynergy +
                priorityScore * weightPriority +
                subScore * weightSUB +
                diversityScore * weightDiversity +
                bonusRatingScore * weightBonusRating
            
            // Resolve best category highlight for this user
            let (highlight, matched) = resolveCategoryHighlight(
                template: template,
                userCategories: userCategories
            )
            
            return ScoredRecommendation(
                template: template,
                cardTemplate: cardTemplate,
                score: totalScore,
                reasonTags: reasons,
                bestCategoryHighlight: highlight,
                matchedCategory: matched
            )
        }
        
        // Step 3: Sort & limit
        return scored
            .sorted { $0.score > $1.score }
            .prefix(limit)
            .map { $0 }
    }
    
    // MARK: - Category Highlight Resolution
    
    /// Pick the best category punchline based on user's Financial Aura.
    /// 1. Find the first category that overlaps between the card's categories and the user's strategy-derived categories
    /// 2. If a matching categoryHighlight exists, use it
    /// 3. Otherwise fall back to "default"
    /// 4. If no "default", use the first available highlight
    private static func resolveCategoryHighlight(
        template: RecommendationTemplate,
        userCategories: Set<String>
    ) -> (highlight: String, matchedCategory: String?) {
        // Try to find a category that matches the user's strategies
        for category in template.categories {
            if userCategories.contains(category),
               let highlight = template.categoryHighlights[category] {
                return (highlight, category)
            }
        }
        
        // Fall back to "default" punchline
        if let defaultHighlight = template.categoryHighlights["default"] {
            return (defaultHighlight, nil)
        }
        
        // Last resort: first available highlight value
        if let firstHighlight = template.categoryHighlights.values.first {
            return (firstHighlight, template.categories.first)
        }
        
        return ("", nil)
    }
}
