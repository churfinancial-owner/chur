//
//  SeedDataValidator.swift
//  Chur
//
//  DEBUG-only validation of the seed JSON files. Runs once at launch and prints
//  ⚠️ for every broken reference plus a set of pricing invariants, so a bad
//  merchant/category edit is caught immediately instead of silently falling
//  back to the "everything" rate.
//

#if DEBUG
import Foundation
import UIKit

enum SeedDataValidator {

    static func run() {
        var issues: [String] = []

        // MARK: Category tree integrity
        // loadCategoryTemplates() already includes brand categories auto-generated
        // from SeedDataMerchants.json, so those participate in every check below.
        let templates = SeedDataLoader.loadCategoryTemplates()
        let categoryIDs = Set(templates.map(\.id))

        for template in templates {
            if let parentID = template.parentCategoryID, !categoryIDs.contains(parentID) {
                issues.append("Category '\(template.id)': parentCategoryID '\(parentID)' does not exist")
            }
            for link in template.categoryLinks ?? [] where !categoryIDs.contains(link.id) {
                issues.append("Category '\(template.id)': categoryLink '\(link.id)' does not exist")
            }
            // Walk the parent chain to catch cycles and broken intermediate levels
            var visited = Set<String>()
            var currentID = template.parentCategoryID
            while let id = currentID {
                if visited.contains(id) {
                    issues.append("Category '\(template.id)': cycle in parent chain at '\(id)'")
                    break
                }
                visited.insert(id)
                currentID = templates.first { $0.id == id }?.parentCategoryID
            }
        }

        // MARK: Unified merchant seed (SeedDataMerchants_*.json)
        let seedFile = MerchantSeedDatabase.seed
        if seedFile.merchants.isEmpty {
            issues.append("No merchants loaded from SeedDataMerchants_*.json (missing or failed to decode?)")
        }
        // Entries span multiple group files — catch the same merchant pasted into two files
        var seenMerchantIDs = Set<String>()
        for merchant in seedFile.merchants {
            if !seenMerchantIDs.insert(merchant.id).inserted {
                issues.append("Merchant '\(merchant.id)': duplicate entry across SeedDataMerchants_*.json files")
            }
        }
        for merchant in seedFile.merchants {
            if !categoryIDs.contains(merchant.category) {
                issues.append("Merchant '\(merchant.id)': category '\(merchant.category)' does not exist")
            }
            if let icon = merchant.merchantIconName, UIImage(named: icon) == nil {
                issues.append("Merchant '\(merchant.id)': icon asset '\(icon)' not found")
            }
            if let mapCategory = merchant.map?.categoryID, !categoryIDs.contains(mapCategory) {
                issues.append("Merchant '\(merchant.id)': map categoryID '\(mapCategory)' does not exist")
            }
            for override in merchant.map?.overrides ?? [] where !categoryIDs.contains(override.categoryID) {
                issues.append("Merchant '\(merchant.id)': map override categoryID '\(override.categoryID)' does not exist")
            }
            if let parent = merchant.brandCategory?.parent, !categoryIDs.contains(parent) {
                issues.append("Merchant '\(merchant.id)': brandCategory parent '\(parent)' does not exist")
            }
            for link in merchant.brandCategory?.links ?? [] where !categoryIDs.contains(link) {
                issues.append("Merchant '\(merchant.id)': brandCategory link '\(link)' does not exist")
            }
            // `businessRegion` is the only source of the cross-border FX fee for online
            // merchants: it becomes `acceptedRegions`, and with it nil `isCrossBorderSpend`
            // returns false for every card. Nothing else reports the omission — the rate is
            // simply quoted too high, which reads as correct. All 77 merchants were missing
            // it until 2026-08-15, so this check exists to stop it recurring one merchant
            // at a time.
            //
            // A merchant opts out with `globalBilling: true`, which is how an intentional
            // omission is told apart from a forgotten one. Airlines and subscriptions bill the
            // customer in their own currency and are genuinely global; without the marker this
            // fired 22 times a launch, which would have trained everyone to ignore the one case
            // that matters. Scoping it to "has a map block" was tried first and failed —
            // airlines and Netflix have map blocks too.
            let listedRegions = Set((merchant.featured ?? []) + (merchant.popular ?? []))
            if merchant.businessRegion == nil, merchant.globalBilling != true,
               !listedRegions.isEmpty, listedRegions != ["US"] {
                issues.append("Merchant '\(merchant.id)': listed in \(listedRegions.sorted().joined(separator: "/")) but declares neither businessRegion nor globalBilling — cross-border FX will not be applied for any card")
            }
            if merchant.businessRegion != nil, merchant.globalBilling == true {
                issues.append("Merchant '\(merchant.id)': has both businessRegion and globalBilling — pricing follows businessRegion, so the globalBilling claim is wrong")
            }
            // An empty array is worse than a missing one: `Set([])` is not nil, so
            // `isCrossBorderSpend` finds no card's region in it and charges FX to everyone.
            // Nothing has this today; the check makes sure nothing acquires it.
            if merchant.businessRegion?.isEmpty == true {
                issues.append("Merchant '\(merchant.id)': businessRegion is an empty array — this charges the FX fee to every card. Use null for a global merchant")
            }
        }

        // Two merchants claiming the same map pattern is decided by file enumeration order,
        // so the loser never matches and the winner mis-prices the other's stores. Found on
        // 2026-08-15 with `costco` and `target` both claiming "target" — which would have
        // priced Target as Costco, whose category is Visa-only, hiding most of the wallet.
        var patternOwner: [String: String] = [:]
        for merchant in seedFile.merchants {
            for pattern in merchant.map?.patterns ?? [] {
                let key = pattern.lowercased()
                if let owner = patternOwner[key], owner != merchant.id {
                    issues.append("Merchant '\(merchant.id)': map pattern '\(pattern)' is already claimed by '\(owner)' — whichever file loads first wins, so one of them never matches")
                } else {
                    patternOwner[key] = merchant.id
                }
            }
        }

        // MARK: Generic map mappings
        //
        // A single malformed entry fails the decode of the whole file, and the whole file is
        // every generic map rule there is — so one typo silently costs all map name-matching,
        // not just its own rule. It happened on 2026-08-15: three new rules were added to
        // `containsMatches` using `prefix` (the key `prefixMatches` takes) instead of
        // `keyword`, and the console error was easy to read past because the app carried on
        // working, just worse at recognising places.
        if seedFile.genericMappings == nil {
            issues.append("SeedDataGenericMappings.json did not decode — every generic map rule is missing, so most places will fall back to a generic category. Check the ❌ MerchantSeedDatabase line above for the failing key and index")
        }
        if let generic = seedFile.genericMappings {
            var refs: [(source: String, categoryID: String)] =
                generic.exactMatches.map { ("exactMatch '\($0.key)'", $0.value) }
            refs += (generic.prefixMatches ?? []).map { ("prefixMatch '\($0.prefix)'", $0.categoryID) }
            refs += (generic.containsMatches ?? []).map { ("containsMatch '\($0.keyword)'", $0.categoryID) }
            for rule in generic.patternRules {
                refs.append(("patternRule \(rule.patterns)", rule.categoryID))
                refs += (rule.overrides ?? []).map { ("patternRule \(rule.patterns) override", $0.categoryID) }
            }
            for ref in refs where !categoryIDs.contains(ref.categoryID) {
                issues.append("Map mapping \(ref.source): categoryID '\(ref.categoryID)' does not exist")
            }
        }

        // MARK: Card → benefit references
        // A card listing a benefit id BenefitDatabase can't resolve shows no perk
        // and reports nothing anywhere else: enumerateFolder drops a file it can't
        // decode, and CardSyncService.syncBenefits skips an unresolvable id. Both
        // are silent, so a benefit can be missing from the app for months.
        let loadedBenefitIDs = Set(BenefitDatabase.getAllBenefits().map(\.id))
        for card in CardDatabase.getAllCards() {
            for benefitID in card.benefitIDs where !loadedBenefitIDs.contains(benefitID) {
                issues.append("Card '\(card.id)': benefit '\(benefitID)' did not load — no file with that id, or its JSON failed to decode as _BenefitJSON")
            }
        }

        // MARK: Pricing invariants
        issues.append(contentsOf: checkPricingInvariants(templates: templates))

        print("ℹ️ SeedDataValidator: \(loadedBenefitIDs.count) benefits loaded")

        if issues.isEmpty {
            print("✅ SeedDataValidator: all seed data checks passed (\(templates.count) categories, \(seedFile.merchants.count) merchants)")
        } else {
            for issue in issues { print("⚠️ SeedDataValidator: \(issue)") }
            print("⚠️ SeedDataValidator: \(issues.count) issue(s) found")
        }
    }

