//
//  BoostProgramDatabase.swift
//  Chur
//
//  Created by Pak Ho on 2/17/26.
//
//  P1f part 2: a "boost program" is an earning layer — a bonus stacked on top of
//  a card's own reward rows, with its own mode (multiply or add), scope, and the
//  user's selection (a tier, an allocation of weights, or one pick). The US
//  relationship tiers are the `multiply` special case. See ROADMAP.md § P1f and
//  REWARD_SETUP_REFERENCE.md "Pattern 7 — Earning layers".
//
//  The JSON domain name (`boostPrograms`) and every program id and tier name are
//  load-bearing: `User.boostEnrollments` is keyed by them.
//

import Foundation

// MARK: - Layer vocabulary

enum LayerMode: String, Codable {
    /// Scale the whole earn (BofA Preferred Rewards 1.25×). The default.
    case multiply
    /// Add on top of the base rate (Travel Guru +3%, Red Hot +5X).
    case add
}

enum LayerUnit: String, Codable {
    /// `value` is in the reward's own rate units (points per dollar). The default.
    case rate
    /// `value` is a cash rate (0.03 = 3%) added after the point value, so one layer
    /// can sit on cards whose programs differ (RewardCash on a miles card).
    case cash
}

enum LayerSelection: String, Codable {
    /// The user picks one tier (default).
    case tier
    /// The user spreads `allocation.total` weights across `allocation.categories`.
    case allocate
    /// The user picks one of `options`.
    case pickOne
    /// Always on for eligible cards; nothing to enrol in (a card's own extra).
    /// Not named `none`: that reads as `Optional.none` wherever the field is optional.
    case always
}

/// Where a layer applies (`appliesTo`) or does not (`excludes`). Every field is
/// optional; an absent field means "no constraint on that dimension".
///
/// `categories` may name overlay ids: `foreign_transactions` means cross-border,
/// `online_transactions` means the online channel — the same convention reward
/// rows use. `currencies` and `paymentMethods` decode now and take effect in
/// P1f part 3 when the pricing context carries those dimensions.
struct LayerScope: Codable, Equatable {
    var categories: [String]?
    var channels: [String]?
    var crossBorder: Bool?
    var countries: [String]?
    var currencies: [String]?
    var paymentMethods: [String]?
}

/// A spend gate or a cap. **Display only** — the app tracks no spend, so these
/// render as small print and never enter the engine.
struct LayerCondition: Codable, Equatable {
    var amount: Double?
    var currency: String?
    /// calendarMonth · statementCycle · quarter · halfYear · year · promo
    var period: String?
    /// spend · reward
    var kind: String?
    /// Layers sharing a `group` share one cap pool.
    var group: String?
    var note: String?
}

struct LayerAllocation: Codable, Equatable {
    let categories: [String]
    let total: Int
    var maxPerCategory: Int?
}

// MARK: - Models

struct BoostTier: Codable {
    let name: String        // "Gold", "Platinum Honors", "GURU"
    /// `multiply` mode: 1.25 = 25% bonus on top of base rate.
    var multiplier: Double?
    /// `add` mode: the amount added, in the program's `unit`.
    var value: Double?
    let description: String // shown as subtitle in the picker
    var cap: LayerCondition?
}

struct BoostProgram: Codable {
    let id: String
    let name: String
    let issuer: String              // for display purposes

    // Scope — either a template list or issuer + country.
    var eligibleTemplateIDs: [String]?
    var eligibleIssuer: String?
    var eligibleCountry: String?

    var mode: LayerMode?
    var unit: LayerUnit?
    var appliesTo: LayerScope?
    var excludes: LayerScope?

    var selection: LayerSelection?
    var allocation: LayerAllocation?
    var options: [String]?
    /// `allocate`: value per weight unit. `pickOne` / `none`: the layer's value.
    var value: Double?

    var gate: LayerCondition?
    var cap: LayerCondition?

    var tiers: [BoostTier]?
    let footnote: String?

    var resolvedMode: LayerMode { mode ?? .multiply }
    var resolvedUnit: LayerUnit { unit ?? .rate }
    var resolvedSelection: LayerSelection { selection ?? .tier }
    var resolvedTiers: [BoostTier] { tiers ?? [] }

