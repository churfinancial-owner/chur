import Foundation
import SwiftData

// MARK: - Card Template

/// A lightweight, value-type snapshot of a card used for browsing.
/// It intentionally does NOT conform to @Model — it lives entirely in memory.
struct CardTemplate {
    let id: String
    let name: String
    let issuer: String
    let network: String
    let imageName: String
    let cardType: String
    let annualFee: Int
    let hasForeignTransactionFee: Bool
    let foreignTransactionFeeRate: Double?
    let benefitIDs: [String]
    let rewardPlans: [PlanTemplate]
    let isPopular: Bool
    let popularSortOrder: Int
    let country: String

    func toCreditCard(modelContext: ModelContext) -> CreditCard {
        let cardInstanceID = UUID().uuidString
        let now = Date.current()
        let calendar = Calendar.current
        let card = CreditCard(
            id: cardInstanceID,
            templateID: self.id,
            name: name,
            issuer: issuer,
            network: network,
            imageName: imageName,
            cardType: cardType,
            annualFee: annualFee,
            approvedMonth: calendar.component(.month, from: now),
            approvedDay: calendar.component(.day, from: now),
            approvedYear: calendar.component(.year, from: now),
            country: country,
            hasForeignTransactionFee: hasForeignTransactionFee,
            foreignTransactionFeeRate: foreignTransactionFeeRate
        )
        
        modelContext.insert(card)

        // Create reward plans
        for planTemplate in rewardPlans {
            let plan = RewardPlan(
                id: planTemplate.id,
                name: planTemplate.name,
                isDefault: planTemplate.isDefault,
                isAvailableForNewUsers: planTemplate.isAvailableForNewUsers,
                planStartDate: planTemplate.planStartDate,
                planEndDate: planTemplate.planEndDate,
                isCustomPlan: false,
                isPromo: planTemplate.isPromo  // ✅ Copy isPromo from template
            )
            modelContext.insert(plan)
            
            for r in planTemplate.rewards {
                let reward = RewardRate(
                    rate: r.rate,
                    rewardProgramName: r.rewardProgramName,
                    pointCashValue: r.pointCashValue,
                    pointCashValueCurrency: r.pointCashValueCurrency,
                    categories: r.categories,
                    merchantIdentifier: r.merchantIdentifier,
                    merchantName: r.merchantName,
                    countries: r.countries,
                    channels: r.channels,
                    rewardStartDate: r.rewardStartDate,
                    rewardEndDate: r.rewardEndDate,
                    isRotating: r.isRotating,
                    rewardNotes: r.rewardNotes,
                    groupLabel: r.groupLabel,
                    isUserConfigurable: r.isUserConfigurable,
                    configurableSlot: r.configurableSlot,
                    configurableOptions: r.configurableOptions,
                    configurableIncludes: r.configurableIncludes
                )
                modelContext.insert(reward)
                plan.rewards.append(reward)
            }
            
            card.rewardPlans.append(plan)
        }
        
        for benefitID in benefitIDs {
            if let template = BenefitDatabase.getBenefit(id: benefitID) {
                let benefit = template.toBenefit(cardInstanceID: cardInstanceID, modelContext: modelContext)
                card.benefits.append(benefit)
            }
        }
        
        return card
    }
}

// MARK: - Plan Template

struct PlanTemplate {
    let id: String
    let name: String
    let isDefault: Bool
    let isAvailableForNewUsers: Bool
    let planStartDate: Date?
    let planEndDate: Date?
    let isPromo: Bool  // NEW: Mark promotional plans
    let rewards: [RewardTemplate]
}

// MARK: - Reward Template

struct RewardTemplate {
    let rate: Double
    let rewardProgramName: String
    let pointCashValue: Double
    let pointCashValueCurrency: String
    let categories: [String]?
    let merchantIdentifier: String?
    let merchantName: String?
    let countries: [String]?
    let channels: [String]?
    let rewardStartDate: Date?
    let rewardEndDate: Date?
    let isRotating: Bool
    let rewardNotes: String?
    let groupLabel: String?
    let isUserConfigurable: Bool
    let configurableSlot: String?
    let configurableOptions: [String]?
    let configurableIncludes: [String: [String]]?
}

// MARK: - Private JSON shapes

private struct _CardJSON: Codable {
    let id: String
    let name: String
    let issuer: String
    let network: String
    let imageName: String
    let cardType: String
    let annualFee: Int
    let hasForeignTransactionFee: Bool
    let foreignTransactionFeeRate: Double?
    let benefits: [String]
    let isPopular: Bool?
    let popularSortOrder: Int?
    let country: String?  // Country where the card is issued (e.g., "US", "HK")
}

