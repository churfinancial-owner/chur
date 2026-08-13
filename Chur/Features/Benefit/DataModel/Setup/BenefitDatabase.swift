//  BenefitDatabase.swift
//  Chur
//
//  Created by Pak Ho on 3/9/26.
//
//  Master Catalog interface. Manages the high-level lifecycle
//  of benefit data, including caching and reload triggers.

import Foundation
import SwiftData


/// Static catalog of all known benefits. Results are cached after the first parse.
struct BenefitDatabase {

    // MARK: - Public API

    static func getAllBenefits() -> [BenefitTemplate] {
        return cachedBenefits
    }

    static func getBenefit(id: String) -> BenefitTemplate? {
        return cachedBenefits.first { $0.id == id }
    }

    /// Rebuilds the benefit cache. Prefers remotely published content when
    /// `FeatureFlags.remoteContentEnabled` is on and a payload is cached,
    /// otherwise reads the bundled JSON. Name kept for symmetry with the other
    /// `reloadFromBundle()` databases called together in reset_refresh_tool.
    static func reloadFromBundle() {
        cachedBenefits = loadCachedBenefits()
    }

    // MARK: - Internal Storage

    private static var cachedBenefits: [BenefitTemplate] = loadCachedBenefits()

    private static func loadCachedBenefits() -> [BenefitTemplate] {
        let isoFormatter = ISO8601DateFormatter()

        // 1. Remotely published content wins when present and decodable. A decode
        // failure here is the last safety net for a bad publish, so it falls
        // through to the bundled JSON rather than leaving the user with nothing.
        if let remote = loadRemoteBenefits(formatter: isoFormatter) {
            return remote
        }

        // 2. Try Folder Structure
        if let folderBenefits = loadBenefitsFromFolders() {
            return folderBenefits
        }

        // 3. Fallback to Single Legacy File
        if let legacy: [_BenefitJSON] = parseJSON(from: TestDataConfiguration.SeedFiles.benefits) {
            return legacy.map { convertLegacyBenefit($0, formatter: isoFormatter) }
        }
        
        print("⚠️ BenefitDatabase: No benefits loaded")
        return []
    }
}
