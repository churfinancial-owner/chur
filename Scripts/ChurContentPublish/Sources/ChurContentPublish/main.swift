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

/// benefits/**/*.json — one benefit object per file, aggregated into an array.
/// Mirrors BenefitDatabase.loadBenefitsFromFolders(), which enumerates the whole
/// tree; the US/ and CA/ folders are organizational, not a scoping mechanism.
///
/// A duplicate id is fatal rather than a warning. BenefitDatabase.getBenefit(id:)
/// returns the first match, so two files claiming one id means the winner is
/// whichever the enumeration reaches first — publishing that only freezes an
/// arbitrary choice into every client.
func loadBenefits(repoRoot: URL) throws -> [[String: Any]] {
    let dir = repoRoot.appendingPathComponent("Chur/Resources/json/benefits")
    var benefits: [[String: Any]] = []
    var seenIDs: [String: String] = [:]   // id -> relative path that claimed it

    for url in try jsonFiles(in: dir) {
        let object = try parseObject(at: url)
        guard let id = object["id"] as? String, !id.isEmpty else {
            throw PublishError("\(url.lastPathComponent): missing or empty string field 'id'")
        }
        let relativePath = url.path.replacingOccurrences(of: dir.path + "/", with: "")
        if let existing = seenIDs[id] {
            throw PublishError("Duplicate benefit id '\(id)' in \(relativePath) and \(existing)")
        }
        seenIDs[id] = relativePath
        benefits.append(object)
    }

    guard !benefits.isEmpty else { throw PublishError("No benefits found under \(dir.path)") }
    return benefits
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

/// merchants/SeedDataMerchants_*.json — plain arrays concatenated, mirroring
/// MerchantSeedDatabase.loadSeed(). Grouping by file is organizational only.
///
/// Duplicate ids are fatal for the same reason they are for cards: the app keeps
/// both, and which one wins depends on enumeration order.
func loadMerchants(repoRoot: URL) throws -> [[String: Any]] {
    let dir = repoRoot.appendingPathComponent("Chur/Resources/json/merchants")
    var merchants: [[String: Any]] = []
    var seenIDs: [String: String] = [:]

    for url in try jsonFiles(in: dir) where url.lastPathComponent.hasPrefix("SeedDataMerchants_") {
        let parsed = try JSONSerialization.jsonObject(with: try Data(contentsOf: url))
        guard let array = parsed as? [[String: Any]] else {
            throw PublishError("\(url.lastPathComponent): expected an array of merchant objects")
        }
        for entry in array {
            guard let id = entry["id"] as? String, !id.isEmpty else {
                throw PublishError("\(url.lastPathComponent): a merchant is missing its 'id'")
            }
            guard (entry["category"] as? String)?.isEmpty == false else {
                throw PublishError("\(url.lastPathComponent): merchant '\(id)' is missing its 'category'")
            }
            if let existing = seenIDs[id] {
                throw PublishError("Duplicate merchant id '\(id)' in \(url.lastPathComponent) and \(existing)")
            }
            seenIDs[id] = url.lastPathComponent
            merchants.append(entry)
        }
    }

    guard !merchants.isEmpty else { throw PublishError("No merchants found under \(dir.path)") }
    return merchants
}

/// merchants/SeedDataGenericMappings.json — a single object, published as its
/// own domain so a bad edit here can't take the merchant list down with it.
func loadMerchantMappings(repoRoot: URL) throws -> [String: Any] {
    let url = repoRoot.appendingPathComponent("Chur/Resources/json/merchants/SeedDataGenericMappings.json")
    let object = try parseObject(at: url)
    guard object["exactMatches"] is [String: Any] else {
        throw PublishError("SeedDataGenericMappings.json: missing 'exactMatches'")
    }
    return object
}

// MARK: - Card art

/// Source of truth for card images, relative to the repo root.
let cardArtDirectory = "CardArt"

/// One card image, keyed by the `imageName` a card's JSON refers to.
struct CardArt {
    let imageName: String
    let source: URL
    let sha256: String
    let bytes: Int

    /// `CardArt/` holds a mix of PNG and JPEG. The asset catalog used to resolve
    /// either one through `UIImage(named:)`, so the difference was invisible;
    /// served over HTTP, the extension has to be carried explicitly.
    var pathExtension: String { source.pathExtension.lowercased() }

    var contentType: String { pathExtension == "png" ? "image/png" : "image/jpeg" }

    /// Content-addressed remote key. A changed image gets a new key, so nothing
    /// ever has to be cache-invalidated and a rollback is just an old manifest
    /// pointing at keys that are still there.
    var key: String { "art/\(imageName)-\(String(sha256.prefix(8))).\(pathExtension)" }
}

/// Every image under `CardArt/`. The filename is the `imageName` cards refer to;
/// the issuer subfolders are for humans only and nothing here reads them.
///
/// Deliberately outside `Chur/`: that folder is a synchronized root group in the
/// Xcode project, so art living under it would be compiled back into the app —
/// the 19 MB that removing it saved.
func loadCardArt(repoRoot: URL) throws -> [CardArt] {
    let dir = repoRoot.appendingPathComponent(cardArtDirectory)

    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: dir.path, isDirectory: &isDirectory), isDirectory.boolValue else {
        throw PublishError("Card art directory missing: \(dir.path)")
    }
    guard let enumerator = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: nil) else {
        throw PublishError("Could not read \(dir.path)")
    }

    let imageExtensions: Set<String> = ["png", "jpg", "jpeg"]
    var art: [CardArt] = []

    for case let url as URL in enumerator where imageExtensions.contains(url.pathExtension.lowercased()) {
        let data = try Data(contentsOf: url)
        art.append(CardArt(imageName: url.deletingPathExtension().lastPathComponent,
                           source: url,
                           sha256: sha256Hex(data),
                           bytes: data.count))
    }

    // An empty index is what the app rejects outright, and a rejected domain
    // aborts the whole refresh — cards, rewards and all. Cheaper to fail here
    // than to discover it in a device log after uploading.
    guard !art.isEmpty else {
        throw PublishError("No card art found under \(dir.path) — publishing an empty index would break every domain on device")
    }

    // Two files with the same name in different issuer folders would silently
    // resolve to whichever the enumerator reached last.
    let duplicates = Dictionary(grouping: art, by: \.imageName).filter { $0.value.count > 1 }
    guard duplicates.isEmpty else {
        let detail = duplicates.keys.sorted().joined(separator: ", ")
        throw PublishError("Duplicate imageName in \(cardArtDirectory): \(detail)")
    }

    return art.sorted { $0.imageName < $1.imageName }
}

