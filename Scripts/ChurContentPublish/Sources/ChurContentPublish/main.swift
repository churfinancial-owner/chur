//
//  main.swift
//  ChurContentPublish
//
//  Aggregates Chur/Resources/json/ into CDN-ready content bundles + a manifest.
//
//  Usage:
//    swift run ChurContentPublish [--repo <path>] [--out <path>]
//                                 [--version <int>] [--base-url <url>]
//                                 [--min-app-version <semver>]
//
//  Deliberately parses generic JSON rather than importing the app's Codable
//  types: _CardJSON and _RewardStructure are private to CardDatabase.swift,
//  so redeclaring them here would create a second definition free to drift.
//  Structural validation happens here; the app's decode is the real contract.
//

import Foundation
import CryptoKit

// MARK: - Errors

struct PublishError: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}

// MARK: - Arguments

struct Arguments {
    var repoRoot: URL
    var outDir: URL
    var version: Int?
    var baseURL: String
    var minAppVersion: String

    static func parse() throws -> Arguments {
        var repo: String?
        var out: String?
        var version: Int?
        var baseURL = "https://content.chur.app"
        var minAppVersion = "1.0.0"

        var iterator = CommandLine.arguments.dropFirst().makeIterator()
        while let flag = iterator.next() {
            guard let value = iterator.next() else {
                throw PublishError("Missing value for \(flag)")
            }
            switch flag {
            case "--repo": repo = value
            case "--out": out = value
            case "--version":
                guard let parsed = Int(value), parsed > 0 else {
                    throw PublishError("--version must be a positive integer, got '\(value)'")
                }
                version = parsed
            case "--base-url": baseURL = value.hasSuffix("/") ? String(value.dropLast()) : value
            case "--min-app-version": minAppVersion = value
            default: throw PublishError("Unknown flag \(flag)")
            }
        }

        let repoRoot = try repo.map { URL(fileURLWithPath: $0) } ?? Arguments.findRepoRoot()
        let outDir = out.map { URL(fileURLWithPath: $0) } ?? repoRoot.appendingPathComponent("dist")

        return Arguments(repoRoot: repoRoot,
                         outDir: outDir,
                         version: version,
                         baseURL: baseURL,
                         minAppVersion: minAppVersion)
    }

    /// Walks up from the working directory looking for Chur/Resources/json.
    private static func findRepoRoot() throws -> URL {
        var candidate = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        for _ in 0..<8 {
            let marker = candidate.appendingPathComponent("Chur/Resources/json")
            if FileManager.default.fileExists(atPath: marker.path) { return candidate }
            candidate = candidate.deletingLastPathComponent()
        }
        throw PublishError("Could not locate Chur/Resources/json above the working directory. Pass --repo <path>.")
    }
}

// MARK: - Loading

/// Every .json file under `directory`, sorted for deterministic output.
func jsonFiles(in directory: URL) throws -> [URL] {
    guard let enumerator = FileManager.default.enumerator(at: directory,
                                                          includingPropertiesForKeys: [.isRegularFileKey]) else {
        throw PublishError("Could not read \(directory.path)")
    }
    var files: [URL] = []
    for case let url as URL in enumerator where url.pathExtension == "json" {
        files.append(url)
    }
    return files.sorted { $0.path < $1.path }
}

func parseObject(at url: URL) throws -> [String: Any] {
    let data = try Data(contentsOf: url)
    let parsed = try JSONSerialization.jsonObject(with: data)
    guard let object = parsed as? [String: Any] else {
        throw PublishError("\(url.lastPathComponent): expected a JSON object at the top level")
    }
    return object
}

/// cards/**/*.json — one card object per file, aggregated into an array.
func loadCards(repoRoot: URL) throws -> [[String: Any]] {
    let dir = repoRoot.appendingPathComponent("Chur/Resources/json/cards")
    var cards: [[String: Any]] = []
    var seenIDs: [String: String] = [:]   // id -> filename that claimed it

    for url in try jsonFiles(in: dir) {
        let object = try parseObject(at: url)
        guard let id = object["id"] as? String, !id.isEmpty else {
            throw PublishError("\(url.lastPathComponent): missing or empty string field 'id'")
        }
        if let existing = seenIDs[id] {
            throw PublishError("Duplicate card id '\(id)' in \(url.lastPathComponent) and \(existing)")
        }
        seenIDs[id] = url.lastPathComponent
        cards.append(object)
    }

    guard !cards.isEmpty else { throw PublishError("No cards found under \(dir.path)") }
    return cards
}

