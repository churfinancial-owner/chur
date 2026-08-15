//
//  MerchantSeedDatabase.swift
//  Chur
//
//  Unified merchant seed. Merchants live in SeedDataMerchants_<group>.json
//  files (plain arrays, concatenated at load — grouping is organizational only,
//  mirroring SeedDataCategories_*.json); non-merchant map rules live in
//  SeedDataGenericMappings.json. One entry per merchant covers online search,
//  map name-matching, and an optional auto-generated brand target category.
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

    /// `true` = deliberately global: the customer is billed in their own currency, so no
    /// cross-border fee applies anywhere (airline tickets, streaming subscriptions).
    /// Read only by `SeedDataValidator`, to tell an intentional omission of `businessRegion`
    /// from a forgotten one. Pricing reads `businessRegion` and nothing else.
    let globalBilling: Bool?
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

        /// "hidden" drops the synthesized category from the picker while keeping
        /// its id resolvable. This is how a brand category is retired: deleting
        /// the merchant instead would strand every `User.selectedCategories`
        /// entry pointing at it, which the publish id-lock refuses.
        let visibility: String?
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

/// In-memory aggregate of all SeedDataMerchants_*.json files + SeedDataGenericMappings.json.
struct MerchantSeedFile {
    let merchants: [MerchantEntry]
    let genericMappings: MerchantMappings?
}

// MARK: - Database

struct MerchantSeedDatabase {

    private(set) static var seed: MerchantSeedFile = loadSeed()

    /// Rebuilds the merchant seed. Prefers remotely published content when
    /// `FeatureFlags.remoteContentEnabled` is on and a payload is cached,
    /// otherwise reads the bundled JSON. Name kept for symmetry with the other
    /// `reloadFromBundle()` databases called together in reset_refresh_tool.
    static func reloadFromBundle() {
        seed = loadSeed()
    }

    /// Decodes a remotely published bundle, or nil when the feature is off,
    /// nothing is cached, or the payload doesn't match the expected shape.
    /// Each half falls back independently, so bad mappings can't cost the
    /// merchant list (and vice versa).
    private static func decodeRemote<T: Decodable>(_ domain: ContentDomain) -> T? {
        guard FeatureFlags.remoteContentEnabled,
              let data = ContentStore.data(for: domain) else { return nil }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            #if DEBUG
            print("❌ MerchantSeedDatabase: remote '\(domain.rawValue)' failed to decode, using bundled JSON: \(error)")
            #endif
            return nil
        }
    }

    private static func loadSeed() -> MerchantSeedFile {
        // Remotely published content wins when present and decodable; a decode
        // failure is the last safety net for a bad publish, so it falls through
        // to the bundled JSON rather than leaving the user with nothing.
        let remoteMerchants: [MerchantEntry]? = decodeRemote(.merchants)
        let remoteMappings: MerchantMappings? = decodeRemote(.merchantMappings)

        if let remoteMerchants, !remoteMerchants.isEmpty {
            return MerchantSeedFile(merchants: remoteMerchants,
                                    genericMappings: remoteMappings ?? bundledMappings())
        }

        var merchants: [MerchantEntry] = []
        let merchantURLs = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: nil)?
            .filter { $0.lastPathComponent.hasPrefix("SeedDataMerchants_") } ?? []

        for url in merchantURLs {
            do {
                let data = try Data(contentsOf: url)
                let batch = try JSONDecoder().decode([MerchantEntry].self, from: data)
                merchants.append(contentsOf: batch)
            } catch {
                #if DEBUG
                print("❌ MerchantSeedDatabase: Failed to decode '\(url.lastPathComponent)': \(error)")
                #endif
            }
        }
        #if DEBUG
        if merchantURLs.isEmpty {
            print("❌ MerchantSeedDatabase: no SeedDataMerchants_*.json files found in bundle")
        }
        #endif

        return MerchantSeedFile(merchants: merchants,
                                genericMappings: remoteMappings ?? bundledMappings())
    }

    private static func bundledMappings() -> MerchantMappings? {
        guard let url = Bundle.main.url(forResource: "SeedDataGenericMappings", withExtension: "json") else {
            return nil
        }
        do {
            return try JSONDecoder().decode(MerchantMappings.self, from: try Data(contentsOf: url))
        } catch {
            #if DEBUG
            print("❌ MerchantSeedDatabase: Failed to decode SeedDataGenericMappings.json: \(error)")
            #endif
            return nil
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
                visibility: spec.visibility
            )
        }
    }
}
