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
        }

        // MARK: Generic map mappings
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

        // MARK: Pricing invariants
        issues.append(contentsOf: checkPricingInvariants(templates: templates))

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
