//
//  OnboardingAddCardsStep.swift
//  Chur
//
//  Step 4: Add first cards from the database.
//

import SwiftUI
import SwiftData

struct OnboardingAddCardsStep: View {
    let selectedCountry: String
    
    // Bindings to persist data in the container
    @Binding var pendingTemplates: [CardTemplate]
    @Binding var pendingTemplateCounts: [String: Int]
    
    let onContinue: ([CardTemplate]) -> Void

    @State private var filterState: CardAddFilterState
    
    init(selectedCountry: String,
         pendingTemplates: Binding<[CardTemplate]>,
         pendingTemplateCounts: Binding<[String: Int]>,
         onContinue: @escaping ([CardTemplate]) -> Void) {
        
        self.selectedCountry = selectedCountry
        self._pendingTemplates = pendingTemplates
        self._pendingTemplateCounts = pendingTemplateCounts
        self.onContinue = onContinue
        _filterState = State(initialValue: CardAddFilterState(userCountry: selectedCountry))
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                // Professional Title
                Text("Add Your Cards")
                    .font(.churTitle())
                    .foregroundStyle(Color.churDarkGray)
                
                Text("Select the cards currently in your wallet.")
                    .font(.churRowTextRegular())
                    .foregroundStyle(Color.churMediumGray)
            }
            .padding(.top, 8)
            .padding(.bottom, 12)

            CardPickerCoreView(
                filterState: $filterState,
                pendingTemplates: $pendingTemplates,
                pendingTemplateCounts: $pendingTemplateCounts,
                existingTemplateIds: [],
                onDuplicateDetected: { _ in }
            )

            VStack(spacing: 12) {
                Button {
                    onContinue(pendingTemplates)
                } label: {
                    HStack(spacing: 8) {
                        // Changed text to "Finish" for the final step
                        Text(pendingTemplates.isEmpty ? "Finish" : "Finish & Setup Wallet")
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
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24) // Added a bit more breathing room at the bottom
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

    private func loadInitialData() async {
        filterState.selectedCountry = selectedCountry
        filterState.allTemplates = CardDatabase.getAllCards()
        filterState.updateFilterOptionsCache()
        filterState.updateFilters()
    }
}
