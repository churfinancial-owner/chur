//
//  Cards_Add_Card_View.swift
//  Chur
//
//  • Card list display via CardPickerCoreView
//  • SwiftData persistence logic
//  • Duplicate wallet checks
//

import SwiftUI
import SwiftData

struct CardsView_AddCardView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var cards: [CreditCard]
    @Query private var users: [User]
    
    @State private var filterState: CardAddFilterState
    @State private var pendingTemplates: [CardTemplate] = []
    @State private var pendingTemplateCounts: [String: Int] = [:]
    @State private var pendingDuplicateTemplate: CardTemplate? = nil
    @State private var existingTemplateIds: Set<String> = []
    
    init() {
        _filterState = State(initialValue: CardAddFilterState())
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                Text("Add Cards")
                    .font(.churTitle())
                    .foregroundStyle(Color.churDarkGray)
                    .padding(.top, 8)
                    .padding(.bottom, 12)

                // Shared core handles search bar, filters, and the card list
                CardPickerCoreView(
                    filterState: $filterState,
                    pendingTemplates: $pendingTemplates,
                    pendingTemplateCounts: $pendingTemplateCounts,
                    existingTemplateIds: existingTemplateIds,
                    onDuplicateDetected: { template in
                        pendingDuplicateTemplate = template
                    }
                )
            }
            .background(Color.churOffWhite)
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await loadInitialData()
            }
            .toolbar {
                toolbarContent
            }
            .onDisappear {
                cleanup()
            }
            .alert("Already in Your Wallet", isPresented: duplicateAlertBinding, presenting: pendingDuplicateTemplate) { template in
                Button("Add Another") {
                    // Manual trigger for the core logic
                    stageCardManually(template)
                    pendingDuplicateTemplate = nil
                }
                Button("Cancel", role: .cancel) {
                    pendingDuplicateTemplate = nil
                }
            } message: { template in
                Text("Looks like \(template.name) is already in your wallet. Do you want to add another one?")
            }
        }
    }

    // MARK: - Toolbar
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") {
                dismiss()
            }
            .foregroundStyle(.red)
            .fontWeight(.bold)
            .font(.churRowText())
        }
        
        ToolbarItem(placement: .primaryAction) {
            confirmButton
        }
    }
    
    private var confirmButton: some View {
        Button {
            confirmAndSave()
        } label: {
            HStack(spacing: 8) {
                Text("Done")
                
                if !pendingTemplates.isEmpty {
                    Text("\(pendingTemplates.count)")
                        .font(.churSmallBold())
                        .foregroundStyle(.white)
                        .frame(width: 20, height: 20)
                        .background(Color.churOlive)
                        .clipShape(Circle())
                }
            }
        }
        .font(.churRowText())
        .fontWeight(.bold)
        .foregroundStyle(Color.churOlive)
        .foregroundStyle(Color.churOlive)
        .disabled(pendingTemplates.isEmpty)
    }
    
    // MARK: - Logic
    
    private func loadInitialData() async {
        if filterState.allTemplates.isEmpty {
            if let user = users.first {
                filterState.selectedCountry = user.country
            }
            filterState.allTemplates = CardDatabase.getAllCards()
            filterState.updateFilterOptionsCache()
        }
        
        // Update local cache of IDs for duplicate checking
        existingTemplateIds = Set(cards.compactMap { $0.templateID })
        filterState.updateFilters()
    }

    private func stageCardManually(_ template: CardTemplate) {
        // This mirrors the logic in Core for when the user bypasses the duplicate alert
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            pendingTemplates.append(template)
            pendingTemplateCounts[template.id, default: 0] += 1
        }
    }
    
    private func confirmAndSave() {
        let newlyAdded = commitAllPending()
        
        // Detect and apply program upgrades (e.g. CSR -> Sapphire)
        let currentWallet = cards + newlyAdded
        let proposals = ProgramUpgradeDatabase.detectPendingChanges(cards: currentWallet)
        ProgramUpgradeDatabase.applyAll(proposals)
        
        try? modelContext.save()
        dismiss()
    }
    
    @discardableResult
    private func commitAllPending() -> [CreditCard] {
        guard !pendingTemplates.isEmpty, let user = users.first else { return [] }
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        var newlyCreatedCards: [CreditCard] = []
        var existingCategorySet = Set(user.selectedCategories)
        var newCategories: [String] = []

        for template in pendingTemplates {
            let newCard = template.toCreditCard(modelContext: modelContext)
            newlyCreatedCards.append(newCard)

            if !user.cardDisplayOrder.contains(newCard.id) {
                user.cardDisplayOrder.append(newCard.id)
            }

            let cardCategories = newCard.activeRewards.compactMap { $0.categories }.joined()
            for categoryID in cardCategories where categoryID != "merchants" {
                if !existingCategorySet.contains(categoryID) {
                    existingCategorySet.insert(categoryID)
                    newCategories.append(categoryID)
                }
            }
        }

        if !newCategories.isEmpty {
            user.selectedCategories.append(contentsOf: newCategories)
        }
        
        return newlyCreatedCards
    }

    private func cleanup() {
        existingTemplateIds.removeAll()
    }
    
    private var duplicateAlertBinding: Binding<Bool> {
        Binding(
            get: { pendingDuplicateTemplate != nil },
            set: { if !$0 { pendingDuplicateTemplate = nil } }
        )
    }
}