/// rewards/*-rewards.json — each a dictionary keyed by card template ID,
/// merged into one dictionary. Mirrors CardDatabase.discoverRewardFiles().
func loadRewards(repoRoot: URL) throws -> [String: Any] {
    let dir = repoRoot.appendingPathComponent("Chur/Resources/json/rewards")
    var merged: [String: Any] = [:]
    var seenKeys: [String: String] = [:]

    for url in try jsonFiles(in: dir) {
        let object = try parseObject(at: url)
        for (cardID, structure) in object {
            if let existing = seenKeys[cardID] {
                throw PublishError("Duplicate reward key '\(cardID)' in \(url.lastPathComponent) and \(existing)")
            }
            seenKeys[cardID] = url.lastPathComponent
            merged[cardID] = structure
        }
    }

    guard !merged.isEmpty else { throw PublishError("No rewards found under \(dir.path)") }
    return merged
}

// MARK: - Writing

func canonicalData(_ value: Any) throws -> Data {
    try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys, .prettyPrinted])
}

func sha256Hex(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

struct BundleEntry {
    let domain: String
    let filename: String
    let sha256: String
    let bytes: Int

    func manifestObject(baseURL: String) -> [String: Any] {
        ["domain": domain, "url": "\(baseURL)/\(filename)", "sha256": sha256, "bytes": bytes]
    }
}

func write(_ value: Any, domain: String, version: Int, to outDir: URL) throws -> BundleEntry {
    let data = try canonicalData(value)
    let filename = "\(domain)-\(version).json"
    try data.write(to: outDir.appendingPathComponent(filename), options: .atomic)
    return BundleEntry(domain: domain, filename: filename, sha256: sha256Hex(data), bytes: data.count)
}

/// Next version = highest previously published + 1, so re-running never
/// silently overwrites a bundle a shipped app may already have cached.
func resolveVersion(explicit: Int?, outDir: URL) -> Int {
    if let explicit { return explicit }
    guard let data = try? Data(contentsOf: outDir.appendingPathComponent("manifest.json")),
          let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let previous = object["contentVersion"] as? Int else {
        return 1
    }
    return previous + 1
}

// MARK: - Main

do {
    let args = try Arguments.parse()

    let cards = try loadCards(repoRoot: args.repoRoot)
    let rewards = try loadRewards(repoRoot: args.repoRoot)

    // Reward keys with no card are harmless at runtime (nothing looks them up)
    // but usually mean a renamed or removed card left its rates behind.
    // Warn rather than block — a stale entry in one region must not stop a publish.
    let cardIDs = Set(cards.compactMap { $0["id"] as? String })
    let orphans = rewards.keys.filter { !cardIDs.contains($0) }.sorted()
    if !orphans.isEmpty {
        print("⚠️  Reward entries with no matching card (\(orphans.count)): \(orphans.joined(separator: ", "))")
    }
    let cardsWithoutRewards = cardIDs.subtracting(rewards.keys).sorted()
    if !cardsWithoutRewards.isEmpty {
        print("⚠️  Cards with no reward data (\(cardsWithoutRewards.count)): \(cardsWithoutRewards.joined(separator: ", "))")
    }

    try FileManager.default.createDirectory(at: args.outDir, withIntermediateDirectories: true)
    let version = resolveVersion(explicit: args.version, outDir: args.outDir)

    let entries = [
        try write(cards, domain: "cards", version: version, to: args.outDir),
        try write(rewards, domain: "rewards", version: version, to: args.outDir)
    ]

    let formatter = ISO8601DateFormatter()
    let manifest: [String: Any] = [
        "contentVersion": version,
        "minAppVersion": args.minAppVersion,
        "generatedAt": formatter.string(from: Date()),
        "bundles": entries.map { $0.manifestObject(baseURL: args.baseURL) }
    ]
    let manifestData = try canonicalData(manifest)
    try manifestData.write(to: args.outDir.appendingPathComponent("manifest.json"), options: .atomic)

    print("✅ contentVersion \(version) → \(args.outDir.path)")
    print("   cards:   \(cards.count) cards, \(entries[0].bytes) bytes")
    print("   rewards: \(rewards.count) entries, \(entries[1].bytes) bytes")
    print("   manifest: \(manifestData.count) bytes, base URL \(args.baseURL)")
    print("\nUpload all three files to the R2 bucket root.")
} catch let error as PublishError {
    FileHandle.standardError.write(Data("❌ \(error.description)\n".utf8))
    exit(1)
} catch {
    FileHandle.standardError.write(Data("❌ \(error)\n".utf8))
    exit(1)
}
