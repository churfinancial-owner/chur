
//
//  OnboardingAddCardsStep.swift
//  Chur
//
//  Step 4: Add first cards from the database.
//  Reuses CardAddFilterState and CardDatabaseRow components.
//

import SwiftUI
import SwiftData

struct OnboardingAddCardsStep: View {
    let selectedCountry: String
    let onContinue: ([CardTemplate]) -> Void
    let onSkip: () -> Void

    @State private var filterState: CardAddFilterState
    @State private var pendingTemplates: [CardTemplate] = []
    @State private var pendingTemplateCounts: [String: Int] = [:]
    
    init(selectedCountry: String, onContinue: @escaping ([CardTemplate]) -> Void, onSkip: @escaping () -> Void) {
        self.selectedCountry = selectedCountry
        self.onContinue = onContinue
        self.onSkip = onSkip
        _filterState = State(initialValue: CardAddFilterState(userCountry: selectedCountry))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Text("Add Cards")
                    .font(.churTitle())
                    .foregroundStyle(Color.churDarkGray)
            }
            .padding(.top, 8)
            .padding(.bottom, 12)

            // Replaces: CardAddFilterSection, Divider, and the ScrollView/LazyVStack logic
            CardPickerCoreView(
                filterState: $filterState,
                pendingTemplates: $pendingTemplates,
                pendingTemplateCounts: $pendingTemplateCounts,
                existingTemplateIds: [], // Empty during onboarding
                onDuplicateDetected: { _ in } // No alert needed for onboarding
            )

            // Bottom buttons
            VStack(spacing: 12) {
                Button {
                    onContinue(pendingTemplates)
                } label: {
                    HStack(spacing: 8) {
                        Text("Continue")
                            .font(.churHeadline())

                        if !pendingTemplates.isEmpty {
                            Text("\(pendingTemplates.count)")
                                .font(.churSmallBold())
                                .foregroundStyle(Color.churOlive)
                                .frame(width: 22, height: 22)
                                .background(Color.white)
                                .clipShape(Circle())
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.churOlive)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                Button {
                    onSkip()
                } label: {
                    Text("I'll add cards later")
                        .font(.churRowTextMedium())
                        .foregroundStyle(Color.churMediumGray)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
            .padding(.top, 8)
            .background(
                Color.churOffWhite
                    .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: -2)
            )
        }
        .background(Color.churOffWhite)
        .task {
            await loadInitialData()
        }
    }

    // MARK: - Data Loading

    private func loadInitialData() async {
        // Prepare filterState with database cards
        filterState.selectedCountry = selectedCountry
        filterState.allTemplates = CardDatabase.getAllCards()
        filterState.updateFilterOptionsCache()
        filterState.updateFilters()
    }
}
