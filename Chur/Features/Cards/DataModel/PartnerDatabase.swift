//
//  PartnerDatabase.swift
//  Chur
//
//  Partner metadata for non-bank entities (airlines, hotels, merchants).
//  Single source of truth for display names, logos, alliances, and localization.
//  Used by TransferPartnerDatabase and NewsDetailView footer.
//

import Foundation

// MARK: - Model

struct Partner: Identifiable, Codable {
    let id: String
    let name: String              // Full display name (e.g. "Singapore Airlines")
    let shortName: String         // Compact form for pills and lists (e.g. "Singapore")
    let type: String              // "airline", "hotel", "merchant"
    let logoImageName: String?    // Asset catalog image name, nil if unavailable
    let alliance: String?         // "star", "oneworld", "skyteam", or nil
    let localizedNames: [String: String]?  // e.g. { "zh-HK": "新加坡航空" }

    /// Returns localizedNames[locale] if available, otherwise shortName.
    func displayName(locale: String? = nil) -> String {
        guard let locale, let localized = localizedNames?[locale] else { return shortName }
        return localized
    }
}

// MARK: - Database

struct PartnerDatabase {

    /// All loaded partners in source order
    private(set) static var allPartners: [Partner] = loadAllPartners()

    /// Lookup by partner id (e.g. "delta", "hilton")
    private(set) static var byID: [String: Partner] = buildByID()

    /// Lookup by shortName (e.g. "Delta", "Hilton")
    private(set) static var byName: [String: Partner] = buildByName()

    static func reloadFromBundle() {
        allPartners = loadAllPartners()
        byID = buildByID()
        byName = buildByName()
    }

    /// All partners of a given type ("airline", "hotel", "merchant")
    static func partners(ofType type: String) -> [Partner] {
        allPartners.filter { $0.type == type }
    }

    // MARK: - Private Loaders

    private static func loadAllPartners() -> [Partner] {
        guard let url = Bundle.main.url(forResource: "SeedDataPartners", withExtension: "json") else {
            #if DEBUG
            print("❌ PartnerDatabase: SeedDataPartners.json not found in bundle")
            #endif
            return []
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([Partner].self, from: data)
        } catch {
            #if DEBUG
            print("❌ PartnerDatabase: Failed to decode SeedDataPartners.json: \(error)")
            #endif
            return []
        }
    }

    private static func buildByID() -> [String: Partner] {
        Dictionary(allPartners.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    private static func buildByName() -> [String: Partner] {
        Dictionary(allPartners.map { ($0.shortName, $0) }, uniquingKeysWith: { first, _ in first })
    }
}
