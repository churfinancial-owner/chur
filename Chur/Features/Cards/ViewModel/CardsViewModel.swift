//
//  CardsViewModel.swift
//  Chur
//
//  Created by Pak Ho on 3/16/26.
//

import SwiftUI
import SwiftData

@Observable
class CardsViewModel {
    /// The card.id of the currently visible carousel card. String-typed so it maps
    /// directly to the .id(card.id) view identity used by scrollPosition.
    var currentPage: String? = nil

    var showingAddCard = false
    var cardToEdit: CreditCard? = nil
    var selectedTab: CardViewTab = .cardinforewards
    var showingCardOrder = false
    var showingApprovedDates = false
    var showingGoToCard = false
    /// Set to a card.id to trigger a programmatic centered scroll via the carousel's proxy.
    var pendingScrollToCardID: String? = nil
    var selectedFrequency: String? = nil
    
    func getSortedCards(cards: [CreditCard], user: User?) -> [CreditCard] {
        guard let user = user, !user.cardDisplayOrder.isEmpty else {
            return cards.sorted { $0.name < $1.name }
        }
        let chronological = cards.sorted { card1, card2 in
            let index1 = user.cardDisplayOrder.firstIndex(of: card1.id) ?? Int.max
            let index2 = user.cardDisplayOrder.firstIndex(of: card2.id) ?? Int.max
            return index1 < index2
        }
        return chronological.reversed()
    }
    
    func cardWidth(for screenWidth: CGFloat) -> CGFloat {
        let preferredWidth = screenWidth * 0.78
        return min(preferredWidth, 300)
    }
}
