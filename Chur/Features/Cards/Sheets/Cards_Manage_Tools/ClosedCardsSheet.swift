//
//  ClosedCardsSheet.swift
//  Chur
//
//  Lists cancelled wallet cards (hidden from the main wallet + pricing calculations)
//  and lets the user reactivate one.
//

import SwiftUI
import SwiftData

struct ClosedCardsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<CreditCard> { $0.status == "cancelled" },
           sort: \CreditCard.cancelledDate, order: .reverse)
    private var closedCards: [CreditCard]

    var body: some View {
        NavigationStack {
            Group {
                if closedCards.isEmpty {
                    EmptyStatePlaceholder(
                        icon: "archivebox",
                        title: "No Closed Cards",
                        subtitle: "Cards you cancel show up here, with their history kept."
                    )
                } else {
                    List(closedCards) { card in
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(card.name)
                                    .font(.churCaption())
                                    .foregroundStyle(Color.churDarkGray)
                                Text(card.issuer)
                                    .font(.churSmall())
                                    .foregroundStyle(Color.churMediumGray)
                                if let cancelledDate = card.cancelledDate {
                                    Text("Cancelled \(cancelledDate.formatted(.dateTime.month().day().year()))")
                                        .font(.churSmall())
                                        .foregroundStyle(Color.churMediumGray)
                                }
                            }
                            Spacer()
                            Button("Reactivate") {
                                CardProductChangeService.reactivate(card: card)
                            }
                            .font(.churSmallBold())
                            .foregroundStyle(Color.churOlive)
                        }
                        .padding(.vertical, 4)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Closed Cards")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color.churOffWhite)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
