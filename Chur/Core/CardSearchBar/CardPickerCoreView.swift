//
//  CardPickerCoreView.swift
//  Chur
//
//  Created by Pak Ho on 4/9/26.
//

import SwiftUI

struct CardPickerCoreView: View {
    @Binding var filterState: CardAddFilterState
    @Binding var pendingTemplates: [CardTemplate]
    @Binding var pendingTemplateCounts: [String: Int]
    
    // External logic passed in
    let existingTemplateIds: Set<String>
    let onDuplicateDetected: (CardTemplate) -> Void
    
    @State private var isLoadingData = false
    @FocusState private var isSearchFocused: Bool

    // Haptics
    private let lightHaptic = UIImpactFeedbackGenerator(style: .light)
    private let mediumHaptic = UIImpactFeedbackGenerator(style: .medium)

    var body: some View {
        VStack(spacing: 0) {
            // 1. Filter Section (Reusing your existing component)
            CardAddFilterSection(filterState: filterState, isSearchFocused: $isSearchFocused)

            Divider()

            // 2. Card List
            ScrollView {
                if isLoadingData {
                    ProgressView("Loading cards...")
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if filterState.filteredTemplates.isEmpty {
                    emptyState
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(filterState.filteredTemplates, id: \.id) { template in
                            CardDatabaseRow(
                                template: template,
                                addedCount: pendingTemplateCounts[template.id] ?? 0,
                                onAdd: { handleAdd(template) },
                                onRemove: { handleRemove(template) }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 100) // Space for bottom buttons
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "creditcard")
                .font(.churBigTitle())
                .foregroundStyle(Color.churOlive.opacity(0.5))
            Text("No cards found")
                .font(.churSubheadline())
                .foregroundStyle(Color.churDarkGray)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    private func handleAdd(_ template: CardTemplate) {
        let alreadyInWallet = existingTemplateIds.contains(template.id)
        let alreadyPending = pendingTemplateCounts[template.id] != nil
        
        if alreadyInWallet || alreadyPending {
            onDuplicateDetected(template)
        } else {
            forceAdd(template)
        }
    }

    // Public method so parents can trigger addition (e.g., after an alert)
    func forceAdd(_ template: CardTemplate) {
        lightHaptic.impactOccurred()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            pendingTemplates.append(template)
            pendingTemplateCounts[template.id, default: 0] += 1
        }
    }

    private func handleRemove(_ template: CardTemplate) {
        guard let lastIndex = pendingTemplates.lastIndex(where: { $0.id == template.id }) else { return }
        mediumHaptic.impactOccurred()

        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            pendingTemplates.remove(at: lastIndex)
            let newCount = (pendingTemplateCounts[template.id] ?? 1) - 1
            if newCount <= 0 {
                pendingTemplateCounts.removeValue(forKey: template.id)
            } else {
                pendingTemplateCounts[template.id] = newCount
            }
        }
    }
}
