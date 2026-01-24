import SwiftUI
import SwiftData

struct TrustedTravelerView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var cards: [CreditCard]

    /// Collect every (card, benefit) pair that qualifies
    private var allEntries: [TTPEntry] {
        var results: [TTPEntry] = []
        for card in cards {
            for benefit in card.benefits where isTTPBenefit(benefit) {
                results.append(TTPEntry(card: card, benefit: benefit))
            }
        }
        return results
    }

    /// Group by benefit template ID, so cards sharing the same program show together
    private var programGroups: [TTPGroup] {
        let grouped = Dictionary(grouping: allEntries) { entry -> String in
            // Benefit.id format is "{cardInstanceID}_{templateID}" — extract the template portion
            let prefix = "\(entry.card.id)_"
            return entry.benefit.id.hasPrefix(prefix)
                ? String(entry.benefit.id.dropFirst(prefix.count))
                : entry.benefit.id
        }
        return grouped.map { templateID, entries in
            let representative = entries.first!.benefit
            return TTPGroup(
                benefitID: templateID,
                programName: representative.displayName,
                value: representative.value,
                valueCurrency: representative.valueCurrency,
                frequency: representative.frequency,
                cards: entries.map { CardRef(name: $0.card.name, imageName: $0.card.imageName) }
            )
        }
        .sorted { $0.programName > $1.programName }
    }

    private func isTTPBenefit(_ benefit: Benefit) -> Bool {
        benefit.displayGroup == "travel_tsa"
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView {
                VStack(spacing: 0) {
                    // MARK: - Pattern Header
                    PatternHeaderBanner(imageName: "HeaderPattern5")

                    VStack(alignment: .leading, spacing: 24) {
                        // MARK: - Hero Header
                        VStack(alignment: .leading, spacing: 6) {
                            Text("TRAVEL")
                                .font(.system(size: 10, weight: .black, design: .rounded))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.churPillColor1Orange)
                                .clipShape(Capsule())

                            Text("Trusted Traveler")
                                .font(.churTitle())
                                .foregroundStyle(Color.churDarkGray)

                            Text("Security programs covered by your cards — TSA PreCheck, Global Entry, CLEAR, and NEXUS.")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(Color.churMediumGray)
                                .lineSpacing(2)
                        }
                        .padding(.top, 12)

                        // MARK: - Programs
                        if programGroups.isEmpty {
                            emptyState
                        } else {
                            VStack(spacing: 12) {
                                ForEach(programGroups, id: \.benefitID) { group in
                                    programCard(group: group)
                                }
                            }
                        }
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 24)
                }
            }
            .background(Color.churOffWhite)
            .ignoresSafeArea(edges: .top)

            SheetDismissButton { dismiss() }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Program Card

    private func programCard(group: TTPGroup) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            // Program name & value
            HStack(alignment: .top) {
                Text(group.programName)
                    .font(.churSectionHeader())
                    .foregroundStyle(Color.churDarkGray)
                Spacer()
                if group.value > 0 {
                    Text("\(group.valueCurrency) \(group.value)")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(Color.churOlive)
                }
            }

            // Frequency & limit badges
            HStack(spacing: 6) {
                frequencyBadge(group.frequency)
            }

            Divider()

            // Qualifying cards
            VStack(alignment: .leading, spacing: 8) {
                Text("COVERED BY \(group.cards.count) CARD\(group.cards.count == 1 ? "" : "S")")
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .foregroundStyle(Color.churMediumGray)
                    .tracking(0.5)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(group.cards, id: \.name) { card in
                            cardChip(card: card)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.03), radius: 5, x: 0, y: 2)
    }

    // MARK: - Card Chip

    private func cardChip(card: CardRef) -> some View {
        HStack(spacing: 6) {
            Image(card.imageName)
                .resizable()
                .scaledToFit()
                .frame(width: 28, height: 18)
                .clipShape(RoundedRectangle(cornerRadius: 3))

            Text(card.name)
                .font(.churBadgeBold())
                .foregroundStyle(Color.churDarkGray)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.churOffWhite)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Frequency Badge

    private func frequencyBadge(_ frequency: String) -> some View {
        let color: Color = switch frequency.lowercased() {
        case "annual": .blue
        case "quadrennial": .cyan
        default: .churOlive
        }
        return Text(frequency.uppercased())
            .font(.system(size: 9, weight: .black, design: .rounded))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.1))
            .clipShape(Capsule())
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "shield.checkered")
                .font(.churBigTitle3())
                .foregroundStyle(Color.churMediumGray)
            Text("No trusted traveler programs yet")
                .font(.churSectionHeader())
                .foregroundStyle(Color.churDarkGray)
            Text("Add a card that covers TSA PreCheck, Global Entry, CLEAR, or NEXUS to see your coverage here.")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Color.churMediumGray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.03), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Data Models

private struct TTPEntry {
    let card: CreditCard
    let benefit: Benefit
}

private struct TTPGroup {
    let benefitID: String
    let programName: String
    let value: Int
    let valueCurrency: String
    let frequency: String
    let cards: [CardRef]
}

private struct CardRef {
    let name: String
    let imageName: String
}