    /// Whether this program can apply to `card` at all (before enrolment).
    func isEligible(_ card: CreditCard) -> Bool {
        if let ids = eligibleTemplateIDs, let templateID = card.templateID, ids.contains(templateID) {
            return true
        }
        if let issuer = eligibleIssuer, issuer == card.issuer {
            guard let country = eligibleCountry else { return true }
            return RegionDatabase.normalizeRegionCode(country) == RegionDatabase.normalizeRegionCode(card.country)
        }
        return false
    }

    /// Whether the user has to choose something for the layer to fire.
    var requiresEnrollment: Bool { resolvedSelection != .always }
}

// MARK: - The user's selection

/// What the user chose for one program. Stored in `User.boostEnrollments`, keyed by
/// program id. Exactly one of the three is meaningful for a given program.
///
/// Decodes from a bare string as well as an object, and encodes a tier-only value
/// back to a bare string, so pre-P1f stores, Drive backups and test fixtures
/// (`"usbank-smartly": "50% Smartly Earning Bonus"`) keep working unchanged.
struct ProgramSelection: Codable, Equatable, Hashable {
    var tier: String?
    var allocation: [String: Int]?
    var pick: String?

    init(tier: String? = nil, allocation: [String: Int]? = nil, pick: String? = nil) {
        self.tier = tier
        self.allocation = allocation
        self.pick = pick
    }

    private enum CodingKeys: String, CodingKey { case tier, allocation, pick }

    init(from decoder: Decoder) throws {
        if let single = try? decoder.singleValueContainer(), let tierName = try? single.decode(String.self) {
            self.init(tier: tierName)
            return
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            tier: try container.decodeIfPresent(String.self, forKey: .tier),
            allocation: try container.decodeIfPresent([String: Int].self, forKey: .allocation),
            pick: try container.decodeIfPresent(String.self, forKey: .pick)
        )
    }

    func encode(to encoder: Encoder) throws {
        if let tier, allocation == nil, pick == nil {
            var single = encoder.singleValueContainer()
            try single.encode(tier)
            return
        }
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(tier, forKey: .tier)
        try container.encodeIfPresent(allocation, forKey: .allocation)
        try container.encodeIfPresent(pick, forKey: .pick)
    }

    /// Total weight assigned, for the allocate picker's "3 of 5 assigned".
    var allocatedTotal: Int { allocation?.values.reduce(0, +) ?? 0 }
}

typealias BoostEnrollments = [String: ProgramSelection]

// MARK: - Database

struct BoostProgramDatabase {

    // MARK: - Lookup

    /// Every program that can apply to `card`, enrolled or not, in file order.
    static func programs(for card: CreditCard) -> [BoostProgram] {
        all.filter { $0.isEligible(card) }
    }

    static func program(id: String) -> BoostProgram? {
        all.first { $0.id == id }
    }

    /// The pre-P1f single-program lookup by template id. Kept for the one caller
    /// that only needs "does any program name this template"; new code should use
    /// `programs(for:)`, since a card can sit under several layers.
    static func program(for templateID: String?) -> BoostProgram? {
        guard let templateID else { return nil }
        return all.first { $0.eligibleTemplateIDs?.contains(templateID) == true }
    }

    /// Returns the multiplier for a given program ID + tier name combo.
    /// Defaults to 1.0 (no boost) if not found or if the tier is not a multiplier.
    static func multiplier(programID: String, tierName: String) -> Double {
        program(id: programID)?
            .resolvedTiers.first { $0.name == tierName }?
            .multiplier ?? 1.0
    }

    // MARK: - All Programs

    /// A `var` rather than a `let` since P1d: this publishes remotely, and a
    /// `let` is resolved once on first access — which for a rates input means a
    /// refresh landing mid-session would be ignored until the app relaunched.
    private(set) static var all: [BoostProgram] = loadAll()

    static func reloadFromBundle() {
        all = loadAll()
    }

    private static func loadAll() -> [BoostProgram] {
        if let remote: [BoostProgram] = RemoteSeed.decodeArray(.boostPrograms, label: "BoostProgramDatabase") {
            return remote
        }

        guard let url = Bundle.main.url(forResource: "boost_programs", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let programs = try? JSONDecoder().decode([BoostProgram].self, from: data) else {
            print("⚠️ BoostProgramDatabase: Failed to load boost_programs.json")
            return []
        }
        return programs
    }
}
