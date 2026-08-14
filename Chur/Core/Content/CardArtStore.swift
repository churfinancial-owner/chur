//
//  CardArtStore.swift
//  Chur
//
//  On-disk cache for downloaded card art.
//
//  Lives beside the content bundles in the App Group container, so the widget
//  planned in ROADMAP §P4 can read the same files without downloading its own
//  copies. Filenames carry the content hash, so a republished image lands
//  beside the old one rather than needing invalidation, and a partially written
//  file can never masquerade as a complete one.
//

import Foundation
import CryptoKit
import UIKit

enum CardArtStore {

    private static let directoryName = "CardArt"

    /// Resolved once — this is hit on every art lookup, so a computed property
    /// meant a directory-exists check per image per scroll frame.
    static let directoryURL: URL? = {
        guard let base = ContentStore.containerURL else { return nil }
        let directory = base.appendingPathComponent(directoryName, isDirectory: true)
        if !FileManager.default.fileExists(atPath: directory.path) {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory
    }()

    /// `<imageName>-<sha8>.<ext>` — content-addressed, matching the remote key.
    ///
    /// The extension is carried through rather than assumed: the asset catalog
    /// holds both PNG and JPEG, a difference `UIImage(named:)` hides completely
    /// and HTTP does not.
    static func fileURL(for imageName: String, sha256: String, pathExtension: String) -> URL? {
        let ext = pathExtension.isEmpty ? "png" : pathExtension
        return directoryURL?.appendingPathComponent("\(imageName)-\(sha256.prefix(8)).\(ext)")
    }

    static func write(_ data: Data, for imageName: String, sha256: String, pathExtension: String) {
        guard let url = fileURL(for: imageName, sha256: sha256, pathExtension: pathExtension) else { return }
        try? data.write(to: url, options: .atomic)
        pruneOldVersions(of: imageName, keeping: url)
    }

    /// Deletes earlier hashes of the same image. Without this, every art update
    /// leaves its predecessor on disk forever — the cache would only ever grow,
    /// and the whole point of removing art from the binary is footprint.
    private static func pruneOldVersions(of imageName: String, keeping current: URL) {
        guard let directory = directoryURL,
              let contents = try? FileManager.default.contentsOfDirectory(at: directory,
                                                                         includingPropertiesForKeys: nil) else { return }
        for file in contents
        where file.lastPathComponent.hasPrefix("\(imageName)-") && file != current {
            try? FileManager.default.removeItem(at: file)
        }
    }

    /// Card art no longer ships in the binary — `Assets.xcassets/Cards` was
    /// removed once the CDN pipeline was proven, taking 19 MB with it. This
    /// stays as the seam: it returns nil for every card today, and would start
    /// answering again if any art were ever re-bundled.
    static func bundledImage(named imageName: String) -> UIImage? {
        UIImage(named: imageName)
    }

    /// Removes every cached image. Called by ContentStore.clear(), so the debug
    /// "Clear Content Cache" action resets art along with everything else.
    static func clear() {
        guard let directory = directoryURL else { return }
        let contents = (try? FileManager.default.contentsOfDirectory(at: directory,
                                                                     includingPropertiesForKeys: nil)) ?? []
        for file in contents {
            try? FileManager.default.removeItem(at: file)
        }
    }

    /// Bytes currently cached — surfaced in the debug menu, since "why is the
    /// app 40 MB" is otherwise unanswerable once art stops shipping in the binary.
    static var cachedByteCount: Int {
        guard let directory = directoryURL,
              let contents = try? FileManager.default.contentsOfDirectory(
                at: directory, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        return contents.reduce(0) { total, url in
            total + ((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
    }

    static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
