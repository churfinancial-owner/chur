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

    static func reloadFromBundle() {
        cachedBenefits = loadCachedBenefits()
    }

    // MARK: - Internal Storage

    private static var cachedBenefits: [BenefitTemplate] = loadCachedBenefits()

    private static func loadCachedBenefits() -> [BenefitTemplate] {
        let isoFormatter = ISO8601DateFormatter()
        
        // 1. Try Folder Structure
        if let folderBenefits = loadBenefitsFromFolders() {
            return folderBenefits
        }
        
        // 2. Fallback to Single Legacy File
        if let legacy: [_BenefitJSON] = parseJSON(from: TestDataConfiguration.SeedFiles.benefits) {
            return legacy.map { convertLegacyBenefit($0, formatter: isoFormatter) }
        }
        
        print("⚠️ BenefitDatabase: No benefits loaded")
        return []
    }
}
