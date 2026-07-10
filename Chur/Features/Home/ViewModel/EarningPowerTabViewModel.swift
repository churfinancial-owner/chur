//
//  EarningPowerTabViewModel.swift
//  Chur
//
//  Created by Pak Ho on 3/18/26.
//

import SwiftUI
import SwiftData

@Observable
class EarningPowerViewModel {
    var user: User
    var cards: [CreditCard]
    var categories: [SpendingCategory]
    var currentRegionCodeOverride: String?
    
    init(user: User, cards: [CreditCard], categories: [SpendingCategory], currentRegionCodeOverride: String? = nil) {
        self.user = user
        self.cards = cards
        self.categories = categories
        self.currentRegionCodeOverride = currentRegionCodeOverride
    }

    // MARK: - Region Logic
    var homeRegionCode: String? {
        RegionDatabase.normalizeRegionCode(user.country)
    }

    var currentRegionCode: String? {
        RegionDatabase.normalizeRegionCode(currentRegionCodeOverride ?? Locale.current.region?.identifier)
    }

    var isAwayFromHomeRegion: Bool {
        guard let home = homeRegionCode, let current = currentRegionCode else { return false }
        return home != current
    }

    var effectiveTravelModeEnabled: Bool {
        user.earningPowerTravelModeEnabled && isAwayFromHomeRegion
    }

    // MARK: - Category Logic
    var availableCategoryIDs: Set<String> {
        var available = Set<String>()
        for card in cards {
            for reward in card.activeRewards {
                reward.categories?.forEach { available.insert($0) }
            }
        }

        for category in categories where available.contains(category.id) && category.level == .child {
            if let parentID = category.parentCategoryID { available.insert(parentID) }
            category.categoryLinks?.forEach { available.insert($0.id) }
        }

        for category in categories where category.level == .parent && available.contains(category.id) {
            available.insert(category.id)
        }
        return available
    }

    var directlyRewardedCategoryIDs: Set<String> {
        Set(cards.flatMap { $0.activeRewards }.compactMap { $0.categories }.flatMap { $0 })
    }

    var selectedCategories: [SpendingCategory] {
        let selectedIDs = Set(user.selectedCategories)
        let inferredParentIDs = Set(categories.filter { selectedIDs.contains($0.id) && $0.level == .child }.compactMap(\.parentCategoryID))
        let explicitParentIDs = Set(categories.filter { selectedIDs.contains($0.id) && $0.level == .parent }.map(\.id))
        
        let parentIDsToShow = explicitParentIDs.union(inferredParentIDs)

        return categories
            .filter { parentIDsToShow.contains($0.id) && $0.level == .parent && $0.visibility?.lowercased() != "hidden" }
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    // MARK: - Cached Rate Results
    /// Pre-computed best card results keyed by category ID.
    /// Call `rebuildRateCache()` when inputs change (cards, categories, boostEnrollments, travel mode).
    private(set) var cachedRates: [String: CardRateSummary] = [:]

    func rebuildRateCache() {
        var results: [String: CardRateSummary] = [:]
        let crossBorder = effectiveTravelModeEnabled
        let enrollments = user.boostEnrollments
        let effectiveRegion = crossBorder ? currentRegionCode : homeRegionCode

        for category in selectedCategories {
            let calc = CardRateCalculator(
                cards: cards,
                category: category,
                rate: 0,
                allCategories: categories,
                boostEnrollments: enrollments,
                region: effectiveRegion,
                channel: nil,
                allowPaymentMethodFallback: false,
                forceCrossBorder: crossBorder
            )
            if let best = calc.bestCard {
                results[category.id] = best
            }
        }
        cachedRates = results
    }

    /// Returns the cached best card summary for a category, or nil if not pre-computed.
    func bestCard(for categoryID: String) -> CardRateSummary? {
        cachedRates[categoryID]
    }

    // MARK: - Calculator for on-demand use (popups, child categories)
    func calculator(for category: SpendingCategory) -> CardRateCalculator {
        let crossBorder = effectiveTravelModeEnabled
        return CardRateCalculator(
            cards: cards,
            category: category,
            rate: 0,
            allCategories: categories,
            boostEnrollments: user.boostEnrollments,
            region: crossBorder ? currentRegionCode : homeRegionCode,
            channel: nil,
            allowPaymentMethodFallback: false,
            forceCrossBorder: crossBorder
        )
    }

    func categoryRows() -> [[SpendingCategory]] {
        let cats = selectedCategories
        var rows: [[SpendingCategory]] = []
        for i in stride(from: 0, to: cats.count, by: 2) {
            let end = min(i + 2, cats.count)
            rows.append(Array(cats[i..<end]))
        }
        return rows
    }
}
