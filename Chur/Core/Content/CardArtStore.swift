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
        guard let base = ContentStore.containerURL else {
            print("⚠️ CardArtStore: no container — art will download every launch and never cache")
            return nil
        }
        let directory = base.appendingPathComponent(directoryName, isDirectory: true)
        if !FileManager.default.fileExists(atPath: directory.path) {
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            } catch {
                // Was `try?`. A cache directory that cannot be created makes every
                // later write fail silently, which is indistinguishable from art
                // simply never being requested.
                print("⚠️ CardArtStore: could not create \(directory.path) — \(error)")
                return nil
            }
        }
        print("🖼️ CardArtStore: caching art in \(directory.path)")
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
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            // Was `try?`. A failed write still leaves the image in the memory
            // cache, so art looks fine and silently re-downloads every launch.
            print("⚠️ CardArtStore: could not cache '\(imageName)' — \(error)")
            return
        }
        pruneOldVersions(of: imageName, keeping: url)
    }

    /// Deletes earlier hashes of the same image. Without this, every art update
    /// leaves its predecessor on disk forever — the cache would only ever grow,
    /// and the whole point of removing art from the binary is footprint.
    ///
    /// Matching is on the full `<imageName>-<8 hex>.<ext>` shape, not a bare
    /// `hasPrefix("\(imageName)-")`. Card names nest: caching `amex-gold` would
    /// otherwise delete `amex-gold-business`, and the two would evict each other
    /// for as long as both are in the wallet. 25 of the 171 published names are
    /// a prefix of another one.
    private static func pruneOldVersions(of imageName: String, keeping current: URL) {
        guard let directory = directoryURL,
              let contents = try? FileManager.default.contentsOfDirectory(at: directory,
                                                                          includingPropertiesForKeys: nil) else { return }
        for file in contents
        where isCacheFile(file.lastPathComponent, for: imageName)
            && file.lastPathComponent != current.lastPathComponent {
            try? FileManager.default.removeItem(at: file)
        }
    }

    /// True when `filename` is this image's cache entry at some hash — i.e. the
    /// name is followed by exactly a hyphen, 8 hex characters and an extension.
    ///
    /// Compared by filename rather than by `URL`, because a URL from
    /// `contentsOfDirectory` and one built by `fileURL(for:…)` can differ in
    /// representation while pointing at the same file.
    static func isCacheFile(_ filename: String, for imageName: String) -> Bool {
        let name = (filename as NSString).deletingPathExtension
        guard name.hasPrefix("\(imageName)-") else { return false }

        let hash = name.dropFirst(imageName.count + 1)
        return hash.count == 8 && hash.allSatisfy(\.isHexDigit)
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
    ///
    /// Falls back to `.totalFileAllocatedSize` because a nil `fileSize` would
    /// otherwise sum to zero, which reads identically to "nothing is cached" —
    /// two very different problems.
    static var cachedByteCount: Int {
        cachedFiles.reduce(0) { total, url in
            let values = try? url.resourceValues(forKeys: [.fileSizeKey, .totalFileAllocatedSizeKey])
            return total + (values?.fileSize ?? values?.totalFileAllocatedSize ?? 0)
        }
    }

    /// Companion to `cachedByteCount`: zero files and zero bytes means nothing is
    /// being written, while files with no bytes means the measurement is wrong.
    static var cachedFileCount: Int { cachedFiles.count }

    private static var cachedFiles: [URL] {
        guard let directory = directoryURL,
              let contents = try? FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.fileSizeKey, .totalFileAllocatedSizeKey]) else { return [] }
        return contents
    }

    static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
