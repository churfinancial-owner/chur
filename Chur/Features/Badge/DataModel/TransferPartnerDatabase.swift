//
//  TransferPartnerDatabase.swift
//  Chur
//
//  Loads transfer partner data from SeedDataTransferPartners.json.
//  Partner metadata (name, type, alliance, logo) is resolved from PartnerDatabase.

import Foundation

// MARK: - Resolved Models

struct TransferPartner {
    let partnerId: String
    let name: String        // Resolved from PartnerDatabase.shortName
    let type: String        // "airline" or "hotel"
    let alliance: String?   // "star", "oneworld", "skyteam", or nil
    let ratio: String       // "points:miles" — "1:1", "1:1.6"
    let iconName: String?   // Asset image name from PartnerDatabase

    /// Miles received per point transferred, parsed from `ratio` (P1f part 5).
    /// `"1:1.6"` is 1.6. nil when the string is not a parseable pair.
    var milesPerPoint: Double? {
        let parts = ratio.split(separator: ":").map { Double($0.trimmingCharacters(in: .whitespaces)) }
        guard parts.count == 2, let points = parts[0], let miles = parts[1], points > 0 else { return nil }
        return miles / points
    }

    /// What one mile costs on this route, given the program's point value.
    /// `1:1` at a point worth HK$0.10 is HK$0.10 a mile.
    func costPerMile(pointCashValue: Double) -> Double? {
        guard let milesPerPoint, milesPerPoint > 0 else { return nil }
        return pointCashValue / milesPerPoint
    }

    init(ref: TransferPartnerRef, partner: Partner?) {
        self.partnerId = ref.partnerId
        self.name = partner?.shortName ?? ref.partnerId
        self.type = partner?.type ?? "airline"
        self.alliance = partner?.alliance
        self.ratio = ref.ratio
        self.iconName = partner?.logoImageName
    }
}

/// What a bank charges to move points out, e.g. Citi HK's HK$200 per redemption.
///
/// **Display only**, like a gate or a cap: its real cost per mile depends on how
/// many points the user moves, which the app does not know. Shown so the reader
/// can judge whether a small transfer is worth making at all.
struct TransferFee: Codable, Equatable {
    let amount: Double
    let currency: String
    /// `redemption` (default) — one flat charge per transfer request.
    /// `transaction` — charged per partner transaction within a redemption.
    var basis: String?
    var note: String?

    var resolvedBasis: String { basis ?? "redemption" }
}

struct TransferProgram {
    let programName: String   // Matches RewardRate.rewardProgramName (e.g. "Ultimate Rewards")
    let displayName: String   // Short label for UI (e.g. "Chase")
    let region: String?       // "US", "HK", etc. nil means available in all regions
    let partners: [TransferPartner]
    /// Handling fee charged to move points out, when the bank charges one.
    let fee: TransferFee?

    /// The cheapest mile available on this program, and the partner offering it.
    func bestRoute(pointCashValue: Double) -> (partner: TransferPartner, costPerMile: Double)? {
        partners
            .compactMap { partner in
                partner.costPerMile(pointCashValue: pointCashValue).map { (partner: partner, costPerMile: $0) }
            }
            .min { $0.costPerMile < $1.costPerMile }
    }
}

// MARK: - Private JSON Models

struct TransferPartnerRef: Codable {
    let partnerId: String
    let ratio: String
}

private struct TransferProgramJSON: Codable {
    let programName: String
    let displayName: String
    let region: String?
    let fee: TransferFee?
    let partners: [TransferPartnerRef]
}

private struct TransferPartnerFile: Codable {
    let programs: [TransferProgramJSON]
}

// MARK: - Database

enum TransferPartnerDatabase {

    private(set) static var programs: [TransferProgram] = []

    /// Every program in the payload, ignoring the region filter.
    ///
    /// `programs` is filtered to the user's region because the Points Transfer
    /// tool answers "what could I do from here". A card in the wallet is
    /// concrete, so its own info screen looks here instead: a US-resident user
    /// holding an HSBC HK card should still see where that card's points go.
    private(set) static var allPrograms: [TransferProgram] = []

    /// All unique airline partner short names, sorted
    private(set) static var airlines: [String] = []

    /// All unique hotel partner short names, sorted
    private(set) static var hotels: [String] = []

    /// programDisplayName → Set of partner short names
    private(set) static var mappings: [String: Set<String>] = [:]

    /// programDisplayName → [partnerName: ratio]
    private(set) static var transferRatios: [String: [String: String]] = [:]

    /// partnerName → alliance asset image name
    private(set) static var allianceImages: [String: String] = [:]

