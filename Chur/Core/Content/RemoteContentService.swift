//
//  RemoteContentService.swift
//  Chur
//
//  Fetches published content bundles and commits them to ContentStore.
//
//  Safety model — a bad publish must never brick the app:
//    1. sha256 must match the manifest
//    2. the payload must pass structural validation
//    3. every domain must succeed before any is committed (no half-applied
//       versions, which would pair new cards with stale rewards)
//    4. the reading database's decode is a final net — CardDatabase and
//       BenefitDatabase both fall back to bundled JSON if the cached payload
//       can't be decoded
//
//  Any failure leaves the previous cache untouched.
//

import Foundation
import CryptoKit

@MainActor
final class RemoteContentService {

    static let shared = RemoteContentService()
    private init() {}

    private static let manifestURL = URL(string: "https://content.chur.app/manifest.json")!

    /// Matches the 30-minute gate in NewsService.fetchNewsIfNeeded().
    private static let minimumRefreshInterval: TimeInterval = 1800

    private(set) var isRefreshing = false

    // MARK: - Entry points

    /// Rate-limited refresh for launch and foreground. Returns true when new
    /// content was applied, so the caller knows to reload the databases.
    @discardableResult
    func refreshIfNeeded() async -> Bool {
        guard FeatureFlags.remoteContentEnabled else {
            ContentRefreshLog.record(.disabled)
            return false
        }
        if let last = ContentStore.lastRefreshedAt,
           Date().timeIntervalSince(last) < Self.minimumRefreshInterval {
            ContentRefreshLog.record(.rateLimited)
            return false
        }
        return await refresh()
    }

