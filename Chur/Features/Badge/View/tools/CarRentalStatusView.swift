import SwiftUI
import SwiftData

struct CarRentalStatusView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var cards: [CreditCard]

    private var allEntries: [CarRentalEntry] {
        var results: [CarRentalEntry] = []
        for card in cards {
            for benefit in card.benefits where isCarRentalBenefit(benefit) {
                results.append(CarRentalEntry(card: card, benefit: benefit))
            }
        }
        return results
    }

    /// Group by program name so many cards sharing the same status show together
    private var programGroups: [CarRentalGroup] {
        let grouped = Dictionary(grouping: allEntries) { $0.benefit.displayName }
        return grouped.map { name, entries in
            CarRentalGroup(
                programName: name,
                cards: entries.map { CardRef(name: $0.card.name, imageName: $0.card.imageName) }
            )
        }
        .sorted { $0.programName < $1.programName }
    }

    private func isCarRentalBenefit(_ benefit: Benefit) -> Bool {
        benefit.displayGroup == "travel_carstatus"
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView {
                VStack(spacing: 0) {
                    // MARK: - Pattern Header
                    PatternHeaderBanner(imageName: "HeaderPattern5")

                    // MARK: - Hero Header
                    VStack(alignment: .leading, spacing: 6) {
                        Text("TRAVEL")
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.churPillColor1Orange)
                            .clipShape(Capsule())

                        Text("Car Rental Status")
                            .font(.churTitle())
                            .foregroundStyle(Color.churDarkGray)

                        Text("Elite rental car statuses you receive through your cards.")
                            .font(.churSmallBold())
                            .foregroundStyle(Color.churMediumGray)
                            .lineSpacing(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 12)

                    // MARK: - Programs
                    if programGroups.isEmpty {
                        emptyState
                            .padding(.horizontal, 24)
                            .padding(.top, 24)
                    } else {
                        VStack(spacing: 12) {
                            ForEach(programGroups, id: \.programName) { group in
                                programCard(group: group)
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

    // MARK: - Program Card

    private func programCard(group: CarRentalGroup) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Circle()
                    .fill(Color.churOlive)
                    .frame(width: 10, height: 10)

                Text(group.programName)
                    .font(.churSectionHeader())
                    .foregroundStyle(Color.churDarkGray)
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
        HStack(spacing: 8) {
            Image(card.imageName)
                .resizable()
                .scaledToFit()
                .frame(width: 36, height: 24)
                .clipShape(RoundedRectangle(cornerRadius: 4))

            Text(card.name)
                .font(.churSmallBold())
                .foregroundStyle(Color.churDarkGray)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.churOffWhite)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "car.fill")
                .font(.churBigTitle3())
                .foregroundStyle(Color.churMediumGray)
            Text("No car rental status yet")
                .font(.churSectionHeader())
                .foregroundStyle(Color.churDarkGray)
            Text("Add a card with rental car elite status to see your coverage here.")
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

private struct CarRentalEntry {
    let card: CreditCard
    let benefit: Benefit
}

private struct CarRentalGroup {
    let programName: String
    let cards: [CardRef]
}

private struct CardRef {
    let name: String
    let imageName: String
}