private struct _ConfigurableOption: Codable {
    let label: String
    let includes: [String]
}

private struct _RewardJSON: Codable {
    let rate: Double
    let rewardProgramName: String
    let pointCashValue: Double? // Optional — resolved from SeedDataPrograms if absent
    let category: String?       // Legacy single-value field
    let categories: [String]?   // Preferred multi-value field
    let merchantIdentifier: String?
    let merchantName: String?
    let countries: [String]?
    let channels: [String]?
    let rewardStartDate: String?
    let rewardEndDate: String?
    let isRotating: Bool?
    let rewardNotes: String?
    let groupLabel: String?
    let isUserConfigurable: Bool?
    let configurableSlot: String?
    let configurableOptions: [_ConfigurableOption]?
}

private struct _RewardProgramJSON: Codable {
    let pointCashValue: Double
    let currency: String
}

// MARK: - New Plan-Based Structures

private struct _RewardPlanJSON: Codable {
    let planID: String
    let planName: String
    let isDefault: Bool
    let isAvailableForNewUsers: Bool
    let planStartDate: String?
    let planEndDate: String?
    let isPromo: Bool?  // NEW: Mark promotional plans
    let rewards: [_RewardJSON]
}

private struct _RewardPlanContainer: Codable {
    let plans: [_RewardPlanJSON]
}

/// Support both old (simple array) and new (plans object) formats
private enum _RewardStructure: Codable {
    case simple([_RewardJSON])          // Old format: direct array of rewards
    case plans(_RewardPlanContainer)    // New format: plans with metadata
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        // Try to decode as array first (old format)
        if let rewards = try? container.decode([_RewardJSON].self) {
            self = .simple(rewards)
            return
        }
        
        // Try to decode as plan container (new format)
        if let planContainer = try? container.decode(_RewardPlanContainer.self) {
            self = .plans(planContainer)
            return
        }
        
        throw DecodingError.dataCorrupted(
            DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Invalid reward structure: expected array or plans object"
            )
        )
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .simple(let rewards):
            try container.encode(rewards)
        case .plans(let planContainer):
            try container.encode(planContainer)
        }
    }
}

// MARK: - CardDatabase

struct CardDatabase {

    static func getAllCards() -> [CardTemplate] {
        return cachedCards
    }

    static func getCard(id: String) -> CardTemplate? {
        return cardsByID[id]
    }

    static func reloadFromBundle() {
        cachedCards = loadCachedCards()
        cardsByID = Dictionary(cachedCards.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
    }

    private static var cachedCards: [CardTemplate] = loadCachedCards()
    private static var cardsByID: [String: CardTemplate] = Dictionary(cachedCards.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })

