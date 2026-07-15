//
//  Nearby_Engine.swift
//  Chur
//
//  NearbyRecommendationEngine.swift contains:
//  - NearbyMerchant: Model for nearby places with name, category, location, distance, and optional region
//  - NearbyRecommendation: Result model with merchant, best card match, earning value, and display string
//  - NearbyRecommendationEngine: Core engine that matches merchants to best credit cards using CardRateCalculator with region-aware filtering
//  - Display formatting: Converts rates to user-friendly strings (e.g., "5x", "3% back")
//
//  Key feature: Always returns recommendations even when no card matches, ensuring UI consistency.
//
//
//  Created by Pak Ho on 1/29/26.
//

import Foundation
import CoreLocation

// MARK: - Nearby Merchant Model
struct NearbyMerchant: Identifiable, Equatable {
    let id: String
    let name: String              // "McDonald's"
    let categoryID: String        // Maps to SpendingCategory.id like "dining"
    let latitude: Double
    let longitude: Double
    let distance: Double          // miles from user
    let address: String
    let region: String?           // Region code (e.g., "US", "TW", "HK") - nil if unknown
    let poiCategory: String?      // Raw MapKit POI category (e.g., "MKPOICategoryRestaurant") - for debugging
    let paymentMethods: Set<String>? // Accepted payment methods for online merchants — nil = no restriction
    /// All regions where this merchant operates. nil = global (no FX fee for any card).
    /// For online merchants, populated from OnlineMerchant.businessRegion.
    /// For map merchants, nil (single region handled by `region`).
    let acceptedRegions: Set<String>?

    init(
        id: String, name: String, categoryID: String,
        latitude: Double, longitude: Double, distance: Double,
        address: String, region: String?, poiCategory: String?,
        paymentMethods: Set<String>?, acceptedRegions: Set<String>? = nil
    ) {
        self.id = id; self.name = name; self.categoryID = categoryID
        self.latitude = latitude; self.longitude = longitude; self.distance = distance
        self.address = address; self.region = region; self.poiCategory = poiCategory
        self.paymentMethods = paymentMethods; self.acceptedRegions = acceptedRegions
    }
}

// MARK: - Nearby Recommendation
struct NearbyRecommendation: Identifiable {
    let id: String
    let merchant: NearbyMerchant
    let card: CreditCard?         // The actual card object for image/issuer (nil if no match)
    let bestCard: CardRateSummary? // Summary for display info (nil if no match)
    let valueFor50: Double        // e.g. $2.50 value on $50 spend
    let pointsDisplay: String     // "5x points" or "5% back" or "No card matches"
    let hasMatch: Bool            // Whether a card was found for this merchant
}

// MARK: - Nearby Recommendation Engine
struct NearbyRecommendationEngine {
    let cards: [CreditCard]
    let allCategories: [SpendingCategory]
    let boostEnrollments: [String: String]
    
    /// Generate a recommendation for a specific merchant
    /// Always returns a recommendation, even if no card matches
    /// `categoryMaps` lets batch callers (`recommendAll`) share one precomputed
    /// category-ancestor map across merchants instead of rebuilding it each call.
    func recommend(for merchant: NearbyMerchant, categoryMaps: CardRateCalculator.CategoryMaps? = nil) -> NearbyRecommendation {
        // 1. Find the spending category that matches this merchant
        guard let category = allCategories.first(where: { $0.id == merchant.categoryID }) else {
            // No category match - return recommendation with no card
            #if DEBUG
            print("⚠️ No category found for merchant '\(merchant.name)' with categoryID '\(merchant.categoryID)'")
            #endif
            return NearbyRecommendation(
                id: merchant.id,
                merchant: merchant,
                card: nil,
                bestCard: nil,
                valueFor50: 0,
                pointsDisplay: "Category not found",
                hasMatch: false
            )
        }
        
        // 2. Use existing CardRateCalculator to find best card
        let calculator = CardRateCalculator(
            cards: cards,
            category: category,
            rate: 1.0,
            allCategories: allCategories,
            boostEnrollments: boostEnrollments,
            region: merchant.region,
            channel: "in_store",
            acceptedRegions: merchant.acceptedRegions,
            categoryMaps: categoryMaps
        )
        
        #if DEBUG
        // Debug logging to understand category matching
        print("🔍 Merchant: \(merchant.name)")
        print("   Category: \(category.id) (parent: \(category.parentCategoryID ?? "none"))")
        print("   Cards checked: \(cards.count)")
        if let bestCard = calculator.bestCard {
            print("   ✅ Best card: \(bestCard.name) @ \(bestCard.effectiveRateDisplayString)")
        } else {
            print("   ❌ No matching card found")
            // Check if any cards have rewards for the parent category
            if let parentID = category.parentCategoryID {
                let parentCards = cards.filter { card in
                    card.activeRewards.contains { reward in
                        reward.categories?.contains(parentID) == true
                    }
                }
                print("   📊 Cards with parent '\(parentID)' rewards: \(parentCards.map { $0.name })")
            }
        }
        #endif
        
        guard let bestCard = calculator.bestCard else {
            // No card match for this category - return recommendation anyway
            return NearbyRecommendation(
                id: merchant.id,
                merchant: merchant,
                card: nil,
                bestCard: nil,
                valueFor50: 0,
                pointsDisplay: "❓",
                hasMatch: false
            )
        }
        
        // 3. Find the actual CreditCard object that matches the best card name
        guard let actualCard = cards.first(where: { $0.name == bestCard.name }) else {
            // Shouldn't happen, but handle gracefully
            return NearbyRecommendation(
                id: merchant.id,
                merchant: merchant,
                card: nil,
                bestCard: bestCard,
                valueFor50: 0,
                pointsDisplay: "Card not found",
                hasMatch: false
            )
        }
        
        // 4. Calculate value for $50 spend
        let valueFor50 = bestCard.effectiveCashBackRate * 50
        
        // 5. Format display string (e.g. "5x points" or "5% back")
        let pointsDisplay = formatPointsDisplay(
            rate: bestCard.rate,
            effectiveRate: bestCard.effectiveCashBackRate
        )
        
        return NearbyRecommendation(
            id: merchant.id,
            merchant: merchant,
            card: actualCard,
            bestCard: bestCard,
            valueFor50: valueFor50,
            pointsDisplay: pointsDisplay,
            hasMatch: true
        )
    }
    
