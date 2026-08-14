//
//  PricingEngineVectorTests.swift
//  ChurTests
//
//  Runs the shared pricing-engine vectors in `ChurTests/pricing-engine.json`.
//  The fixture — not this file — is the spec. See `Chur/PRICING_VECTORS_REFERENCE.md`.
//

import Foundation
import SwiftData
import Testing
@testable import Chur

// MARK: - Fixture model
//
// Mirrors ChurTests/pricing-engine.json. Every optional carries the same default
// the app's own model does, so a vector only states what it is actually testing.

private struct VectorFile: Codable, Sendable {
    let formatVersion: Int
    let categories: [CategoryFixture]
    let vectors: [Vector]
}

private struct CategoryFixture: Codable, Sendable {
    let id: String
    let name: String
    var level: CategoryLevel?
    var parentCategoryID: String?
    var categoryLinks: [String]?
    var excludeFromParent: Bool?
    var cardFilter: CardFilter?
    var excludedPaymentMethods: [String]?
    var channels: [String]?
}

private struct Vector: Codable, Sendable {
    let id: String
    let rule: String
    let input: Input
    let cards: [CardFixture]
    let expected: [ExpectedRow]
}

private struct Input: Codable, Sendable {
    let categoryID: String
    var region: String?
    var channel: String?
    var boostEnrollments: [String: String]?
    var allowPaymentMethodFallback: Bool?
    var forceCrossBorder: Bool?
    var acceptedPaymentMethods: [String]?
    var acceptedRegions: [String]?
    /// ISO-8601. Pins `Date.current()` so date-bounded rewards are deterministic.
    var asOf: String?
}

private struct CardFixture: Codable, Sendable {
    var id: String?
    let name: String
    var templateID: String?
    var issuer: String?
    var network: String?
    var country: String?
    var cardType: String?
    var status: String?
    var hasForeignTransactionFee: Bool?
    var foreignTransactionFeeRate: Double?
    var rewards: [RewardFixture]?
    var plans: [PlanFixture]?
}

private struct PlanFixture: Codable, Sendable {
    let id: String
    let name: String
    var isDefault: Bool?
    let rewards: [RewardFixture]
}

private struct RewardFixture: Codable, Sendable {
    let rate: Double
    var pointCashValue: Double?
    var pointCashValueCurrency: String?
    var rewardProgramName: String?
    var categories: [String]?
    var countries: [String]?
    var channels: [String]?
    var rewardStartDate: String?
    var rewardEndDate: String?
}

private struct ExpectedRow: Codable, Sendable {
    let name: String
    let effectiveCashBackRate: Double
    /// `CardRateSummary.rate` — the raw multiplier after any boost. Only asserted when present.
    var rate: Double?
}

// MARK: - Fixture loading

/// Marker for locating the test bundle — Swift Testing has no `XCTestCase` to hand to `Bundle(for:)`.
private final class BundleMarker {}

private enum Fixture {
    /// The fixture sits next to this file in `ChurTests/`, which is a **synchronized folder** in the
    /// Xcode project — every file inside it joins the target automatically, JSON included, so the
    /// fixture lands in the test bundle with no Build Phases wiring to set up or forget. It is
    /// outside `Chur/`, so it never compiles into the shipping app.
    ///
    /// The bundle is tried first because tests run inside the simulator, which cannot read paths on
    /// the host Mac. `#filePath` is kept as a fallback for any future host-side runner (a SwiftPM
    /// target, or a macOS destination), where the source tree *is* reachable.
    static let candidateURLs: [URL] = {
        var urls: [URL] = []
        if let bundled = Bundle(for: BundleMarker.self).url(forResource: "pricing-engine", withExtension: "json") {
            urls.append(bundled)
        }
        urls.append(
            URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()   // ChurTests/
                .appendingPathComponent("pricing-engine.json")
        )
        return urls
    }()

    /// `nil` rather than a crash: a missing fixture should be one readable red test, not a
    /// process abort that takes the whole suite's output with it.
    static let file: VectorFile? = {
        for url in candidateURLs {
            guard let data = try? Data(contentsOf: url) else { continue }
            return try? JSONDecoder().decode(VectorFile.self, from: data)
        }
        return nil
    }()

    static var vectors: [Vector] { file?.vectors ?? [] }