    /// Unconditional refresh, ignoring the interval gate. Used by the debug tool.
    @discardableResult
    func refresh() async -> Bool {
        guard FeatureFlags.remoteContentEnabled else { return false }
        guard !isRefreshing else { return false }
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let manifest = try await fetchManifest()

            guard isSupported(minAppVersion: manifest.minAppVersion) else {
                print("⏭️ RemoteContent: build older than minAppVersion \(manifest.minAppVersion), skipping")
                ContentRefreshLog.record(.tooOld, detail: "needs \(manifest.minAppVersion)")
                return false
            }

            // Record the attempt even when there's nothing new, so a healthy
            // no-op doesn't re-fetch on every foreground.
            ContentStore.lastRefreshedAt = Date()

            guard manifest.contentVersion > ContentStore.currentVersion else {
                ContentRefreshLog.record(.upToDate)
                return false
            }

            var staged: [(ContentDomain, Data)] = []
            for domain in ContentDomain.allCases {
                guard let reference = manifest.bundle(for: domain) else { continue }
                let data = try await fetchBundle(reference)
                try validate(data, for: domain)
                staged.append((domain, data))
            }

            guard !staged.isEmpty else {
                throw ContentError.validationFailed("manifest listed no known domains")
            }

            for (domain, data) in staged {
                try ContentStore.write(data, for: domain)
            }
            ContentStore.currentVersion = manifest.contentVersion

            print("✅ RemoteContent: applied contentVersion \(manifest.contentVersion)")
            ContentRefreshLog.record(.applied, detail: "\(staged.count) domains")
            return true
        } catch {
            // A cancellation is not a failure: the caller went away (view
            // teardown, app backgrounded) and the download was abandoned
            // mid-flight. Logging it as a failure buries the ones that matter.
            if (error as NSError).code == NSURLErrorCancelled {
                print("⏹️ RemoteContent: refresh cancelled before it finished")
                ContentRefreshLog.record(.cancelled)
                return false
            }

            print("⚠️ RemoteContent: refresh failed — \(error)")
            // The reason is the whole point: a checksum mismatch and a dropped
            // connection look identical from the outside and need opposite fixes.
            ContentRefreshLog.record(.failed, detail: "\(error)")
            return false
        }
    }

    // MARK: - Networking

    private func fetchManifest() async throws -> ContentManifest {
        var request = URLRequest(url: Self.manifestURL)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let (data, response) = try await URLSession.shared.data(for: request)
        try check(response, label: "manifest")
        return try JSONDecoder().decode(ContentManifest.self, from: data)
    }

    private func fetchBundle(_ reference: ContentBundleRef) async throws -> Data {
        guard let url = URL(string: reference.url) else {
            throw ContentError.badResponse("malformed URL for '\(reference.domain)'")
        }
        let (data, response) = try await URLSession.shared.data(from: url)
        try check(response, label: reference.domain)

        guard sha256Hex(data) == reference.sha256.lowercased() else {
            throw ContentError.checksumMismatch(reference.domain)
        }
        return data
    }

    private func check(_ response: URLResponse, label: String) throws {
        guard let http = response as? HTTPURLResponse else {
            throw ContentError.badResponse("\(label): not an HTTP response")
        }
        guard http.statusCode == 200 else {
            throw ContentError.badResponse("\(label): HTTP \(http.statusCode)")
        }
    }

    // MARK: - Validation

    /// Structural checks only — this type deliberately doesn't know the content
    /// schema. Decoding into the real models happens in CardDatabase, which
    /// falls back to bundled JSON if it fails.
    private func validate(_ data: Data, for domain: ContentDomain) throws {
        let parsed = try JSONSerialization.jsonObject(with: data)

        switch domain {
        case .cards:
            guard let array = parsed as? [[String: Any]], !array.isEmpty else {
                throw ContentError.validationFailed("cards: expected a non-empty array of objects")
            }
            guard array.allSatisfy({ ($0["id"] as? String)?.isEmpty == false }) else {
                throw ContentError.validationFailed("cards: every entry needs a non-empty 'id'")
            }
        case .rewards:
            guard let dictionary = parsed as? [String: Any], !dictionary.isEmpty else {
                throw ContentError.validationFailed("rewards: expected a non-empty object keyed by card id")
            }
        case .benefits:
            guard let array = parsed as? [[String: Any]], !array.isEmpty else {
                throw ContentError.validationFailed("benefits: expected a non-empty array of objects")
            }
            guard array.allSatisfy({ ($0["id"] as? String)?.isEmpty == false }) else {
                throw ContentError.validationFailed("benefits: every entry needs a non-empty 'id'")
            }
        case .merchants:
            guard let array = parsed as? [[String: Any]], !array.isEmpty else {
                throw ContentError.validationFailed("merchants: expected a non-empty array of objects")
            }
            // `category` is what a brand category is synthesized from, so an
            // entry missing it would produce a category with an empty id.
            guard array.allSatisfy({ ($0["id"] as? String)?.isEmpty == false }) else {
                throw ContentError.validationFailed("merchants: every entry needs a non-empty 'id'")
            }
            guard array.allSatisfy({ ($0["category"] as? String)?.isEmpty == false }) else {
                throw ContentError.validationFailed("merchants: every entry needs a non-empty 'category'")
            }
        case .merchantMappings:
            guard let dictionary = parsed as? [String: Any], dictionary["exactMatches"] is [String: Any] else {
                throw ContentError.validationFailed("merchantMappings: expected an object with 'exactMatches'")
            }
        case .cardArt, .iconArt:
            guard let dictionary = parsed as? [String: Any], !dictionary.isEmpty else {
                throw ContentError.validationFailed("\(domain.rawValue): expected a non-empty object keyed by imageName")
            }
            guard dictionary.values.allSatisfy({ ($0 as? [String: Any])?["url"] is String }) else {
                throw ContentError.validationFailed("\(domain.rawValue): every entry needs a 'url'")
            }

        // MARK: P1d domains
        //
        // The switch is exhaustive over ContentDomain on purpose: adding a case
        // there without a rule here is a compile error, not a domain that ships
        // unvalidated. Keep in sync with `validatePayload` in ChurContentPublish,
        // which applies the same rules before a byte is uploaded.

        case .badges, .partners, .issuers, .boostPrograms, .programUpgrades, .categories:
            try requireIDs("id", parsed, domain: domain)

        case .recommendations:
            try requireIDs("cardTemplateID", parsed, domain: domain)

        case .autoRentalCoverage, .cellPhoneProtection:
            try requireIDs("cardId", parsed, domain: domain)

        case .transferPartners:
            guard let dictionary = parsed as? [String: Any],
                  let programs = dictionary["programs"] as? [[String: Any]], !programs.isEmpty else {
                throw ContentError.validationFailed("transferPartners: expected an object with a non-empty 'programs' array")
            }

        case .programs:
            // Keyed by program name, not by an id field. An empty object would
            // silently zero every card's point value.
            guard let dictionary = parsed as? [String: Any], !dictionary.isEmpty else {
                throw ContentError.validationFailed("programs: expected a non-empty object keyed by program name")
            }
        }
    }

    /// Non-empty array of objects, each carrying a non-empty string at `key`.
    /// The shape most P1d domains share.
    private func requireIDs(_ key: String, _ parsed: Any, domain: ContentDomain) throws {
        guard let array = parsed as? [[String: Any]], !array.isEmpty else {
            throw ContentError.validationFailed("\(domain.rawValue): expected a non-empty array of objects")
        }
        guard array.allSatisfy({ ($0[key] as? String)?.isEmpty == false }) else {
            throw ContentError.validationFailed("\(domain.rawValue): every entry needs a non-empty '\(key)'")
        }
    }

    // MARK: - Helpers

    private func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private func isSupported(minAppVersion: String) -> Bool {
        let current = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        return compare(current, minAppVersion) >= 0
    }

    /// Dot-separated numeric comparison. Returns -1, 0 or 1.
    private func compare(_ lhs: String, _ rhs: String) -> Int {
        let left = lhs.split(separator: ".").map { Int($0) ?? 0 }
        let right = rhs.split(separator: ".").map { Int($0) ?? 0 }
        for index in 0..<max(left.count, right.count) {
            let a = index < left.count ? left[index] : 0
            let b = index < right.count ? right[index] : 0
            if a != b { return a < b ? -1 : 1 }
        }
        return 0
    }
}