    /// Generate recommendations for multiple merchants (in-store / nearby)
    func recommendAll(for merchants: [NearbyMerchant]) -> [NearbyRecommendation] {
        let categoryMaps = CardRateCalculator.CategoryMaps(allCategories: allCategories)
        return merchants.map { recommend(for: $0, categoryMaps: categoryMaps) }
    }

    /// Generate recommendations for online merchants.
    /// Uses `channel: "online"` so channel-restricted rewards (e.g. PayPal online-only) are included.
    func recommendAllOnline(for merchants: [NearbyMerchant]) -> [NearbyRecommendation] {
        let categoryMaps = CardRateCalculator.CategoryMaps(allCategories: allCategories)
        return merchants.map { recommendOnline(for: $0, categoryMaps: categoryMaps) }
    }

    /// Recommend for an online merchant — identical to `recommend(for:)` but with channel = "online"
    private func recommendOnline(for merchant: NearbyMerchant, categoryMaps: CardRateCalculator.CategoryMaps? = nil) -> NearbyRecommendation {
        guard let category = allCategories.first(where: { $0.id == merchant.categoryID }) else {
            return NearbyRecommendation(
                id: merchant.id,
                merchant: merchant,
                card: nil,
                bestCard: nil,
                valueFor50: 0,
                pointsDisplay: "Category not found",
                hasMatch: false
            )
        }
        
        let calculator = CardRateCalculator(
            cards: cards,
            category: category,
            rate: 1.0,
            allCategories: allCategories,
            boostEnrollments: boostEnrollments,
            region: merchant.region,
            channel: "online",
            // Online merchants require explicit declaration to earn payment-method rewards.
            // nil paymentMethods → empty set (no PM rewards), vs in-store where nil = no restriction.
            acceptedPaymentMethods: merchant.paymentMethods ?? Set<String>(),
            acceptedRegions: merchant.acceptedRegions,
            categoryMaps: categoryMaps
        )
        
        guard let bestCard = calculator.bestCard else {
            return NearbyRecommendation(
                id: merchant.id,
                merchant: merchant,
                card: nil,
                bestCard: nil,
                valueFor50: 0,
                pointsDisplay: "❓",
                hasMatch: false
            )
        }
        
        guard let actualCard = cards.first(where: { $0.name == bestCard.name }) else {
            return NearbyRecommendation(
                id: merchant.id,
                merchant: merchant,
                card: nil,
                bestCard: bestCard,
                valueFor50: 0,
                pointsDisplay: "Card not found",
                hasMatch: false
            )
        }
        
        let valueFor50 = bestCard.effectiveCashBackRate * 50
        let pointsDisplay = formatPointsDisplay(
            rate: bestCard.rate,
            effectiveRate: bestCard.effectiveCashBackRate
        )
        
        return NearbyRecommendation(
            id: merchant.id,
            merchant: merchant,
            card: actualCard,
            bestCard: bestCard,
            valueFor50: valueFor50,
            pointsDisplay: pointsDisplay,
            hasMatch: true
        )
    }
    
    // MARK: - Helper Methods
    
    /// Format the points/cashback display string based on card's advertised rate
    /// Shows what users see on their card (e.g., "3x", "1.5x", "2x")
    /// Always uses multiplier format (Nx) for consistency across all cards
    private func formatPointsDisplay(rate: Double, effectiveRate: Double) -> String {
        if rate == floor(rate) {
            return "\(Int(rate))x"
        }
        
        if (rate * 10).truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.1fx", rate)
        }
        
        return String(format: "%.2fx", rate)
    }
}

