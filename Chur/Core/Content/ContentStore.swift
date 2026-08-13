//
//  ContentStore.swift
//  Chur
//
//  Cache-first resolver for remotely published seed content.
//
//  Returns raw `Data` rather than decoded models on purpose: the JSON shapes
//  (`_CardJSON`, `_RewardStructure`) are private to CardDatabase, and callers
//  decode with their own types. Nothing here knows the content schema.
//
//  Callers must treat a nil return as "no remote content" and fall back to
//  the bundled JSON, which ships in the binary permanently.
//

import Foundation

enum ContentStore {

    /// Shared with the widget extension (ROADMAP §P4). The app's bundle
    /// identifier is `ChurFinancial`, so this is not reverse-DNS — App Group
    /// IDs only need the `group.` prefix.
    static let appGroupID = "group.ChurFinancial.shared"

    private static let versionKey = "chur.content.version"
    private static let refreshedAtKey = "chur.content.refreshedAt"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    /// Cache directory inside the App Group container. Falls back to
    /// Application Support when the App Group isn't provisioned, so a missing
    /// entitlement degrades to app-only content rather than breaking launch.
    static var containerURL: URL? {
        let base = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        guard let base else { return nil }

        let directory = base.appendingPathComponent("ChurContent", isDirectory: true)
        if !FileManager.default.fileExists(atPath: directory.path) {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory
    }

    static func cacheURL(for domain: ContentDomain) -> URL? {
        containerURL?.appendingPathComponent(domain.cacheFilename)
    }

    /// Cached payload for `domain`, or nil when nothing has been downloaded.
    static func data(for domain: ContentDomain) -> Data? {
        guard let url = cacheURL(for: domain) else { return nil }
        return try? Data(contentsOf: url)
    }

    static func write(_ data: Data, for domain: ContentDomain) throws {
        guard let url = cacheURL(for: domain) else { throw ContentError.noContainer }
        try data.write(to: url, options: .atomic)
    }

    // MARK: - Bookkeeping

    static var currentVersion: Int {
        get { defaults.integer(forKey: versionKey) }
        set { defaults.set(newValue, forKey: versionKey) }
    }

    static var lastRefreshedAt: Date? {
        get { defaults.object(forKey: refreshedAtKey) as? Date }
        set { defaults.set(newValue, forKey: refreshedAtKey) }
    }

    /// Cache state for the debug menu — the only way to tell on device whether
    /// a publish actually landed.
    static var debugStatusLabel: String {
        guard FeatureFlags.remoteContentEnabled else { return "off" }
        guard currentVersion > 0 else { return "none cached" }
        guard let refreshed = lastRefreshedAt else { return "v\(currentVersion)" }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return "v\(currentVersion) · \(formatter.localizedString(for: refreshed, relativeTo: Date()))"
    }

    /// Drops all cached content so the next launch reads bundled JSON.
    /// Used by the debug reset tool.
    static func clear() {
        for domain in ContentDomain.allCases {
            if let url = cacheURL(for: domain) {
                try? FileManager.default.removeItem(at: url)
            }
        }
        // Downloaded PNGs live outside the domain caches, so they need clearing
        // explicitly — otherwise art from a published version survives a reset
        // that was meant to return the app to its bundle.
        CardArtStore.clear()

        defaults.removeObject(forKey: versionKey)
        defaults.removeObject(forKey: refreshedAtKey)
    }
}
