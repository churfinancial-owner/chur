//
//  BoostProgramDatabase.swift
//  Chur
//
//  Created by Pak Ho on 2/17/26.
//

import Foundation

// MARK: - Models

struct BoostTier: Codable {
    let name: String        // "Gold", "Platinum Honors"
    let multiplier: Double  // 1.25 = 25% bonus on top of base rate
    let description: String // shown as subtitle in the picker
}

struct BoostProgram: Codable {
    let id: String
    let name: String
    let issuer: String              // for display purposes
    let eligibleTemplateIDs: [String]
    let tiers: [BoostTier]
    let footnote: String?
}

// MARK: - Database

struct BoostProgramDatabase {

    // MARK: - Lookup

    /// Returns the boost program that applies to a given card template ID, if any.
    static func program(for templateID: String?) -> BoostProgram? {
        guard let templateID else { return nil }
        return all.first { $0.eligibleTemplateIDs.contains(templateID) }
    }

    /// Returns the multiplier for a given program ID + tier name combo.
    /// Defaults to 1.0 (no boost) if not found.
    static func multiplier(programID: String, tierName: String) -> Double {
        all.first { $0.id == programID }?
            .tiers.first { $0.name == tierName }?
            .multiplier ?? 1.0
    }

    // MARK: - All Programs

    static let all: [BoostProgram] = loadAll()

    private static func loadAll() -> [BoostProgram] {
        guard let url = Bundle.main.url(forResource: "boost_programs", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let programs = try? JSONDecoder().decode([BoostProgram].self, from: data) else {
            print("⚠️ BoostProgramDatabase: Failed to load boost_programs.json")
            return []
        }
        return programs
    }
}
