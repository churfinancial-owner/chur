import SwiftUI
import SwiftData

struct LoungeAccessView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var cards: [CreditCard]

    private var loungeGroups: [LoungeGroup] {
        var entries: [(card: CreditCard, benefit: Benefit)] = []
        for card in cards {
            for benefit in card.benefits where benefit.benefitType == "lounge_access" {
                entries.append((card: card, benefit: benefit))
            }
        }
        let grouped = Dictionary(grouping: entries) { $0.benefit.displayName }
        return grouped.map { name, items in
            let representative = items.first!.benefit
            return LoungeGroup(
                programName: name,
                benefit: representative,
                cards: items.map { LoungeCardRef(name: $0.card.name, imageName: $0.card.imageName) }
            )
        }
        .sorted { $0.programName < $1.programName }
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

                            Text("Lounge Access")
                                .font(.churTitle())
                                .foregroundStyle(Color.churDarkGray)

                            Text("Airport lounges you can access with your cards.")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(Color.churMediumGray)
                                .lineSpacing(2)
                        }
                        .padding(.top, 12)

                        // MARK: - Lounge List
                        if loungeGroups.isEmpty {
                            emptyState
                        } else {
                            VStack(spacing: 12) {
                                ForEach(loungeGroups, id: \.programName) { group in
                                    loungeCard(group: group)
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

    // MARK: - Lounge Card

    private func loungeCard(group: LoungeGroup) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Text(group.programName)
                    .font(.churSectionHeader())
                    .foregroundStyle(Color.churDarkGray)
                Spacer()
            }

            // Access badge
            accessBadge(for: group.benefit)

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

    private func cardChip(card: LoungeCardRef) -> some View {
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

    // MARK: - Access Badge

    @ViewBuilder
    private func accessBadge(for benefit: Benefit) -> some View {
        let isUnlimited = benefit.usageLimit == -1
        let label = isUnlimited ? "UNLIMITED" : "LIMITED"
        let color: Color = isUnlimited ? .churOlive : .orange
        let needsUnlock = isUnlimited && benefit.activationMode != "unlock"

        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 9, weight: .black, design: .rounded))
                .foregroundStyle(color)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(color.opacity(0.1))
                .clipShape(Capsule())

            if needsUnlock {
                HStack(spacing: 3) {
                    Image(systemName: "lock.fill")
                        .font(.churBadge())
                    Text("UNLOCK REQUIRED")
                        .font(.system(size: 9, weight: .black, design: .rounded))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.churDarkGray)
                .clipShape(Capsule())
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "airplane.departure")
                .font(.churBigTitle3())
                .foregroundStyle(Color.churMediumGray)
            Text("No lounge access yet")
                .font(.churSectionHeader())
                .foregroundStyle(Color.churDarkGray)
            Text("Add a card with lounge benefits to see your access here.")
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

private struct LoungeGroup {
    let programName: String
    let benefit: Benefit
    let cards: [LoungeCardRef]
}

private struct LoungeCardRef {
    let name: String
    let imageName: String
}
