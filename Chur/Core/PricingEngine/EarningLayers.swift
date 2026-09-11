//
//  EarningLayers.swift
//  Chur
//
//  P1f part 2. Resolves the user's boost-program enrolments into the layers that
//  fire for one card on one transaction, and folds them into a single
//  `AppliedBoost` the engine and the display sites both use.
//
//  Formula, in `AppliedBoost.effectiveRate`:
//
//      ((rate + rateAdds) × pointCashValue + cashAdds) × multipliers
//
//  Multipliers scale the whole earn (the US relationship-tier case); adds sit on
//  top of the base rate, in rate units or in cash. Layers apply on top of
//  whichever reward row wins for the card — the engine computes one boost per
//  card per transaction and applies it to every candidate row.
//

import Foundation

// MARK: - A layer that fired

struct AppliedLayer: Equatable {
    let programID: String
    let programName: String
    /// The user-facing selection: a tier name, "Dining ×3", or the picked option.
    let label: String
    let mode: LayerMode
    let unit: LayerUnit
    /// `multiply`: the multiplier. `add`: the amount, in `unit`.
    let value: Double
    let gate: LayerCondition?
    let cap: LayerCondition?
}

// MARK: - The folded result

struct AppliedBoost: Equatable {
    let layers: [AppliedLayer]
    let multiplier: Double
    let rateAdd: Double
    let cashAdd: Double

    static let unboosted = AppliedBoost(layers: [], multiplier: 1.0, rateAdd: 0, cashAdd: 0)

    init(layers: [AppliedLayer]) {
        var multiplier = 1.0
        var rateAdd = 0.0
        var cashAdd = 0.0
        for layer in layers {
            switch layer.mode {
            case .multiply:
                multiplier *= layer.value
            case .add:
                switch layer.unit {
                case .rate: rateAdd += layer.value
                case .cash: cashAdd += layer.value
                }
            }
        }
        self.init(layers: layers, multiplier: multiplier, rateAdd: rateAdd, cashAdd: cashAdd)
    }

    private init(layers: [AppliedLayer], multiplier: Double, rateAdd: Double, cashAdd: Double) {
        self.layers = layers
        self.multiplier = multiplier
        self.rateAdd = rateAdd
        self.cashAdd = cashAdd
    }

    var isEmpty: Bool { layers.isEmpty }

    /// Cash earned per dollar before any FX fee.
    func effectiveRate(rate: Double, pointCashValue: Double) -> Double {
        ((rate + rateAdd) * pointCashValue + cashAdd) * multiplier
    }

    /// The "multiplier" a pill shows (`CardRateSummary.rate`): the raw rate after
    /// layers. Cash adds are converted back through the point value so the pill
    /// and the effective rate agree.
    func displayRate(rate: Double, pointCashValue: Double) -> Double {
        let cashAsRate = pointCashValue > 0 ? cashAdd / pointCashValue : 0
        return (rate + rateAdd + cashAsRate) * multiplier
    }
}

// MARK: - Resolution

extension CardRateCalculator {

    /// The boost that applies to `card` for the transaction in `context`.
    ///
    /// `isCrossBorder` is passed in rather than derived so the engine's own
    /// cross-border decision (which knows about `acceptedRegions` and
    /// `forceCrossBorder`) is the single source of truth.
    static func resolveBoost(
        for card: CreditCard,
        context: PricingContext,
        isCrossBorder: Bool,
        ancestorsByCategoryID: [String: Set<String>]
    ) -> AppliedBoost {
        var fired: [AppliedLayer] = []

        for program in BoostProgramDatabase.programs(for: card) {
            let selection = context.boostEnrollments[program.id]
            for candidate in candidateLayers(program: program, selection: selection) {
                guard scopeAllows(candidate.appliesTo, context: context, isCrossBorder: isCrossBorder,
                                  card: card, ancestorsByCategoryID: ancestorsByCategoryID),
                      !scopeExcludes(candidate.excludes, context: context, isCrossBorder: isCrossBorder,
                                     card: card, ancestorsByCategoryID: ancestorsByCategoryID)
                else { continue }
                fired.append(candidate.layer)
            }
        }

        return fired.isEmpty ? .unboosted : AppliedBoost(layers: fired)
    }

