//
//  CardRateCalculator.swift
//  Chur
//
//  Created by Pak Ho on 1/26/26.
//

import Foundation

// MARK: - Card Rate Calculator
struct CardRateCalculator {
    let cards: [CreditCard]
    let category: SpendingCategory
    let rate: Double
    let allCategories: [SpendingCategory]
    private let categoryByID: [String: SpendingCategory]
    /// Pre-computed ancestor sets: category.id → all ancestor IDs via parentCategoryID chain.
    /// Eliminates fragile multi-hop walks — O(1) lookup in matchWeight step 5.
    private let ancestorsByCategoryID: [String: Set<String>]
    let boostEnrollments: [String: String]
    let region: String?  // Region code for location-based filtering (e.g., "US", "TW") - nil if not location-based
    let channel: String? // "in_store", "online", or nil (all channels) — used to filter rewards by channel
    let allowPaymentMethodFallback: Bool
    let forceCrossBorder: Bool
    let acceptedPaymentMethods: Set<String>? // If set, payment method rewards only apply for listed methods
    /// Regions where the merchant operates. nil = global (no FX fee for any card).
    /// Overrides single `region` for cross-border detection when set.
    let acceptedRegions: Set<String>?

    /// Pre-computed matching results with effective rates stored alongside.
    /// Computed once in init, read by all public properties.
    private let cachedMatchingRewards: [MatchedReward]

    /// A matched reward with its effective rate pre-computed.
    private struct MatchedReward {
        let card: CreditCard
        let reward: RewardRate
        let effectiveRate: Double
        let boost: Double
    }

