//
//  RemoteSeed.swift
//  Chur
//
//  One place to ask "is there a published payload for this domain, and does it
//  decode".
//
//  P1a through P1b had four domains and each database wrote its own version of
//  this — check the flag, read the cache, decode, log, fall back. P1d takes it
//  to eighteen, which is the point where four near-identical copies become
//  twelve and one of them quietly loses the fallback.
//
//  The contract every caller depends on: **nil means use the bundled JSON.**
//  The feature being off, nothing cached, a payload that doesn't decode and a
//  payload that decodes to nothing are all the same answer, because the correct
//  response to all four is identical. A bad publish must never leave a user with
//  less than the build shipped with.
//

import Foundation

enum RemoteSeed {

    /// Decodes a published bundle, or nil when the bundled JSON should be used.
    ///
    /// `label` names the calling database in the log line. Worth passing
    /// properly: "remote 'programs' failed to decode" says which *payload* is
    /// broken, and the label says which *feature* just silently reverted, which
    /// is the half you notice as a user.
    static func decode<T: Decodable>(_ domain: ContentDomain, label: String) -> T? {
        guard FeatureFlags.remoteContentEnabled,
              let data = ContentStore.data(for: domain) else { return nil }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            // Never `try?`. A domain that silently reverts to the bundle looks
            // exactly like one that was never published, and the difference is
            // "nobody has published yet" against "the last publish is broken on
            // every device". P1b lost most of a session to that distinction.
            print("❌ \(label): remote '\(domain.rawValue)' failed to decode, using bundled JSON: \(error)")
            return nil
        }
    }

    /// The array case, which is most of them. Rejects an empty payload for the
    /// same reason the publisher refuses to write one: an empty array is a
    /// well-formed way of saying "this feature has no data", and it would apply
    /// silently to every device.
    static func decodeArray<T: Decodable>(_ domain: ContentDomain, label: String) -> [T]? {
        guard let decoded: [T] = decode(domain, label: label) else { return nil }
        guard !decoded.isEmpty else {
            print("❌ \(label): remote '\(domain.rawValue)' decoded to nothing, using bundled JSON")
            return nil
        }
        return decoded
    }
}