    static var loadDiagnostic: String {
        """
        pricing-engine.json was not readable at any known location.

        Tried:
        \(candidateURLs.map { "  • \($0.path)" }.joined(separator: "\n"))

        It should sit beside this file in ChurTests/ and be picked up automatically —
        ChurTests is a synchronized folder. If it is missing from the test bundle, check
        that ChurTests/pricing-engine.json exists on disk and rebuild.
        """
    }

    /// Built per call rather than cached — `ISO8601DateFormatter` is not `Sendable`, and
    /// a handful of fixture dates per run is not worth a shared-mutable-state exception.
    static func date(_ string: String?, in vectorID: String, field: String) -> Date? {
        guard let string else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        guard let parsed = formatter.date(from: string) else {
            fatalError("Vector '\(vectorID)': \(field) '\(string)' is not an ISO-8601 date")
        }
        return parsed
    }
}

extension Vector: CustomTestStringConvertible {
    /// Keeps the test navigator showing `exact-match-outranks-everything` rather than a struct dump.
    var testDescription: String { id }
}

// MARK: - Tests

/// Serialized because each vector pins `TestDataConfiguration.mockCurrentDate`, which is
/// process-global. Parallel vectors would race on it and fail intermittently.
@Suite("Pricing engine vectors", .serialized)
struct PricingEngineVectorTests {

