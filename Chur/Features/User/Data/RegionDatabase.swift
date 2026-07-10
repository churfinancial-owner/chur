//
//  RegionDatabase.swift
//  Chur
//
//  Supported regions loaded from SeedDataRegions.json.
//  Single source of truth for country availability, flags, currency, etc.
//

import Foundation

// MARK: - Model

struct Region: Identifiable, Codable {
    let id: String              // "US", "CA", "HK"
    let name: String            // "United States"
    let flag: String            // "🇺🇸"
    let currency: String        // "USD"
    let currencySymbol: String  // "$"
    let isActive: Bool          // Whether this region is currently available
    let sortOrder: Int
    let localeIdentifiers: [String]  // Locale region codes that map to this region
}

// MARK: - Database

struct RegionDatabase {

    /// All regions defined in JSON (active + inactive), sorted by sortOrder
    private(set) static var allRegions: [Region] = loadAllRegions()

    /// Only regions the user can currently select (isActive == true)
    private(set) static var activeRegions: [Region] = allRegions.filter { $0.isActive }

    /// Lookup region by ID (e.g. "US")
    private(set) static var byID: [String: Region] = buildByID()

    /// Maps locale identifiers to region IDs (e.g. "PR" → "US", "HK" → "HK")
    private static var localeToRegion: [String: String] = buildLocaleToRegion()

    /// Reload all region data from the bundle JSON
    static func reloadFromBundle() {
        allRegions = loadAllRegions()
        activeRegions = allRegions.filter { $0.isActive }
        byID = buildByID()
        localeToRegion = buildLocaleToRegion()
    }

    /// Detect user's region from device locale, falling back to "US"
    static func detectUserRegion() -> String {
        let regionCode = Locale.current.region?.identifier ?? "US"
        return localeToRegion[regionCode] ?? "US"
    }

    /// Currency code for a given country (e.g. "US" → "USD")
    static func currencyCode(for countryID: String) -> String {
        byID[countryID]?.currency ?? "USD"
    }

    /// Currency symbol for a given country (e.g. "HK" → "HK$")
    static func currencySymbol(for countryID: String) -> String {
        byID[countryID]?.currencySymbol ?? "$"
    }

    /// Returns the flag emoji for a 2-letter ISO country code (e.g. "US" → "🇺🇸").
    /// Returns nil for invalid or nil input.
    static func flagEmoji(for code: String?) -> String? {
        guard let code = normalizeRegionCode(code) else { return nil }
        let scalars = code.unicodeScalars.compactMap { Unicode.Scalar(127397 + $0.value) }
        guard scalars.count == 2 else { return nil }
        return scalars.map { String($0) }.joined()
    }

    /// Normalizes a raw region/locale code to a canonical uppercase ISO country code.
    /// US territories (PR, VI, GU, AS, MP) are mapped to "US".
    /// Returns nil for blank or nil input.
    static func normalizeRegionCode(_ code: String?) -> String? {
        guard let raw = code?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(), !raw.isEmpty else { return nil }
        return ["PR", "VI", "GU", "AS", "MP"].contains(raw) ? "US" : raw
    }

    // MARK: - Private Loaders

    private static func loadAllRegions() -> [Region] {
        guard let url = Bundle.main.url(forResource: "SeedDataRegions", withExtension: "json") else {
            #if DEBUG
            print("❌ RegionDatabase: SeedDataRegions.json not found in bundle")
            #endif
            return []
        }
        do {
            let data = try Data(contentsOf: url)
            let regions = try JSONDecoder().decode([Region].self, from: data)
            return regions.sorted { $0.sortOrder < $1.sortOrder }
        } catch {
            #if DEBUG
            print("❌ RegionDatabase: Failed to decode SeedDataRegions.json: \(error)")
            #endif
            return []
        }
    }

    private static func buildByID() -> [String: Region] {
        Dictionary(allRegions.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    private static func buildLocaleToRegion() -> [String: String] {
        var map: [String: String] = [:]
        for region in allRegions {
            for locale in region.localeIdentifiers {
                map[locale] = region.id
            }
        }
        return map
    }
}
