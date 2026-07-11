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

    /// Minimal decode of SeedDataOnlineMerchants.json — only what validation needs.
    private struct OnlineMerchantEntry: Codable {
        let id: String
        let category: String
        let merchantIconName: String?
    }

    /// Minimal mirror of SeedDataMerchantMappings.json — mirrors the private
    /// structs in Nearby_Engine_CategoryMapper.swift; only categoryIDs are validated.
    private struct MerchantMappings: Codable {
        struct PrefixMatch: Codable { let prefix: String; let categoryID: String }
        struct ContainsMatch: Codable { let keyword: String; let categoryID: String }
        struct PatternRule: Codable {
            struct Override: Codable { let ifContains: String; let categoryID: String }
            let patterns: [String]
            let categoryID: String
            let overrides: [Override]?
        }
        let exactMatches: [String: String]
        let prefixMatches: [PrefixMatch]?
        let containsMatches: [ContainsMatch]?
        let patternRules: [PatternRule]

        /// Every categoryID referenced anywhere in the mapping file, with a label for reporting.
        var allCategoryRefs: [(source: String, categoryID: String)] {
            var refs: [(String, String)] = exactMatches.map { ("exactMatch '\($0.key)'", $0.value) }
            refs += (prefixMatches ?? []).map { ("prefixMatch '\($0.prefix)'", $0.categoryID) }
            refs += (containsMatches ?? []).map { ("containsMatch '\($0.keyword)'", $0.categoryID) }
            for rule in patternRules {
                refs.append(("patternRule \(rule.patterns)", rule.categoryID))
                refs += (rule.overrides ?? []).map { ("patternRule \(rule.patterns) override", $0.categoryID) }
            }
            return refs
        }
    }

    static func run() {
        var issues: [String] = []

        // MARK: Category tree integrity
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

        // MARK: Online merchants
        for merchant in decode([OnlineMerchantEntry].self, from: "SeedDataOnlineMerchants") {
            if !categoryIDs.contains(merchant.category) {
                issues.append("Online merchant '\(merchant.id)': category '\(merchant.category)' does not exist")
            }
            if let icon = merchant.merchantIconName, UIImage(named: icon) == nil {
                issues.append("Online merchant '\(merchant.id)': icon asset '\(icon)' not found")
            }
        }

        // MARK: Map merchant mappings
        if let mappings = decodeObject(MerchantMappings.self, from: "SeedDataMerchantMappings") {
            for ref in mappings.allCategoryRefs where !categoryIDs.contains(ref.categoryID) {
                issues.append("Map mapping \(ref.source): categoryID '\(ref.categoryID)' does not exist")
            }
        } else {
            issues.append("Could not load or decode SeedDataMerchantMappings.json")
        }

        // MARK: Pricing invariants
        issues.append(contentsOf: checkPricingInvariants(templates: templates))

        if issues.isEmpty {
            print("✅ SeedDataValidator: all seed data checks passed (\(templates.count) categories)")
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
            ("stream_netflix", "streaming", true) // 3-level ancestor walk
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

    private static func decode<T: Decodable & ExpressibleByArrayLiteral>(_ type: T.Type, from filename: String) -> T {
        guard let decoded = decodeObject(T.self, from: filename) else {
            print("⚠️ SeedDataValidator: could not load or decode '\(filename).json'")
            return []
        }
        return decoded
    }

    private static func decodeObject<T: Decodable>(_ type: T.Type, from filename: String) -> T? {
        guard let url = Bundle.main.url(forResource: filename, withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}
#endif