    private static func loadCachedCards() -> [CardTemplate] {
        // Try to load from folder structure first
        var cards: [_CardJSON] = []
        
        if let folderCards = loadCardsFromFolders() {
            cards = folderCards
        } else if let legacyCards: [_CardJSON] = CardDatabase.parseJSON(from: TestDataConfiguration.SeedFiles.cards) {
            cards = legacyCards
        } else {
            print("⚠️ CardDatabase: No cards loaded")
            return []
        }

        // Load rewards dynamically from all *-rewards.json files in the rewards folder
        var rewardsMap: [String: _RewardStructure] = [:]
        
        let discoveredRewardFiles = CardDatabase.discoverRewardFiles()
        for file in discoveredRewardFiles {
            if let partialMap: [String: _RewardStructure] = CardDatabase.parseJSON(from: file) {
                rewardsMap.merge(partialMap) { _, new in new }
            }
        }
        
        // Fallback to monolithic file if no split files were loaded
        if rewardsMap.isEmpty {
            if let monolithicMap: [String: _RewardStructure] = CardDatabase.parseJSON(from: TestDataConfiguration.SeedFiles.rewards) {
                rewardsMap = monolithicMap
            }
        }
        
        let programsMap: [String: _RewardProgramJSON] = CardDatabase.parseJSON(from: "SeedDataPrograms") ?? [:]

        return cards.map { cardData in
            var planTemplates: [PlanTemplate] = []
            
            if let rewardStructure = rewardsMap[cardData.id] {
                switch rewardStructure {
                case .simple(let rewardsList):
                    // OLD FORMAT: Create a single default plan
                    let rewardTemplates = rewardsList.map { r in
                        createRewardTemplate(from: r, programsMap: programsMap)
                    }
                    
                    let defaultPlan = PlanTemplate(
                        id: "\(cardData.id)-default",
                        name: "Current Rewards",
                        isDefault: true,
                        isAvailableForNewUsers: true,
                        planStartDate: nil,
                        planEndDate: nil,
                        isPromo: false,  // Legacy cards default to non-promo
                        rewards: rewardTemplates
                    )
                    planTemplates.append(defaultPlan)
                    
                case .plans(let planContainer):
                    // NEW FORMAT: Create multiple plans
                    planTemplates = planContainer.plans.map { planJSON in
                        let iso8601 = ISO8601DateFormatter()
                        let rewardTemplates = planJSON.rewards.map { r in
                            createRewardTemplate(from: r, programsMap: programsMap)
                        }
                        
                        return PlanTemplate(
                            id: planJSON.planID,
                            name: planJSON.planName,
                            isDefault: planJSON.isDefault,
                            isAvailableForNewUsers: planJSON.isAvailableForNewUsers,
                            planStartDate: planJSON.planStartDate.flatMap { iso8601.date(from: $0) },
                            planEndDate: planJSON.planEndDate.flatMap { iso8601.date(from: $0) },
                            isPromo: planJSON.isPromo ?? false,  // ✅ Copy isPromo from JSON
                            rewards: rewardTemplates
                        )
                    }
                }
            }

            return CardTemplate(
                id: cardData.id,
                name: cardData.name,
                issuer: cardData.issuer,
                network: cardData.network,
                imageName: cardData.imageName,
                cardType: cardData.cardType,
                annualFee: cardData.annualFee,
                hasForeignTransactionFee: cardData.hasForeignTransactionFee,
                foreignTransactionFeeRate: cardData.foreignTransactionFeeRate,
                benefitIDs: cardData.benefits,
                rewardPlans: planTemplates,
                isPopular: cardData.isPopular ?? false,
                popularSortOrder: cardData.popularSortOrder ?? 999,
                country: cardData.country ?? "US"  // Default to US if not specified
            )
        }
    }
    
    /// Load cards from cards/**/*.json folder structure or flat bundle root
    private static func loadCardsFromFolders() -> [_CardJSON]? {
        let fileManager = FileManager.default
        
        // Try to find a cards folder first (preferred structure)
        let possiblePaths: [String?] = [
            nil,        // Root of bundle
            "SeedData", // Standard path
            "cards"     // Direct cards folder
        ]
        
        var cardsURL: URL?
        for subdirectory in possiblePaths {
            let url: URL?
            if let subdir = subdirectory {
                url = Bundle.main.url(forResource: "cards", withExtension: nil, subdirectory: subdir)
            } else {
                url = Bundle.main.url(forResource: "cards", withExtension: nil)
            }
            
            if let url = url {
                cardsURL = url
                break
            }
        }
        
        // If we found a cards folder, enumerate it
        if let cardsURL = cardsURL {
            guard let enumerator = fileManager.enumerator(at: cardsURL, includingPropertiesForKeys: [.isRegularFileKey]) else {
                return nil
            }
            
            var cards: [_CardJSON] = []
            
            for case let fileURL as URL in enumerator {
                guard fileURL.pathExtension == "json" else { continue }
                
                do {
                    let data = try Data(contentsOf: fileURL)
                    let cardJSON = try JSONDecoder().decode(_CardJSON.self, from: data)
                    cards.append(cardJSON)
                } catch {
                    print("⚠️ CardDatabase: Failed to load card from \(fileURL.lastPathComponent): \(error)")
                }
            }
            
            return cards.isEmpty ? nil : cards
        }
        
        // FALLBACK: If no cards folder, look for individual card JSON files in bundle root
        // This handles the case where files were added as groups and flattened to the root
        guard let bundleURL = Bundle.main.resourceURL else {
            return nil
        }
        
        guard let allFiles = try? fileManager.contentsOfDirectory(at: bundleURL, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) else {
            return nil
        }
        
        var cards: [_CardJSON] = []
        
        // Exclude reward data files from card parsing (discovered dynamically)
        let excludedRewardDataFiles = Set(CardDatabase.discoverRewardFiles().map { "\($0).json" })

        let cardFiles = allFiles.filter { url in
            url.pathExtension == "json" &&
            !url.lastPathComponent.hasPrefix("SeedData") &&
            !url.lastPathComponent.hasPrefix("EXAMPLE") &&
            !excludedRewardDataFiles.contains(url.lastPathComponent)
        }
        
        for fileURL in cardFiles {
            do {
                let data = try Data(contentsOf: fileURL)
                let cardJSON = try JSONDecoder().decode(_CardJSON.self, from: data)
                cards.append(cardJSON)
            } catch {
                // Silently skip files that don't match our card structure
                continue
            }
        }
        
        return cards.isEmpty ? nil : cards
    }
    
