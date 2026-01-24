//
//  IssuerDatabase.swift
//  Chur
//
//  Card issuer metadata loaded from SeedDataIssuers.json.
//  Provides issuer logos, short names, and popularity info.
//

import Foundation

// MARK: - Model

struct Issuer: Identifiable, Codable {
    let id: String
    let name: String           // Full display name (matches card template issuer field)
    let shortName: String      // Abbreviated name for compact UI (pills, etc.)
    let logoImageName: String  // Asset catalog image name
    let countries: [String]    // Countries this issuer operates in
    let popularIn: [String]    // Countries where this issuer is considered popular
    let sortOrder: Int
}

// MARK: - Database

struct IssuerDatabase {

    /// All loaded issuers, sorted by sortOrder
    private(set) static var allIssuers: [Issuer] = loadAllIssuers()

    /// Lookup issuer by full name (e.g. "American Express")
    private(set) static var byName: [String: Issuer] = buildByName()

    /// Lookup issuer by ID (e.g. "american_express")
    private(set) static var byID: [String: Issuer] = buildByID()

    /// Reload all issuer data from the bundle JSON
    static func reloadFromBundle() {
        allIssuers = loadAllIssuers()
        byName = buildByName()
        byID = buildByID()
    }

    /// Popular issuers for a given country, sorted by sortOrder
    static func popularIssuers(for country: String) -> [Issuer] {
        allIssuers.filter { $0.popularIn.contains(country) }
    }

    /// All issuers available in a given country, sorted by sortOrder
    static func issuers(for country: String) -> [Issuer] {
        allIssuers.filter { $0.countries.contains(country) }
    }

    // MARK: - Private Loaders

    private static func loadAllIssuers() -> [Issuer] {
        guard let url = Bundle.main.url(forResource: "SeedDataIssuers", withExtension: "json") else {
            #if DEBUG
            print("❌ IssuerDatabase: SeedDataIssuers.json not found in bundle")
            #endif
            return []
        }
        do {
            let data = try Data(contentsOf: url)
            let issuers = try JSONDecoder().decode([Issuer].self, from: data)
            return issuers.sorted { $0.sortOrder < $1.sortOrder }
        } catch {
            #if DEBUG
            print("❌ IssuerDatabase: Failed to decode SeedDataIssuers.json: \(error)")
            #endif
            return []
        }
    }

    private static func buildByName() -> [String: Issuer] {
        Dictionary(allIssuers.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })
    }

    private static func buildByID() -> [String: Issuer] {
        Dictionary(allIssuers.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }
}
