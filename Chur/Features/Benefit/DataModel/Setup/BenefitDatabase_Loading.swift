//
//  BenefitDatabase_Loading.swift
//  Chur
//
//  Created by Pak Ho on 3/9/26.
//
//  Extension for file system discovery. Handles folder enumeration,
//  bundle scanning, and finding the physical JSON files on disk.

import Foundation

extension BenefitDatabase {
    
    /// Logic to find and enumerate benefit JSON files across multiple possible paths.
    static func loadBenefitsFromFolders() -> [BenefitTemplate]? {
        let fileManager = FileManager.default
        let possiblePaths: [String?] = [nil, "SeedData", "benefits"]
        var benefitsURL: URL?

        for subdirectory in possiblePaths {
            if let url = Bundle.main.url(forResource: "benefits", withExtension: nil, subdirectory: subdirectory) {
                benefitsURL = url
                break
            }
        }

        if let url = benefitsURL {
            return enumerateFolder(at: url)
        }

        // Final fallback: Scan root bundle for any non-system JSONs
        return scanBundleRoot()
    }

    private static func enumerateFolder(at url: URL) -> [BenefitTemplate]? {
        let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey])
        var results: [BenefitTemplate] = []
        let formatter = ISO8601DateFormatter()

        while let fileURL = enumerator?.nextObject() as? URL {
            guard fileURL.pathExtension == "json" else { continue }
            if let data = try? Data(contentsOf: fileURL),
               let json = try? JSONDecoder().decode(_BenefitJSON.self, from: data) {
                results.append(convertBenefit(json, formatter: formatter))
            }
        }
        return results.isEmpty ? nil : results
    }

    private static func scanBundleRoot() -> [BenefitTemplate]? {
        guard let bundleURL = Bundle.main.resourceURL,
              let allFiles = try? FileManager.default.contentsOfDirectory(at: bundleURL, includingPropertiesForKeys: nil) else { return nil }
        
        let formatter = ISO8601DateFormatter()
        let benefitFiles = allFiles.filter { url in
            url.pathExtension == "json" &&
            !url.lastPathComponent.hasPrefix("SeedData") &&
            !url.lastPathComponent.contains("rewards.json")
        }

        var results: [BenefitTemplate] = []
        for url in benefitFiles {
            if let data = try? Data(contentsOf: url),
               let json = try? JSONDecoder().decode(_BenefitJSON.self, from: data) {
                results.append(convertBenefit(json, formatter: formatter))
            }
        }
        return results.isEmpty ? nil : results
    }
}