    /// Display-site variant: no merchant, no channel, not cross-border. Layers
    /// scoped to a channel or to foreign spend do not fire here — card info lists
    /// those by their scope text instead. `category == nil` fires only layers with
    /// no category scope.
    static func appliedBoost(
        for card: CreditCard,
        enrollments: BoostEnrollments,
        category: SpendingCategory?,
        categoryMaps: CategoryMaps
    ) -> AppliedBoost {
        let context = PricingContext(
            category: category ?? displayPlaceholderCategory,
            boostEnrollments: enrollments
        )
        return resolveBoost(
            for: card,
            context: context,
            isCrossBorder: false,
            ancestorsByCategoryID: categoryMaps.ancestorsByCategoryID
        )
    }

    /// Transient, never inserted into a context. With id `everything` and no
    /// ancestors, `matchWeight` accepts only layers scoped to `everything` or to
    /// nothing — exactly "the number with no category in view".
    private static var displayPlaceholderCategory: SpendingCategory {
        SpendingCategory(
            id: "everything", nameEN: "Everything", nameZH_Hans: "Everything",
            nameZH_HK: "Everything", nameZH_TW: "Everything", emoji: "✨", sortOrder: 0
        )
    }

    // MARK: - Candidate layers from a program + selection

    private struct CandidateLayer {
        let layer: AppliedLayer
        let appliesTo: LayerScope?
        let excludes: LayerScope?
    }

    private static func candidateLayers(program: BoostProgram, selection: ProgramSelection?) -> [CandidateLayer] {
        let mode = program.resolvedMode
        let unit = program.resolvedUnit

        func make(label: String, value: Double, scope: LayerScope?, cap: LayerCondition?) -> CandidateLayer {
            CandidateLayer(
                layer: AppliedLayer(
                    programID: program.id, programName: program.name, label: label,
                    mode: mode, unit: unit, value: value, gate: program.gate, cap: cap ?? program.cap
                ),
                appliesTo: scope,
                excludes: program.excludes
            )
        }

        switch program.resolvedSelection {
        case .tier:
            guard let tierName = selection?.tier,
                  let tier = program.resolvedTiers.first(where: { $0.name == tierName }) else { return [] }
            let value: Double
            switch mode {
            case .multiply: value = tier.multiplier ?? 1.0
            case .add:      value = tier.value ?? 0
            }
            return [make(label: tier.name, value: value, scope: program.appliesTo, cap: tier.cap)]

        case .allocate:
            guard let allocation = program.allocation,
                  let weights = selection?.allocation,
                  let perUnit = program.value else { return [] }
            return allocation.categories.compactMap { categoryID in
                guard let weight = weights[categoryID], weight > 0 else { return nil }
                var scope = program.appliesTo ?? LayerScope()
                scope.categories = [categoryID]
                return make(label: "\(categoryID) ×\(weight)", value: perUnit * Double(weight), scope: scope, cap: nil)
            }

        case .pickOne:
            guard let pick = selection?.pick,
                  program.options?.contains(pick) == true,
                  let value = program.value else { return [] }
            var scope = program.appliesTo ?? LayerScope()
            scope.categories = [pick]
            return [make(label: pick, value: value, scope: scope, cap: nil)]

        case .always:
            guard let value = program.value else { return [] }
            return [make(label: program.name, value: value, scope: program.appliesTo, cap: nil)]
        }
    }

    // MARK: - Scope matching

    private static let onlineOverlay = "online_transactions"
    private static let foreignOverlay = "foreign_transactions"

