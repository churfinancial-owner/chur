//
//  TransferPartnerDatabase.swift
//  Chur
//
//  Loads transfer partner data from SeedDataTransferPartners.json

import Foundation

// MARK: - JSON Models

struct TransferPartner: Codable {
    let name: String
    let type: String         // "airline" or "hotel"
    let alliance: String?    // "star", "oneworld", "skyteam", or nil
    let ratio: String        // "1:1", "3:1.5", etc.
    let iconName: String?    // Asset image name (e.g. "icon_delta")
}

struct TransferProgram: Codable {
    let programName: String   // Matches RewardRate.rewardProgramName (e.g. "Ultimate Rewards")
    let displayName: String   // Short label for UI (e.g. "Chase")
    let region: String?       // "US", "HK", etc. nil means available in all regions
    let partners: [TransferPartner]
}

private struct TransferPartnerFile: Codable {
    let programs: [TransferProgram]
}

// MARK: - Database

enum TransferPartnerDatabase {
    
    private(set) static var programs: [TransferProgram] = []
    
    /// All unique airline partner names, sorted
    private(set) static var airlines: [String] = []
    
    /// All unique hotel partner names, sorted
    private(set) static var hotels: [String] = []
    
    /// programDisplayName → Set of partner names
    private(set) static var mappings: [String: Set<String>] = [:]
    
    /// programDisplayName → [partnerName: ratio]
    private(set) static var transferRatios: [String: [String: String]] = [:]
    
    /// partnerName → alliance asset image name
    private(set) static var allianceImages: [String: String] = [:]
    
    /// partnerName → icon asset image name (from JSON iconName field)
    private(set) static var partnerIcons: [String: String] = [:]
    
    /// Display names for the top "Point Sources" row
    static var displayNames: [String] { programs.map(\.displayName) }
    
    // MARK: - Loading
    
    /// Load transfer partners for a specific region. Programs with a matching region (or no region) are included.
    static func loadFromBundle(region: String = "US") {
        guard let url = Bundle.main.url(forResource: "SeedDataTransferPartners", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            #if DEBUG
            print("⚠️ TransferPartnerDatabase: SeedDataTransferPartners.json not found")
            #endif
            return
        }
        
        do {
            let file = try JSONDecoder().decode(TransferPartnerFile.self, from: data)
            programs = file.programs.filter { $0.region == nil || $0.region == region }
            buildDerivedData()
            #if DEBUG
            print("✅ TransferPartnerDatabase: Loaded \(programs.count) programs for region \(region), \(airlines.count) airlines, \(hotels.count) hotels")
            #endif
        } catch {
            #if DEBUG
            print("❌ TransferPartnerDatabase: Failed to decode: \(error)")
            #endif
        }
    }
    
    // MARK: - Lookups
    
    /// Get the programName (for matching RewardRate) from a display name
    static func programName(for displayName: String) -> String? {
        programs.first(where: { $0.displayName == displayName })?.programName
    }
    
    /// Get ratio between a program (by displayName) and a partner
    static func ratio(program displayName: String, partner: String) -> String? {
        guard let program = programs.first(where: { $0.displayName == displayName }),
              let partnerEntry = program.partners.first(where: { $0.name == partner }) else {
            return nil
        }
        return partnerEntry.ratio
    }
    
    /// Get alliance image asset name for a partner
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
