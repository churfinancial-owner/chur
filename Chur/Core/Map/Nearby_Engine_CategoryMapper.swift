//
//  MerchantCategoryMapper.swift
//  Chur
//
//  Multi-strategy merchant-to-category mapping system.
//  Maps merchants to spending category IDs using five strategies:
//  1. Exact merchant name matching (TARGET-level categories like "apple", "united_airline")
//  1.5. Prefix + POI matching (brand prefix + MapKit POI confirmation, e.g. "Apple Stoneridge Mall" + Store)
//  1.7. Contains + POI matching (keyword anywhere in name + POI confirmation, e.g. "JW Marriott SF" + Hotel)
//  2. Pattern matching (CHILD-level categories like "fast_food", "gas_stations")
//  3. MapKit POI category mapping (converts MKPointOfInterestCategory to category IDs)
//
//  Note: Works in conjunction with NearbyPlacesService's bucket definitions,
//  which define which POI categories are requested from MapKit.
//
//  Created by Pak Ho on 3/1/26.
//

import Foundation

// Merchant name-matching rules (MerchantMappings and friends) are defined in
// Features/Rewards/DataModel/MerchantSeedDatabase.swift — the unified
// SeedDataMerchants.json is the single source for merchant data.

/// Maps merchants to spending category IDs using multiple strategies
struct MerchantCategoryMapper {

    /// Cached merchant mappings: genericMappings + per-merchant map rules from SeedDataMerchants.json
    private static var mappings: MerchantMappings? = MerchantSeedDatabase.combinedMappings

    /// Reload merchant mappings from the bundle JSON
    static func reloadFromBundle() {
        MerchantSeedDatabase.reloadFromBundle()
        mappings = MerchantSeedDatabase.combinedMappings
    }
    
    /// Maps a merchant to a category ID using multiple strategies
    /// Priority: Exact match > Prefix+POI > Contains+POI > Name pattern > POI category > Fallback
    /// Maps to child/target categories when possible for better accuracy
    static func mapToCategory(
        merchantName: String,
        poiCategory: String? = nil  // MKPointOfInterestCategory.rawValue
    ) -> String {
        // Strategy 1: Exact name matching for TARGET-level categories (highest confidence)
        if let exactMatch = exactMerchantMatch(merchantName) {
            return exactMatch
        }
        
        // Strategy 1.5: Prefix + POI confirmation (e.g. "Apple Stoneridge Mall" + Store → "apple")
        if let prefixMatch = prefixMerchantMatch(merchantName, poiCategory: poiCategory) {
            return prefixMatch
        }
        
        // Strategy 1.7: Contains + POI confirmation (e.g. "JW Marriott SF" + Hotel → "marriott_hotels")
        if let containsMatch = containsMerchantMatch(merchantName, poiCategory: poiCategory) {
            return containsMatch
        }
        
        // Strategy 2: Pattern matching for CHILD-level categories (high confidence)
        if let patternMatch = patternMerchantMatch(merchantName) {
            return patternMatch
        }
        
        // Strategy 3: MapKit POI category mapping (medium confidence)
        if let poiCategory = poiCategory {
            let poiMatch = mapPOICategory(poiCategory)
            if poiMatch != "everything" {
                return poiMatch
            }
        }
        
        // Strategy 4: Default fallback to parent categories
        return "everything"  // Everything Else
    }
    
    // MARK: - Strategy 1: Exact Merchant Matching (loaded from JSON)
    
    /// Exact merchant name matches for TARGET-level categories
    private static func exactMerchantMatch(_ merchantName: String) -> String? {
        guard let exactMatches = mappings?.exactMatches else { return nil }
        let name = merchantName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if let direct = exactMatches[name] {
            return direct
        }
        return exactMatches.first(where: { $0.key.lowercased() == name })?.value
    }
    
    // MARK: - Strategy 1.5: Prefix + POI Matching (loaded from JSON)
    
    /// Matches brand prefixes confirmed by MapKit POI category
    /// e.g. "Apple Stoneridge Mall" starts with "apple" AND POI is Store → "apple"
    private static func prefixMerchantMatch(_ merchantName: String, poiCategory: String?) -> String? {
        guard let prefixRules = mappings?.prefixMatches else { return nil }
        let name = merchantName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        for rule in prefixRules {
            if name.hasPrefix(rule.prefix.lowercased()) {
                // If POI confirmation is required, check it
                if let requiredPOI = rule.requiredPOI {
                    if poiCategory == requiredPOI {
                        return rule.categoryID
                    }
                    // POI doesn't match — skip this prefix rule
                } else {
                    // No POI required — prefix alone is sufficient
                    return rule.categoryID
                }
            }
        }
        
        return nil
    }
    
    // MARK: - Strategy 1.7: Contains + POI Matching (loaded from JSON)
    