    /// `appliesTo`: every stated dimension must hold. Absent scope = applies everywhere.
    private static func scopeAllows(
        _ scope: LayerScope?,
        context: PricingContext,
        isCrossBorder: Bool,
        card: CreditCard,
        ancestorsByCategoryID: [String: Set<String>]
    ) -> Bool {
        guard let scope else { return true }

        if let categories = scope.categories, !categories.isEmpty {
            let any = categories.contains {
                categoryTermMatches($0, context: context, isCrossBorder: isCrossBorder, ancestorsByCategoryID: ancestorsByCategoryID)
            }
            if !any { return false }
        }
        if let channels = scope.channels, !channels.isEmpty, let channel = context.channel {
            if !channels.contains(channel) { return false }
        }
        if let crossBorder = scope.crossBorder, crossBorder != isCrossBorder { return false }
        if let countries = scope.countries, !countries.isEmpty {
            guard let region = regionForCountryCheck(context: context, card: card),
                  countries.map({ $0.uppercased() }).contains(region) else { return false }
        }
        if let currencies = scope.currencies, !currencies.isEmpty {
            let billed = transactionCurrency(for: card, context: context)
            guard currencies.map({ CurrencyConversion.normalized($0) }).contains(billed) else { return false }
        }
        if let methods = scope.paymentMethods, !methods.isEmpty,
           let effective = effectivePaymentMethods(context: context) {
            guard !effective.isDisjoint(with: methods) else { return false }
        }
        return true
    }

    /// `excludes`: any stated dimension that matches knocks the layer out.
    private static func scopeExcludes(
        _ scope: LayerScope?,
        context: PricingContext,
        isCrossBorder: Bool,
        card: CreditCard,
        ancestorsByCategoryID: [String: Set<String>]
    ) -> Bool {
        guard let scope else { return false }

        if let categories = scope.categories, categories.contains(where: {
            categoryTermMatches($0, context: context, isCrossBorder: isCrossBorder, ancestorsByCategoryID: ancestorsByCategoryID)
        }) { return true }
        if let channels = scope.channels, let channel = context.channel, channels.contains(channel) { return true }
        if let crossBorder = scope.crossBorder, crossBorder == isCrossBorder { return true }
        if let countries = scope.countries, !countries.isEmpty,
           let region = regionForCountryCheck(context: context, card: card),
           countries.map({ $0.uppercased() }).contains(region) { return true }
        if let currencies = scope.currencies, !currencies.isEmpty,
           currencies.map({ CurrencyConversion.normalized($0) }).contains(transactionCurrency(for: card, context: context)) { return true }
        // A payment-method exclusion ("no bonus via e-wallet") knocks the layer out only
        // when every way this purchase could be paid is excluded — with the optimistic
        // set the user can still pay by card, so the layer stays. An explicit "Paying
        // with AlipayHK" narrows the set to one method and the exclusion bites.
        if let excluded = scope.paymentMethods, !excluded.isEmpty,
           let effective = effectivePaymentMethods(context: context),
           !effective.isEmpty, effective.isSubset(of: Set(excluded)) { return true }
        return false
    }

    /// One `categories` entry: an overlay id maps to a context condition, anything
    /// else goes through the same `matchWeight` the reward rows use (payment-method
    /// fallback off — a layer names a payment method via `paymentMethods`, not here).
    private static func categoryTermMatches(
        _ term: String,
        context: PricingContext,
        isCrossBorder: Bool,
        ancestorsByCategoryID: [String: Set<String>]
    ) -> Bool {
        switch term {
        case onlineOverlay:  return context.isOnline
        case foreignOverlay: return isCrossBorder
        default:
            return matchWeight(
                rewardCategory: term,
                category: context.category,
                ancestorsByCategoryID: ancestorsByCategoryID,
                allowPaymentMethodFallback: false,
                acceptedPaymentMethods: nil
            ) > 0
        }
    }
}
