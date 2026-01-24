//
//  MerchantDetailSheet_ViewModel.swift
//  Chur
//
//  Created by Pak Ho on 3/30/26.
//

import SwiftUI
import SwiftData
import Observation

@Observable
class MerchantDetailViewModel {
    let merchant: NearbyMerchant
    let category: SpendingCategory
    let cards: [CreditCard]
    let allCategories: [SpendingCategory]
    let boostEnrollments: [String: String]
    let channel: String
    
    // Pre-computed results (all inputs are immutable, so compute once)
    let bestCardSummary: CardRateSummary?
    let otherCardRates: [CardRateSummary]
    let merchantIconName: String?
    let categoryBubbleLabel: String?
    
    init(merchant: NearbyMerchant, category: SpendingCategory, cards: [CreditCard], allCategories: [SpendingCategory], boostEnrollments: [String: String], channel: String = "in_store") {
        self.merchant = merchant
        self.category = category
        self.cards = cards
        self.allCategories = allCategories
        self.boostEnrollments = boostEnrollments
        self.channel = channel
        
        // Compute calculator once
        let calculator = CardRateCalculator(
            cards: cards,
            category: category,
            rate: 1.0,
            allCategories: allCategories,
            boostEnrollments: boostEnrollments,
            region: merchant.region,
            channel: channel,
            // Online merchants require explicit paymentMethods declaration; nil → empty set (no PM rewards).
            // In-store merchants keep nil = no restriction.
            acceptedPaymentMethods: channel == "online" ? (merchant.paymentMethods ?? Set<String>()) : merchant.paymentMethods
        )
        
        self.bestCardSummary = calculator.bestCard
        
        let bestName = calculator.bestCard?.name
        self.otherCardRates = calculator.rankedCardSummaries
            .filter { $0.name != bestName }
            .prefix(5)
            .map { $0 }
        
        self.merchantIconName = OnlineMerchantDatabase.allMerchants.first(where: { $0.id == merchant.id })?.merchantIconName
            ?? OnlineMerchantDatabase.merchant(forCategory: merchant.categoryID)?.merchantIconName
        
        // Category bubble label: show parent if category name is redundant with merchant name
        let merchantLower = merchant.name.lowercased()
        let categoryLower = category.displayName.lowercased()
        let isRedundant = merchantLower.contains(categoryLower) || categoryLower.contains(merchantLower)
        
        if isRedundant, let parentID = category.parentCategoryID,
           let parent = allCategories.first(where: { $0.id == parentID }) {
            self.categoryBubbleLabel = parent.displayName
        } else if isRedundant {
            self.categoryBubbleLabel = nil
        } else {
            self.categoryBubbleLabel = category.displayName
        }
    }
    
    func formatRate(for summary: CardRateSummary, showEffectiveRate: Bool) -> String {
        if showEffectiveRate {
            return summary.effectiveRateDisplayString
        }
        let rate = summary.rate
        if rate == floor(rate) { return "\(Int(rate))x" }
        return String(format: (rate * 10).truncatingRemainder(dividingBy: 1) == 0 ? "%.1fx" : "%.2fx", rate)
    }
}
