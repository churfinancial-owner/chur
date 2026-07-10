
//
//  View_CalculatorPopup.swift
//  Chur
//
//  Detailed breakdown view showing how card recommendations are calculated
//  Shows category matching, rate calculation, and card comparison
//

import SwiftUI
import SwiftData

struct CalculatorPopup: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var users: [User]
    
    let merchant: NearbyMerchant
    let category: SpendingCategory
    let cards: [CreditCard]
    let allCategories: [SpendingCategory]
    let boostEnrollments: [String: String]
    var channel: String = "in_store" // "in_store" or "online"

    // Online merchants require explicit paymentMethods declaration to earn PM rewards.
    // nil means "no restriction" only for in-store; for online, nil → empty set (no PM rewards).
    private var effectivePaymentMethods: Set<String>? {
        channel == "online" ? (merchant.paymentMethods ?? Set<String>()) : merchant.paymentMethods
    }

    // Calculator
    private var calculator: CardRateCalculator {
        CardRateCalculator(
            cards: cards,
            category: category,
            rate: 1.0,
            allCategories: allCategories,
            boostEnrollments: boostEnrollments,
            region: merchant.region,
            channel: channel,
            acceptedPaymentMethods: effectivePaymentMethods,
            acceptedRegions: merchant.acceptedRegions
        )
    }

    // Category hierarchy — shows matching priority order used by CardRateCalculator
    // Payment methods are evaluated at step 3 (before excludeFromParent) so they always show first.
    private var categoryHierarchy: [String] {
        var hierarchy: [String] = [category.id]

        // Step 2: categoryLinks
        if let links = category.categoryLinks {
            for link in links {
                if !hierarchy.contains(link.id) { hierarchy.append(link.id) }
            }
        }

        // Step 3: payment methods (evaluated before excludeFromParent)
        for pm in Self.paymentMethodCategories.sorted() {
            if !(category.excludedPaymentMethods?.contains(pm) ?? false) {
                hierarchy.append(pm)
            }
        }

        // Step 4: excludeFromParent stops here — no parent chain
        if !category.excludeFromParent {
            let categoryByID = Dictionary(allCategories.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            var currentID = category.parentCategoryID
            while let parentID = currentID {
                if !hierarchy.contains(parentID) { hierarchy.append(parentID) }
                if let parent = categoryByID[parentID] {
                    // Include ancestor's categoryLinks (reachable via step 5 of matchWeight)
                    parent.categoryLinks?.forEach { link in
                        if !hierarchy.contains(link.id) { hierarchy.append(link.id) }
                    }
                    currentID = parent.parentCategoryID
                } else {
                    break
                }
            }
        }

        // Final fallback
        if !hierarchy.contains("everything") {
            hierarchy.append("everything")
        }

        return hierarchy
    }
    
    // Detailed card analysis
    struct CardAnalysis: Identifiable {
        let id = UUID()
        let card: CreditCard
        let isFiltered: Bool
        let filterReason: String?
        let matchingRewards: [(reward: RewardRate, matchReason: String, breakdown: RateBreakdown)]
        let bestReward: (reward: RewardRate, breakdown: RateBreakdown)?
        /// Rewards that target a payment method (e.g. mobile_pay) but are blocked at this merchant
        let excludedPaymentMethodRewards: [(reward: RewardRate, paymentMethod: String, effectiveRate: Double)]
        let isCrossBorder: Bool
    }
    
    private var cardAnalyses: [CardAnalysis] {
        cards.map { card in
            // Check if filtered
            var isFiltered = false
            var filterReason: String? = nil
            
            if let filter = category.cardFilter,
               let regionalFilter = filter.filterFor(region: merchant.region) {
                if !regionalFilter.allows(card) {
                    isFiltered = true
                    let region = merchant.region ?? "unknown"
                    filterReason = "Filtered in region '\(region)' - network: \(card.network)"
                }
            }
            
            // Check for zero-rate suppression
            if !isFiltered {
                let isSuppressed = card.activeRewards.contains { reward in
                    reward.rate == 0.0 &&
                    reward.categories?.contains(category.id) == true
                }
                if isSuppressed {
                    isFiltered = true
                    filterReason = "Zero-rate suppression for \(category.id)"
                }
            }
            
            // Find matching rewards
            var matchingRewards: [(reward: RewardRate, matchReason: String, breakdown: RateBreakdown)] = []
            
            if !isFiltered {
                for reward in card.activeRewards where reward.isActive() {
                    guard let cats = reward.categories else { continue }
                    
                    // Skip overlay categories from normal matching — handled below
                    let nonOverlayCats = cats.filter { !Self.overlayCategories.contains($0) }
                    guard !nonOverlayCats.isEmpty else { continue }
                    
                    // Channel filtering: skip rewards that don't apply in current channel
                    if let rewardChannels = reward.channels, !rewardChannels.isEmpty {
                        if !rewardChannelsAllowChannel(rewardChannels) { continue }
                    }

                    // Country filtering: skip rewards restricted to specific countries
                    if let allowedCountries = reward.countries, !allowedCountries.isEmpty {
                        let regionToCheck = RegionDatabase.normalizeRegionCode(merchant.region) ?? RegionDatabase.normalizeRegionCode(card.country)
                        guard let regionToCheck,
                              allowedCountries.map({ $0.uppercased() }).contains(regionToCheck) else {
                            continue
                        }
                    }

                    // Check each non-overlay category in the reward
                    for rewardCat in nonOverlayCats {
                        if categoryChannelRestrictionText(for: rewardCat) != nil { continue }
                        let weight = matchWeight(rewardCategory: rewardCat)
                        if weight > 0 {
                            let matchReason = determineMatchReason(rewardCategory: rewardCat)
                            let breakdown = effectiveRateBreakdown(for: card, reward: reward)
                            matchingRewards.append((
                                reward: reward,
                                matchReason: matchReason,
                                breakdown: breakdown
                            ))
                            break // Only count each reward once
                        }
                    }
                }
                
                // Overlay bonus candidates (online_transactions / foreign_transactions)
                if channel == "online" {
                    if let onlineReward = bestOverlayReward(for: card, overlayID: "online_transactions") {
                        let breakdown = effectiveRateBreakdown(for: card, reward: onlineReward)
                        matchingRewards.append((
                            reward: onlineReward,
                            matchReason: "Online transactions overlay",
                            breakdown: breakdown
                        ))
                    }
                }
                
                if isCrossBorderSpend(for: card) {
                    if let foreignReward = bestOverlayReward(for: card, overlayID: "foreign_transactions") {
                        let breakdown = effectiveRateBreakdown(for: card, reward: foreignReward)
                        matchingRewards.append((
                            reward: foreignReward,
                            matchReason: "Foreign transactions overlay",
                            breakdown: breakdown
                        ))
                    }
                }
            }
            
            // Find rewards blocked by payment method restrictions or channel rules
            var excludedPMRewards: [(reward: RewardRate, paymentMethod: String, effectiveRate: Double)] = []
            for reward in card.activeRewards where reward.isActive() {
                guard let cats = reward.categories else { continue }
                for rewardCat in cats where Self.paymentMethodCategories.contains(rewardCat) {
                    let effectiveRate = netEffectiveRate(for: card, reward: reward)

                    // Blocked by category's excludedPaymentMethods (e.g. Walmart blocks apple_pay)
                    if let excluded = category.excludedPaymentMethods, excluded.contains(rewardCat) {
                        excludedPMRewards.append((reward: reward, paymentMethod: "\(rewardCat) — excluded by merchant category", effectiveRate: effectiveRate))
                        break
                    }

                    // Blocked because merchant declared accepted methods and this one isn't in the list
                    if let accepted = effectivePaymentMethods, !accepted.contains(rewardCat) {
                        excludedPMRewards.append((reward: reward, paymentMethod: "\(rewardCat) — not accepted at this merchant", effectiveRate: effectiveRate))
                        break
                    }

                    // Blocked by category channel restriction (e.g. paypal_pay is online-only in category metadata)
                    if let categoryChannelReason = categoryChannelRestrictionText(for: rewardCat) {
                        excludedPMRewards.append((reward: reward, paymentMethod: "\(rewardCat) — \(categoryChannelReason)", effectiveRate: effectiveRate))
                        break
                    }

                    // Blocked by reward's own channel restriction (e.g. in_store reward used online)
                    if let rewardChannels = reward.channels, !rewardChannels.isEmpty,
                       !rewardChannelsAllowChannel(rewardChannels) {
                        let channelList = rewardChannels.joined(separator: ", ")
                        excludedPMRewards.append((reward: reward, paymentMethod: "\(rewardCat) — \(channelList) only", effectiveRate: effectiveRate))
                        break
                    }
                }
            }
            
            // Find best reward
            let bestReward = matchingRewards.max(by: { $0.breakdown.netRate < $1.breakdown.netRate })
                .map { (reward: $0.reward, breakdown: $0.breakdown) }
            
            return CardAnalysis(
                card: card,
                isFiltered: isFiltered,
                filterReason: filterReason,
                matchingRewards: matchingRewards,
                bestReward: bestReward,
                excludedPaymentMethodRewards: excludedPMRewards,
                isCrossBorder: isCrossBorderSpend(for: card)
            )
        }
        .sorted { lhs, rhs in
            // Sort: best cards first, then filtered cards last
            if lhs.bestReward != nil && rhs.bestReward == nil { return true }
            if lhs.bestReward == nil && rhs.bestReward != nil { return false }
            if let lhsRate = lhs.bestReward?.breakdown.netRate,
               let rhsRate = rhs.bestReward?.breakdown.netRate {
                return lhsRate > rhsRate
            }
            return lhs.card.name < rhs.card.name
        }
    }
    
    // Payment method categories (must match CardRateCalculator)
    private static let paymentMethodCategories: Set<String> = ["mobile_pay", "apple_pay", "paypal_pay"]
    private static let overlayCategories: Set<String> = ["online_transactions", "foreign_transactions"]
    private static let channelAliases: [String: Set<String>] = [
        "in_store": ["in_store"],
        "online": ["online"]
    ]

    /// Mirrors CardRateCalculator.buildAncestorSets — pre-computes reachable ancestor IDs for step 5.
    private var ancestorsByCategoryID: [String: Set<String>] {
        let categoryByID = Dictionary(allCategories.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
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

    // Match weight helper — mirrors CardRateCalculator.matchWeight exactly
    private func matchWeight(rewardCategory: String) -> Double {
        // 1. Exact match
        if rewardCategory == category.id { return 1.0 }

        // 2. Explicit categoryLinks
        if let links = category.categoryLinks {
            if links.contains(where: { $0.id == rewardCategory }) { return 1.0 }
        }

        // 3. Payment method fallback — before excludeFromParent so brand categories still qualify
        if Self.paymentMethodCategories.contains(rewardCategory),
           category.id != "everything",
           !(category.excludedPaymentMethods?.contains(rewardCategory) ?? false) {
            if let accepted = effectivePaymentMethods {
                return accepted.contains(rewardCategory) ? 1.0 : 0.0
            }
            return 1.0
        }

        // 4. excludeFromParent gate
        if category.excludeFromParent {
            if rewardCategory == "everything" { return 1.0 }
            return 0.0
        }

        // 5. O(1) ancestor lookup using pre-computed set (mirrors CardRateCalculator)
        if ancestorsByCategoryID[category.id]?.contains(rewardCategory) == true { return 1.0 }

        // 6. Everything fallback
        if rewardCategory == "everything" { return 1.0 }

        return 0.0
    }

    private func categoryChannelRestrictionText(for rewardCategory: String) -> String? {
        guard let categoryModel = allCategories.first(where: { $0.id == rewardCategory }) else { return nil }
        guard let allowedChannels = categoryModel.channels, !allowedChannels.isEmpty else { return nil }

        let normalizedAllowed = Set(allowedChannels.flatMap { Self.channelAliases[$0] ?? [$0] })
        let normalizedCurrent = Self.channelAliases[channel] ?? [channel]
        if normalizedAllowed.isDisjoint(with: normalizedCurrent) {
            return "\(allowedChannels.joined(separator: ", ")) only"
        }
        return nil
    }

    private func rewardChannelsAllowChannel(_ rewardChannels: [String]) -> Bool {
        let normalizedRewardChannels = Set(rewardChannels.flatMap { Self.channelAliases[$0] ?? [$0] })
        let normalizedCurrent = Self.channelAliases[channel] ?? [channel]
        return !normalizedRewardChannels.isDisjoint(with: normalizedCurrent)
    }

    /// Returns the best overlay reward for the given card and overlay category ID.
    private func bestOverlayReward(for card: CreditCard, overlayID: String) -> RewardRate? {
        card.activeRewards
            .filter { $0.isActive() && $0.categories?.contains(overlayID) == true }
            .max(by: { netEffectiveRate(for: card, reward: $0) < netEffectiveRate(for: card, reward: $1) })
    }

    private func isCrossBorderSpend(for card: CreditCard) -> Bool {
        guard let cardRegion = RegionDatabase.normalizeRegionCode(card.country) else { return false }
        if let acceptedRegions = merchant.acceptedRegions {
            return !acceptedRegions.contains(cardRegion.uppercased())
        }
        guard let merchantRegion = RegionDatabase.normalizeRegionCode(merchant.region) else { return false }
        return merchantRegion != cardRegion
    }

    private func foreignTransactionFeeRate(for card: CreditCard) -> Double {
        guard card.hasForeignTransactionFee else { return 0.0 }
        return max(0.0, card.foreignTransactionFeeRate ?? 0.0)
    }

    private func netEffectiveRate(for card: CreditCard, reward: RewardRate) -> Double {
        let boost = card.boostMultiplier(enrollments: boostEnrollments)
        let baseRate = reward.effectiveCashBackRate * boost
        if isCrossBorderSpend(for: card) {
            return baseRate - foreignTransactionFeeRate(for: card)
        } else {
            return baseRate
        }
    }

    struct RateBreakdown {
        let baseRate: Double          // rate × pointCashValue × boost (percentage)
        let fxFeeRate: Double         // Foreign transaction fee (percentage)
        let netRate: Double           // baseRate - fxFeeRate (percentage)
        let rewardProgramName: String
        let pointValue: Double        // Cash value per point
        let pointValueCurrency: String // Currency of pointCashValue
        let boostMultiplier: Double
    }

    private func effectiveRateBreakdown(for card: CreditCard, reward: RewardRate) -> RateBreakdown {
        let boost = card.boostMultiplier(enrollments: boostEnrollments)
        let baseRate = reward.effectiveCashBackRate * boost
        let fxFee = isCrossBorderSpend(for: card) ? foreignTransactionFeeRate(for: card) : 0.0
        return RateBreakdown(
            baseRate: baseRate,
            fxFeeRate: fxFee,
            netRate: baseRate - fxFee,
            rewardProgramName: reward.rewardProgramName,
            pointValue: reward.pointCashValue,
            pointValueCurrency: CurrencyConversion.normalized(reward.pointCashValueCurrency),
            boostMultiplier: boost
        )
    }
    
    private func determineMatchReason(rewardCategory: String) -> String {
        if rewardCategory == category.id {
            return "Exact match"
        }

        if let links = category.categoryLinks {
            if links.contains(where: { $0.id == rewardCategory }) {
                return "Category link: \(category.id) → \(rewardCategory)"
            }
        }

        // Payment method — checked before excludeFromParent (mirrors CardRateCalculator)
        if Self.paymentMethodCategories.contains(rewardCategory),
           !(category.excludedPaymentMethods?.contains(rewardCategory) ?? false) {
            if let accepted = effectivePaymentMethods {
                if accepted.contains(rewardCategory) {
                    return "Payment method: \(rewardCategory) (merchant accepts)"
                }
            } else {
                return "Payment method: \(rewardCategory) (no restriction)"
            }
        }

        var currentID: String? = category.parentCategoryID
        var depth = 1
        while let ancestorID = currentID {
            if rewardCategory == ancestorID {
                return "Parent cascade (level \(depth)): \(category.id) → \(rewardCategory)"
            }
            if let ancestor = allCategories.first(where: { $0.id == ancestorID }) {
                if let links = ancestor.categoryLinks {
                    if links.contains(where: { $0.id == rewardCategory }) {
                        return "Ancestor link: \(ancestorID) → \(rewardCategory)"
                    }
                }
                currentID = ancestor.parentCategoryID
                depth += 1
            } else {
                break
            }
        }

        if rewardCategory == "everything" {
            return "Everything fallback"
        }

        return "Unknown match"
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    
                    // MARK: - Merchant Header
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("MERCHANT")
                                    .font(.churMicroBold())
                                    .foregroundStyle(Color.churMediumGray)
                                    .tracking(0.5)
                                
                                Text(merchant.name)
                                    .font(.churTitle2())
                                    .foregroundStyle(Color.churDarkGray)
                                
                                HStack(spacing: 8) {
                                    if let region = merchant.region {
                                        HStack(spacing: 4) {
                                            Image(systemName: "location.fill")
                                                .font(.churBadge())
                                            Text(region)
                                                .font(.churFootnoteMedium())
                                        }
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(Color.churOlive)
                                        .clipShape(Capsule())
                                    }
                                    
                                    Text(category.displayName)
                                        .font(.churFootnoteMedium())
                                        .foregroundStyle(Color.churDarkGray)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(Color.churOliveLight.opacity(0.3))
                                        .clipShape(Capsule())
                                    
                                    if let poi = merchant.poiCategory {
                                        Text(poi.replacingOccurrences(of: "MKPOICategory", with: ""))
                                            .font(.churSmall())
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.blue.opacity(0.6))
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                            
                            Spacer()

                            Text(category.emoji)
                                .font(.churTitle2())
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.churOffWhite)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    
                    // MARK: - Best Card Result
                    if let bestCard = calculator.bestCard {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("BEST CARD")
                                    .font(.churMicroBold())
                                    .foregroundStyle(Color.churMediumGray)
                                    .tracking(0.5)
                                
                                Spacer()
                                
                                HStack(spacing: 6) {
                                    Text("\(bestCard.effectiveRateDisplayString)")
                                        .font(.churSectionHeader())
                                        .foregroundStyle(bestCard.effectiveCashBackRate < 0 ? Color(red: 0.78, green: 0.25, blue: 0.42) : Color.churOlive)
                                    
                                    Text("(\(String(format: "%.1fx", bestCard.rate)))")
                                        .font(.churFootnoteMedium())
                                        .foregroundStyle(Color.churMediumGray)
                                }
                            }
                            
                            HStack(spacing: 12) {
                                // Card image
                                if let card = cards.first(where: { $0.name == bestCard.name }),
                                   let uiImage = UIImage(named: card.imageName) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 80, height: 50)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                                } else if let card = cards.first(where: { $0.name == bestCard.name }) {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(cardColor(for: card.issuer))
                                        .frame(width: 80, height: 50)
                                        .overlay {
                                            Text(card.issuer.prefix(2))
                                                .font(.churHeadline())
                                                .foregroundStyle(.white)
                                        }
                                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(bestCard.name)
                                        .font(.churHeadline())
                                        .foregroundStyle(Color.churDarkGray)
                                    
                                    if let card = cards.first(where: { $0.name == bestCard.name }) {
                                        Text(card.issuer)
                                            .font(.churFootnoteMedium())
                                            .foregroundStyle(Color.churMediumGray)
                                    }
                                }
                                
                                Spacer()
                            }
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white)
                                .shadow(color: Color.churOlive.opacity(0.15), radius: 8, x: 0, y: 4)
                        )
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "questionmark.circle.fill")
                                    .font(.churBigTitle4())
                                    .foregroundStyle(Color.churMediumGray)
                                
                                Text("No Matching Card")
                                    .font(.churHeadline())
                                    .foregroundStyle(Color.churDarkGray)
                            }
                            
                            Text("None of your cards offer rewards for this category.")
                                .font(.churCaptionRegular())
                                .foregroundStyle(Color.churMediumGray)
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.churOffWhite)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    
                    // MARK: - All Cards Comparison
                    VStack(alignment: .leading, spacing: 12) {
                        Text("CARDS COMPARISON")
                            .font(.churMicroBold())
                            .foregroundStyle(Color.churMediumGray)
                            .tracking(0.5)
                            .padding(.horizontal, 4)
                        
                        VStack(spacing: 12) {
                            ForEach(cardAnalyses) { analysis in
                                CardAnalysisRow(analysis: analysis)
                            }
                        }
                    }
                    
                    // MARK: - Category Hierarchy (Collapsible)
                    DisclosureGroup {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(categoryHierarchy.enumerated()), id: \.offset) { index, catID in
                                let isPaymentMethod = Self.paymentMethodCategories.contains(catID)
                                let merchantAccepts: Bool? = isPaymentMethod
                                    ? (effectivePaymentMethods.map { $0.contains(catID) })
                                    : nil

                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(index == 0 ? Color.churOlive : Color.churLightGray)
                                        .frame(width: 8, height: 8)

                                    Text(catID)
                                        .font(index == 0 ? .churFootnoteBold() : .churFootnote())
                                        .foregroundStyle(index == 0 ? Color.churOlive : Color.churDarkGray)

                                    if index == 0 {
                                        Text("(current)")
                                            .font(.churMicroMedium())
                                            .foregroundStyle(Color.churMediumGray)
                                    }

                                    if isPaymentMethod {
                                        if let accepts = merchantAccepts {
                                            Text(accepts ? "✓ accepted" : "✗ not accepted")
                                                .font(.churMicroMedium())
                                                .foregroundStyle(accepts ? Color.green : Color.orange)
                                        } else {
                                            Text("(no restriction)")
                                                .font(.churMicroMedium())
                                                .foregroundStyle(Color.churMediumGray)
                                        }
                                    }

                                    if catID == "everything" {
                                        Text("(fallback)")
                                            .font(.churMicroMedium())
                                            .foregroundStyle(Color.churMediumGray)
                                    }

                                    Spacer()
                                }
                                .padding(.vertical, 4)
                            }

                            if category.excludeFromParent {
                                HStack(spacing: 6) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.churSmall())
                                        .foregroundStyle(.orange)
                                    Text("Parent cascade blocked (payment methods still apply)")
                                        .font(.churSmallMedium())
                                        .foregroundStyle(.orange)
                                }
                                .padding(.top, 8)
                            }

                            if let excluded = category.excludedPaymentMethods, !excluded.isEmpty {
                                HStack(spacing: 6) {
                                    Image(systemName: "creditcard.trianglebadge.exclamationmark")
                                        .font(.churSmall())
                                        .foregroundStyle(.orange)
                                    Text("Category excludes: \(excluded.joined(separator: ", "))")
                                        .font(.churSmallMedium())
                                        .foregroundStyle(.orange)
                                }
                                .padding(.top, 4)
                            }

                            if let accepted = effectivePaymentMethods {
                                HStack(spacing: 6) {
                                    Image(systemName: "checkmark.seal.fill")
                                        .font(.churSmall())
                                        .foregroundStyle(.blue)
                                    Text("Merchant accepts: \(accepted.sorted().joined(separator: ", "))")
                                        .font(.churSmallMedium())
                                        .foregroundStyle(.blue)
                                }
                                .padding(.top, 4)
                            }
                        }
                        .padding(.vertical, 8)
                    } label: {
                        HStack {
                            Text("CATEGORY DETAILS")
                                .font(.churMicroBold())
                                .foregroundStyle(Color.churMediumGray)
                                .tracking(0.5)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.down")
                                .font(.churBadgeBold())
                                .foregroundStyle(Color.churMediumGray)
                        }
                    }
                    .tint(Color.churOlive)
                    .padding(16)
                    .background(Color.churOffWhite)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(20)
            }
            .background(Color.white)
            .navigationTitle("Card Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.churBigTitle4())
                            .foregroundStyle(Color.churMediumGray)
                    }
                }
            }
        }
    }
    
    private func cardColor(for issuer: String) -> Color {
        .cardColor(for: issuer)
    }
}




