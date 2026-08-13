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

enum CardArtStore {

    private static let directoryName = "CardArt"

    static var directoryURL: URL? {
        guard let base = ContentStore.containerURL else { return nil }
        let directory = base.appendingPathComponent(directoryName, isDirectory: true)
        if !FileManager.default.fileExists(atPath: directory.path) {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory
    }

    /// `<imageName>-<sha8>.png` — content-addressed, matching the remote key.
    static func fileURL(for imageName: String, sha256: String) -> URL? {
        directoryURL?.appendingPathComponent("\(imageName)-\(sha256.prefix(8)).png")
    }

    static func write(_ data: Data, for imageName: String, sha256: String) {
        guard let url = fileURL(for: imageName, sha256: sha256) else { return }
        try? data.write(to: url, options: .atomic)
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
