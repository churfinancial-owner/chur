import Foundation
import SwiftData

// MARK: - JSON Codable Structures

struct CategoryJSON: Codable {
    let id: String
    let nameEN: String
    let nameZH_Hans: String
    let nameZH_HK: String
    let nameZH_TW: String
    let emoji: String
    let iconName: String?
    let sortOrder: Int
    let isDefault: Bool
    let parentCategoryID: String?
    let level: String?
    let categoryLinks: [CategoryLink]?
    let excludeFromParent: Bool? // optional — defaults to false if absent from JSON
    let cardFilter: CardFilter?  // NEW: optional card filtering rules
    let excludedPaymentMethods: [String]? // Payment methods not accepted (e.g. ["apple_pay", "mobile_pay"])
    let channels: [String]? // Optional channel constraints (e.g. ["online"] for paypal_pay)
    let visibility: String? // Optional picker visibility ("hidden" hides from picker)
}

private struct CardJSON: Codable {
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
}

/// A single selectable option in a configurable reward slot.
/// Always an object — label is shown in the UI, includes are the category IDs this option covers.
private struct ConfigurableOption: Codable {
    let label: String
    let includes: [String]
}

private struct RewardJSON: Codable {
    let rate: Double
    let rewardProgramName: String
    let pointCashValue: Double?
    let category: String?           // legacy single string — supported for backwards compatibility
    let categories: [String]?       // new multi-category array
    let merchantIdentifier: String?
    let merchantName: String?
    let channels: [String]?
    let rewardStartDate: String?
    let rewardEndDate: String?
    let isRotating: Bool?
    let rewardNotes: String?
    let groupLabel: String?
    let isUserConfigurable: Bool?
    let configurableSlot: String?
    let configurableOptions: [ConfigurableOption]?

    /// Resolves either the new `categories` array or the legacy `category` string
    var resolvedCategories: [String]? {
        categories ?? category.map { [$0] }
    }
}

// MARK: - New Plan-Based Structures

private struct RewardPlanJSON: Codable {
    let planID: String
    let planName: String
    let isDefault: Bool
    let isAvailableForNewUsers: Bool
    let planStartDate: String?
    let planEndDate: String?
    let isPromo: Bool?
    let rewards: [RewardJSON]
}

private struct RewardPlanContainer: Codable {
    let plans: [RewardPlanJSON]
}

/// Support both old (simple array) and new (plans object) formats
private enum RewardStructure: Codable {
    case simple([RewardJSON])           // Old format: direct array of rewards
    case plans(RewardPlanContainer)     // New format: plans with metadata
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        // Try to decode as array first (old format)
        if let rewards = try? container.decode([RewardJSON].self) {
            self = .simple(rewards)
            return
        }
        
