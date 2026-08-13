//
//  AppVersion.swift
//  Chur
//
//  Build identity for the Settings footer.
//
//  Exists for support, not for users: "what version are you on, and is your
//  content stale?" is the first question behind any wrong-rate report, and the
//  answer is otherwise invisible outside the DEBUG hammer menu.
//

import Foundation

enum AppVersion {

    /// Marketing version, e.g. "1.0".
    static var short: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    /// Build number, e.g. "42".
    static var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }

    /// "Chur 1.0 (42) · content v9", or "Chur 1.0 (42)" before any publish has
    /// been applied. The content segment is dropped rather than shown as v0,
    /// which reads like something is broken when it is simply a fresh install
    /// running on bundled JSON.
    static var footerLabel: String {
        let base = String(
            format: String(localized: "Chur %@ (%@)", comment: "Settings footer: app name, version, build number"),
            short, build
        )
        guard ContentStore.currentVersion > 0 else { return base }

        let content = String(
            format: String(localized: "content v%lld", comment: "Settings footer: version of the remotely published content bundle"),
            ContentStore.currentVersion
        )
        return "\(base) · \(content)"
    }
}
