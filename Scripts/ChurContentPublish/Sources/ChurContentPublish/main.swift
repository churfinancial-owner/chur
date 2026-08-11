//
//  main.swift
//  ChurContentPublish
//
//  Aggregates Chur/Resources/json/ into CDN-ready content bundles + a manifest.
//
//  Usage:
//    swift run ChurContentPublish                    # write dist/ only
//    swift run ChurContentPublish --upload           # write dist/ and push to R2
//
//  Options:
//    --repo <path>             repo root (default: found by walking up)
//    --out <path>              output dir (default: <repo>/dist)
//    --version <int>           override version (default: previous + 1)
//    --base-url <url>          CDN base (default: https://content.chur.app)
//    --min-app-version <ver>   gate old clients (default: 1.0.0)
//    --upload                  upload via `npx wrangler` — needs Node + `wrangler login`
//    --bucket <name>           R2 bucket (default: chur-content)
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
    var upload: Bool
    var bucket: String

    static func parse() throws -> Arguments {
        var repo: String?
        var out: String?
        var version: Int?
        var baseURL = "https://content.chur.app"
        var minAppVersion = "1.0.0"
        var upload = false
        var bucket = "chur-content"

        var iterator = CommandLine.arguments.dropFirst().makeIterator()
        while let flag = iterator.next() {
            // Boolean flags take no value, so handle them before reading ahead.
            if flag == "--upload" {
                upload = true
                continue
            }

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
            case "--bucket": bucket = value
            default: throw PublishError("Unknown flag \(flag)")
            }
        }

        let repoRoot = try repo.map { URL(fileURLWithPath: $0) } ?? Arguments.findRepoRoot()
        let outDir = out.map { URL(fileURLWithPath: $0) } ?? repoRoot.appendingPathComponent("dist")

        return Arguments(repoRoot: repoRoot,
                         outDir: outDir,
                         version: version,
                         baseURL: baseURL,
                         minAppVersion: minAppVersion,
                         upload: upload,
                         bucket: bucket)
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

/// Empties the output directory so it only ever holds the current version's
/// three files. Without this, versions accumulate and it stops being obvious
/// which files to upload — the single easiest way to publish a stale manifest.
/// Must run *after* resolveVersion, which reads the previous manifest.
func clean(_ outDir: URL) throws {
    guard let existing = try? FileManager.default.contentsOfDirectory(at: outDir,
                                                                     includingPropertiesForKeys: nil) else { return }
    for file in existing where file.pathExtension == "json" {
        try FileManager.default.removeItem(at: file)
    }
}

/// Uploads a file to R2 via wrangler. Kept behind --upload so the script has
/// no Node dependency by default.
func upload(_ file: URL, key: String, bucket: String) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = [
        "npx", "--yes", "wrangler", "r2", "object", "put",
        "\(bucket)/\(key)",
        "--file", file.path,
        "--content-type", "application/json",
        "--remote"
    ]
    try process.run()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
        throw PublishError("wrangler failed uploading \(key) (exit \(process.terminationStatus))")
    }
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

    // Read the previous version before clearing — the old manifest is what
    // the auto-increment is based on.
    let version = resolveVersion(explicit: args.version, outDir: args.outDir)
    try clean(args.outDir)

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

    if args.upload {
        // Bundles first, manifest last: the manifest is what makes a version
        // live, so it must never point at bundles that aren't uploaded yet.
        print("\nUploading to R2 bucket '\(args.bucket)'…")
        for entry in entries {
            try upload(args.outDir.appendingPathComponent(entry.filename),
                       key: entry.filename,
                       bucket: args.bucket)
            print("   ✓ \(entry.filename)")
        }
        try upload(args.outDir.appendingPathComponent("manifest.json"),
                   key: "manifest.json",
                   bucket: args.bucket)
        print("   ✓ manifest.json")
        print("\n✅ Published. Verify: curl -s \(args.baseURL)/manifest.json | grep contentVersion")
    } else {
        print("\nUpload all three files in \(args.outDir.lastPathComponent)/ to the R2 bucket root.")
        print("manifest.json is the one that matters — nothing goes live without it.")
        print("Or re-run with --upload to do it automatically.")
    }
} catch let error as PublishError {
    FileHandle.standardError.write(Data("❌ \(error.description)\n".utf8))
    exit(1)
} catch {
    FileHandle.standardError.write(Data("❌ \(error)\n".utf8))
    exit(1)
}
