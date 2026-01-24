import SwiftUI
import SwiftData

struct HotelStatusView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var cards: [CreditCard]

    /// Build grouped structure: hotel chain → status tiers → qualifying cards
    private var groupedEntries: [(program: String, statuses: [HotelStatusGroup])] {
        var entries: [(card: CreditCard, benefit: Benefit)] = []
        for card in cards {
            for benefit in card.benefits where benefit.displayGroup == "travel_hotelstatus" {
                entries.append((card: card, benefit: benefit))
            }
        }

        // Group by hotel chain, then by status name within each chain
        let byChain = Dictionary(grouping: entries) { extractProgram($0.benefit.displayName) }
        return byChain.sorted { $0.key < $1.key }.map { chain, chainEntries in
            let byStatus = Dictionary(grouping: chainEntries) { $0.benefit.displayName }
            let statuses = byStatus.map { name, items in
                HotelStatusGroup(
                    statusName: name,
                    cards: items.map { HotelCardRef(name: $0.card.name, imageName: $0.card.imageName) }
                )
            }
            .sorted { statusTierRank($0.statusName) < statusTierRank($1.statusName) }
            return (program: chain, statuses: statuses)
        }
    }

    private func extractProgram(_ name: String) -> String {
        let lowered = name.lowercased()
        if lowered.contains("hilton") { return "Hilton" }
        if lowered.contains("marriott") || lowered.contains("bonvoy") { return "Marriott" }
        if lowered.contains("hyatt") { return "Hyatt" }
        if lowered.contains("wyndham") { return "Wyndham" }
        if lowered.contains("ihg") { return "IHG" }
        if lowered.contains("best western") { return "Best Western" }
        if lowered.contains("choice") { return "Choice" }
        return "Other"
    }

    private func statusTierRank(_ name: String) -> Int {
        let lowered = name.lowercased()
        if lowered.contains("diamond") { return 0 }
        if lowered.contains("platinum") { return 1 }
        if lowered.contains("gold") { return 2 }
        if lowered.contains("silver") { return 3 }
        return 4
    }

    private func statusTierColor(_ name: String) -> Color {
        let lowered = name.lowercased()
        if lowered.contains("diamond") { return Color(red: 0.35, green: 0.55, blue: 0.85) }
        if lowered.contains("platinum") || lowered.contains("silver") { return Color(red: 0.75, green: 0.75, blue: 0.78) }
        if lowered.contains("gold") { return Color(red: 1.0, green: 0.84, blue: 0.0) }
        return .churOlive
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

                            Text("Hotel Status")
                                .font(.churTitle())
                                .foregroundStyle(Color.churDarkGray)

                            Text("Elite hotel statuses you receive through your cards.")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(Color.churMediumGray)
                                .lineSpacing(2)
                        }
                        .padding(.top, 12)

                        // MARK: - Status List
                        if groupedEntries.isEmpty {
                            emptyState
                        } else {
                            VStack(spacing: 20) {
                                ForEach(groupedEntries, id: \.program) { group in
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text(group.program.uppercased())
                                            .font(.system(size: 10, weight: .black, design: .rounded))
                                            .foregroundStyle(Color.churMediumGray)
                                            .tracking(1)

                                        VStack(spacing: 10) {
                                            ForEach(group.statuses, id: \.statusName) { status in
                                                statusCard(status: status)
                                            }
                                        }
                                    }
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

    // MARK: - Status Card

    private func statusCard(status: HotelStatusGroup) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Circle()
                    .fill(statusTierColor(status.statusName))
                    .frame(width: 10, height: 10)

                Text(status.statusName)
                    .font(.churSectionHeader())
                    .foregroundStyle(Color.churDarkGray)
            }

            Divider()

            // Qualifying cards
            VStack(alignment: .leading, spacing: 8) {
                Text("COVERED BY \(status.cards.count) CARD\(status.cards.count == 1 ? "" : "S")")
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .foregroundStyle(Color.churMediumGray)
                    .tracking(0.5)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(status.cards, id: \.name) { card in
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

    private func cardChip(card: HotelCardRef) -> some View {
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
            Image(systemName: "bed.double")
                .font(.churBigTitle3())
                .foregroundStyle(Color.churMediumGray)
            Text("No hotel status yet")
                .font(.churSectionHeader())
                .foregroundStyle(Color.churDarkGray)
            Text("Add a card with hotel elite status benefits to see them here.")
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

private struct HotelStatusGroup {
    let statusName: String
    let cards: [HotelCardRef]
}

private struct HotelCardRef {
    let name: String
    let imageName: String
}
