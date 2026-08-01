import SwiftUI
import SwiftData

struct CellPhoneProtectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var cards: [CreditCard]

    // MARK: - Data

    private var matchedCards: [(card: CreditCard, entry: CellPhoneProtectionEntry)] {
        let entries = Self.cachedEntries
        var results: [(CreditCard, CellPhoneProtectionEntry)] = []
        for card in cards {
            guard let templateID = card.templateID else { continue }
            if let entry = entries.first(where: { $0.cardId == templateID && $0.hasProtection }) {
                results.append((card, entry))
            }
        }
        return results
    }

    private var recommendedCards: [(card: CreditCard, entry: CellPhoneProtectionEntry)] {
        matchedCards.filter { $0.entry.recommended }
    }

    private var otherCards: [(card: CreditCard, entry: CellPhoneProtectionEntry)] {
        matchedCards.filter { !$0.entry.recommended }
    }

    // MARK: - Body
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView {
                VStack(spacing: 0) {
                    // MARK: - Hero Banner
                    ToolSheetHeaderBanner(onClose: { dismiss() }) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("PROTECTIONS")
                                .font(.churBadgeBold())
                                .foregroundStyle(Color.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.green)
                                .clipShape(Capsule())

                            Text("Cell Phone Protection")
                                .font(.churTitle())
                                .foregroundStyle(Color.churDarkGray)

                            Text("Cards that cover phone damage, theft, and screen repair. Plans and coverage terms change frequently. Information may not reflect the latest provider updates; always verify with your card issuer.")
                                .font(.churSmallMedium())
                                .foregroundStyle(Color.churDarkGray.opacity(0.7))
                                .lineSpacing(2)
                        }
                    }

                    // MARK: - Card List
                    if matchedCards.isEmpty {
                        emptyState
                            .padding(.horizontal, 24)
                            .padding(.top, 24)
                    } else {
                        VStack(alignment: .leading, spacing: 24) {
                            if !recommendedCards.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("TOP PICKS FOR YOU")
                                        .font(.churBadgeBold())
                                        .foregroundStyle(Color.churMediumGray)
                                        .tracking(1)

                                    VStack(spacing: 10) {
                                        ForEach(recommendedCards, id: \.card.id) { item in
                                            protectionCard(card: item.card, entry: item.entry)
                                        }
                                    }
                                }
                            }

                            if !otherCards.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("ALSO COVERED")
                                        .font(.churBadgeBold())
                                        .foregroundStyle(Color.churMediumGray)
                                        .tracking(1)

                                    VStack(spacing: 10) {
                                        ForEach(otherCards, id: \.card.id) { item in
                                            protectionCard(card: item.card, entry: item.entry)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 24)
                    }

                    Spacer(minLength: 40)
                }
            }
            .background(Color.churOffWhite)
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Protection Card

    private func protectionCard(card: CreditCard, entry: CellPhoneProtectionEntry) -> some View {
        VStack(alignment: .leading, spacing: 12) {
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

                if entry.recommended {
                    Text("TOP PICK")
                        .font(.churNanoBold())
                        .foregroundStyle(Color.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.03), radius: 5, x: 0, y: 2)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "iphone.slash")
                .font(.churBigTitle3())
                .foregroundStyle(Color.churMediumGray)
            Text("No phone protection yet")
                .font(.churSectionHeader())
                .foregroundStyle(Color.churDarkGray)
            Text("Add a card with cell phone protection to see your coverage here.")
                .font(.churSmallMedium())
                .foregroundStyle(Color.churMediumGray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.03), radius: 5, x: 0, y: 2)
    }

    // MARK: - JSON Loading

    private static var cachedEntries: [CellPhoneProtectionEntry] = loadEntries()

    private static func loadEntries() -> [CellPhoneProtectionEntry] {
        guard let url = Bundle.main.url(forResource: "SeedDataCellPhoneProtection", withExtension: "json") else {
            return []
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([CellPhoneProtectionEntry].self, from: data)
        } catch {
            return []
        }
    }
}

// MARK: - Data Model

private struct CellPhoneProtectionEntry: Codable {
    let cardId: String
    let hasProtection: Bool
    let recommended: Bool
    let description: String
}