    /// Helper to create a RewardTemplate from JSON
    private static func createRewardTemplate(
        from r: _RewardJSON,
        programsMap: [String: _RewardProgramJSON]
    ) -> RewardTemplate {
        let program = programsMap[r.rewardProgramName]
        let resolvedPointCashValue = r.pointCashValue ?? program?.pointCashValue ?? 0.01
        let resolvedCurrency = program?.currency ?? "USD"
        let iso8601 = ISO8601DateFormatter()
        
        return RewardTemplate(
            rate: r.rate,
            rewardProgramName: r.rewardProgramName,
            pointCashValue: resolvedPointCashValue,
            pointCashValueCurrency: resolvedCurrency,
            categories: r.categories ?? r.category.map { [$0] },
            merchantIdentifier: r.merchantIdentifier,
            merchantName: r.merchantName,
            countries: r.countries,
            channels: r.channels,
            rewardStartDate: r.rewardStartDate.flatMap { iso8601.date(from: $0) },
            rewardEndDate: r.rewardEndDate.flatMap { iso8601.date(from: $0) },
            isRotating: r.isRotating ?? false,
            rewardNotes: r.rewardNotes,
            groupLabel: r.groupLabel,
            isUserConfigurable: r.isUserConfigurable ?? false,
            configurableSlot: r.configurableSlot,
            configurableOptions: r.configurableOptions.map { $0.map { $0.label } },
            configurableIncludes: r.configurableOptions.map { options in
                Dictionary(uniqueKeysWithValues: options.map { ($0.label, $0.includes) })
            }
        )
    }

    /// Dynamically discovers all *-rewards.json files in the bundle's rewards folder (or flat root).
    /// Returns filenames without the .json extension, e.g. ["chase-rewards", "amex-rewards", ...].
    /// Validates each candidate actually contains reward data (a dictionary of card-id → reward structures),
    /// to avoid picking up card JSON files whose names happen to end in "-rewards".
    private static func discoverRewardFiles() -> [String] {
        let fileManager = FileManager.default
        
        // Try rewards folder first (preferred structure)
        let folderNames = [nil, "SeedData", "rewards"]
        for subdirectory in folderNames {
            let url: URL?
            if let subdir = subdirectory {
                url = Bundle.main.url(forResource: "rewards", withExtension: nil, subdirectory: subdir)
            } else {
                url = Bundle.main.url(forResource: "rewards", withExtension: nil)
            }
            
            if let rewardsURL = url,
               let enumerator = fileManager.enumerator(at: rewardsURL, includingPropertiesForKeys: [.isRegularFileKey]) {
                var files: [String] = []
                for case let fileURL as URL in enumerator {
                    let name = fileURL.lastPathComponent
                    if name.hasSuffix("-rewards.json") {
                        files.append(String(name.dropLast(5))) // strip ".json"
                    }
                }
                if !files.isEmpty { return files }
            }
        }
        
        // Fallback: scan bundle root for *-rewards.json files
        guard let bundleURL = Bundle.main.resourceURL,
              let allFiles = try? fileManager.contentsOfDirectory(at: bundleURL, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) else {
            return []
        }
        
        let candidates = allFiles.filter { $0.lastPathComponent.hasSuffix("-rewards.json") }
        
        // Validate each candidate actually decodes as a reward dictionary,
        // not a single card JSON (which also matches *-rewards.json naming)
        return candidates.compactMap { url in
            guard let data = try? Data(contentsOf: url),
                  let _ = try? JSONDecoder().decode([String: _RewardStructure].self, from: data) else {
                return nil
            }
            return String(url.deletingPathExtension().lastPathComponent)
        }
    }

    private static func parseJSON<T: Codable>(from filename: String) -> T? {
        guard let url = Bundle.main.url(forResource: filename, withExtension: "json") else {
            print("❌ CardDatabase: JSON file not found in bundle — '\(filename).json'")
            return nil
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            print("❌ CardDatabase: Failed to decode '\(filename).json' as \(T.self): \(error)")
            return nil
        }
    }
}