    init(
        cards: [CreditCard],
        category: SpendingCategory,
        rate: Double,
        allCategories: [SpendingCategory],
        boostEnrollments: [String: String],
        region: String?,
        channel: String?,
        allowPaymentMethodFallback: Bool = true,
        forceCrossBorder: Bool = false,
        acceptedPaymentMethods: Set<String>? = nil,
        acceptedRegions: Set<String>? = nil
    ) {
        self.cards = cards
        self.category = category
        self.rate = rate
        self.allCategories = allCategories
        let builtCategoryByID = Dictionary(allCategories.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        self.categoryByID = builtCategoryByID
        self.ancestorsByCategoryID = Self.buildAncestorSets(categoryByID: builtCategoryByID)
        self.boostEnrollments = boostEnrollments
        self.region = region
        self.channel = channel
        self.allowPaymentMethodFallback = allowPaymentMethodFallback
        self.forceCrossBorder = forceCrossBorder
        self.acceptedPaymentMethods = acceptedPaymentMethods
        self.acceptedRegions = acceptedRegions

        // Eagerly compute all matching rewards once
        self.cachedMatchingRewards = Self.computeAllMatchingRewards(
            cards: cards,
            category: category,
            categoryByID: builtCategoryByID,
            ancestorsByCategoryID: self.ancestorsByCategoryID,
            boostEnrollments: boostEnrollments,
            region: region,
            channel: channel,
            allowPaymentMethodFallback: allowPaymentMethodFallback,
            forceCrossBorder: forceCrossBorder,
            acceptedPaymentMethods: acceptedPaymentMethods,
            acceptedRegions: acceptedRegions
        )
    }

    // MARK: - Payment method categories that apply as a near-universal fallback
    private static let paymentMethodCategories: Set<String> = ["mobile_pay", "apple_pay", "paypal_pay"]
    private static let channelAliases: [String: Set<String>] = [
        "in_store": ["in_store"],
        "online": ["online"]
    ]
    
    // MARK: - Category matching helper
    // Returns the effective weight for a reward category against the current category.
    // Matching priority:
    // 1. Exact match (category.id == rewardCategory) → 1.0
    // 2. Explicit categoryLinks (even if excludeFromParent is true) → 1.0 (weight ignored for matching)
    // 3. Payment method fallback (mobile_pay, apple_pay, paypal_pay) unless excluded by the category → 1.0
    //    Evaluated before excludeFromParent so brand categories (e.g. amazon) still get payment-method rewards.
    //    Note: rewards with channel restrictions (e.g. online-only) are filtered in allMatchingRewards
    // 4. If excludeFromParent → stop (except "everything")
    // 5. Parent chain via parentCategoryID → 1.0
    // 6. "everything" universal fallback (lowest priority, always matches) → 1.0
    // 7. No match → 0.0
    private static func matchWeight(
        rewardCategory: String,
        category: SpendingCategory,
        ancestorsByCategoryID: [String: Set<String>],
        allowPaymentMethodFallback: Bool,
        acceptedPaymentMethods: Set<String>?
    ) -> Double {
        // 1. Always accept an exact match at full weight
        if rewardCategory == category.id { return 1.0 }

        // 2. Check categoryLinks FIRST (explicit links work even with excludeFromParent)
        if let links = category.categoryLinks {
            if links.contains(where: { $0.id == rewardCategory }) {
                return 1.0
            }
        }

        // 3. Payment method fallback — evaluated before excludeFromParent so that
        //    brand categories (excludeFromParent: true) still get payment-method rewards
        //    when the merchant declares it accepts that method (e.g. Amazon + apple_pay).
        if allowPaymentMethodFallback,
           paymentMethodCategories.contains(rewardCategory) {
            if category.id != "everything",
               !(category.excludedPaymentMethods?.contains(rewardCategory) ?? false) {
                // If merchant declares which payment methods it accepts, only apply for those
                if let accepted = acceptedPaymentMethods {
                    return accepted.contains(rewardCategory) ? 1.0 : 0.0
                }
                return 1.0
            }
        }

        // 4. If this category blocks parent cascade, skip to "everything" fallback
        if category.excludeFromParent {
            if rewardCategory == "everything" { return 1.0 }
            return 0.0
        }

        // 5. O(1) ancestor lookup using pre-computed set (replaces fragile multi-hop parent walk)
        if ancestorsByCategoryID[category.id]?.contains(rewardCategory) == true { return 1.0 }

        // 6. Final fallback: "everything" always matches (lowest priority, after parent walk)
        if rewardCategory == "everything" { return 1.0 }

        return 0.0
    }

    // MARK: - Channel helper
    private static func isCategoryAllowedInChannel(
        _ rewardCategory: String,
        channel: String?,
        categoryByID: [String: SpendingCategory]
    ) -> Bool {
        guard let calcChannel = channel else { return true }
        guard let categoryModel = categoryByID[rewardCategory] else { return true }
        guard let allowedChannels = categoryModel.channels, !allowedChannels.isEmpty else { return true }

        let normalizedAllowed = Set(allowedChannels.flatMap { channelAliases[$0] ?? [$0] })
        let normalizedCurrent = channelAliases[calcChannel] ?? [calcChannel]
        return !normalizedAllowed.isDisjoint(with: normalizedCurrent)
    }

    // MARK: - Cross-border effective rate helpers
    private static func normalizedRegionCode(_ code: String?) -> String? {
        RegionDatabase.normalizeRegionCode(code)
    }

    private static func isCrossBorderSpend(
        for card: CreditCard,
        region: String?,
        acceptedRegions: Set<String>?,
        forceCrossBorder: Bool
    ) -> Bool {
        if forceCrossBorder { return true }
        guard let cardRegion = normalizedRegionCode(card.country) else { return false }
        // If merchant declares accepted regions, check card country against the full set
        if let acceptedRegions {
            return !acceptedRegions.contains(cardRegion.uppercased())
        }
        // Single-region fallback (map merchants); nil region = global = no FX
        guard let merchantRegion = normalizedRegionCode(region) else { return false }
        return merchantRegion != cardRegion
    }

    private static func foreignTransactionFeeRate(for card: CreditCard) -> Double {
        guard card.hasForeignTransactionFee else { return 0.0 }
        return max(0.0, card.foreignTransactionFeeRate ?? 0.0)
    }

    // MARK: - Overlay reward helpers (online_transactions / foreign_transactions)

    private static let overlayCategories: Set<String> = ["online_transactions", "foreign_transactions"]

    private static func bestOverlayReward(
        for card: CreditCard,
        overlayID: String,
        boostEnrollments: [String: String],
        region: String?,
        acceptedRegions: Set<String>?,
        forceCrossBorder: Bool
    ) -> (reward: RewardRate, effectiveRate: Double)? {
        card.activeRewards
            .filter { $0.isActive() && $0.categories?.contains(overlayID) == true }
            .map { reward in
                let rate = computeEffectiveRate(
                    for: card, reward: reward,
                    boostEnrollments: boostEnrollments,
                    region: region, acceptedRegions: acceptedRegions, forceCrossBorder: forceCrossBorder
                )
                return (reward: reward, effectiveRate: rate)
            }
            .max(by: { $0.effectiveRate < $1.effectiveRate })
    }

    private static func computeEffectiveRate(
        for card: CreditCard,
        reward: RewardRate,
        boostEnrollments: [String: String],
        region: String?,
        acceptedRegions: Set<String>?,
        forceCrossBorder: Bool
    ) -> Double {
        let boost = card.boostMultiplier(enrollments: boostEnrollments)
        let baseRate = reward.effectiveCashBackRate * boost

        if isCrossBorderSpend(for: card, region: region, acceptedRegions: acceptedRegions, forceCrossBorder: forceCrossBorder) {
            return baseRate - foreignTransactionFeeRate(for: card)
        } else {
            return baseRate
        }
    }
    
    // MARK: - Card Filtering Helper
    private static func shouldExcludeCard(_ card: CreditCard, for category: SpendingCategory, region: String?) -> Bool {
        if let filter = category.cardFilter {
            if let regionalFilter = filter.filterFor(region: region) {
                let allowed = regionalFilter.allows(card)
                if !allowed {
                    #if DEBUG
                    let regionDisplay = region ?? "unknown"
                    print("   🚫 \(card.name) (\(card.network)) filtered in region '\(regionDisplay)'")
                    #endif
                }
                return !allowed
            }
        }
        return false
    }

    // MARK: - Ancestor set builder
    /// Builds a map from category.id → set of all IDs reachable via step 5 of matchWeight.
    /// Includes: each ancestor's own ID, plus each ancestor's categoryLinks IDs.
    private static func buildAncestorSets(categoryByID: [String: SpendingCategory]) -> [String: Set<String>] {
        var result: [String: Set<String>] = [:]
        for id in categoryByID.keys {
            var reachable: Set<String> = []
            var current: String? = categoryByID[id]?.parentCategoryID
            while let ancestorID = current {
                reachable.insert(ancestorID)
                if let ancestor = categoryByID[ancestorID] {
                    ancestor.categoryLinks?.forEach { reachable.insert($0.id) }
                    current = ancestor.parentCategoryID
                } else {
                    break
                }
            }
            result[id] = reachable
        }
        return result
    }

    // MARK: - Core computation (runs once in init)
    /// Computes all matching rewards eagerly with effective rates pre-calculated.
    /// Each card contributes at most one entry (its highest effective rate reward).
    private static func computeAllMatchingRewards(
        cards: [CreditCard],
        category: SpendingCategory,
        categoryByID: [String: SpendingCategory],
        ancestorsByCategoryID: [String: Set<String>],
        boostEnrollments: [String: String],
        region: String?,
        channel: String?,
        allowPaymentMethodFallback: Bool,
        forceCrossBorder: Bool,
        acceptedPaymentMethods: Set<String>?,
        acceptedRegions: Set<String>?
    ) -> [MatchedReward] {
        let isOnline = channel == "online"
        var bestPerCardID: [String: MatchedReward] = [:]

        for card in cards {
            if shouldExcludeCard(card, for: category, region: region) {
                continue
            }
            
            let isSuppressed = card.activeRewards.contains { reward in
                reward.rate == 0.0 &&
                reward.categories?.contains(category.id) == true
            }
            if isSuppressed { continue }

            let boost = card.boostMultiplier(enrollments: boostEnrollments)

            for reward in card.activeRewards where reward.isActive() {
                guard let cats = reward.categories else { continue }

                let nonOverlayCats = cats.filter { !overlayCategories.contains($0) }
                guard !nonOverlayCats.isEmpty else { continue }

                let applies = nonOverlayCats.contains { rewardCategory in
                    matchWeight(
                        rewardCategory: rewardCategory,
                        category: category,
                        ancestorsByCategoryID: ancestorsByCategoryID,
                        allowPaymentMethodFallback: allowPaymentMethodFallback,
                        acceptedPaymentMethods: acceptedPaymentMethods
                    ) > 0 &&
                    isCategoryAllowedInChannel(rewardCategory, channel: channel, categoryByID: categoryByID)
                }
                
                guard applies else { continue }

                if let allowedCountries = reward.countries, !allowedCountries.isEmpty {
                    // For global merchants (nil region), fall back to the card's own country so
                    // region-restricted rewards (e.g. US-only streaming) still apply for US cards.
                    let regionToCheck = normalizedRegionCode(region) ?? normalizedRegionCode(card.country)
                    guard let regionToCheck,
                          allowedCountries.map({ $0.uppercased() }).contains(regionToCheck) else {
                        continue
                    }
                }

                if let calcChannel = channel, let rewardChannels = reward.channels, !rewardChannels.isEmpty {
                    if !rewardChannels.contains(calcChannel) { continue }
                }

                let netRate = computeEffectiveRate(
                    for: card, reward: reward,
                    boostEnrollments: boostEnrollments,
                    region: region, acceptedRegions: acceptedRegions, forceCrossBorder: forceCrossBorder
                )
                let existingRate = bestPerCardID[card.id]?.effectiveRate ?? -1

                if netRate > existingRate {
                    bestPerCardID[card.id] = MatchedReward(
                        card: card, reward: reward,
                        effectiveRate: netRate, boost: boost
                    )
                }
            }

            // Overlay bonus candidates
            if isOnline,
               let overlay = bestOverlayReward(
                   for: card, overlayID: "online_transactions",
                   boostEnrollments: boostEnrollments,
                   region: region, acceptedRegions: acceptedRegions, forceCrossBorder: forceCrossBorder
               ) {
                let existingRate = bestPerCardID[card.id]?.effectiveRate ?? -1
                if overlay.effectiveRate > existingRate {
                    bestPerCardID[card.id] = MatchedReward(
                        card: card, reward: overlay.reward,
                        effectiveRate: overlay.effectiveRate, boost: boost
                    )
                }
            }

            if isCrossBorderSpend(for: card, region: region, acceptedRegions: acceptedRegions, forceCrossBorder: forceCrossBorder),
               let overlay = bestOverlayReward(
                   for: card, overlayID: "foreign_transactions",
                   boostEnrollments: boostEnrollments,
                   region: region, acceptedRegions: acceptedRegions, forceCrossBorder: forceCrossBorder
               ) {
                let existingRate = bestPerCardID[card.id]?.effectiveRate ?? -1
                if overlay.effectiveRate > existingRate {
                    bestPerCardID[card.id] = MatchedReward(
                        card: card, reward: overlay.reward,
                        effectiveRate: overlay.effectiveRate, boost: boost
                    )
                }
            }
        }

        return Array(bestPerCardID.values)
    }

    /// The ranked list used for display — one entry per unique card *name*.
    /// If a user holds two copies of the same card (e.g. two Freedom Flex),
    /// only the better-performing instance is shown to avoid duplicate rows.
    private var rankedUniqueRewards: [MatchedReward] {
        var bestPerName: [String: MatchedReward] = [:]
        for entry in cachedMatchingRewards {
            let existing = bestPerName[entry.card.name]?.effectiveRate ?? -1
            if entry.effectiveRate > existing {
                bestPerName[entry.card.name] = entry
            }
        }
        return Array(bestPerName.values)
    }

    /// Get the best card summary for this category, ranked by effective cash back rate.
    /// If multiple cards tie for best rate, prefer the one with the higher raw multiplier,
    /// then alphabetically by name for consistency.
    var bestCard: CardRateSummary? {
        rankedUniqueRewards
            .max(by: {
                if $0.effectiveRate != $1.effectiveRate {
                    return $0.effectiveRate < $1.effectiveRate
                }
                if $0.reward.rate != $1.reward.rate {
                    return $0.reward.rate < $1.reward.rate
                }
                return $0.card.name > $1.card.name
            })
            .map {
                CardRateSummary(
                    name: $0.card.name,
                    rate: $0.reward.rate * $0.boost,
                    effectiveCashBackRate: $0.effectiveRate,
                    pointCashValue: $0.reward.pointCashValue,
                    pointCashValueCurrency: $0.reward.pointCashValueCurrency,
                    rewardProgramName: $0.reward.rewardProgramName
                )
            }
    }
    
    /// Get all cards tied for the best effective cash back rate.
    /// Returns an empty array if no cards match this category.
    var bestCards: [CardRateSummary] {
        guard let topRate = rankedUniqueRewards.map(\.effectiveRate).max() else {
            return []
        }
        
        return rankedUniqueRewards
            .filter { $0.effectiveRate == topRate }
            .map {
                CardRateSummary(
                    name: $0.card.name,
                    rate: $0.reward.rate * $0.boost,
                    effectiveCashBackRate: $0.effectiveRate,
                    pointCashValue: $0.reward.pointCashValue,
                    pointCashValueCurrency: $0.reward.pointCashValueCurrency,
                    rewardProgramName: $0.reward.rewardProgramName
                )
            }
            .sorted { $0.name < $1.name }
    }

    /// Get the next best card summaries (max 2), ranked by effective rate, below the best.
    /// Returns empty if multiple cards are tied for best — in that case, use `bestCards` instead.
    var nextCards: [CardRateSummary] {
        guard bestCards.count == 1 else { return [] }
        
        let bestEffectiveRate = bestCard?.effectiveCashBackRate ?? 0

        var bestPerName: [String: MatchedReward] = [:]

        for entry in cachedMatchingRewards {
            guard entry.effectiveRate < bestEffectiveRate else { continue }
            let existing = bestPerName[entry.card.name]?.effectiveRate ?? -.infinity
            if entry.effectiveRate > existing {
                bestPerName[entry.card.name] = entry
            }
        }

        return bestPerName.values
            .map {
                CardRateSummary(
                    name: $0.card.name,
                    rate: $0.reward.rate * $0.boost,
                    effectiveCashBackRate: $0.effectiveRate,
                    pointCashValue: $0.reward.pointCashValue,
                    pointCashValueCurrency: $0.reward.pointCashValueCurrency,
                    rewardProgramName: $0.reward.rewardProgramName
                )
            }
            .sorted { $0.effectiveCashBackRate > $1.effectiveCashBackRate }
            .prefix(5)
            .map { $0 }
    }

    /// All matched cards ranked by effective rate descending, then alphabetically.
    /// No cap applied — callers decide how many to show.
    /// Use this to build runner-up lists instead of `bestCards + nextCards`.
    var rankedCardSummaries: [CardRateSummary] {
        rankedUniqueRewards
            .sorted {
                if $0.effectiveRate != $1.effectiveRate { return $0.effectiveRate > $1.effectiveRate }
                return $0.card.name < $1.card.name
            }
            .map {
                CardRateSummary(
                    name: $0.card.name,
                    rate: $0.reward.rate * $0.boost,
                    effectiveCashBackRate: $0.effectiveRate,
                    pointCashValue: $0.reward.pointCashValue,
                    pointCashValueCurrency: $0.reward.pointCashValueCurrency,
                    rewardProgramName: $0.reward.rewardProgramName
                )
            }
    }

    /// Convenience: best card name only (for backwards compatibility)
    var bestCardName: String? { bestCard?.name }

    /// Convenience: next card tuples only (for backwards compatibility)
    var nextCardTuples: [(name: String, rate: Double)] {
        nextCards.map { (name: $0.name, rate: $0.rate) }
    }
}