    /// partnerName → icon asset image name
    private(set) static var partnerIcons: [String: String] = [:]

    /// Display names for the top "Point Sources" row
    static var displayNames: [String] { programs.map(\.displayName) }

    // MARK: - Loading

    /// Load transfer partners for a specific region. Programs with a matching region (or no region) are included.
    static func loadFromBundle(region: String = "US") {
        if let remote: TransferPartnerFile = RemoteSeed.decode(.transferPartners, label: "TransferPartnerDatabase"),
           !remote.programs.isEmpty {
            apply(remote, region: region)
            return
        }

        guard let url = Bundle.main.url(forResource: "SeedDataTransferPartners", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            #if DEBUG
            print("⚠️ TransferPartnerDatabase: SeedDataTransferPartners.json not found")
            #endif
            return
        }

        do {
            apply(try JSONDecoder().decode(TransferPartnerFile.self, from: data), region: region)
        } catch {
            #if DEBUG
            print("❌ TransferPartnerDatabase: Failed to decode: \(error)")
            #endif
        }
    }

    /// Resolves a decoded file into the published tables, whichever source it
    /// came from. Region filtering happens here rather than at the publish step:
    /// the bundle carries every region and the remote payload has to as well, so
    /// switching region in Settings stays a local reload rather than a download.
    private static func apply(_ file: TransferPartnerFile, region: String) {
        let resolvedAll = file.programs.map { json -> TransferProgram in
            let resolved = json.partners.map { ref in
                TransferPartner(ref: ref, partner: PartnerDatabase.byID[ref.partnerId])
            }
            return TransferProgram(
                programName: json.programName,
                displayName: json.displayName,
                region: json.region,
                partners: resolved,
                fee: json.fee
            )
        }
        allPrograms = resolvedAll
        programs = resolvedAll.filter { $0.region == nil || $0.region == region }
        buildDerivedData()
        #if DEBUG
        print("✅ TransferPartnerDatabase: Loaded \(programs.count) programs for region \(region), \(airlines.count) airlines, \(hotels.count) hotels")
        #endif
    }

    // MARK: - Lookups

    /// The transfer program a reward program name belongs to, region ignored.
    /// nil means the program has no partners, i.e. the card earns cash or points
    /// that do not move to an airline.
    static func program(named programName: String) -> TransferProgram? {
        allPrograms.first { $0.programName == programName }
    }

    /// Get the programName (for matching RewardRate) from a display name
    static func programName(for displayName: String) -> String? {
        programs.first(where: { $0.displayName == displayName })?.programName
    }

    /// Get ratio between a program (by displayName) and a partner (by short name)
    static func ratio(program displayName: String, partner: String) -> String? {
        guard let program = programs.first(where: { $0.displayName == displayName }),
              let partnerEntry = program.partners.first(where: { $0.name == partner }) else {
            return nil
        }
        return partnerEntry.ratio
    }

    /// Get alliance image asset name for a partner (by short name)
    static func allianceImage(for partnerName: String) -> String? {
        allianceImages[partnerName]
    }

    // MARK: - Private

    private static func buildDerivedData() {
        var airlineSet = Set<String>()
        var hotelSet = Set<String>()
        var newMappings: [String: Set<String>] = [:]
        var newRatios: [String: [String: String]] = [:]
        var newAlliances: [String: String] = [:]
        var newIcons: [String: String] = [:]

        for program in programs {
            var partnerNames = Set<String>()
            var ratioMap: [String: String] = [:]

            for partner in program.partners {
                partnerNames.insert(partner.name)
                ratioMap[partner.name] = partner.ratio

                if partner.type == "airline" {
                    airlineSet.insert(partner.name)
                } else if partner.type == "hotel" {
                    hotelSet.insert(partner.name)
                }

                if let alliance = partner.alliance, newAlliances[partner.name] == nil {
                    switch alliance {
                    case "star":     newAlliances[partner.name] = "icon_star_alliance"
                    case "oneworld": newAlliances[partner.name] = "icon_oneworld_alliance"
                    case "skyteam":  newAlliances[partner.name] = "icon_skyteam_alliance"
                    default: break
                    }
                }

                if let icon = partner.iconName, newIcons[partner.name] == nil {
                    newIcons[partner.name] = icon
                }
            }

            newMappings[program.displayName] = partnerNames
            newRatios[program.displayName] = ratioMap
        }

        airlines = airlineSet.sorted()
        hotels = hotelSet.sorted()
        mappings = newMappings
        transferRatios = newRatios
        allianceImages = newAlliances
        partnerIcons = newIcons
    }
}