    @Test("fixture is loadable and non-trivial")
    func fixtureLoads() throws {
        let file = try #require(Fixture.file, "\(Fixture.loadDiagnostic)")
        #expect(file.formatVersion == 1)
        #expect(Fixture.vectors.count >= 20)

        let ids = Fixture.vectors.map(\.id)
        #expect(Set(ids).count == ids.count, "vector ids must be unique")

        let categoryIDs = Set(file.categories.map(\.id))
        for vector in Fixture.vectors {
            #expect(
                categoryIDs.contains(vector.input.categoryID),
                "vector '\(vector.id)' targets unknown category '\(vector.input.categoryID)'"
            )
        }
    }

    // `fileprivate`, not internal: the fixture types are file-private, and a method may not
    // be more accessible than the types in its signature.
    @Test("vector", arguments: Fixture.vectors)
    fileprivate func runVector(_ vector: Vector) throws {
        let container = try ModelContainer(
            for: Schema(ChurSchemaCurrent.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)

        let fixtureFile = try #require(Fixture.file, "\(Fixture.loadDiagnostic)")

        let categories = fixtureFile.categories.map { fixture -> SpendingCategory in
            let category = SpendingCategory(
                id: fixture.id,
                nameEN: fixture.name,
                nameZH_Hans: fixture.name,
                nameZH_HK: fixture.name,
                nameZH_TW: fixture.name,
                emoji: "🧪",
                sortOrder: 0,
                parentCategoryID: fixture.parentCategoryID,
                level: fixture.level,
                categoryLinks: fixture.categoryLinks?.map { CategoryLink(id: $0) },
                excludeFromParent: fixture.excludeFromParent ?? false,
                cardFilter: fixture.cardFilter,
                excludedPaymentMethods: fixture.excludedPaymentMethods,
                channels: fixture.channels
            )
            context.insert(category)
            return category
        }

        let cards = vector.cards.map { make(card: $0, in: context, vectorID: vector.id) }

        guard let category = categories.first(where: { $0.id == vector.input.categoryID }) else {
            Issue.record("vector '\(vector.id)': unknown category '\(vector.input.categoryID)'")
            return
        }

        let previousMockDate = currentMockDate()
        defer { setMockDate(previousMockDate) }
        setMockDate(Fixture.date(vector.input.asOf, in: vector.id, field: "asOf"))

        let calculator = CardRateCalculator(
            cards: cards,
            category: category,
            // `CardRateCalculator.rate` is stored but never read by the engine.
            rate: 1.0,
            allCategories: categories,
            boostEnrollments: vector.input.boostEnrollments ?? [:],
            region: vector.input.region,
            channel: vector.input.channel,
            allowPaymentMethodFallback: vector.input.allowPaymentMethodFallback ?? true,
            forceCrossBorder: vector.input.forceCrossBorder ?? false,
            acceptedPaymentMethods: vector.input.acceptedPaymentMethods.map { Set($0) },
            acceptedRegions: vector.input.acceptedRegions.map { Set($0) }
        )

        let actual = calculator.rankedCardSummaries

        #expect(
            actual.map(\.name) == vector.expected.map(\.name),
            """
            vector '\(vector.id)' ranked the wrong cards
              rule:     \(vector.rule)
              expected: \(describe(vector.expected))
              actual:   \(describe(actual))
            """
        )

        guard actual.count == vector.expected.count else { return }

        for (row, expectedRow) in zip(actual, vector.expected) {
            #expect(
                abs(row.effectiveCashBackRate - expectedRow.effectiveCashBackRate) < 1e-9,
                """
                vector '\(vector.id)': \(expectedRow.name) earned the wrong rate
                  rule:     \(vector.rule)
                  expected: \(expectedRow.effectiveCashBackRate)
                  actual:   \(row.effectiveCashBackRate)
                """
            )
            if let expectedMultiplier = expectedRow.rate {
                #expect(
                    abs(row.rate - expectedMultiplier) < 1e-9,
                    """
                    vector '\(vector.id)': \(expectedRow.name) reported the wrong multiplier
                      expected: \(expectedMultiplier)
                      actual:   \(row.rate)
                    """
                )
            }
        }
    }

    // MARK: - Building models

    private func make(card fixture: CardFixture, in context: ModelContext, vectorID: String) -> CreditCard {
        let card = CreditCard(
            id: fixture.id ?? fixture.name.replacingOccurrences(of: " ", with: "-").lowercased(),
            templateID: fixture.templateID,
            name: fixture.name,
            issuer: fixture.issuer ?? "Test Issuer",
            network: fixture.network ?? "Visa",
            imageName: "test-card",
            cardType: fixture.cardType ?? "personal",
            country: fixture.country ?? "US",
            status: fixture.status ?? "active",
            hasForeignTransactionFee: fixture.hasForeignTransactionFee ?? false,
            foreignTransactionFeeRate: fixture.foreignTransactionFeeRate
        )
        context.insert(card)

        card.rewards = (fixture.rewards ?? []).map { make(reward: $0, in: context, vectorID: vectorID) }

        card.rewardPlans = (fixture.plans ?? []).map { planFixture in
            let plan = RewardPlan(
                id: planFixture.id,
                name: planFixture.name,
                isDefault: planFixture.isDefault ?? false
            )
            context.insert(plan)
            plan.rewards = planFixture.rewards.map { make(reward: $0, in: context, vectorID: vectorID) }
            // `plan.card` is deliberately left unset — `activePlan` reads only `rewardPlans`,
            // and assigning both sides of an inferred inverse during construction is a needless risk.
            return plan
        }

        return card
    }

    private func make(reward fixture: RewardFixture, in context: ModelContext, vectorID: String) -> RewardRate {
        let reward = RewardRate(
            rate: fixture.rate,
            rewardProgramName: fixture.rewardProgramName ?? "Cash Back",
            pointCashValue: fixture.pointCashValue ?? 0.01,
            pointCashValueCurrency: fixture.pointCashValueCurrency ?? "USD",
            categories: fixture.categories,
            countries: fixture.countries,
            channels: fixture.channels,
            rewardStartDate: Fixture.date(fixture.rewardStartDate, in: vectorID, field: "rewardStartDate"),
            rewardEndDate: Fixture.date(fixture.rewardEndDate, in: vectorID, field: "rewardEndDate")
        )
        context.insert(reward)
        return reward
    }

    // MARK: - Helpers

    private func describe(_ rows: [ExpectedRow]) -> String {
        rows.map { "\($0.name)@\($0.effectiveCashBackRate)" }.joined(separator: ", ")
    }

    private func describe(_ rows: [CardRateSummary]) -> String {
        rows.map { "\($0.name)@\($0.effectiveCashBackRate)" }.joined(separator: ", ")
    }

    /// `TestDataConfiguration.mockCurrentDate` only exists in DEBUG. Tests run Debug, but
    /// guarding here keeps the suite compilable in any configuration.
    private func setMockDate(_ date: Date?) {
        #if DEBUG
        TestDataConfiguration.mockCurrentDate = date
        #endif
    }

    private func currentMockDate() -> Date? {
        #if DEBUG
        return TestDataConfiguration.mockCurrentDate
        #else
        return nil
        #endif
    }
}
