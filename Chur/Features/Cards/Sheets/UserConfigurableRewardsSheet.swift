//
//  UserConfigurableRewardsSheet.swift
//  Chur
//
//  Created by Pak Ho on 2/15/26.
//

import SwiftUI
import SwiftData

// MARK: - User Configurable Rewards Sheet

struct UserConfigurableRewardsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var card: CreditCard

    @Query private var allCategories: [SpendingCategory]

    /// All rewards on this card that require user configuration, sorted by slot
    private var configurableRewards: [RewardRate] {
        card.activeRewards
            .filter { $0.isUserConfigurable }
            .sorted { ($0.configurableSlot ?? "") < ($1.configurableSlot ?? "") }
    }

    /// Current selections: [slotID: categoryID]
    @State private var selections: [String: String] = [:]

    /// True only when every slot has a selection
    private var isComplete: Bool {
        configurableRewards.allSatisfy { reward in
            guard let slot = reward.configurableSlot else { return true }
            return selections[slot] != nil
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerView

                    ForEach(configurableRewards, id: \.configurableSlot) { reward in
                        if let slot = reward.configurableSlot {
                            SlotPickerSection(
                                reward: reward,
                                slot: slot,
                                allCategories: allCategories,
                                configurableIncludes: templateIncludes(for: slot),
                                selections: $selections
                            )
                        }
                    }

                    Spacer(minLength: 32)
                }
                .padding()
            }
            .background(Color.churOffWhite)
            .navigationTitle("Set Up Categories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.red)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { commitSelections() }
                        .fontWeight(.bold)
                        .foregroundStyle(isComplete ? Color.churOlive : Color.churMediumGray)
                        .disabled(!isComplete)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onAppear { loadExistingSelections() }
    }

    // MARK: - Header

    /// Card-specific subtitle for the configuration sheet.
    private var headerSubtitle: String {
        switch card.templateID {
        case "us-bank-cash-plus":
            return "Pick two 5% categories and one 2% everyday category. You can change these once per quarter."
        case "citi-custom-cash":
            return "Pick the one category where you spend the most — you'll automatically earn 5% there each billing cycle."
        case "bofa-customized-cash":
            return "Pick the one category where you spend the most — you'll automatically earn 3% there each billing cycle."
        case "synchrony-venmo-visa":
            return "Pick one 3% category and one 2% category where you spend the most — you'll automatically earn extra points there each billing cycle."
        case "cardless-bilt-obsidian":
            return "3X points on your choice of grocery or dining. Your 3X category choice remains in effect for the entire calendar year."
        default:
            return "Select a category for each reward tier."
        }
    }

    private var headerView: some View {
        VStack(spacing: 8) {
            Text("💳")
                .font(.churBigTitle1())

            Text(headerSubtitle)
                .font(.churCaptionRegular())
                .foregroundStyle(Color.churMediumGray)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    // MARK: - Logic

    /// Returns configurableIncludes for a slot from the live CardDatabase template.
    /// Always reads from the template — never from SwiftData — because [String: [String]]?
    /// does not roundtrip reliably in SwiftData.
    private func templateIncludes(for slot: String) -> [String: [String]]? {
        guard let templateID = card.templateID,
              let template = CardDatabase.getCard(id: templateID) else { return nil }
        return template.rewardPlans
            .flatMap { $0.rewards }
            .first { $0.configurableSlot == slot }?
            .configurableIncludes
    }

    /// Pre-populate selections from any already-configured rewards
    private func loadExistingSelections() {
        for reward in configurableRewards {
            guard let slot = reward.configurableSlot else { continue }
            // Prefer the directly-stored label (reliable); fall back to reverse-lookup for legacy data
            if let label = reward.selectedConfigurableLabel {
                selections[slot] = label
            } else if let existingCategoryIDs = reward.categories, !existingCategoryIDs.isEmpty {
                let matchingLabel = templateIncludes(for: slot)?.first { _, ids in
                    ids == existingCategoryIDs
                }?.key
                if let label = matchingLabel {
                    selections[slot] = label
                }
            }
        }
    }

    /// Write selections back to the RewardRate objects
    private func commitSelections() {
        for reward in configurableRewards {
            guard let slot = reward.configurableSlot,
                  let selectedLabel = selections[slot] else { continue }
            reward.selectedConfigurableLabel = selectedLabel
            let includes = templateIncludes(for: slot)?[selectedLabel] ?? [selectedLabel]
            reward.categories = includes
        }
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Slot Picker Section

private struct SlotPickerSection: View {
    let reward: RewardRate
    let slot: String
    let allCategories: [SpendingCategory]
    let configurableIncludes: [String: [String]]? // sourced from CardDatabase, not SwiftData
    @Binding var selections: [String: String]

    /// Labels taken by OTHER slots — not available here
    private var unavailableLabels: Set<String> {
        Set(selections.filter { $0.key != slot }.values)
    }

    /// The options for this slot, as (label, SpendingCategory) pairs.
    /// `configurableOptions` holds display labels; `configurableIncludes` maps each label → [categoryID].
    /// We use the first categoryID from includes to find the SpendingCategory for display/selection.
    private var options: [(label: String, category: SpendingCategory)] {
        guard let labels = reward.configurableOptions else { return [] }
        return labels.compactMap { label -> (label: String, category: SpendingCategory)? in
            guard let categoryIDs = configurableIncludes?[label],
                  let firstID = categoryIDs.first,
                  let category = allCategories.first(where: { $0.id == firstID })
            else { return nil }
            return (label: label, category: category)
        }
    }

    private var currentSelection: String? { selections[slot] }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // Section header
            HStack {
                Text(slotDisplayLabel(for: slot, rate: reward.rate).uppercased())
                    .font(.churSmallBold())
                    .foregroundStyle(Color.churOlive)
                    .tracking(0.5)

                Spacer()

                Text(reward.rate.formatAsRate())
                    .font(.churFootnoteBold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.churOlive)
                    .clipShape(Capsule())
            }

            // Options grid
            LazyVGrid(columns: [GridItem(.flexible())], spacing: 10)
            {
                ForEach(options, id: \.label) { option in
                    let isSelected = currentSelection == option.label
                    let isUnavailable = unavailableLabels.contains(option.label)

                    CategoryOptionRow(
                        label: option.label,
                        category: option.category,
                        isSelected: isSelected,
                        isUnavailable: isUnavailable
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selections[slot] = option.label
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Category Option Row

private struct CategoryOptionRow: View {
    let label: String
    let category: SpendingCategory
    let isSelected: Bool
    let isUnavailable: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Text(category.emoji)
                    .font(.churBigTitle4())

                Text(label)
                    .font(.churFootnoteBold())
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(labelColor)

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.churOlive : Color.churLightGray.opacity(0.5))
                    .font(.churBody())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isSelected ? Color.churOlive : Color.clear, lineWidth: 1.5)
            )
            .opacity(isUnavailable ? 0.35 : 1.0)
        }
        .disabled(isUnavailable)
        .buttonStyle(ScaleButtonStyle())
    }

    private var backgroundColor: Color {
        if isSelected { return Color.churOlive.opacity(0.1) }
        return Color.churLightGray.opacity(0.2)
    }

    private var labelColor: Color {
        if isUnavailable { return Color.churMediumGray }
        if isSelected { return Color.churOlive }
        return Color.churDarkGray
    }
}

// MARK: - Slot Label Helper

/// Converts slot + actual rate → "Choose your 3% category", "Choose your 2% category", etc.
/// Uses the real reward.rate rather than parsing from the slot name, so mismatched
/// slot IDs (e.g. "5pct_slot_1" on a 3x reward) display correctly.
func slotDisplayLabel(for slot: String, rate: Double) -> String {
    // Format rate: show as integer if whole number, otherwise one decimal place
    let rateStr: String
    if rate.truncatingRemainder(dividingBy: 1) == 0 {
        rateStr = String(format: "%.0f", rate)
    } else {
        rateStr = String(format: "%.1f", rate)
    }

    return "Choose your \(rateStr)% category"
}
