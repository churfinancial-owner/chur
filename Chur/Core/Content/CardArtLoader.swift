//
//  CardArtLoader.swift
//  Chur
//
//  Resolves card art by `imageName`, in three tiers: decoded in memory, PNG on
//  disk, then the CDN.
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
import UIKit

/// One entry in the published cardArt index.
struct CardArtRef: Codable {
    let url: String
    let sha256: String
    let bytes: Int
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

    // MARK: - Public API

    /// Cached image, if one is already available without touching the network.
    /// Lets a view render synchronously on the common path instead of flashing
    /// a placeholder for art it already has.
    func cached(_ imageName: String) -> UIImage? {
        if let image = memory.object(forKey: imageName as NSString) { return image }

        guard let ref = reference(for: imageName),
              let url = CardArtStore.fileURL(for: imageName, sha256: ref.sha256),
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

    /// Drops decoded images. The disk cache is cleared by ContentStore.clear().
    func clearMemory() {
        memory.removeAllObjects()
        index = nil
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

            CardArtStore.write(data, for: imageName, sha256: ref.sha256)
            memory.setObject(image, forKey: imageName as NSString)
            return image
        } catch {
            return nil
        }
    }

    /// The published index, decoded once per launch. Nil until a content refresh
    /// has landed, which is why bundled art remains the fallback until the
    /// pipeline is proven.
    private func reference(for imageName: String) -> CardArtRef? {
        if index == nil {
            guard let data = ContentStore.data(for: .cardArt),
                  let decoded = try? JSONDecoder().decode([String: CardArtRef].self, from: data) else {
                return nil
            }
            index = decoded
        }
        return index?[imageName]
    }
}
