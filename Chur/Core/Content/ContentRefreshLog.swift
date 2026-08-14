//
//  ContentRefreshLog.swift
//  Chur
//
//  A short history of what the last few content refreshes actually did.
//
//  Content refresh is silent by design — a failure keeps the previous cache and
//  says nothing, which is right for the user and useless for support. Without a
//  record, "the app is showing the wrong rate" cannot be told apart from a
//  checksum failure, a build below minAppVersion, or a device that has simply
//  never been online since the publish.
//
//  Local only: no network, no identifiers, nothing to disclose. This answers
//  "what happened on this device". Answering "how often does this fail across
//  all devices" needs analytics (ROADMAP §P2) and is a different question.
//

import Foundation

struct ContentRefreshEntry: Codable {
    let date: Date
    let outcome: String
    let detail: String
    let version: Int

    var summary: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        let stamp = formatter.string(from: date)
        return detail.isEmpty
            ? "\(stamp) · \(outcome) · v\(version)"
            : "\(stamp) · \(outcome) · v\(version) · \(detail)"
    }
}

enum ContentRefreshLog {

    /// Five is enough to see a pattern and small enough to paste into a support
    /// message without anyone scrolling.
    private static let limit = 5
    private static let key = "chur.content.refreshLog"

    /// Resolved once, for the same reason as ContentStore.defaults: an
    /// unentitled suite lookup fails and logs on every call.
    private static let defaults: UserDefaults = UserDefaults(suiteName: ContentStore.appGroupID) ?? .standard

    static func record(_ outcome: Outcome, detail: String = "") {
        var entries = all
        entries.insert(
            ContentRefreshEntry(date: Date(),
                                outcome: outcome.rawValue,
                                detail: detail,
                                version: ContentStore.currentVersion),
            at: 0
        )
        entries = Array(entries.prefix(limit))

        guard let data = try? JSONEncoder().encode(entries) else { return }
        defaults.set(data, forKey: key)
    }

    static var all: [ContentRefreshEntry] {
        guard let data = defaults.data(forKey: key),
              let entries = try? JSONDecoder().decode([ContentRefreshEntry].self, from: data) else {
            return []
        }
        return entries
    }

    static var latest: ContentRefreshEntry? { all.first }

    /// Ready to paste into a bug report — the shape the planned report-an-issue
    /// button will send.
    static var supportSummary: String {
        guard !all.isEmpty else { return "Content: no refresh recorded" }
        return (["Content refresh history:"] + all.map { "  \($0.summary)" }).joined(separator: "\n")
    }

    static func clear() {
        defaults.removeObject(forKey: key)
    }

    /// Every way a refresh can end, including the quiet ones. "Skipped" outcomes
    /// matter most: they are the states where the app is working exactly as
    /// designed and the user still sees old data.
    enum Outcome: String {
        case applied            // new content downloaded and committed
        case upToDate           // manifest matched what we already have
        case tooOld             // build below the manifest's minAppVersion
        case rateLimited        // inside the 30-minute window
        case failed             // network, checksum, or validation
        case cancelled          // caller went away mid-download; not a fault
        case disabled           // feature flag off
    }
}
