import SwiftUI
import SwiftData

struct AutoRentalCoverageView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var cards: [CreditCard]
    @State private var showInfoDetail = false

    // MARK: - Data

    private var matchedCards: [(card: CreditCard, entry: AutoRentalEntry)] {
        let entries = Self.cachedEntries
        var results: [(CreditCard, AutoRentalEntry)] = []
        for card in cards {
            guard let templateID = card.templateID else { continue }
            if let entry = entries.first(where: { $0.cardId == templateID && $0.hasCoverage }) {
                results.append((card, entry))
            }
        }
        return results
    }

    private var primaryCards: [(card: CreditCard, entry: AutoRentalEntry)] {
        matchedCards.filter { $0.entry.coverageType == "primary" }
    }

    private var secondaryCards: [(card: CreditCard, entry: AutoRentalEntry)] {
        matchedCards.filter { $0.entry.coverageType == "secondary" }
    }

    /// Flat sorted list: primary recommended → primary other → secondary recommended → secondary other
    private var sortedCards: [(card: CreditCard, entry: AutoRentalEntry)] {
        matchedCards.sorted { a, b in
            let aPriority = sortPriority(a.entry)
            let bPriority = sortPriority(b.entry)
            if aPriority != bPriority { return aPriority < bPriority }
            return a.card.name < b.card.name
        }
    }

    private func sortPriority(_ entry: AutoRentalEntry) -> Int {
        switch (entry.coverageType, entry.recommended) {
        case ("primary", true): return 0
        case ("primary", false): return 1
        case (_, true): return 2
        default: return 3
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView {
                VStack(spacing: 0) {
                    // MARK: - Pattern Header
                    PatternHeaderBanner(imageName: "HeaderPattern5")

                    // MARK: - Hero Header
                    VStack(alignment: .leading, spacing: 6) {
                        Text("PROTECTIONS")
                            .font(.churSmallBold())
                            .foregroundStyle(Color.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.green)
                            .clipShape(Capsule())

                        Text("Auto Rental Coverage")
                            .font(.churTitle())
                            .foregroundStyle(Color.churDarkGray)

                        Text("Rental car collision and damage coverage through your cards. Plans and coverage terms change frequently. Information may not reflect the latest provider updates; always verify with your card issuer.")
                            .font(.churCaptionMedium())
                            .foregroundStyle(Color.churMediumGray)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 12)

                    // MARK: - Summary Bar
                    if !matchedCards.isEmpty {
                        HStack(spacing: 12) {
                            if !primaryCards.isEmpty {
                                summaryPill(
                                    label: "PRIMARY",
                                    count: primaryCards.count,
                                    color: .churOlive
                                )
                            }
                            if !secondaryCards.isEmpty {
                                summaryPill(
                                    label: "SECONDARY",
                                    count: secondaryCards.count,
                                    color: .orange
                                )
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 24)
                    }

                    // MARK: - Info Callout
                    if !matchedCards.isEmpty {
                        infoBanner
                            .padding(.horizontal, 24)
                            .padding(.top, 16)
                    }

                    // MARK: - Card List
                    if matchedCards.isEmpty {
                        emptyState
                            .padding(.horizontal, 24)
                            .padding(.top, 24)
                    } else {
                        VStack(spacing: 10) {
                            ForEach(sortedCards, id: \.card.id) { item in
                                coverageCard(card: item.card, entry: item.entry)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 24)
                    }

                    Spacer(minLength: 40)
                }
            }
            .background(Color.churOffWhite)

            SheetDismissButton { dismiss() }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Summary Pill

    private func summaryPill(label: String, count: Int, color: Color) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.churSmallBold())
                .foregroundStyle(color)
                .tracking(0.5)

            Text("\(count)")
                .font(.churSmallBold())
                .foregroundStyle(color)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(color.opacity(0.15))
                .clipShape(Capsule())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(color.opacity(0.06))
        .clipShape(Capsule())
    }

    // MARK: - Info Banner

    private var infoBanner: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                showInfoDetail.toggle()
            }
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "info.circle.fill")
                    .font(.churCaptionRegular())
                    .foregroundStyle(Color.blue.opacity(0.7))
                    .padding(.top, 1)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Primary vs Secondary")
                            .font(.churSmallBold())
                            .foregroundStyle(Color.churDarkGray)

                        Spacer()

                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.churMediumGray)
                            .rotationEffect(.degrees(showInfoDetail ? 180 : 0))
                    }

                    if showInfoDetail {
                        Text("Primary Auto Rental Collision Damage Waiver (CDW) provides first-tier reimbursement for covered theft or collision damage, eliminating the requirement to file a claim with your personal insurer. Secondary coverage acts as supplemental protection, covering eligible costs and deductibles not reimbursed by your primary automobile policy.")
                            .font(.churSmallBold())
                            .foregroundStyle(Color.churDarkGray)
                            .lineSpacing(2)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
            .padding(14)
            .background(Color.blue.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Coverage Card

    private func coverageCard(card: CreditCard, entry: AutoRentalEntry) -> some View {
        let isPrimary = entry.coverageType == "primary"
        let accentColor: Color = isPrimary ? .churOlive : .orange

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(card.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 36, height: 24)
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                Text(card.name)
                    .font(.churSectionHeader())
                    .foregroundStyle(Color.churDarkGray)

                Spacer()

                Text(isPrimary ? "PRIMARY" : "SECONDARY")
                    .font(.churBadgeBold())
                    .foregroundStyle(accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(accentColor.opacity(0.1))
                    .clipShape(Capsule())
            }

        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.03), radius: 5, x: 0, y: 2)
    }

    private var emptyState: some View {
        EmptyStatePlaceholder(icon: "car.side", title: "No rental coverage yet", subtitle: "Add a card with auto rental coverage to see your protection here.")
    }

    // MARK: - JSON Loading

    private static var cachedEntries: [AutoRentalEntry] = loadEntries()

    private static func loadEntries() -> [AutoRentalEntry] {
        guard let url = Bundle.main.url(forResource: "SeedDataAutoRentalCoverage", withExtension: "json") else {
            return []
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([AutoRentalEntry].self, from: data)
        } catch {
            return []
        }
    }
}

// MARK: - Data Model

private struct AutoRentalEntry: Codable {
    let cardId: String
    let hasCoverage: Bool
    let coverageType: String
    let recommended: Bool
    let description: String
}