/// Keys already pushed to R2. Uploading 163 images through `npx wrangler` takes
/// minutes, and content-addressed keys never change once written — so a normal
/// publish should upload nothing. Committed so the record survives a fresh clone.
struct ArtIndex {
    static let filename = "art-uploaded.json"
    var keys: Set<String>

    static func load(from url: URL) -> ArtIndex {
        guard let data = try? Data(contentsOf: url),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let keys = root["keys"] as? [String] else {
            return ArtIndex(keys: [])
        }
        return ArtIndex(keys: Set(keys))
    }

    func write(to url: URL) throws {
        let body: [String: Any] = [
            "note": "Card art keys already uploaded to R2. Content-addressed, so entries are never removed — "
                  + "an old key must keep resolving for rollback. Delete this file to force a full re-upload.",
            "keys": keys.sorted()
        ]
        try canonicalData(body).write(to: url, options: .atomic)
    }
}

// MARK: - Load-bearing IDs

/// Category ids as the app assembles them: hand-authored files plus the ones
/// synthesized from merchant `brandCategory` blocks. Mirrors
/// SeedDataLoader.loadCategoryTemplates() + MerchantSeedDatabase.brandCategoryTemplates().
/// Read-only here — categories and merchants aren't published yet, but their ids
/// are already user-referenced, so the lock has to cover them.
func loadCategoryIDs(repoRoot: URL, merchants: [[String: Any]]) throws -> Set<String> {
    var ids: Set<String> = []

    let categoryDir = repoRoot.appendingPathComponent("Chur/Resources/json/categories")
    for url in try jsonFiles(in: categoryDir) {
        let parsed = try JSONSerialization.jsonObject(with: try Data(contentsOf: url))
        guard let array = parsed as? [[String: Any]] else {
            throw PublishError("\(url.lastPathComponent): expected an array of category objects")
        }
        for object in array {
            if let id = object["id"] as? String, !id.isEmpty { ids.insert(id) }
        }
    }

    for entry in merchants where entry["brandCategory"] != nil {
        if let category = entry["category"] as? String, !category.isEmpty { ids.insert(category) }
    }

    return ids
}

