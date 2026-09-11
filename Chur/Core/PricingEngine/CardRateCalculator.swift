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
    /// The transaction being priced — see `PricingContext`.
    let context: PricingContext
    let allCategories: [SpendingCategory]
    private let categoryByID: [String: SpendingCategory]
    /// Pre-computed ancestor sets: category.id → all ancestor IDs via parentCategoryID chain.
    /// Eliminates fragile multi-hop walks — O(1) lookup in matchWeight step 5.
    private let ancestorsByCategoryID: [String: Set<String>]

    /// Pre-computed matching results with effective rates stored alongside.
    /// Computed once in init, read by all public properties.
    private let cachedMatchingRewards: [MatchedReward]

    /// A matched reward with its effective rate pre-computed.
    private struct MatchedReward {
        let card: CreditCard
        let reward: RewardRate
        let effectiveRate: Double
        let boost: AppliedBoost
        /// The payment method that made this row apply, if it depended on one.
        let viaPaymentMethod: String?
    }

    /// `categoryByID`/`ancestorsByCategoryID`, precomputed once and shared across many
    /// `CardRateCalculator` instances that match different merchants against the same
    /// category set (e.g. `NearbyRecommendationEngine.recommendAll`), instead of every
    /// instance rebuilding the same ancestor-set map from scratch.
    struct CategoryMaps {
        let categoryByID: [String: SpendingCategory]
        let ancestorsByCategoryID: [String: Set<String>]

        init(allCategories: [SpendingCategory]) {
            let byID = Dictionary(allCategories.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            self.categoryByID = byID
            self.ancestorsByCategoryID = CardRateCalculator.buildAncestorSets(categoryByID: byID)
        }
    }

    /// Primary initializer. The transaction lives in `context`; the wallet and the category
    /// tree are the other two inputs.
    init(
        cards: [CreditCard],
        context: PricingContext,
        allCategories: [SpendingCategory],
        categoryMaps: CategoryMaps? = nil
    ) {
        // Cancelled cards never earn rewards — exclude them for every caller in one place.
        let cards = cards.filter { $0.status != "cancelled" }
        self.cards = cards
        self.context = context
        self.allCategories = allCategories
        let maps = categoryMaps ?? CategoryMaps(allCategories: allCategories)
        self.categoryByID = maps.categoryByID
        self.ancestorsByCategoryID = maps.ancestorsByCategoryID

        // Eagerly compute all matching rewards once
        self.cachedMatchingRewards = Self.computeAllMatchingRewards(
            cards: cards,
            context: context,
            categoryByID: maps.categoryByID,
            ancestorsByCategoryID: maps.ancestorsByCategoryID
        )
    }

    /// Pre-P1f signature, kept so existing call sites compile unchanged. New code should
    /// build a `PricingContext` and use `init(cards:context:allCategories:categoryMaps:)`.
    /// `rate` was stored and never read; it is accepted and dropped.
    init(
        cards: [CreditCard],
        category: SpendingCategory,
        rate: Double,
        allCategories: [SpendingCategory],
        boostEnrollments: BoostEnrollments,
        region: String?,
        channel: String?,
        allowPaymentMethodFallback: Bool = true,
        forceCrossBorder: Bool = false,
        acceptedPaymentMethods: Set<String>? = nil,
        acceptedRegions: Set<String>? = nil,
        categoryMaps: CategoryMaps? = nil
    ) {
        self.init(
            cards: cards,
            context: PricingContext(
                category: category,
                region: region,
                channel: channel,
                boostEnrollments: boostEnrollments,
                allowPaymentMethodFallback: allowPaymentMethodFallback,
                forceCrossBorder: forceCrossBorder,
                acceptedPaymentMethods: acceptedPaymentMethods,
                acceptedRegions: acceptedRegions
            ),
            allCategories: allCategories,
            categoryMaps: categoryMaps
        )
    }

    // MARK: - Payment method categories that apply as a near-universal fallback
    private static let paymentMethodCategories: Set<String> = PaymentMethods.all
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
    static func matchWeight(
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

    private static func isCrossBorderSpend(for card: CreditCard, context: PricingContext) -> Bool {
        if context.forceCrossBorder { return true }
        guard let cardRegion = normalizedRegionCode(card.country) else { return false }
        // If merchant declares accepted regions, check card country against the full set
        if let acceptedRegions = context.acceptedRegions {
            return !acceptedRegions.contains(cardRegion.uppercased())
        }
        // Single-region fallback (map merchants); nil region = global = no FX
        guard let merchantRegion = normalizedRegionCode(context.region) else { return false }
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
        context: PricingContext,
        boost: AppliedBoost
    ) -> (reward: RewardRate, effectiveRate: Double)? {
        card.activeRewards
            .filter { $0.isActive() && $0.categories?.contains(overlayID) == true }
            .filter { constraintsApply($0, card: card, context: context) }
            .map { reward in
                (reward: reward, effectiveRate: computeEffectiveRate(for: card, reward: reward, context: context, boost: boost))
            }
            .max(by: { $0.effectiveRate < $1.effectiveRate })
    }

    /// `boost` is resolved once per card per transaction (see `EarningLayers.swift`)
    /// and applied to every candidate row; layers sit on top of whichever row wins.
    private static func computeEffectiveRate(
        for card: CreditCard,
        reward: RewardRate,
        context: PricingContext,
        boost: AppliedBoost
    ) -> Double {
        let baseRate = boost.effectiveRate(rate: reward.rate, pointCashValue: reward.pointCashValue)

        if isCrossBorderSpend(for: card, context: context) {
            return baseRate - foreignTransactionFeeRate(for: card)
        } else {
            return baseRate
        }
    }

    // MARK: - Transaction dimensions (P1f part 3)

    /// The methods this purchase could be paid with: an explicit narrowing from the
    /// context, else what the merchant accepts, else every method — minus what the
    /// merchant category excludes. nil = unrestricted.
    static func effectivePaymentMethods(context: PricingContext) -> Set<String>? {
        var methods = context.paymentMethods ?? context.acceptedPaymentMethods
        if let excluded = context.category.excludedPaymentMethods, !excluded.isEmpty {
            methods = (methods ?? PaymentMethods.all).subtracting(excluded)
        }
        return methods
    }

    /// The currency the purchase is billed in, consistent with `isCrossBorderSpend`:
    /// a merchant that operates in the card's own region bills locally (an online
    /// merchant with `businessRegion` covering HK bills an HK card in HKD, whatever
    /// region its listing leads with); a merchant with a foreign region bills in
    /// that region's currency; a global merchant (nil region) bills in the card's own.
    static func transactionCurrency(for card: CreditCard, context: PricingContext) -> String {
        if let accepted = context.acceptedRegions,
           let cardRegion = normalizedRegionCode(card.country),
           accepted.contains(cardRegion.uppercased()) {
            return CurrencyConversion.normalized(card.currency)
        }
        if let region = normalizedRegionCode(context.region) {
            return CurrencyConversion.currencyCode(forRegion: region)
        }
        return CurrencyConversion.normalized(card.currency)
    }

    /// The region a country list is checked against: the merchant's, or the card's
    /// own for a global merchant (so US-only rewards still apply for US cards).
    static func regionForCountryCheck(context: PricingContext, card: CreditCard) -> String? {
        normalizedRegionCode(context.region) ?? normalizedRegionCode(card.country)
    }

    /// Which payment method a reward relied on, for the popup's "with Apple Pay".
    private static func paymentMethodUsed(by reward: RewardRate, context: PricingContext) -> String? {
        let named = reward.paymentMethods ?? []
        let legacy = (reward.categories ?? []).filter { paymentMethodCategories.contains($0) }
        guard !(named.isEmpty && legacy.isEmpty) else { return nil }
        let effective = effectivePaymentMethods(context: context)
        return (named + legacy).first { effective?.contains($0) ?? true }
    }

    // MARK: - Applicability chain
    //
    // Whether a (non-overlay) reward applies to the transaction in `context`. One ordered
    // chain, each step a pure predicate, so a new dimension (currency, payment method) is
    // one more step here and nowhere else:
    //   1. date         — the reward is active today
    //   2. category     — at least one reward category matches (matchWeight) and is allowed
    //                     in this channel by the category's own `channels`
    //   3. countries    — the reward's `countries` list, if any, contains the merchant region
    //                     (or the card's own country for a global merchant)
    //   4. channels     — the reward's `channels` list, if any, contains the context channel
    //   5. excludedCountries — the merchant region is not on the reward's exclusion list
    //   6. currencies   — the derived transaction currency is on the reward's list, if any
    //   7. paymentMethods — the reward's methods intersect what the purchase can be paid with
    // Steps 3–7 are `constraintsApply`, shared with the overlay rows (which have no
    // category step of their own).
    private static func rewardApplies(
        _ reward: RewardRate,
        card: CreditCard,
        context: PricingContext,
        categoryByID: [String: SpendingCategory],
        ancestorsByCategoryID: [String: Set<String>]
    ) -> Bool {
        // 1. date
        guard reward.isActive() else { return false }

        // 2. category
        guard let cats = reward.categories else { return false }
        let nonOverlayCats = cats.filter { !overlayCategories.contains($0) }
        guard !nonOverlayCats.isEmpty else { return false }

        let categoryMatches = nonOverlayCats.contains { rewardCategory in
            matchWeight(
                rewardCategory: rewardCategory,
                category: context.category,
                ancestorsByCategoryID: ancestorsByCategoryID,
                allowPaymentMethodFallback: context.allowPaymentMethodFallback,
                acceptedPaymentMethods: effectivePaymentMethods(context: context)
            ) > 0 &&
            isCategoryAllowedInChannel(rewardCategory, channel: context.channel, categoryByID: categoryByID)
        }
        guard categoryMatches else { return false }

        return constraintsApply(reward, card: card, context: context)
    }

    /// Steps 3–7 of the chain: everything about the reward that is not its category.
    private static func constraintsApply(_ reward: RewardRate, card: CreditCard, context: PricingContext) -> Bool {
        // 3. countries
        if let allowedCountries = reward.countries, !allowedCountries.isEmpty {
            // For global merchants (nil region), fall back to the card's own country so
            // region-restricted rewards (e.g. US-only streaming) still apply for US cards.
            guard let regionToCheck = regionForCountryCheck(context: context, card: card),
                  allowedCountries.map({ $0.uppercased() }).contains(regionToCheck) else {
                return false
            }
        }

        // 4. channels
        if let calcChannel = context.channel, let rewardChannels = reward.channels, !rewardChannels.isEmpty {
            if !rewardChannels.contains(calcChannel) { return false }
        }

        // 5. excludedCountries
        if let excluded = reward.excludedCountries, !excluded.isEmpty,
           let regionToCheck = regionForCountryCheck(context: context, card: card),
           excluded.map({ $0.uppercased() }).contains(regionToCheck) {
            return false
        }

        // 6. currencies
        if let currencies = reward.currencies, !currencies.isEmpty {
            let billed = transactionCurrency(for: card, context: context)
            guard currencies.map({ CurrencyConversion.normalized($0) }).contains(billed) else { return false }
        }

        // 7. paymentMethods
        if let methods = reward.paymentMethods, !methods.isEmpty {
            guard context.allowPaymentMethodFallback else { return false }
            if let effective = effectivePaymentMethods(context: context) {
                guard !effective.isDisjoint(with: methods) else { return false }
            }
        }

        return true
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

    /// Standalone category-matching check (payment-method fallback disabled).
    /// Used by the DEBUG seed validator to assert pricing invariants without building a full calculator.
    static func categoryMatches(rewardCategory: String, category: SpendingCategory, allCategories: [SpendingCategory]) -> Bool {
        let byID = Dictionary(allCategories.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return matchWeight(
            rewardCategory: rewardCategory,
            category: category,
            ancestorsByCategoryID: buildAncestorSets(categoryByID: byID),
            allowPaymentMethodFallback: false,
            acceptedPaymentMethods: nil
        ) > 0
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
        context: PricingContext,
        categoryByID: [String: SpendingCategory],
        ancestorsByCategoryID: [String: Set<String>]
    ) -> [MatchedReward] {
        let category = context.category
        var bestPerCardID: [String: MatchedReward] = [:]

        for card in cards {
            if shouldExcludeCard(card, for: category, region: context.region) {
                continue
            }
            
            let isSuppressed = card.activeRewards.contains { reward in
                reward.rate == 0.0 &&
                reward.categories?.contains(category.id) == true
            }
            if isSuppressed { continue }

            let isCrossBorder = isCrossBorderSpend(for: card, context: context)
            let boost = resolveBoost(
                for: card, context: context, isCrossBorder: isCrossBorder,
                ancestorsByCategoryID: ancestorsByCategoryID
            )

            /// Keep this reward for the card if it beats the card's current best.
            func offer(_ reward: RewardRate, effectiveRate: Double) {
                let existingRate = bestPerCardID[card.id]?.effectiveRate ?? -1
                if effectiveRate > existingRate {
                    bestPerCardID[card.id] = MatchedReward(
                        card: card, reward: reward,
                        effectiveRate: effectiveRate, boost: boost,
                        viaPaymentMethod: paymentMethodUsed(by: reward, context: context)
                    )
                }
            }

            for reward in card.activeRewards {
                guard rewardApplies(
                    reward, card: card, context: context,
                    categoryByID: categoryByID, ancestorsByCategoryID: ancestorsByCategoryID
                ) else { continue }

                offer(reward, effectiveRate: computeEffectiveRate(for: card, reward: reward, context: context, boost: boost))
            }

            // Overlay bonus candidates
            if context.isOnline,
               let overlay = bestOverlayReward(for: card, overlayID: "online_transactions", context: context, boost: boost) {
                offer(overlay.reward, effectiveRate: overlay.effectiveRate)
            }

            if isCrossBorder,
               let overlay = bestOverlayReward(for: card, overlayID: "foreign_transactions", context: context, boost: boost) {
                offer(overlay.reward, effectiveRate: overlay.effectiveRate)
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
                    rate: $0.boost.displayRate(rate: $0.reward.rate, pointCashValue: $0.reward.pointCashValue),
                    effectiveCashBackRate: $0.effectiveRate,
                    pointCashValue: $0.reward.pointCashValue,
                    pointCashValueCurrency: $0.reward.pointCashValueCurrency,
                    rewardProgramName: $0.reward.rewardProgramName,
                    boostLayers: $0.boost.layers,
                    viaPaymentMethod: $0.viaPaymentMethod
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
                    rate: $0.boost.displayRate(rate: $0.reward.rate, pointCashValue: $0.reward.pointCashValue),
                    effectiveCashBackRate: $0.effectiveRate,
                    pointCashValue: $0.reward.pointCashValue,
                    pointCashValueCurrency: $0.reward.pointCashValueCurrency,
                    rewardProgramName: $0.reward.rewardProgramName,
                    boostLayers: $0.boost.layers,
                    viaPaymentMethod: $0.viaPaymentMethod
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
                    rate: $0.boost.displayRate(rate: $0.reward.rate, pointCashValue: $0.reward.pointCashValue),
                    effectiveCashBackRate: $0.effectiveRate,
                    pointCashValue: $0.reward.pointCashValue,
                    pointCashValueCurrency: $0.reward.pointCashValueCurrency,
                    rewardProgramName: $0.reward.rewardProgramName,
                    boostLayers: $0.boost.layers,
                    viaPaymentMethod: $0.viaPaymentMethod
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
                    rate: $0.boost.displayRate(rate: $0.reward.rate, pointCashValue: $0.reward.pointCashValue),
                    effectiveCashBackRate: $0.effectiveRate,
                    pointCashValue: $0.reward.pointCashValue,
                    pointCashValueCurrency: $0.reward.pointCashValueCurrency,
                    rewardProgramName: $0.reward.rewardProgramName,
                    boostLayers: $0.boost.layers,
                    viaPaymentMethod: $0.viaPaymentMethod
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