    /// Known-good matching behavior for key merchants. If a cleanup pass over the
    /// seed JSON breaks one of these, it shows up here instead of as a wrong price.
    private static func checkPricingInvariants(templates: [CategoryJSON]) -> [String] {
        let categories = templates.map { template in
            SpendingCategory(
                id: template.id,
                nameEN: template.nameEN,
                nameZH_Hans: template.nameZH_Hans,
                nameZH_HK: template.nameZH_HK,
                nameZH_TW: template.nameZH_TW,
                emoji: template.emoji,
                sortOrder: template.sortOrder,
                parentCategoryID: template.parentCategoryID,
                level: template.level.flatMap { CategoryLevel(rawValue: $0) },
                categoryLinks: template.categoryLinks,
                excludeFromParent: template.excludeFromParent ?? false
            )
        }
        let byID = Dictionary(categories.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        // (merchant category, reward category, should match)
        let invariants: [(String, String, Bool)] = [
            ("costco", "wholesale", true),        // isolated brand reaches its link
            ("costco", "groceries", false),       // ...but must NOT cascade to groceries
            ("wholefood", "groceries", true),     // parent chain
            ("wholefood", "amazon", true),        // cross-link
            ("stream_netflix", "streaming", true) // auto-generated brand target → ancestor walk
        ]

        var issues: [String] = []
        for (categoryID, rewardCategory, expected) in invariants {
            guard let category = byID[categoryID] else {
                issues.append("Pricing invariant: category '\(categoryID)' missing from seed data")
                continue
            }
            let matches = CardRateCalculator.categoryMatches(
                rewardCategory: rewardCategory,
                category: category,
                allCategories: categories
            )
            if matches != expected {
                issues.append("Pricing invariant broken: '\(categoryID)' vs reward '\(rewardCategory)' — expected \(expected ? "match" : "no match"), got \(matches ? "match" : "no match")")
            }
        }
        return issues
    }
}
#endif