/// Every id namespace that persisted user data points at, keyed by namespace name.
///
/// Renaming or removing one of these is destructive in a way no compiler catches:
/// the JSON is just strings, and the damage lands on devices 30 minutes after a
/// publish. Slots are scoped per card because `card.slotSelections` is.
func loadBearingIDs(cards: [[String: Any]],
                    rewards: [String: Any],
                    benefits: [[String: Any]],
                    categoryIDs: Set<String>) -> [String: Set<String>] {
    var planIDs: Set<String> = []
    var slots: Set<String> = []

    for (cardID, structure) in rewards {
        var rewardObjects: [[String: Any]] = []

        if let container = structure as? [String: Any], let plans = container["plans"] as? [[String: Any]] {
            for plan in plans {
                if let planID = plan["planID"] as? String, !planID.isEmpty { planIDs.insert(planID) }
                rewardObjects += (plan["rewards"] as? [[String: Any]]) ?? []
            }
        } else if let simple = structure as? [[String: Any]] {
            rewardObjects = simple
        }

        for reward in rewardObjects {
            if let slot = reward["configurableSlot"] as? String, !slot.isEmpty {
                slots.insert("\(cardID):\(slot)")
            }
        }
    }

    return [
        "cards": Set(cards.compactMap { $0["id"] as? String }),
        "benefits": Set(benefits.compactMap { $0["id"] as? String }),
        "plans": planIDs,
        "slots": slots,
        "categories": categoryIDs
    ]
}

/// What each namespace costs when an id disappears — printed with the error so
/// the consequence is in front of you at the moment you'd otherwise override it.
let namespaceStakes: [String: String] = [
    "cards": "CreditCard.templateID — the card silently stops syncing and keeps stale rates forever",
    "benefits": "Benefit.id — CardSyncService deletes the benefit, and usageHistory cascades, so the user's redemption history is destroyed",
    "plans": "card.selectedPlanID — the user's chosen reward plan resets to nil",
    "slots": "card.slotSelections — the user's category picks are orphaned and reward categories re-derive wrong",
    "categories": "User.selectedCategories / deselectedCategories — the user's picks go inert"
]

/// Append-only registry of every id ever published, per namespace.
///
/// Lives beside the publisher rather than in Resources/json because it is
/// publishing infrastructure, not seed data — the app must not bundle it.
struct IDLock {
    var namespaces: [String: (active: Set<String>, retired: Set<String>)]

    static let filename = "id-lock.json"

    static func load(from url: URL) throws -> IDLock? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let stored = root["namespaces"] as? [String: [String: Any]] else {
            throw PublishError("\(filename) is malformed — expected a 'namespaces' object")
        }
        var namespaces: [String: (active: Set<String>, retired: Set<String>)] = [:]
        for (name, entry) in stored {
            namespaces[name] = (
                active: Set((entry["active"] as? [String]) ?? []),
                retired: Set((entry["retired"] as? [String]) ?? [])
            )
        }
        return IDLock(namespaces: namespaces)
    }

    func write(to url: URL) throws {
        let body: [String: Any] = [
            "version": 1,
            "note": "Ids that persisted user data points at. Append-only: never rename or remove one. "
                  + "To retire an id, move it from 'active' to 'retired' — and leave the entry itself in the "
                  + "seed data, hidden (categories: visibility 'hidden'; benefits: isActive false), so existing "
                  + "user references keep resolving. ChurContentPublish refuses to publish if an active id disappears.",
            "namespaces": namespaces.mapValues { value in
                ["active": value.active.sorted(), "retired": value.retired.sorted()]
            }
        ]
        try canonicalData(body).write(to: url, options: .atomic)
    }
}

