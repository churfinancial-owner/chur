//
//  RecommendationStackOverlay.swift
//  Chur
//

import SwiftUI

struct RecommendationStackOverlay: View {
    @Binding var isPresented: Bool
    let userCards: [CreditCard]
    let allCategories: [SpendingCategory]
    let user: User?
    
    @State private var currentIndex: Int = 0
    @State private var dragOffset: CGSize = .zero
    private let swipeThreshold: CGFloat = 120

    // MARK: - Logic
    /// This computed property is still used to drive the UI
    private var scoredRecommendations: [ScoredRecommendation] {
        let templates = RecommendationDatabase.getRecommendations(for: user?.country ?? "US")
        return CardRecommendationEngine.recommend(
            allTemplates: templates,
            userCards: userCards,
            userStrategies: user?.strategyPreferences ?? [],
            userCountry: user?.country ?? "US",
            limit: 8
        )
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { withAnimation { isPresented = false } }

            VStack(spacing: 20) {
                // Header
                HStack {
                    if !scoredRecommendations.isEmpty {
                        let count = scoredRecommendations.count
                        Text("Top Picks for you (\(currentIndex % count + 1)/\(count))")
                            .font(.churSectionHeader())
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    Button { withAnimation { isPresented = false } } label: {
                        Image(systemName: "xmark.circle.fill").font(.churBigTitle3()).foregroundStyle(.white)
                    }
                }
                .padding(.horizontal, 30)

                // The Infinite Stack
                ZStack {
                    let count = scoredRecommendations.count
                    if count > 0 {
                        let safeIndex = currentIndex % count
                        let rotated = scoredRecommendations[safeIndex...] + scoredRecommendations[..<safeIndex]
                        
                        // Show up to 4 cards to make the stack look richer
                        let visibleItems = Array(rotated.prefix(4))
                        
                        ForEach(Array(visibleItems.enumerated()), id: \.element.id) { index, rec in
                            let isTopCard = index == 0
                            
                            RecommendedCardView(recommendation: rec, allCategories: allCategories)
                                .frame(height: 500)
                                .scaleEffect(isTopCard ? 1.0 : 1.0 - (CGFloat(index) * 0.05))
                                .offset(
                                    x: isTopCard ? dragOffset.width : 0,
                                    y: isTopCard ? dragOffset.height : CGFloat(index * -12)
                                )
                                .rotationEffect(.degrees(isTopCard ? Double(dragOffset.width) / 15 : Double(index * 2)))
                                .zIndex(Double(count - index))
                                .opacity(isTopCard ? 1.0 : 1.0 - (Double(index) * 0.2))
                                .gesture(isTopCard ? dragGesture : nil)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
            }
        }
        .transition(.asymmetric(insertion: .scale(scale: 0.9).combined(with: .opacity), removal: .opacity))
        .zIndex(100)
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { dragOffset = $0.translation }
            .onEnded { value in
                if abs(value.translation.width) > swipeThreshold {
                    let direction: CGFloat = value.translation.width > 0 ? 1 : -1
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                        dragOffset = CGSize(width: direction * 800, height: 0)
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        dragOffset = .zero
                        currentIndex += 1
                    }
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { dragOffset = .zero }
                }
            }
    }
}
