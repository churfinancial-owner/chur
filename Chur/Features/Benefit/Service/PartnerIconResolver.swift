//
//  PartnerIconResolver.swift
//  Chur
//
//  Turns a benefit's partner into an icon name that `IconArtView` can render.
//
//  `Benefit.partnerID` existed since the model was written and was read by
//  nothing — `DataDictionary.md` described it as a "stable partner/merchant
//  identifier for future cross-reference". This is that cross-reference.
//
//  Two things about the shape of this, both deliberate:
//
//  1. **`partnerName` is the primary key, not `partnerID`.** Only 24 of 276
//     benefits carry a `partnerID`; 195 name a partner at all. So the
//     resolver reads `partnerID` first as an *override* and falls back to
//     `partnerName`, which means the common case needs no data authoring at all
//     and a stale `partnerID` can never *hide* a working `partnerName`.
//
//  2. **Four namespaces, in a fixed order.** A partner can be an issuer
//     ("Chase Travel"), a transfer partner ("Hilton"), an online merchant
//     ("Grubhub") or a spending category ("Uber"). They overlap, so the order
//     below is the tie-break and is part of the contract — issuers first
//     because an issuer-operated portal should show the bank's mark, then
//     partners, whose logos are the most brand-accurate, then merchants, then
//     categories, which are the broadest and least specific.
//
//  The cost of keying on display text is that renaming a merchant's `name`
//  silently drops an icon. `SeedDataValidator` prints the full resolution
//  table on every run for exactly that reason — an icon that quietly falls
//  back reads as intentional, which is the failure mode `IconArtView`'s own
//  header warns about.
//

import Foundation

struct PartnerIconResolver {

    // MARK: - Public

    /// The icon name for a benefit's partner, or nil when the partner is
    /// unknown, has no artwork, or the benefit names no partner at all
    /// (81 of 276 — Global Entry, TSA PreCheck, generic statement credits).
    static func iconName(partnerID: String?, partnerName: String?) -> String? {
        if let partnerID, let hit = lookup(partnerID) { return hit.iconName }
        if let partnerName, let hit = lookup(partnerName) { return hit.iconName }
        return nil
    }

    /// Full resolution result, for `SeedDataValidator`'s coverage report.
    /// Callers that only need to draw something want `iconName` above.
    static func resolve(partnerID: String?, partnerName: String?) -> Match? {
        if let partnerID, let hit = lookup(partnerID) { return hit }
        if let partnerName, let hit = lookup(partnerName) { return hit }
        return nil
    }

    struct Match {
        let namespace: Namespace
        /// The normalized key that matched, for diagnostics.
        let key: String
        let iconName: String
    }

    enum Namespace: String {
        case issuer, partner, merchant, category
    }

    // MARK: - Lookup

    private static func lookup(_ raw: String) -> Match? {
        for key in candidateKeys(raw) {
            for namespace in order {
                if let icon = index[namespace]?[key], !icon.isEmpty {
                    return Match(namespace: namespace, key: key, iconName: icon)
                }
            }
        }
        return nil
    }

    private static let order: [Namespace] = [.issuer, .partner, .merchant, .category]

    /// Normalization, in the order they are tried. The full string wins over any
    /// trimmed form, so "Disney Stores" matches the `disney_stores` category
    /// rather than collapsing to "disney".
    ///
    /// - the normalized string ("American Express Travel" → `american express travel`)
    /// - the same with one trailing qualifier removed (→ `american express`),
    ///   which is what makes the six issuer travel portals resolve
    /// - the same with all spaces removed (`u s bank` → `usbank`), which covers
    ///   punctuation spelt differently on the two sides ("U.S. Bank" / "US Bank")
    static func candidateKeys(_ raw: String) -> [String] {
        let base = normalize(raw)
        guard !base.isEmpty else { return [] }

        var keys = [base]
        for qualifier in trailingQualifiers where base.hasSuffix(" \(qualifier)") {
            let trimmed = String(base.dropLast(qualifier.count + 1))
            if !trimmed.isEmpty { keys.append(trimmed) }
            break
        }
        let collapsed = base.replacingOccurrences(of: " ", with: "")
        if collapsed != base { keys.append(collapsed) }
        return keys
    }

    private static let trailingQualifiers = [
        "travel", "airlines", "airline", "air lines", "hotels", "hotel", "group", "inc"
    ]

    /// Lowercase, drop apostrophes outright (so "McDonald's" and "mcdonalds"
    /// agree), turn every other run of non-alphanumerics into a single space.
    static func normalize(_ raw: String) -> String {
        let stripped = raw.lowercased().filter { $0 != "'" && $0 != "\u{2019}" && $0 != "`" }
        let spaced: [Character] = stripped.map { character in
            character.isLetter || character.isNumber ? character : " "
        }
        return String(spaced).split(separator: " ").joined(separator: " ")
    }

    // MARK: - Index

    /// Rebuilt whenever content is refreshed — every source below prefers
    /// remotely published data, so an index built once at launch would serve
    /// the previous publish for the rest of the session. Wired into
    /// `ContentRefreshCoordinator.reloadDatabases()` alongside its sources.
    private(set) static var index: [Namespace: [String: String]] = buildIndex()

    static func reloadFromBundle() {
        index = buildIndex()
    }

    private static func buildIndex() -> [Namespace: [String: String]] {
        var built: [Namespace: [String: String]] = [:]

        // First key wins within a namespace, matching how every other database
        // here resolves a collision (`uniquingKeysWith: { first, _ in first }`).
        func add(_ namespace: Namespace, _ names: [String?], _ icon: String?) {
            guard let icon, !icon.isEmpty else { return }
            for case let name? in names {
                let key = normalize(name)
                guard !key.isEmpty else { continue }
                if built[namespace]?[key] == nil { built[namespace, default: [:]][key] = icon }

                // The space-stripped form is indexed as well as queried, or the
                // variant only works when the *query* is the punctuated side.
                // "U.S. Bank" normalizes to `u s bank` and the issuer is spelt
                // "US Bank" → `us bank`; neither is a prefix or suffix of the
                // other, and only `usbank` on both sides makes them meet.
                let collapsed = key.replacingOccurrences(of: " ", with: "")
                if collapsed != key, built[namespace]?[collapsed] == nil {
                    built[namespace, default: [:]][collapsed] = icon
                }
            }
        }

        for issuer in IssuerDatabase.allIssuers {
            add(.issuer, [issuer.id, issuer.name, issuer.shortName], issuer.logoImageName)
        }
        for partner in PartnerDatabase.allPartners {
            add(.partner, [partner.id, partner.name, partner.shortName], partner.logoImageName)
        }
        for merchant in MerchantSeedDatabase.seed.merchants {
            add(.merchant, [merchant.id, merchant.name], merchant.merchantIconName)
        }
        for category in SeedDataLoader.loadCategoryTemplates() {
            add(.category, [category.id, category.nameEN], category.iconName)
        }

        return built
    }
}

// MARK: - Convenience

extension Benefit {
    /// The partner icon for this benefit, or nil. See `PartnerIconResolver`.
    var partnerIconName: String? {
        PartnerIconResolver.iconName(partnerID: partnerID, partnerName: partnerName)
    }
}
