//
//  CardArtLoader.swift
//  Chur
//
//  Resolves card art by `imageName`, in three tiers: decoded in memory, a file
//  on disk, then the CDN.
//
//  Card art is published as individual images rather than a JSON bundle, so it
//  is deliberately outside RemoteContentService's all-or-nothing staging: 15 MB
//  cannot block a content version from applying, and a card the user never looks
//  at should never be downloaded. The index (which image, which URL, which
//  hash) is an ordinary content domain; the bytes are fetched on demand.
//
//  Downloads are content-addressed and sha256-verified, matching the safety
//  model of every other payload — a corrupted or substituted image is discarded
//  rather than cached.
//

import Foundation
import Observation
import UIKit

/// Counter that views observe so a row showing a placeholder retries when the
/// art index arrives.
///
/// A card that resolved to nothing is not re-asked otherwise: `CardArtView`'s
/// task is keyed by `imageName`, which does not change. That is invisible in
/// normal use — the index is already cached — and permanent during onboarding on
/// a fresh install, where the first refresh lands while the card list is on
/// screen.
///
/// Deliberately separate from `CardArtLoader`: bumping has to happen when content
/// is applied, never from the lazy decode inside `reference(for:)`, which runs
/// during view body evaluation.
@Observable
@MainActor
final class CardArtIndexState {
    static let shared = CardArtIndexState()
    private init() {}

    private(set) var generation = 0

    fileprivate func bump() { generation += 1 }
}

/// One entry in the published cardArt index.
struct CardArtRef: Codable {
    let url: String
    let sha256: String
    let bytes: Int

    /// png or jpeg — the catalog contains both, and the cache filename has to
    /// match what was actually downloaded.
    var pathExtension: String { URL(string: url)?.pathExtension.lowercased() ?? "png" }
}

@MainActor
final class CardArtLoader {

    static let shared = CardArtLoader()
    private init() {}

    /// Decoded images. NSCache evicts under memory pressure on its own, which is
    /// what we want on a list of 175 cards.
    private let memory = NSCache<NSString, UIImage>()

    /// One task per imageName, so a fast scroll that asks for the same art from
    /// several rows performs a single download.
    private var inFlight: [String: Task<UIImage?, Never>] = [:]

    private var index: [String: CardArtRef]?

    /// Content version the index was decoded at, so a refresh landing mid-session
    /// invalidates it without anything having to remember to call clearMemory().
    private var indexVersion: Int?

    // MARK: - Public API

    /// Cached image, if one is already available without touching the network.
    /// Lets a view render synchronously on the common path instead of flashing
    /// a placeholder for art it already has.
    func cached(_ imageName: String) -> UIImage? {
        if let image = memory.object(forKey: imageName as NSString) { return image }

        guard let ref = reference(for: imageName),
              let url = CardArtStore.fileURL(for: imageName,
                                             sha256: ref.sha256,
                                             pathExtension: ref.pathExtension),
              let data = try? Data(contentsOf: url),
              let image = UIImage(data: data) else { return nil }

        memory.setObject(image, forKey: imageName as NSString)
        return image
    }

    /// Fetches art, from disk or the network. Returns nil when the name is
    /// unknown, the download fails, or the payload fails its checksum — callers
    /// show the placeholder and try again next time they appear.
    func image(for imageName: String) async -> UIImage? {
        if let image = cached(imageName) { return image }

        if let existing = inFlight[imageName] { return await existing.value }

        let task = Task<UIImage?, Never> { [weak self] in
            await self?.download(imageName) ?? nil
        }
        inFlight[imageName] = task
        let image = await task.value
        inFlight[imageName] = nil
        return image
    }

    /// True when art is already available without a download — bundled, in
    /// memory, or on disk. Deliberately does not decode: prefetch only needs to
    /// know whether the bytes exist.
    func isAvailable(_ imageName: String) -> Bool {
        if CardArtStore.bundledImage(named: imageName) != nil { return true }
        if memory.object(forKey: imageName as NSString) != nil { return true }
        guard let ref = reference(for: imageName),
              let url = CardArtStore.fileURL(for: imageName,
                                             sha256: ref.sha256,
                                             pathExtension: ref.pathExtension) else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }

    /// Downloads art for cards the user owns, so their own wallet survives going
    /// offline. Browsing stays lazy — this is only the handful of cards they
    /// added, which is the difference between "a new install with no signal
    /// shows nothing" and "only cards you don't own show placeholders".
    ///
    /// Sequential on purpose: a wallet is a few cards, and this must never
    /// compete for bandwidth with art the user is currently looking at.
    func prefetch(_ imageNames: [String]) {
        let missing = imageNames.filter { !isAvailable($0) }
        guard !missing.isEmpty else { return }

        Task { [weak self] in
            for name in missing {
                _ = await self?.image(for: name)
            }
        }
    }

    /// Drops decoded images. The disk cache is cleared by ContentStore.clear().
    func clearMemory() {
        memory.removeAllObjects()
        index = nil
        indexVersion = nil
    }

    /// Called by ContentRefreshCoordinator once a new content version has been
    /// written. Drops what was decoded against the old index and tells views to
    /// ask again — `reference(for:)` self-corrects on the next lookup, but
    /// nothing would trigger that lookup on a row already showing a placeholder.
    func contentDidChange() {
        clearMemory()
        CardArtIndexState.shared.bump()
    }

    // MARK: - Internals

    private func download(_ imageName: String) async -> UIImage? {
        guard FeatureFlags.remoteContentEnabled,
              let ref = reference(for: imageName),
              let remoteURL = URL(string: ref.url) else { return nil }

        do {
            let (data, response) = try await URLSession.shared.data(from: remoteURL)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return nil
            }
            guard CardArtStore.sha256Hex(data) == ref.sha256.lowercased() else {
                print("⚠️ CardArt: checksum mismatch for '\(imageName)', discarding")
                return nil
            }
            guard let image = UIImage(data: data) else { return nil }

            CardArtStore.write(data, for: imageName, sha256: ref.sha256, pathExtension: ref.pathExtension)
            memory.setObject(image, forKey: imageName as NSString)
            return image
        } catch {
            return nil
        }
    }

    /// The published index, re-read whenever the content version moves.
    ///
    /// Decoding once per launch was wrong: a refresh that lands while the app is
    /// running writes a new index, and a loader still holding the old one would
    /// serve stale URLs — and return nothing at all for a card added by that
    /// publish, since its name wouldn't be in the old index. The user would see
    /// a permanent placeholder until they happened to relaunch, with no button
    /// to fix it. Stamping the version makes it self-correcting.
    private func reference(for imageName: String) -> CardArtRef? {
        let version = ContentStore.currentVersion
        if index == nil || indexVersion != version {
            guard let data = ContentStore.data(for: .cardArt),
                  let decoded = try? JSONDecoder().decode([String: CardArtRef].self, from: data) else {
                return nil
            }
            // Decoded images are keyed by name, not by hash, so an updated image
            // would otherwise keep resolving to the previous one for the rest of
            // the session.
            if indexVersion != nil { memory.removeAllObjects() }
            index = decoded
            indexVersion = version
        }
        return index?[imageName]
    }
}
