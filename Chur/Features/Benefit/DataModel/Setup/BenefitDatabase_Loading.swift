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

    /// Decodes the remotely published benefits bundle, or nil when the feature
    /// is off, nothing is cached, or the payload isn't a usable array.
    ///
    /// Entries are decoded one at a time so a single malformed benefit is
    /// skipped rather than discarding the whole domain. That matches the bundle
    /// path, where `enumerateFolder` drops a file it can't decode — three seed
    /// files fail `_BenefitJSON` today (`schwab_appreciation_bonus` and
    /// `schwab_redeem_cash` have no `value`, `amex_walmartplus` has a fractional
    /// one against `value: Int`). An all-or-nothing decode here would let those
    /// three permanently force every client back to bundled JSON, silently
    /// disabling remote benefits.
    static func loadRemoteBenefits(formatter: ISO8601DateFormatter) -> [BenefitTemplate]? {
        guard FeatureFlags.remoteContentEnabled,
              let data = ContentStore.data(for: .benefits) else { return nil }

        let decoded: [_FailableBenefit]
        do {
            decoded = try JSONDecoder().decode([_FailableBenefit].self, from: data)
        } catch {
            print("❌ BenefitDatabase: remote 'benefits' is not an array, using bundled JSON: \(error)")
            return nil
        }

        let benefits = decoded.compactMap { $0.value }.map { convertBenefit($0, formatter: formatter) }
        guard !benefits.isEmpty else {
            print("❌ BenefitDatabase: remote 'benefits' decoded to nothing, using bundled JSON")
            return nil
        }

        let skipped = decoded.count - benefits.count
        if skipped > 0 {
            print("⚠️ BenefitDatabase: skipped \(skipped) remote benefit(s) that failed to decode")
        }
        return benefits
    }

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

    /// Element wrapper that turns a decode failure into nil instead of failing
    /// the enclosing array. Never throws, so `[_FailableBenefit]` only fails
    /// when the payload isn't an array at all.
    struct _FailableBenefit: Decodable {
        let value: _BenefitJSON?

        init(from decoder: Decoder) throws {
            value = try? _BenefitJSON(from: decoder)
        }
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