/// Compares the current ids against the lock, adds new ones, and refuses the
/// publish when an active id has vanished. Runs before anything is written or
/// uploaded, so a violation costs nothing but a re-run.
func enforceIDLock(current: [String: Set<String>], lockURL: URL) throws {
    let existing = try IDLock.load(from: lockURL)

    guard var lock = existing else {
        let seeded = IDLock(namespaces: current.mapValues { (active: $0, retired: []) })
        try seeded.write(to: lockURL)
        let total = current.values.reduce(0) { $0 + $1.count }
        print("🔒 Seeded \(IDLock.filename) with \(total) ids across \(current.count) namespaces — commit it.")
        return
    }

    var violations: [(namespace: String, ids: [String])] = []
    var additions: [(namespace: String, count: Int)] = []
    var mutated = false

    for (namespace, ids) in current.sorted(by: { $0.key < $1.key }) {
        let entry = lock.namespaces[namespace] ?? (active: [], retired: [])

        let missing = entry.active.subtracting(ids).sorted()
        if !missing.isEmpty {
            violations.append((namespace, missing))
        }

        // A retired id that came back is fine — it just becomes active again.
        let added = ids.subtracting(entry.active).sorted()
        if !added.isEmpty {
            lock.namespaces[namespace] = (
                active: entry.active.union(ids),
                retired: entry.retired.subtracting(ids)
            )
            additions.append((namespace, added.count))
            mutated = true
        }
    }

    guard violations.isEmpty else {
        var message = "ID lock violation — publishing refused.\n"
        for (namespace, ids) in violations {
            message += "\n   \(namespace): \(ids.joined(separator: ", "))"
            if let stakes = namespaceStakes[namespace] {
                message += "\n      \(stakes)"
            }
        }
        message += """

        \nThese ids are gone from the seed data but shipped to users already.
        A rename counts twice: the new id is added and the old one disappears.

        Either restore the id, or retire it deliberately:
          1. keep the entry in the seed data, hidden — categories: "visibility": "hidden", benefits: "isActive": false
          2. move the id from "active" to "retired" in Scripts/ChurContentPublish/\(IDLock.filename)

        There is no override flag. That is the point.
        """
        throw PublishError(message)
    }

    if mutated {
        try lock.write(to: lockURL)
        let summary = additions.map { "\($0.namespace) +\($0.count)" }.joined(separator: ", ")
        print("🔒 \(IDLock.filename) updated (\(summary)) — commit it alongside the JSON.")
    }
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
/// bundles plus its manifest. Without this, versions accumulate and it stops being obvious
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
func upload(_ file: URL, key: String, bucket: String, contentType: String = "application/json") throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = [
        "npx", "--yes", "wrangler", "r2", "object", "put",
        "\(bucket)/\(key)",
        "--file", file.path,
        "--content-type", contentType,
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
    let benefits = try loadBenefits(repoRoot: args.repoRoot)
    let merchants = try loadMerchants(repoRoot: args.repoRoot)
    let merchantMappings = try loadMerchantMappings(repoRoot: args.repoRoot)
    let cardArt = try loadCardArt(repoRoot: args.repoRoot)

    // A card whose imageName has no image file renders the placeholder forever —
    // invisible unless someone opens that specific card.
    let artNames = Set(cardArt.map { $0.imageName })
    let cardsMissingArt = cards
        .compactMap { $0["imageName"] as? String }
        .filter { !artNames.contains($0) }
        .sorted()
    if !cardsMissingArt.isEmpty {
        print("⚠️  Cards whose imageName has no art (\(cardsMissingArt.count)): \(Set(cardsMissingArt).sorted().joined(separator: ", "))")
    }

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

    // A card listing a benefit id with no file is silently skipped by
    // CardSyncService.syncBenefits — the perk just never appears on the card.
    // Warn rather than block: one missing benefit must not stop a publish that
    // fixes a reward rate.
    let benefitIDs = Set(benefits.compactMap { $0["id"] as? String })
    let referencedBenefitIDs = Set(cards.flatMap { ($0["benefits"] as? [String]) ?? [] })
    let missingBenefits = referencedBenefitIDs.subtracting(benefitIDs).sorted()
    if !missingBenefits.isEmpty {
        print("⚠️  Benefits referenced by a card but not authored (\(missingBenefits.count)): \(missingBenefits.joined(separator: ", "))")
    }

    // Load-bearing ids are checked before anything is written or uploaded, so a
    // violation costs a re-run rather than a bad publish.
    let categoryIDs = try loadCategoryIDs(repoRoot: args.repoRoot, merchants: merchants)
    // A merchant pointing at a category that doesn't exist falls back to the
    // "everything" rate instead of its intended one — a wrong price, not an error.
    let merchantCategoryRefs = merchants.compactMap { entry -> (String, String)? in
        guard let id = entry["id"] as? String, let category = entry["category"] as? String else { return nil }
        return (id, category)
    }
    let danglingMerchants = merchantCategoryRefs
        .filter { !categoryIDs.contains($0.1) }
        .map { "\($0.0) → \($0.1)" }
        .sorted()
    if !danglingMerchants.isEmpty {
        print("⚠️  Merchants pointing at a missing category (\(danglingMerchants.count)): \(danglingMerchants.joined(separator: ", "))")
    }

    let mappedCategoryIDs = Set((merchantMappings["exactMatches"] as? [String: String])?.values ?? [:].values)
    let danglingMappings = mappedCategoryIDs.subtracting(categoryIDs).sorted()
    if !danglingMappings.isEmpty {
        print("⚠️  Map exactMatches pointing at a missing category (\(danglingMappings.count)): \(danglingMappings.joined(separator: ", "))")
    }

    let currentIDs = loadBearingIDs(cards: cards, rewards: rewards, benefits: benefits, categoryIDs: categoryIDs)
    let lockURL = args.repoRoot
        .appendingPathComponent("Scripts/ChurContentPublish")
        .appendingPathComponent(IDLock.filename)
    try enforceIDLock(current: currentIDs, lockURL: lockURL)

    try FileManager.default.createDirectory(at: args.outDir, withIntermediateDirectories: true)

    // Read the previous version before clearing — the old manifest is what
    // the auto-increment is based on.
    let version = resolveVersion(explicit: args.version, outDir: args.outDir)
    try clean(args.outDir)

    let entries = [
        try write(cards, domain: "cards", version: version, to: args.outDir),
        try write(rewards, domain: "rewards", version: version, to: args.outDir),
        try write(benefits, domain: "benefits", version: version, to: args.outDir),
        try write(merchants, domain: "merchants", version: version, to: args.outDir),
        try write(merchantMappings, domain: "merchantMappings", version: version, to: args.outDir),
        try write(cardArt.reduce(into: [String: Any]()) { index, art in
            index[art.imageName] = [
                "url": "\(args.baseURL)/\(art.key)",
                "sha256": art.sha256,
                "bytes": art.bytes
            ]
        }, domain: "cardArt", version: version, to: args.outDir)
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
    print("   cards:    \(cards.count) cards, \(entries[0].bytes) bytes")
    print("   rewards:  \(rewards.count) entries, \(entries[1].bytes) bytes")
    print("   benefits: \(benefits.count) benefits, \(entries[2].bytes) bytes")
    print("   merchants: \(merchants.count) merchants, \(entries[3].bytes) bytes")
    print("   mappings: \(merchantMappings.count) rule groups, \(entries[4].bytes) bytes")
    print("   cardArt: \(cardArt.count) images, \(entries[5].bytes) bytes index (\(cardArt.reduce(0) { $0 + $1.bytes } / 1_048_576) MB of PNGs)")
    print("   manifest: \(manifestData.count) bytes, base URL \(args.baseURL)")

    if args.upload {
        // Art first, then bundles, manifest last. Same reasoning at each step:
        // nothing may point at something that isn't uploaded yet.
        print("\nUploading to R2 bucket '\(args.bucket)'…")

        let artIndexURL = args.repoRoot
            .appendingPathComponent("Scripts/ChurContentPublish")
            .appendingPathComponent(ArtIndex.filename)
        var artIndex = ArtIndex.load(from: artIndexURL)

        let pendingArt = cardArt.filter { !artIndex.keys.contains($0.key) }
        if pendingArt.isEmpty {
            print("   ✓ card art unchanged (\(cardArt.count) images already uploaded)")
        } else {
            print("   uploading \(pendingArt.count) new or changed image(s) — this is the slow part…")
            for art in pendingArt {
                try upload(art.source, key: art.key, bucket: args.bucket, contentType: art.contentType)
                artIndex.keys.insert(art.key)
                // Written after every image so an interrupted run doesn't
                // re-upload everything it already managed to push.
                try artIndex.write(to: artIndexURL)
                print("   ✓ \(art.key)")
            }
            print("   \(ArtIndex.filename) updated — commit it.")
        }

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
        print("\nUpload every file in \(args.outDir.lastPathComponent)/ to the R2 bucket root.")
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
