//
//  EarningPowerTabView.swift
//  Chur
//
//  Created by Pak Ho on 3/18/26.
//

import SwiftUI
import SwiftData

struct EarningPowerSection: View {
    @Bindable var user: User
    let cards: [CreditCard]
    @Query private var categories: [SpendingCategory]
    
    @State private var viewModel: EarningPowerViewModel
    @State private var showingCategoryPicker = false
    @State private var showingTravelModeConfirmation = false
    @State private var isRecalculating = false
    @State private var rebuildTask: Task<Void, Never>?
    
    /// Fingerprint that changes when any card property relevant to earning power changes.
    private var cardsFingerprint: Int {
        var hasher = Hasher()
        for card in cards {
            hasher.combine(card.id)
            hasher.combine(card.selectedPlanID)
            hasher.combine(card.rewardPlans.count)
            for plan in card.rewardPlans {
                hasher.combine(plan.id)
                hasher.combine(plan.rewards.count)
            }
        }
        return hasher.finalize()
    }

    init(cards: [CreditCard], user: User, currentRegionCodeOverride: String? = nil) {
        self.user = user
        self.cards = cards
        _viewModel = State(initialValue: EarningPowerViewModel(user: user, cards: cards, categories: []))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerView
            
            if cards.isEmpty {
                emptyWalletView
            } else if isRecalculating {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
            } else if viewModel.selectedCategories.isEmpty {
                emptySelectionView
            } else {
                categoryGridView
            }
        }
        // Update ViewModel when inputs change, then rebuild rate cache
        .onAppear {
            viewModel.cards = cards
            viewModel.categories = categories
            scheduleRebuild()
        }
        .onChange(of: categories) {
            viewModel.categories = categories
            scheduleRebuild()
        }
        .onChange(of: cardsFingerprint) {
            viewModel.cards = cards
            scheduleRebuild()
        }
        .onChange(of: user.boostEnrollments) { scheduleRebuild() }
        .onChange(of: user.earningPowerTravelModeEnabled) { scheduleRebuild() }
        .onChange(of: user.selectedCategories) { scheduleRebuild() }
        .sheet(isPresented: $showingCategoryPicker) {
            CategoryPickerView(
                user: user,
                categories: categories,
                availableCategoryIDs: viewModel.availableCategoryIDs,
                directlyRewardedCategoryIDs: viewModel.directlyRewardedCategoryIDs
            )
        }
        .alert("Convert to Travel Mode?", isPresented: $showingTravelModeConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Confirm") { user.earningPowerTravelModeEnabled = true }
        } message: {
            Text("When enabled, Earning Power applies foreign transaction fee adjustments as cross-border spend.")
        }
    }
    
    /// Debounced rebuild: cancels any pending rebuild, waits for changes to settle,
    /// yields to let the loading spinner render, then computes rates synchronously.
    private func scheduleRebuild() {
        rebuildTask?.cancel()
        isRecalculating = true
        rebuildTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            // Yield to allow SwiftUI to render the loading state before blocking
            await Task.yield()
            viewModel.rebuildRateCache()
            isRecalculating = false
        }
    }
    
    // Sub-views for better readability
    private var headerView: some View {
        HStack {
            Text("⚡ EARNING POWER")
                .font(.churHeadline())
                .foregroundStyle(Color.churOlive)

            if viewModel.isAwayFromHomeRegion {
                Button {
                    if user.earningPowerTravelModeEnabled { user.earningPowerTravelModeEnabled = false }
                    else { showingTravelModeConfirmation = true }
                } label: {
                    Image(systemName: "airplane")
                        .foregroundStyle(user.earningPowerTravelModeEnabled ? Color.green : Color.gray)
                }
            }
            Spacer()
            if !cards.isEmpty {
                Button { showingCategoryPicker = true } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.churImageMedium())
                        .frame(width: 32, height: 32)
                        .background(Color.churOliveLight)
                        .clipShape(Circle())
                        .foregroundStyle(.churDarkOlive)
                }
            }
        }
    }

    private var categoryGridView: some View {
        VStack(spacing: 12) {
            ForEach(viewModel.categoryRows(), id: \.self) { row in
                HStack(spacing: 12) {
                    ForEach(row, id: \.id) { category in
                        let cached = viewModel.bestCard(for: category.id)
                        CategoryBubble(
                            category: category,
                            rate: cached?.rate ?? 0,
                            effectiveRate: cached?.effectiveCashBackRate ?? 0,
                            showEffectiveRate: user.showEffectiveRate,
                            cards: cards,
                            allCategories: categories,
                            currentRegionCodeOverride: viewModel.currentRegionCode
                        )
                    }
                    if row.count == 1 { Spacer().frame(maxWidth: .infinity) }
                }
            }
        }
    }
    
    private var emptyWalletView: some View {
        VStack(spacing: 16) {
            let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 2)
            LazyVGrid(columns: columns, spacing: 12) {
                emptyWalletTile(emoji: "✈️", label: "Travel")
                emptyWalletTile(emoji: "🍽️", label: "Dining")
                emptyWalletTile(emoji: "🛒", label: "Groceries")
                emptyWalletTile(emoji: "💳", label: "Everything Else")
            }
            .allowsHitTesting(false)
            
            Text("Add cards to see your best earning rates")
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func emptyWalletTile(emoji: String, label: String) -> some View {
        VStack(spacing: 6) {
            Text(emoji).font(.churTitle())
            Text(label)
                .font(.churFootnoteMedium())
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white))
    }
    
    private var emptySelectionView: some View {
        VStack(spacing: 12) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.churBigTitle3())
                .foregroundStyle(.secondary)
            
            Text("No categories selected")
                .font(.churRowText())
                .foregroundStyle(.primary)
            
            Button {
                showingCategoryPicker = true
            } label: {
                Text("Customize Categories")
                    .font(.churCaption())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.churOlive))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}
