//
//  main.swift
//  ChurContentPublish
//
//  Aggregates Chur/Resources/json/ into CDN-ready content bundles + a manifest.
//
//  Usage:
//    swift run ChurContentPublish                    # write dist/ only
//    swift run ChurContentPublish --upload           # write dist/ and push to R2
//    swift run ChurContentPublish --verify           # check what the CDN serves now
//
//  Options:
//    --verify                  validate live content and exit; touches nothing
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

// MARK: - Domains

/// Every domain this script publishes, in the order it writes them.
///
/// Mirrors `ContentDomain` in the app, minus nothing — if the app knows a domain
/// this list omits, `--verify` will not notice the gap, which is the failure it
/// exists to report. `SeedDataRegions` is in neither, on purpose (ROADMAP §P1d).
let allDomains = [
    "cards", "rewards", "benefits", "merchants", "merchantMappings",
    "cardArt", "iconArt",
    "categories", "recommendations",
    "badges", "partners", "transferPartners", "autoRentalCoverage", "cellPhoneProtection",
    "issuers", "programs", "programUpgrades", "boostPrograms"
]

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
    var verify: Bool

    static func parse() throws -> Arguments {
        var repo: String?
        var out: String?
        var version: Int?
        var baseURL = "https://content.chur.app"
        var minAppVersion = "1.0.0"
        var upload = false
        var bucket = "chur-content"
        var verify = false

        var iterator = CommandLine.arguments.dropFirst().makeIterator()
        while let flag = iterator.next() {
            // Boolean flags take no value, so handle them before reading ahead.
            if flag == "--upload" {
                upload = true
                continue
            }
            if flag == "--verify" {
                verify = true
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

        // --verify reads only the CDN, so it must not require being run from
        // inside a checkout — it is the tool you reach for when production looks
        // wrong, which is not always at your desk.
        let repoRoot = try repo.map { URL(fileURLWithPath: $0) }
            ?? (verify ? URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                       : Arguments.findRepoRoot())
        let outDir = out.map { URL(fileURLWithPath: $0) } ?? repoRoot.appendingPathComponent("dist")

        return Arguments(repoRoot: repoRoot,
                         outDir: outDir,
                         version: version,
                         baseURL: baseURL,
                         minAppVersion: minAppVersion,
                         upload: upload,
                         bucket: bucket,
                         verify: verify)
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

// MARK: - P1d domains

/// A single seed file that is already a JSON array — badges, partners, issuers,
/// coverage tables, boost programs.
///
/// The app decodes each of these with one `JSONDecoder().decode([T].self)`, so
/// the published bundle is the file's own bytes re-serialized, not a
/// restructuring. Keeping the shape identical is what lets the remote branch in
/// each `*Database` be a one-line swap of where the `Data` came from.
func loadSeedArray(repoRoot: URL, path: String) throws -> [[String: Any]] {
    let url = repoRoot.appendingPathComponent("Chur/Resources/json/\(path)")
    let parsed = try JSONSerialization.jsonObject(with: try Data(contentsOf: url))
    guard let array = parsed as? [[String: Any]] else {
        throw PublishError("\(path): expected an array of objects at the top level")
    }
    guard !array.isEmpty else {
        throw PublishError("\(path): is empty — publishing it would blank the domain on every device")
    }
    return array
}

/// A single seed file that is a JSON object — reward programs, transfer partners.
func loadSeedObject(repoRoot: URL, path: String) throws -> [String: Any] {
    let url = repoRoot.appendingPathComponent("Chur/Resources/json/\(path)")
    let object = try parseObject(at: url)
    guard !object.isEmpty else {
        throw PublishError("\(path): is empty — publishing it would blank the domain on every device")
    }
    return object
}

/// `categories/SeedDataCategories_*.json` — each an array, concatenated in
/// filename order.
///
/// Mirrors `SeedDataLoader.loadCategoryTemplates()`, with one deliberate
/// difference: that function *also* appends the categories synthesized from
/// merchant `brandCategory` blocks, and this must not. Those already travel in
/// the `merchants` domain, and publishing them twice would put the same id in
/// two bundles with no rule about which wins.
///
/// The precedence the app applies — hand-authored beats merchant-derived on an
/// id clash, because only hand-authored carries `cardFilter` — stays where it
/// is, in the loader. This domain is the hand-authored half alone.
func loadCategories(repoRoot: URL) throws -> [[String: Any]] {
    let dir = repoRoot.appendingPathComponent("Chur/Resources/json/categories")
    var categories: [[String: Any]] = []
    var seenIDs: [String: String] = [:]   // id -> filename that claimed it

    for url in try jsonFiles(in: dir) {
        let parsed = try JSONSerialization.jsonObject(with: try Data(contentsOf: url))
        guard let array = parsed as? [[String: Any]] else {
            throw PublishError("\(url.lastPathComponent): expected an array of category objects")
        }
        for object in array {
            guard let id = object["id"] as? String, !id.isEmpty else {
                throw PublishError("\(url.lastPathComponent): a category is missing its 'id'")
            }
            // Two files claiming one category id is decided by enumeration
            // order on device, and a category is a persisted SpendingCategory —
            // so publishing would freeze an arbitrary choice into every wallet.
            if let existing = seenIDs[id] {
                // Named separately when it is one file: "in X and X" reads like a
                // bug in the checker rather than a copy-paste in the data, and
                // the first real hit was exactly that case.
                let where_ = existing == url.lastPathComponent
                    ? "twice in \(url.lastPathComponent)"
                    : "in \(url.lastPathComponent) and \(existing)"
                throw PublishError("Duplicate category id '\(id)' \(where_)")
            }
            seenIDs[id] = url.lastPathComponent
            categories.append(object)
        }
    }

    guard !categories.isEmpty else { throw PublishError("No categories found under \(dir.path)") }
    return categories
}

/// `recommendations/<region>/<issuer>/rec_*.json` — one object per file,
/// aggregated into an array. The region and issuer folders are organizational;
/// `RecommendationDatabase` walks the whole tree.
func loadRecommendations(repoRoot: URL) throws -> [[String: Any]] {
    let dir = repoRoot.appendingPathComponent("Chur/Resources/json/recommendations")
    var recommendations: [[String: Any]] = []
    var seenIDs: [String: String] = [:]   // cardTemplateID -> filename that claimed it

    for url in try jsonFiles(in: dir) {
        let object = try parseObject(at: url)
        guard let id = object["cardTemplateID"] as? String, !id.isEmpty else {
            throw PublishError("\(url.lastPathComponent): missing or empty string field 'cardTemplateID'")
        }
        if let existing = seenIDs[id] {
            throw PublishError("Duplicate recommendation for card '\(id)' in \(url.lastPathComponent) and \(existing)")
        }
        seenIDs[id] = url.lastPathComponent
        recommendations.append(object)
    }

    guard !recommendations.isEmpty else { throw PublishError("No recommendations found under \(dir.path)") }
    return recommendations
}

// MARK: - Art

/// Source of truth for card images, relative to the repo root.
let cardArtDirectory = "CardArt"

/// Badge, bank and partner icons (P1d). Same shape, same rules, separate folder
/// and separate index domain so a broken icon publish cannot cost card art.
let iconArtDirectory = "IconArt"

/// One image, keyed by the `imageName` the JSON refers to.
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

/// Every image under an art directory. The filename is the `imageName` the JSON
/// refers to; the subfolders are for humans only and nothing here reads them.
///
/// Deliberately outside `Chur/`: that folder is a synchronized root group in the
/// Xcode project, so art living under it would be compiled back into the app —
/// the 19 MB that removing card art saved, and the 7.6 MB icons added in P1d.
///
/// One function for both directories on purpose. When `Assets.xcassets/Cards`
/// was deleted in P1b the publisher kept building its index from the old path,
/// found nothing, and published `{}` — so the *second* art source is exactly
/// where a copy-pasted variant would drift out of sync with the guard that
/// caught it.
func loadArt(repoRoot: URL, directory: String) throws -> [CardArt] {
    let dir = repoRoot.appendingPathComponent(directory)

    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: dir.path, isDirectory: &isDirectory), isDirectory.boolValue else {
        throw PublishError("Art directory missing: \(dir.path)")
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
        throw PublishError("No art found under \(dir.path) — publishing an empty index would break every domain on device")
    }

    // Two files with the same name in different subfolders would silently
    // resolve to whichever the enumerator reached last.
    let duplicates = Dictionary(grouping: art, by: \.imageName).filter { $0.value.count > 1 }
    guard duplicates.isEmpty else {
        let detail = duplicates.keys.sorted().joined(separator: ", ")
        throw PublishError("Duplicate imageName in \(directory): \(detail)")
    }

    // Finder appends " 2" when a file is copied into a folder that already holds
    // it, and the result is a perfectly valid *different* imageName — which is
    // why the check above waves it through. 55 sailed into contentVersion 28
    // that way: inert, because nothing references "icon_delta 2", but 55
    // pointless objects in R2 and 11 KB of index nobody could explain.
    //
    // Blocks rather than warns. No art name has ever contained a space, so this
    // is never intentional, the fix is `git clean -f`, and a warning is what
    // gets skimmed — which is exactly how all 55 shipped.
    let finderCopies = art
        .map(\.imageName)
        .filter { $0.range(of: #" \d+$"#, options: .regularExpression) != nil }
        .sorted()
    guard finderCopies.isEmpty else {
        throw PublishError("""
            \(directory) holds \(finderCopies.count) Finder duplicate(s) — files macOS named "… 2" when copied.
               Nothing references these names, so publishing them adds dead weight to the index.
               Remove them and re-run:  git clean -f \(directory)/
               \(finderCopies.prefix(8).joined(separator: ", "))\(finderCopies.count > 8 ? ", …" : "")
            """)
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
            "note": "Card and icon art keys already uploaded to R2. Content-addressed, so entries are never removed — "
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
                    categoryIDs: Set<String>,
                    boostPrograms: [[String: Any]]) -> [String: Set<String>] {
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

    // `user.boostEnrollments[program.id] = tier` — the id is the key and the
    // tier name is the value, so both are load-bearing. Joined the lock in P1d,
    // when boost programs became remotely publishable; before that a rename
    // needed a release, which is at least visible.
    var boosts: Set<String> = []
    for program in boostPrograms {
        guard let id = program["id"] as? String, !id.isEmpty else { continue }
        boosts.insert(id)
        for tier in (program["tiers"] as? [[String: Any]]) ?? [] {
            if let name = tier["name"] as? String, !name.isEmpty {
                boosts.insert("\(id):\(name)")
            }
        }
    }

    return [
        "cards": Set(cards.compactMap { $0["id"] as? String }),
        "benefits": Set(benefits.compactMap { $0["id"] as? String }),
        "plans": planIDs,
        "slots": slots,
        "categories": categoryIDs,
        "boostPrograms": boosts
    ]
}

/// What each namespace costs when an id disappears — printed with the error so
/// the consequence is in front of you at the moment you'd otherwise override it.
let namespaceStakes: [String: String] = [
    "cards": "CreditCard.templateID — the card silently stops syncing and keeps stale rates forever",
    "benefits": "Benefit.id — CardSyncService deletes the benefit, and usageHistory cascades, so the user's redemption history is destroyed",
    "plans": "card.selectedPlanID — the user's chosen reward plan resets to nil",
    "slots": "card.slotSelections — the user's category picks are orphaned and reward categories re-derive wrong",
    "categories": "User.selectedCategories / deselectedCategories — the user's picks go inert",
    "boostPrograms": "User.boostEnrollments — the user's relationship tier is dropped, so every boosted rate silently reverts to 1.0x"
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
    // Before the file exists, not after: a payload the app would reject should
    // never reach dist/, where the next run's --upload would find it.
    try validatePayload(data, domain: domain)

    let filename = "\(domain)-\(version).json"
    try data.write(to: outDir.appendingPathComponent(filename), options: .atomic)
    return BundleEntry(domain: domain, filename: filename, sha256: sha256Hex(data), bytes: data.count)
}

// MARK: - Payload validation

/// The app's structural rules, applied to the bytes about to be uploaded.
///
/// **Keep in sync with `RemoteContentService.validate(_:for:)`** — the app is the
/// real contract, and it rejects a whole refresh when one domain fails, taking
/// every other domain down with it.
///
/// This script already validates its *inputs* thoroughly. What it never did was
/// look at its *output*: `loadCardArt()` returning an empty array was a legitimate
/// `[CardArt]`, it reduced into `{}`, and that uploaded happily as contentVersion
/// 16 — which the app then refused, so no remote content applied at all until it
/// was republished. Checking assembled bytes closes that whole class rather than
/// adding one more input guard per incident.
///
/// P1c note: when the JSON contract spec exists, these rules and the app's should
/// both be checked against it. Android needs them too and cannot import Swift.
func validatePayload(_ data: Data, domain: String) throws {
    let parsed = try JSONSerialization.jsonObject(with: data)

    func objects() throws -> [[String: Any]] {
        guard let array = parsed as? [[String: Any]], !array.isEmpty else {
            throw PublishError("\(domain): expected a non-empty array of objects — the app would reject this payload")
        }
        return array
    }

    func requireNonEmptyString(_ key: String, in array: [[String: Any]]) throws {
        guard array.allSatisfy({ ($0[key] as? String)?.isEmpty == false }) else {
            throw PublishError("\(domain): every entry needs a non-empty '\(key)' — the app would reject this payload")
        }
    }

    switch domain {
    case "cards", "benefits":
        try requireNonEmptyString("id", in: try objects())

    case "merchants":
        let array = try objects()
        try requireNonEmptyString("id", in: array)
        // A merchant with no category synthesizes a SpendingCategory with an
        // empty id, on every device.
        try requireNonEmptyString("category", in: array)

    case "rewards":
        guard let dictionary = parsed as? [String: Any], !dictionary.isEmpty else {
            throw PublishError("rewards: expected a non-empty object keyed by card id — the app would reject this payload")
        }

    case "merchantMappings":
        guard let dictionary = parsed as? [String: Any], dictionary["exactMatches"] is [String: Any] else {
            throw PublishError("merchantMappings: expected an object with 'exactMatches' — the app would reject this payload")
        }

    case "cardArt", "iconArt":
        guard let dictionary = parsed as? [String: Any], !dictionary.isEmpty else {
            throw PublishError("\(domain): expected a non-empty object keyed by imageName — the app would reject this payload")
        }
        guard dictionary.values.allSatisfy({ ($0 as? [String: Any])?["url"] is String }) else {
            throw PublishError("\(domain): every entry needs a 'url' — the app would reject this payload")
        }

    // MARK: P1d domains

    // Id-keyed catalogs. `categories` is in this list and is the one that moves
    // prices rather than labels — a category with a blank id would synthesize a
    // persisted SpendingCategory nothing can address.
    case "badges", "partners", "issuers", "boostPrograms", "programUpgrades", "categories":
        try requireNonEmptyString("id", in: try objects())

    case "recommendations":
        try requireNonEmptyString("cardTemplateID", in: try objects())

    // Coverage tables key off the card they describe, not off an id of their own.
    case "autoRentalCoverage", "cellPhoneProtection":
        try requireNonEmptyString("cardId", in: try objects())

    case "transferPartners":
        guard let dictionary = parsed as? [String: Any],
              let programs = dictionary["programs"] as? [[String: Any]], !programs.isEmpty else {
            throw PublishError("transferPartners: expected an object with a non-empty 'programs' array — the app would reject this payload")
        }

    case "programs":
        // Keyed by program *name* ("Ultimate Rewards"), not by an id field —
        // these names are what card JSON references, so an empty object silently
        // zeroes every card's point value.
        guard let dictionary = parsed as? [String: Any], !dictionary.isEmpty else {
            throw PublishError("programs: expected a non-empty object keyed by program name — the app would reject this payload")
        }

    default:
        // A domain the app knows about but this script forgot to cover is worse
        // than an unvalidated one, because it looks checked.
        throw PublishError("\(domain): no validation rule — add one here and in RemoteContentService")
    }
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

// MARK: - Verifying what is actually live

/// Synchronous fetch. A CLI has no run loop to await on, and this runs a handful
/// of requests in sequence — the ceremony of an async main earns nothing here.
func fetchSync(_ url: URL) throws -> Data {
    var request = URLRequest(url: url)
    request.cachePolicy = .reloadIgnoringLocalCacheData

    var result: Result<Data, Error>?
    let semaphore = DispatchSemaphore(value: 0)

    URLSession.shared.dataTask(with: request) { data, response, error in
        defer { semaphore.signal() }
        if let error {
            result = .failure(PublishError("\(url.lastPathComponent): \(error.localizedDescription)"))
            return
        }
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            result = .failure(PublishError("\(url.lastPathComponent): HTTP \(code)"))
            return
        }
        result = .success(data ?? Data())
    }.resume()

    semaphore.wait()
    guard let result else { throw PublishError("\(url.lastPathComponent): no response") }
    return try result.get()
}

/// Checks what the CDN is serving right now, rather than what this run would
/// produce. Answers a different question from the pre-upload validation: not
/// "is my candidate sound" but "is production currently broken".
///
/// Exists because the empty cardArt index of 2026-08-14 was live for hours, and
/// the only symptom was a truncated line in a debug menu on a phone.
func verifyLive(baseURL: String) throws {
    print("Verifying \(baseURL)…\n")

    guard let manifestURL = URL(string: "\(baseURL)/manifest.json") else {
        throw PublishError("Malformed base URL '\(baseURL)'")
    }
    let manifestData = try fetchSync(manifestURL)
    guard let manifest = try JSONSerialization.jsonObject(with: manifestData) as? [String: Any],
          let version = manifest["contentVersion"] as? Int,
          let bundles = manifest["bundles"] as? [[String: Any]] else {
        throw PublishError("manifest.json is malformed")
    }

    print("   contentVersion \(version), minAppVersion \(manifest["minAppVersion"] as? String ?? "?")")
    print("   generated \(manifest["generatedAt"] as? String ?? "?")")
    print("   \(bundles.count) bundle(s)\n")

    var failures: [String] = []

    for bundle in bundles {
        guard let domain = bundle["domain"] as? String,
              let urlString = bundle["url"] as? String,
              let url = URL(string: urlString),
              let expectedHash = bundle["sha256"] as? String else {
            failures.append("a manifest entry is missing domain/url/sha256")
            continue
        }

        do {
            let data = try fetchSync(url)

            // Same three checks the app makes, in the same order, so a failure
            // here names exactly what a device would have hit.
            guard sha256Hex(data) == expectedHash.lowercased() else {
                failures.append("\(domain): checksum mismatch — the app discards this")
                continue
            }
            try validatePayload(data, domain: domain)
            print("   ✓ \(domain) — \(data.count) bytes")
        } catch let error as PublishError {
            failures.append(error.description)
        }
    }

    // Art is the half this never looked at. The manifest's bundles are JSON, and
    // the 322 images they index are separate objects that no check has ever
    // touched — so an art index could list a key that 404s and every line above
    // would still print a tick. Twice now the art path has failed while the
    // pipeline reported success, which is two more times than a spot-check costs.
    //
    // A sample, not all 322: this runs on demand and downloading 17 MB to answer
    // "is production broken" would stop anyone running it.
    failures += verifyArtSample(bundles: bundles)

    // The app iterates its own ContentDomain list, so a domain it knows about and
    // the manifest omits falls back to the bundle rather than failing. Worth
    // saying out loud: it means a build can be newer than what is published.
    let published = Set(bundles.compactMap { $0["domain"] as? String })
    let missing = allDomains.filter { !published.contains($0) }
    if !missing.isEmpty {
        print("\n   ℹ️  Not published (the app falls back to its bundle): \(missing.joined(separator: ", "))")
    }

    guard failures.isEmpty else {
        print("\n❌ Live content is broken — the app rejects the whole refresh, every domain:\n")
        for failure in failures { print("   • \(failure)") }
        print("\n   Republish to replace it. Devices stay on their last good version meanwhile.")
        throw PublishError("verification failed")
    }

    print("\n✅ Live content is valid — contentVersion \(version).")
}

/// Fetches a handful of images out of each published art index and checks they
/// resolve and match their recorded hash — the check `--verify` never had.
///
/// Sampled deterministically (evenly spaced through the sorted names) rather
/// than at random, so two runs against the same version report the same thing.
/// The failure this is built for is systemic — a whole index pointing at keys
/// that were never uploaded — and a systemic failure shows up in any sample.
/// It will not catch one individually missing image, and is not meant to.
func verifyArtSample(bundles: [[String: Any]], perDomain: Int = 4) -> [String] {
    var failures: [String] = []

    for domain in ["cardArt", "iconArt"] {
        guard let bundle = bundles.first(where: { $0["domain"] as? String == domain }),
              let urlString = bundle["url"] as? String,
              let url = URL(string: urlString),
              let data = try? fetchSync(url),
              let index = try? JSONSerialization.jsonObject(with: data) as? [String: [String: Any]],
              !index.isEmpty else {
            continue   // A missing or unreadable index is already reported above.
        }

        let names = index.keys.sorted()
        let stride = max(1, names.count / perDomain)
        let sample = Swift.stride(from: 0, to: names.count, by: stride).prefix(perDomain).map { names[$0] }

        var checked = 0
        for name in sample {
            guard let entry = index[name],
                  let imageURLString = entry["url"] as? String,
                  let imageURL = URL(string: imageURLString),
                  let expected = entry["sha256"] as? String else {
                failures.append("\(domain): '\(name)' has no usable url/sha256")
                continue
            }
            do {
                let bytes = try fetchSync(imageURL)
                guard sha256Hex(bytes) == expected.lowercased() else {
                    failures.append("\(domain): '\(name)' is served but its bytes do not match the index hash")
                    continue
                }
                checked += 1
            } catch {
                failures.append("\(domain): '\(name)' does not resolve — \(imageURLString)")
            }
        }
        if checked == sample.count {
            print("   ✓ \(domain) images — \(checked) of \(names.count) sampled, all resolve and match")
        }
    }

    return failures
}

// MARK: - Main

do {
    let args = try Arguments.parse()

    // Read-only, and answers a question about production rather than about this
    // checkout, so it deliberately runs before anything is loaded or assembled.
    if args.verify {
        try verifyLive(baseURL: args.baseURL)
        exit(0)
    }

    let cards = try loadCards(repoRoot: args.repoRoot)
    let rewards = try loadRewards(repoRoot: args.repoRoot)
    let benefits = try loadBenefits(repoRoot: args.repoRoot)
    let merchants = try loadMerchants(repoRoot: args.repoRoot)
    let merchantMappings = try loadMerchantMappings(repoRoot: args.repoRoot)
    let cardArt = try loadArt(repoRoot: args.repoRoot, directory: cardArtDirectory)
    let iconArt = try loadArt(repoRoot: args.repoRoot, directory: iconArtDirectory)

    // P1d domains. Loaded before anything is written, so a malformed file costs
    // a re-run rather than a partial publish.
    let categories = try loadCategories(repoRoot: args.repoRoot)
    let recommendations = try loadRecommendations(repoRoot: args.repoRoot)
    let badges = try loadSeedArray(repoRoot: args.repoRoot, path: "badges/SeedDatabadges.json")
    let partners = try loadSeedArray(repoRoot: args.repoRoot, path: "badges/SeedDataPartners.json")
    let transferPartners = try loadSeedObject(repoRoot: args.repoRoot, path: "badges/SeedDataTransferPartners.json")
    let autoRentalCoverage = try loadSeedArray(repoRoot: args.repoRoot, path: "badges/SeedDataAutoRentalCoverage.json")
    let cellPhoneProtection = try loadSeedArray(repoRoot: args.repoRoot, path: "badges/SeedDataCellPhoneProtection.json")
    let issuers = try loadSeedArray(repoRoot: args.repoRoot, path: "control/SeedDataIssuers.json")
    let programs = try loadSeedObject(repoRoot: args.repoRoot, path: "control/SeedDataPrograms.json")
    let programUpgrades = try loadSeedArray(repoRoot: args.repoRoot, path: "control/SeedDataProgramUpgrades.json")
    let boostPrograms = try loadSeedArray(repoRoot: args.repoRoot, path: "bankrelationshipprograms/boost_programs.json")

    // SeedDataRegions.json is deliberately absent. It gates onboarding and locale
    // resolution, changes approximately never, and a bad payload would leave a
    // user with no region to pick — see ROADMAP §P1d.

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

    // The icon equivalent, and the reason it earns a place next to it: an icon
    // that resolves to nothing falls back to an emoji or an empty slot, which
    // reads as a design choice rather than as breakage. 25 names were in that
    // state when P1d started, some for months. Warn rather than block — a
    // missing logo must not stop a publish that fixes a rate.
    let iconNames = Set(iconArt.map { $0.imageName })
    var referencedIcons: Set<String> = []
    for entry in merchants { if let icon = entry["merchantIconName"] as? String { referencedIcons.insert(icon) } }
    for entry in categories { if let icon = entry["iconName"] as? String { referencedIcons.insert(icon) } }
    for entry in issuers { if let icon = entry["logoImageName"] as? String { referencedIcons.insert(icon) } }
    for entry in partners { if let icon = entry["logoImageName"] as? String { referencedIcons.insert(icon) } }
    // A badge icon may legitimately name an SF Symbol, which has no file here;
    // badge art is the `badge_` prefixed half.
    for entry in badges {
        if let icon = entry["icon"] as? String, icon.hasPrefix("badge_") { referencedIcons.insert(icon) }
    }
    let missingIcons = referencedIcons.subtracting(iconNames).sorted()
    if !missingIcons.isEmpty {
        print("⚠️  Icon names with no file in \(iconArtDirectory)/ (\(missingIcons.count)): \(missingIcons.joined(separator: ", "))")
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

    let currentIDs = loadBearingIDs(cards: cards,
                                    rewards: rewards,
                                    benefits: benefits,
                                    categoryIDs: categoryIDs,
                                    boostPrograms: boostPrograms)
    let lockURL = args.repoRoot
        .appendingPathComponent("Scripts/ChurContentPublish")
        .appendingPathComponent(IDLock.filename)
    try enforceIDLock(current: currentIDs, lockURL: lockURL)

    try FileManager.default.createDirectory(at: args.outDir, withIntermediateDirectories: true)

    // Read the previous version before clearing — the old manifest is what
    // the auto-increment is based on.
    let version = resolveVersion(explicit: args.version, outDir: args.outDir)
    try clean(args.outDir)

    func artIndexPayload(_ art: [CardArt]) -> [String: Any] {
        art.reduce(into: [String: Any]()) { index, art in
            index[art.imageName] = [
                "url": "\(args.baseURL)/\(art.key)",
                "sha256": art.sha256,
                "bytes": art.bytes
            ]
        }
    }

    let entries = [
        try write(cards, domain: "cards", version: version, to: args.outDir),
        try write(rewards, domain: "rewards", version: version, to: args.outDir),
        try write(benefits, domain: "benefits", version: version, to: args.outDir),
        try write(merchants, domain: "merchants", version: version, to: args.outDir),
        try write(merchantMappings, domain: "merchantMappings", version: version, to: args.outDir),
        try write(artIndexPayload(cardArt), domain: "cardArt", version: version, to: args.outDir),
        try write(artIndexPayload(iconArt), domain: "iconArt", version: version, to: args.outDir),
        try write(categories, domain: "categories", version: version, to: args.outDir),
        try write(recommendations, domain: "recommendations", version: version, to: args.outDir),
        try write(badges, domain: "badges", version: version, to: args.outDir),
        try write(partners, domain: "partners", version: version, to: args.outDir),
        try write(transferPartners, domain: "transferPartners", version: version, to: args.outDir),
        try write(autoRentalCoverage, domain: "autoRentalCoverage", version: version, to: args.outDir),
        try write(cellPhoneProtection, domain: "cellPhoneProtection", version: version, to: args.outDir),
        try write(issuers, domain: "issuers", version: version, to: args.outDir),
        try write(programs, domain: "programs", version: version, to: args.outDir),
        try write(programUpgrades, domain: "programUpgrades", version: version, to: args.outDir),
        try write(boostPrograms, domain: "boostPrograms", version: version, to: args.outDir)
    ]

    // The one thing `allDomains` is for is `--verify` reporting an unpublished
    // domain, and it can only do that if it agrees with what was actually
    // written. Cheap to assert, and the alternative is a list that quietly rots.
    let writtenDomains = Set(entries.map { $0.domain })
    guard writtenDomains == Set(allDomains) else {
        let unlisted = writtenDomains.subtracting(allDomains).sorted()
        let unwritten = Set(allDomains).subtracting(writtenDomains).sorted()
        throw PublishError("allDomains is out of date — written but unlisted: \(unlisted.joined(separator: ", ")); listed but unwritten: \(unwritten.joined(separator: ", "))")
    }

    let formatter = ISO8601DateFormatter()
    let manifest: [String: Any] = [
        "contentVersion": version,
        "minAppVersion": args.minAppVersion,
        "generatedAt": formatter.string(from: Date()),
        "bundles": entries.map { $0.manifestObject(baseURL: args.baseURL) }
    ]
    let manifestData = try canonicalData(manifest)
    try manifestData.write(to: args.outDir.appendingPathComponent("manifest.json"), options: .atomic)

    // Looked up by domain rather than indexed positionally: the byte counts are
    // the free diff that tells you whether an edit landed, and reading them off
    // `entries[5]` was one reordered line away from reporting the wrong domain's
    // size — which is exactly the check nobody would re-verify.
    let bytesByDomain = Dictionary(uniqueKeysWithValues: entries.map { ($0.domain, $0.bytes) })
    func summarize(_ domain: String, _ detail: String) {
        print("   \(domain): \(detail), \(bytesByDomain[domain] ?? 0) bytes")
    }
    func megabytes(_ art: [CardArt]) -> String {
        String(format: "%.1f MB", Double(art.reduce(0) { $0 + $1.bytes }) / 1_048_576)
    }

    print("✅ contentVersion \(version) → \(args.outDir.path)")
    summarize("cards", "\(cards.count) cards")
    summarize("rewards", "\(rewards.count) entries")
    summarize("benefits", "\(benefits.count) benefits")
    summarize("merchants", "\(merchants.count) merchants")
    summarize("merchantMappings", "\(merchantMappings.count) rule groups")
    summarize("cardArt", "\(cardArt.count) images (\(megabytes(cardArt)) of files)")
    summarize("iconArt", "\(iconArt.count) icons (\(megabytes(iconArt)) of files)")
    summarize("categories", "\(categories.count) hand-authored categories")
    summarize("recommendations", "\(recommendations.count) cards")
    summarize("badges", "\(badges.count) badges")
    summarize("partners", "\(partners.count) partners")
    summarize("transferPartners", "\((transferPartners["programs"] as? [Any])?.count ?? 0) programs")
    summarize("autoRentalCoverage", "\(autoRentalCoverage.count) cards")
    summarize("cellPhoneProtection", "\(cellPhoneProtection.count) cards")
    summarize("issuers", "\(issuers.count) issuers")
    summarize("programs", "\(programs.count) programs")
    summarize("programUpgrades", "\(programUpgrades.count) paths")
    summarize("boostPrograms", "\(boostPrograms.count) programs")
    print("   manifest: \(manifestData.count) bytes, base URL \(args.baseURL)")

    if args.upload {
        // Art first, then bundles, manifest last. Same reasoning at each step:
        // nothing may point at something that isn't uploaded yet.
        print("\nUploading to R2 bucket '\(args.bucket)'…")

        let artIndexURL = args.repoRoot
            .appendingPathComponent("Scripts/ChurContentPublish")
            .appendingPathComponent(ArtIndex.filename)
        var artIndex = ArtIndex.load(from: artIndexURL)

        // One upload record for both art sets. Keys are content-addressed and
        // the two name spaces are disjoint, so a shared index is correct and
        // means an icon added today is skipped by every later card-art publish.
        let allArt = cardArt + iconArt
        let pendingArt = allArt.filter { !artIndex.keys.contains($0.key) }
        if pendingArt.isEmpty {
            print("   ✓ art unchanged (\(allArt.count) images already uploaded)")
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

        // A publish used to end here, on the strength of wrangler's exit codes.
        // Three times in one session that was wrong: an empty cardArt index in
        // P1b, a cardArt-26.json that never landed, and 55 phantom icons — each
        // time this printed a tick and the CDN disagreed. `--verify` already
        // knew how to catch all three; it was just something you had to
        // remember to run, about a failure you had no reason to suspect.
        //
        // Publishing and confirming are one action now, the same way publishing
        // and committing are.
        print("\n✅ Uploaded contentVersion \(version). Confirming what is live…\n")

        do {
            try verifyLive(baseURL: args.baseURL)
        } catch {
            // R2 is read-after-write consistent, but a custom domain sits in
            // front of it, so a check running the instant the manifest lands can
            // lose a race it has no business losing. One retry — a false alarm
            // here would train you to ignore the real one.
            print("\n   Disagreed on the first look — waiting 5s in case the CDN had not caught up…\n")
            Thread.sleep(forTimeInterval: 5)
            do {
                try verifyLive(baseURL: args.baseURL)
            } catch {
                // Distinct from a pre-upload failure, and the difference matters:
                // the bytes are already in the bucket, so this is "fix and
                // republish", not "nothing happened".
                throw PublishError("""
                    uploaded contentVersion \(version), but the CDN does not serve it correctly — see above.
                       Devices stay on their last good version, so nothing is broken for users.
                       Re-run --upload to replace it.
                    """)
            }
        }
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
