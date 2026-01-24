//
//  CardCarouselView.swift
//  Chur
//
//  Created by Pak Ho on 3/16/26.
//

import SwiftUI

struct CardCarouselView: View {
    let width: CGFloat
    let sortedCards: [CreditCard]
    @Bindable var viewModel: CardsViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // Features/Cards/View/Wallet/CardCarouselView.swift

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 8) { // LazyHStack is more stable for scroll math
                        ForEach(sortedCards) { card in
                            CardCarouselItem(card: card, onEdit: { viewModel.cardToEdit = card })
                                .frame(width: viewModel.cardWidth(for: width))
                                .id(card.id)
                                .onTapGesture { handleTap(cardID: card.id, proxy: proxy) }
                        }
                    }
                    .scrollTargetLayout()
                }
                // FIX: Remove the .padding from the HStack and add this to the ScrollView instead
                .safeAreaPadding(.horizontal, (width - viewModel.cardWidth(for: width)) / 2)
                .scrollTargetBehavior(.viewAligned)
                .scrollPosition(id: $viewModel.currentPage, anchor: .center)
                .frame(height: 180)
                .onChange(of: viewModel.pendingScrollToCardID) { _, cardID in
                    guard let cardID else { return }
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        proxy.scrollTo(cardID, anchor: .center)
                        viewModel.currentPage = cardID
                    }
                    viewModel.pendingScrollToCardID = nil
                }
            }
            
            let currentIndex = sortedCards.firstIndex(where: { $0.id == viewModel.currentPage }) ?? 0
            CustomPageIndicator(
                currentPage: currentIndex,
                totalCards: sortedCards.count
            )
            .frame(maxWidth: width - 40)
            .scaleEffect(sortedCards.count > 8 ? 0.8 : 1.0)
            .padding(.top, 12)
            .padding(.bottom, 8)
        }
    }
    
    private func handleTap(cardID: String, proxy: ScrollViewProxy) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            viewModel.currentPage = cardID
            proxy.scrollTo(cardID, anchor: .center)
        }
    }
}