        // Try to decode as plan container (new format)
        if let planContainer = try? container.decode(RewardPlanContainer.self) {
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

private struct RewardProgramJSON: Codable {
    let pointCashValue: Double
    let currency: String
}

// MARK: - Loader

struct SeedDataLoader {

    // MARK: - Categories

    /// Deletes all existing SpendingCategory records and re-inserts from JSON.
    /// Use this to pick up category JSON changes without restarting the app.
    static func reloadCategories(into modelContext: ModelContext) {
        do {
            try modelContext.delete(model: SpendingCategory.self)
            #if DEBUG
            print("✅ SeedDataLoader: Deleted all SpendingCategory records")
            #endif
        } catch {
            #if DEBUG
            print("❌ SeedDataLoader: Failed to delete SpendingCategory records: \(error)")
            #endif
        }
        loadCategories(into: modelContext)
        #if DEBUG
        print("✅ SeedDataLoader: Categories reloaded from JSON")
        #endif
    }

    /// Decodes all SeedDataCategories_*.json from the bundle.
    /// Returns the raw decoded templates for use by CategorySyncService.
    static func loadCategoryTemplates() -> [CategoryJSON] {
        var allCategories: [CategoryJSON] = []
        let matchingURLs = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: nil)?
            .filter { $0.lastPathComponent.hasPrefix("SeedDataCategories_") } ?? []

        for url in matchingURLs {
            do {
                let data = try Data(contentsOf: url)
                let batch = try JSONDecoder().decode([CategoryJSON].self, from: data)
                allCategories.append(contentsOf: batch)
            } catch {
                #if DEBUG
                print("❌ SeedDataLoader: Failed to decode '\(url.lastPathComponent)': \(error)")
                #endif
            }
        }

        // Brand target categories auto-generated from SeedDataMerchants.json.
        // Hand-authored categories win on ID conflict (they can carry cardFilter etc.).
        let handAuthoredIDs = Set(allCategories.map(\.id))
        for template in MerchantSeedDatabase.brandCategoryTemplates() {
            if handAuthoredIDs.contains(template.id) {
                #if DEBUG
                print("⚠️ SeedDataLoader: brandCategory '\(template.id)' also hand-authored in a SeedDataCategories file — using the hand-authored one")
                #endif
            } else {
                allCategories.append(template)
            }
        }
        return allCategories
    }

    static func loadCategories(into modelContext: ModelContext) {
        let allCategories = loadCategoryTemplates()

        if allCategories.isEmpty {
            #if DEBUG
            print("⚠️ SeedDataLoader: No categories loaded from split files")
            #endif
            return
        }

        for item in allCategories {
            let level = item.level.flatMap { CategoryLevel(rawValue: $0) }

            let category = SpendingCategory(
                id: item.id,
                nameEN: item.nameEN,
                nameZH_Hans: item.nameZH_Hans,
                nameZH_HK: item.nameZH_HK,
                nameZH_TW: item.nameZH_TW,
                emoji: item.emoji,
                iconName: item.iconName,
                sortOrder: item.sortOrder,
                isDefault: item.isDefault,
                parentCategoryID: item.parentCategoryID,
                level: level,
                categoryLinks: item.categoryLinks,
                excludeFromParent: item.excludeFromParent ?? false,
                cardFilter: item.cardFilter,
                excludedPaymentMethods: item.excludedPaymentMethods,
                channels: item.channels,
                visibility: item.visibility
            )

            modelContext.insert(category)
        }
    }

    // MARK: - Cards + Rewards + Benefits

    static func loadCards(into modelContext: ModelContext) {
        #if DEBUG
        print("🚀 SeedDataLoader.loadCards() called")
        #endif
        
        guard let cards: [CardJSON] = parseJSON(from: "SeedDatacards") else {
            return
        }
        guard let rewardsMap: [String: RewardStructure] = parseJSON(from: "SeedDatarewards") else {
            return
        }
        let programsMap: [String: RewardProgramJSON] = parseJSON(from: "SeedDataPrograms") ?? [:]

        #if DEBUG
        print("📚 Loaded \(cards.count) cards from JSON")
        print("🎁 Loaded \(rewardsMap.count) reward structures")
        #endif

        // Get current month and year for default approval date
        // Using Date.current() to respect time travel for testing
        let calendar = Calendar.current
        let now = Date.current()
        let currentMonth = calendar.component(.month, from: now)
        let currentYear = calendar.component(.year, from: now)
        
        for cardData in cards {
            let card = CreditCard(
                id: cardData.id,
                name: cardData.name,
                issuer: cardData.issuer,
                network: cardData.network,
                imageName: cardData.imageName,
                cardType: cardData.cardType,
                annualFee: cardData.annualFee,
                approvedMonth: currentMonth,
                approvedYear: currentYear,
                hasForeignTransactionFee: cardData.hasForeignTransactionFee,
                foreignTransactionFeeRate: cardData.foreignTransactionFeeRate
            )
            modelContext.insert(card)

            // Handle both old and new reward formats
            if let rewardStructure = rewardsMap[cardData.id] {
                switch rewardStructure {
                case .simple(let rewardsList):
                    // OLD FORMAT: Create a single default plan
                    #if DEBUG
                    print("📦 Loading OLD format rewards for: \(cardData.id)")
                    #endif
                    let defaultPlan = createDefaultPlan(
                        cardID: cardData.id,
                        rewards: rewardsList,
                        programsMap: programsMap,
                        modelContext: modelContext
                    )
                    card.rewardPlans.append(defaultPlan)
                    
                case .plans(let planContainer):
                    // NEW FORMAT: Create multiple plans
                    #if DEBUG
                    print("🎯 Loading NEW format plans for: \(cardData.id) (\(planContainer.plans.count) plans)")
                    #endif
                    for planJSON in planContainer.plans {
                        let plan = createPlan(
                            from: planJSON,
                            cardID: cardData.id,
                            programsMap: programsMap,
                            modelContext: modelContext
                        )
                        card.rewardPlans.append(plan)
                    }
                }
            } else {
                #if DEBUG
                print("⚠️ No rewards found for card: \(cardData.id)")
                #endif
            }

            #if DEBUG
            print("🎫 Loading \(cardData.benefits.count) benefits for card: \(cardData.id)")
            #endif
            
            for benefitID in cardData.benefits {
                if let template = BenefitDatabase.getBenefit(id: benefitID) {
                    let benefit = template.toBenefit(cardInstanceID: card.id, modelContext: modelContext)
                    card.benefits.append(benefit)
                    #if DEBUG
                    print("  ✅ Added benefit: \(benefitID)")
                    #endif
                } else {
                    #if DEBUG
                    print("  ⚠️ Benefit not found in database: \(benefitID)")
                    #endif
                }
            }
        }
    }
    
    // MARK: - Private Helpers for Reward Plans
    
    /// Creates a default plan from a simple array of rewards (old format)
    private static func createDefaultPlan(
        cardID: String,
        rewards: [RewardJSON],
        programsMap: [String: RewardProgramJSON],
        modelContext: ModelContext
    ) -> RewardPlan {
        let plan = RewardPlan(
            id: "\(cardID)-default",
            name: "Current Rewards",
            isDefault: true,
            isAvailableForNewUsers: true,
            isCustomPlan: false,
            isPromo: false
        )
        
        modelContext.insert(plan)
        
        for r in rewards {
            let reward = createRewardRate(from: r, programsMap: programsMap)
            modelContext.insert(reward)
            plan.rewards.append(reward)
        }
        
        return plan
    }
    
    /// Creates a plan from the new plan JSON format
    private static func createPlan(
        from planJSON: RewardPlanJSON,
        cardID: String,
        programsMap: [String: RewardProgramJSON],
        modelContext: ModelContext
    ) -> RewardPlan {
        let iso8601 = ISO8601DateFormatter()
        
        let plan = RewardPlan(
            id: planJSON.planID,
            name: planJSON.planName,
            isDefault: planJSON.isDefault,
            isAvailableForNewUsers: planJSON.isAvailableForNewUsers,
            planStartDate: planJSON.planStartDate.flatMap { iso8601.date(from: $0) },
            planEndDate: planJSON.planEndDate.flatMap { iso8601.date(from: $0) },
            isCustomPlan: false,
            isPromo: planJSON.isPromo ?? false
        )
        
        modelContext.insert(plan)
        
        for r in planJSON.rewards {
            let reward = createRewardRate(from: r, programsMap: programsMap)
            modelContext.insert(reward)
            plan.rewards.append(reward)
        }
        
        return plan
    }
    
    /// Creates a RewardRate from JSON
    private static func createRewardRate(
        from r: RewardJSON,
        programsMap: [String: RewardProgramJSON]
    ) -> RewardRate {
        let program = programsMap[r.rewardProgramName]
        let resolvedPointCashValue = r.pointCashValue ?? program?.pointCashValue ?? 0.01
        let resolvedCurrency = program?.currency ?? "USD"
        
        let iso8601 = ISO8601DateFormatter()
        let startDate = r.rewardStartDate.flatMap { iso8601.date(from: $0) }
        let endDate = r.rewardEndDate.flatMap { iso8601.date(from: $0) }
        
        return RewardRate(
            rate: r.rate,
            rewardProgramName: r.rewardProgramName,
            pointCashValue: resolvedPointCashValue,
            pointCashValueCurrency: resolvedCurrency,
            categories: r.resolvedCategories,
            merchantIdentifier: r.merchantIdentifier,
            merchantName: r.merchantName,
            channels: r.channels,
            rewardStartDate: startDate,
            rewardEndDate: endDate,
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

    // MARK: - Private helper

    private static func parseJSON<T: Codable>(from filename: String) -> T? {
        guard let url = Bundle.main.url(forResource: filename, withExtension: "json") else {
            print("❌ SeedDataLoader: JSON file not found in bundle — '\(filename).json'")
            return nil
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            print("❌ SeedDataLoader: Failed to decode '\(filename).json' as \(T.self): \(error)")
            return nil
        }
    }
}