    /// Matches keywords found anywhere in the merchant name, confirmed by optional POI category
    /// e.g. "JW Marriott San Francisco" contains "marriott" AND POI is Hotel → "marriott_hotels"
    private static func containsMerchantMatch(_ merchantName: String, poiCategory: String?) -> String? {
        guard let containsRules = mappings?.containsMatches else { return nil }
        let name = merchantName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        for rule in containsRules {
            if name.contains(rule.keyword.lowercased()) {
                if let requiredPOI = rule.requiredPOI {
                    if poiCategory == requiredPOI {
                        return rule.categoryID
                    }
                } else {
                    return rule.categoryID
                }
            }
        }
        
        return nil
    }
    
    // MARK: - Strategy 2: Pattern Matching (loaded from JSON)
    
    /// Pattern matching for CHILD-level categories
    private static func patternMerchantMatch(_ merchantName: String) -> String? {
        guard let rules = mappings?.patternRules else { return nil }
        let name = merchantName.lowercased()
        
        for rule in rules {
            if rule.patterns.contains(where: { name.contains($0.lowercased()) }) {
                // Check overrides first (e.g., "costco" gas station → costco_gas)
                if let overrides = rule.overrides {
                    for override in overrides {
                        if name.contains(override.ifContains.lowercased()) {
                            return override.categoryID
                        }
                    }
                }
                return rule.categoryID
            }
        }
        
        return nil  // No pattern match
    }
    
    // MARK: - Strategy 3: MapKit POI Category Mapping
    
    /// Maps MapKit's MKPointOfInterestCategory to our internal category IDs
    /// Returns "everything" if no specific mapping exists
    /// Note: Should stay aligned with NearbyPlacesService's bucket definitions
    private static func mapPOICategory(_ poiCategory: String) -> String {
        // MapKit POI categories to our category IDs
        switch poiCategory {
        // Dining & Food
        case "MKPOICategoryRestaurant":
            return "restaurants"
        case "MKPOICategoryCafe":
            return "cafe"
        case "MKPOICategoryBakery":
            return "restaurants"
        case "MKPOICategoryFoodMarket":
            return "supermarkets"
        case "MKPOICategoryBrewery", "MKPOICategoryWinery", "MKPOICategoryNightlife", "MKPOICategoryDistillery":
            return "bars"
            
        // Gas & Transportation
        case "MKPOICategoryGasStation":
            return "gas_stations"
        case "MKPOICategoryEVCharger":
            return "ev_charging"
        case "MKPOICategoryParking":
            return "parking"
        case "MKPOICategoryCarRental":
            return "car_rental"
        case "MKPOICategoryPublicTransport":
            return "transit"
            
        // Retail & Shopping
        case "MKPOICategoryStore":
            return "retail"
        case "MKPOICategoryPharmacy":
            return "pharmacy"
            
        // Travel & Lodging
        case "MKPOICategoryHotel":
            return "hotels"
            
        // Entertainment & Recreation
        case "MKPOICategoryTheater", "MKPOICategoryMovieTheater":
            return "movie_theaters"
        case "MKPOICategoryAmusementPark":
            return "entertainment"
        case "MKPOICategorymusicVenue":
            return "entertainment"
        case "MKPOICategoryMuseum":
            return "entertainment"
        case "MKPOICategoryAquarium":
            return "entertainment"
        case "MKPOICategoryZoo":
            return "entertainment"
        case "MKPOICategoryNationalPark":
            return "entertainment"
        case "MKPOICategoryStadium":
            return "entertainment"
        case "MKPOICategoryCampground":
            return "entertainment"
        case "MKPOICategoryMarina":
            return "entertainment"
            
        // Fitness & Health
        case "MKPOICategoryFitnessCenter":
            return "gym_fitness_centers"
        case "MKPOICategorySpa":
            return "spa"
        case "MKPOICategoryHospital":
            return "hospital"
            
        // PERSONAL CARE CATEGORIES
        
        case "MKPOICategoryBeauty":
            return "Barber_Salons"
        case "MKPOICategoryLaundry":
            return "laundry"
            
        // Financial & Services
        case "MKPOICategoryPostOffice":
            return "shipping"
        case "MKPOICategoryAnimalService":
            return "veterinarian"
            
        // Automotive
        case "MKPOICategoryAutomotiveRepair":
            return "auto_shop"
            
        // Recreation
        case "MKPOICategoryGolf", "MKPOICategoryMiniGolf":
            return "entertainment"
        case "MKPOICategoryBowling":
            return "entertainment"
        case "MKPOICategorySkiing":
            return "entertainment"
            
        // Education
        case "MKPOICategoryUniversity":
            return "everything"
            
        
        default:
            #if DEBUG
            print("⚠️ Unmapped POI category: \(poiCategory)")
            #endif
            return "everything"
        }
    }
}
