//
//  OnlineMerchantDatabase.swift
//  Chur
//
//  Online merchant model and database loader.
//  Loads curated online merchants from SeedDataOnlineMerchants.json
//  and provides search/filtering capabilities for the Online search mode.
//

import Foundation

// MARK: - Online Merchant Model

struct OnlineMerchant: Identifiable, Codable {
    let id: String
    let name: String
    let domain: String?
    let category: String              // Maps to SpendingCategory.id (e.g., "online_retail", "streaming")
    let merchantIconName: String?
    let affiliateID: String?
    let isBrandCategory: Bool?        // true = this merchant owns its category (e.g. "starbucks" → "starbucks"); false/nil = generic category (e.g. "retail", "flights")
    let businessRegion: [String]?     // ["HK", "US"] or nil = global
    let tags: [String]?               // Alternative names / search keywords
    let sortOrder: Int?               // Controls sort order only — use `popular` to control list visibility
    let merchantDescription: String?
    let featured: [String]?           // Country codes where this merchant is featured (e.g., ["US", "HK"])
    let popular: [String]?            // Country codes where this merchant appears in the popular/default list
    let paymentMethods: [String]?     // Accepted payment methods: "apple_pay", "paypal_pay", "mobile_pay" — nil = unknown (no restriction applied)
}

// MARK: - Online Merchant Database

struct OnlineMerchantDatabase {
    
    /// All loaded online merchants, sorted by sortOrder (nil sorted last) then name.
    private(set) static var allMerchants: [OnlineMerchant] = loadAllMerchants()

    /// Reload merchant data from the bundle JSON
    static func reloadFromBundle() {
        allMerchants = loadAllMerchants()
        _merchantByCategory = buildMerchantByCategory()
    }

    private static func loadAllMerchants() -> [OnlineMerchant] {
        guard let url = Bundle.main.url(forResource: "SeedDataOnlineMerchants", withExtension: "json") else {
            #if DEBUG
            print("❌ OnlineMerchantDatabase: SeedDataOnlineMerchants.json not found in bundle")
            #endif
            return []
        }
        do {
            let data = try Data(contentsOf: url)
            let merchants = try JSONDecoder().decode([OnlineMerchant].self, from: data)
            return merchants.sorted { lhs, rhs in
                switch (lhs.sortOrder, rhs.sortOrder) {
                case let (l?, r?) where l != r: return l < r
                case (_?, nil): return true   // non-nil before nil
                case (nil, _?): return false
                default: return lhs.name < rhs.name
                }
            }
        } catch {
            #if DEBUG
            print("❌ OnlineMerchantDatabase: Failed to decode: \(error)")
            #endif
            return []
        }
    }
    
    /// Whether a merchant is available in the given country.
    /// A merchant matches if businessRegion contains the country, or is nil/empty (global).
    static func isAvailable(_ merchant: OnlineMerchant, inCountry country: String) -> Bool {
        guard let regions = merchant.businessRegion, !regions.isEmpty else { return true }
        return regions.contains(country)
    }
    
    /// Featured merchants for a region: country must be in the `featured` array, has an icon, in-region.
    static func featured(forCountry country: String, limit: Int = 9) -> [OnlineMerchant] {
        allMerchants
            .filter {
                guard let regions = $0.featured, regions.contains(country) else { return false }
                return $0.merchantIconName != nil && isAvailable($0, inCountry: country)
            }
            .prefix(limit)
            .map { $0 }
    }
    
    /// Popular merchants for a region (default list when not searching).
    /// Only includes merchants whose `popular` array contains the given country.
    static func popular(forCountry country: String) -> [OnlineMerchant] {
        allMerchants.filter { $0.popular?.contains(country) == true }
    }
    
    /// Search merchants by name or tags using case-insensitive contains matching.
    /// Filters to region-available merchants. Returns popular list if query is empty.
    static func search(query: String, country: String) -> [OnlineMerchant] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return popular(forCountry: country) }
        
        return allMerchants.filter { merchant in
            // Must be available in the user's region
            guard isAvailable(merchant, inCountry: country) else { return false }
            // Match on name
            if merchant.name.lowercased().contains(trimmed) { return true }
            // Match on domain
            if let domain = merchant.domain, domain.lowercased().contains(trimmed) { return true }
            // Match on tags
            if let tags = merchant.tags {
                if tags.contains(where: { $0.lowercased().contains(trimmed) }) { return true }
            }
            return false
        }
    }
    
    /// Legacy search without region filter (kept for compatibility).
    static func search(query: String) -> [OnlineMerchant] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return allMerchants }
        
        return allMerchants.filter { merchant in
            if merchant.name.lowercased().contains(trimmed) { return true }
            if let domain = merchant.domain, domain.lowercased().contains(trimmed) { return true }
            if let tags = merchant.tags {
                if tags.contains(where: { $0.lowercased().contains(trimmed) }) { return true }
            }
            return false
        }
    }
    
    // MARK: - Category → Merchant Bridge
    
    /// Cached lookup: categoryID → first OnlineMerchant with that category.
    /// Enables the map path to resolve a NearbyMerchant's categoryID to the canonical OnlineMerchant.
    private static var _merchantByCategory: [String: OnlineMerchant] = buildMerchantByCategory()

    private static func buildMerchantByCategory() -> [String: OnlineMerchant] {
        var dict: [String: OnlineMerchant] = [:]
        for merchant in allMerchants {
            // First merchant wins (allMerchants is sorted by sortOrder, so the most prominent entry takes priority)
            if dict[merchant.category] == nil {
                dict[merchant.category] = merchant
            }
        }
        return dict
    }
    
    /// Look up the canonical OnlineMerchant for a given categoryID.
    /// Only returns a merchant when isBrandCategory is true — meaning the category
    /// is exclusive to this brand (e.g. "starbucks", "marriott_hotels").
    /// Returns nil for generic categories like "retail", "flights", "department_stores"
    /// where many unrelated businesses share the same categoryID.
    static func merchant(forCategory categoryID: String) -> OnlineMerchant? {
        guard let merchant = _merchantByCategory[categoryID],
              merchant.isBrandCategory == true else { return nil }
        return merchant
    }
    
    /// Look up a brand icon name by categoryID (e.g. "marriott_hotels" → "icon_marriott").
    /// Only returns an icon for brand-owned categories (isBrandCategory == true).
    /// Generic categories fall through to nil so the UI can show a category icon instead.
    static func brandIconName(forCategory categoryID: String) -> String? {
        merchant(forCategory: categoryID)?.merchantIconName
    }
    
    /// Convert an OnlineMerchant to a NearbyMerchant so it can be fed into
    /// the existing NearbyRecommendationEngine / CardRateCalculator pipeline.
    static func toNearbyMerchant(_ merchant: OnlineMerchant) -> NearbyMerchant {
        NearbyMerchant(
            id: merchant.id,
            name: merchant.name,
            categoryID: merchant.category,
            latitude: 0,
            longitude: 0,
            distance: 0,
            address: merchant.domain ?? "",
            region: merchant.businessRegion?.first,  // Use first region for card filtering
            poiCategory: nil,
            paymentMethods: merchant.paymentMethods.map { Set($0) }
        )
    }
}
