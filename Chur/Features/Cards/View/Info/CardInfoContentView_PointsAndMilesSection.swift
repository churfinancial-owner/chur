import SwiftUI

/// Where this card's points go, and what a mile costs (P1f part 5).
///
/// Shown only when the card's current reward program has transfer partners, or
/// when an upgrade rule could give it some. A Freedom held alone gets the second
/// case: the one line its holder actually needs, that a Sapphire unlocks it.
struct PointsAndMilesSection: View {
    let card: CreditCard
    var onTransferTap: () -> Void = {}

    private var routes: [CardTransferRoute] { card.transferRoutes }
    private var potential: [String] { card.potentialTransferProgramNames }

    var body: some View {
        if !routes.isEmpty || !potential.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                CardSectionHeader(title: AppLocale.string("POINTS AND MILES"))
                VStack(spacing: 0) {
                    ForEach(Array(routes.enumerated()), id: \.element.id) { index, route in
                        if index > 0 { CardRowDivider() }
                        routeRow(route)
                    }
                    if routes.isEmpty, let name = potential.first {
                        unlockRow(programName: name)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private func routeRow(_ route: CardTransferRoute) -> some View {
        Button(action: onTransferTap) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(route.program.programName)
                        .font(.churRowText())
                        .foregroundStyle(Color.churDarkGray)
                    Spacer()
                    if let best = route.best {
                        Text(ConditionText.money(best.costPerMile, currency: route.currency) + " / " + AppLocale.string("mile"))
                            .font(.churFootnoteBold())
                            .foregroundStyle(Color.churOlive)
                    }
                    Image(systemName: "chevron.right")
                        .font(.churSmallBold())
                        .foregroundStyle(Color.churMediumGray)
                        .padding(.leading, 4)
                }
                Text(subtitle(for: route))
                    .font(.churMicro())
                    .foregroundStyle(Color.churMediumGray)
            }
            .padding(.vertical, 16)
        }
        .buttonStyle(.plain)
    }

    /// "16 partners · best Cathay Pacific at 1:1 · HK$200 per redemption"
    private func subtitle(for route: CardTransferRoute) -> String {
        var parts = ["\(route.partnerCount) " + AppLocale.string("partners")]
        if let best = route.best {
            parts.append(AppLocale.string("best") + " " + best.partner.name + " " + best.partner.ratio)
        }
        if let fee = ConditionText.transferFee(route.fee) {
            parts.append(fee)
        }
        return parts.joined(separator: " · ")
    }

    /// The Freedom case: points that could transfer, but not on their own.
    private func unlockRow(programName: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Points do not transfer on their own")
                .font(.churRowText())
                .foregroundStyle(Color.churDarkGray)
            Text(AppLocale.string("Add a card on") + " " + programName + " " + AppLocale.string("to move these points to airlines"))
                .font(.churMicro())
                .foregroundStyle(Color.churMediumGray)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 16)
    }
}
