//
//  MerchantSeedDatabase.swift
//  Chur
//
//  Unified merchant seed: SeedDataMerchants.json is the single source for
//  online-search merchants, map name-matching rules, and auto-generated brand
//  target categories. One entry per merchant replaces the three hand-authored
//  pieces (online entry + map mapping + brand SpendingCategory).
//
//  Legacy SeedDataOnlineMerchants.json / SeedDataMerchantMappings.json are
//  dead — no code reads them; their data is being migrated into this file.
//

import Foundation

// MARK: - Map Matching Rules (shared with MerchantCategoryMapper)

/// Name-matching strategies used by MerchantCategoryMapper for map places.
/// Lives in `genericMappings` for rules that aren't tied to a single merchant
/// (POI-gated prefixes, multi-brand patterns); single-merchant rules should be
/// authored on the merchant entry's `map` block instead.
struct MerchantMappings: Codable {
    let exactMatches: [String: String]
    let prefixMatches: [PrefixMatch]?
    let containsMatches: [ContainsMatch]?
    let patternRules: [PatternRule]

    /// A prefix-based mapping rule with optional POI confirmation
    struct PrefixMatch: Codable {
        let prefix: String
        let categoryID: String
        let requiredPOI: String?  // nil means no POI confirmation needed
    }

    /// A contains-based mapping rule with optional POI confirmation
    struct ContainsMatch: Codable {
        let keyword: String
        let categoryID: String
        let requiredPOI: String?
    }

    /// A pattern-based mapping rule with optional overrides
    struct PatternRule: Codable {
        let patterns: [String]
        let categoryID: String
        let overrides: [PatternOverride]?
    }

    /// An override that replaces the default categoryID when a condition is met
    struct PatternOverride: Codable {
        let ifContains: String
        let categoryID: String
    }
}

// MARK: - Merchant Entry

/// One merchant in SeedDataMerchants.json.
struct MerchantEntry: Codable {
    // Identity + pricing category (same semantics as the old OnlineMerchant fields)
    let id: String
    let name: String
    let domain: String?
    let category: String
    let merchantIconName: String?
    let affiliateID: String?
    let isBrandCategory: Bool?
    let businessRegion: [String]?
    let tags: [String]?
    let sortOrder: Int?
    let merchantDescription: String?
    let featured: [String]?
    let popular: [String]?
    let paymentMethods: [String]?

    /// false = map-only merchant, hidden from the Online search mode. Default true.
    let searchable: Bool?

    /// Map name-matching for this merchant. Produces a PatternRule checked
    /// before the genericMappings pattern rules. `categoryID` defaults to `category`.
    let map: MapMatching?

    /// When present, the target SpendingCategory named by `category` is
    /// auto-generated at load time instead of being hand-authored in a
    /// SeedDataCategories_*.json file.
    let brandCategory: BrandCategorySpec?

    struct MapMatching: Codable {
        let patterns: [String]
        let categoryID: String?
        let overrides: [MerchantMappings.PatternOverride]?
    }

    struct BrandCategorySpec: Codable {
        let parent: String?     // parentCategoryID; nil = isolated brand (no ancestor cascade)
        let links: [String]?    // extra cross-links (e.g. isolated brand → "wholesale")
        let emoji: String?      // defaults to 🏷️
    }

    func toOnlineMerchant() -> OnlineMerchant {
        OnlineMerchant(
            id: id,
            name: name,
            domain: domain,
            category: category,
            merchantIconName: merchantIconName,
            affiliateID: affiliateID,
            isBrandCategory: isBrandCategory,
            businessRegion: businessRegion,
            tags: tags,
            sortOrder: sortOrder,
            merchantDescription: merchantDescription,
            featured: featured,
            popular: popular,
            paymentMethods: paymentMethods
        )
    }
}

// MARK: - Seed File

struct MerchantSeedFile: Codable {
    let merchants: [MerchantEntry]
    let genericMappings: MerchantMappings?
}

// MARK: - Database

struct MerchantSeedDatabase {

    private(set) static var seed: MerchantSeedFile = loadSeed()

    static func reloadFromBundle() {
        seed = loadSeed()
    }

    private static func loadSeed() -> MerchantSeedFile {
        guard let url = Bundle.main.url(forResource: "SeedDataMerchants", withExtension: "json") else {
            #if DEBUG
            print("❌ MerchantSeedDatabase: SeedDataMerchants.json not found in bundle")
            #endif
            return MerchantSeedFile(merchants: [], genericMappings: nil)
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(MerchantSeedFile.self, from: data)
        } catch {
            #if DEBUG
            print("❌ MerchantSeedDatabase: Failed to decode: \(error)")
            #endif
            return MerchantSeedFile(merchants: [], genericMappings: nil)
        }
    }

    /// Merchants shown in the Online search mode (searchable != false).
    static var onlineMerchants: [OnlineMerchant] {
        seed.merchants
            .filter { $0.searchable != false }
            .map { $0.toOnlineMerchant() }
    }

    /// Generic mappings merged with per-merchant `map` blocks.
    /// Merchant-derived rules come first so they win over broad generic patterns.
    static var combinedMappings: MerchantMappings {
        let merchantRules: [MerchantMappings.PatternRule] = seed.merchants.compactMap { entry in
            guard let map = entry.map else { return nil }
            return MerchantMappings.PatternRule(
                patterns: map.patterns,
                categoryID: map.categoryID ?? entry.category,
                overrides: map.overrides
            )
        }
        let generic = seed.genericMappings
        return MerchantMappings(
            exactMatches: generic?.exactMatches ?? [:],
            prefixMatches: generic?.prefixMatches,
            containsMatches: generic?.containsMatches,
            patternRules: merchantRules + (generic?.patternRules ?? [])
        )
    }

    /// Synthesized SpendingCategory templates for merchants with a `brandCategory`
    /// block. Merged into the hand-authored templates by SeedDataLoader.
    static func brandCategoryTemplates() -> [CategoryJSON] {
        seed.merchants.compactMap { entry in
            guard let spec = entry.brandCategory else { return nil }
            return CategoryJSON(
                id: entry.category,
                nameEN: entry.name,
                nameZH_Hans: entry.name,
                nameZH_HK: entry.name,
                nameZH_TW: entry.name,
                emoji: spec.emoji ?? "🏷️",
                iconName: entry.merchantIconName,
                sortOrder: entry.sortOrder ?? 999,
                isDefault: false,
                parentCategoryID: spec.parent,
                level: "target",
                categoryLinks: spec.links?.map { CategoryLink(id: $0) },
                excludeFromParent: nil,
                cardFilter: nil,
                excludedPaymentMethods: nil,
                channels: nil,
                visibility: nil
            )
        }
    }
}
