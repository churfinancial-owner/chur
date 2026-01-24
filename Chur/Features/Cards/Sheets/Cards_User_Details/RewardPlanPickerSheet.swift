//
//  RewardPlanPickerSheet.swift
//  Chur
//
//  Created by Pak Ho on 2/23/26.
//

import SwiftUI
import SwiftData

struct RewardPlanPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var card: CreditCard
    
    /// The currently selected plan ID (nil = default plan)
    private var currentPlanID: String? { card.selectedPlanID }
    
    /// All available plans for this card
    private var allPlans: [RewardPlan] {
        card.rewardPlans.sorted { plan1, plan2 in
            // Default plan first
            if plan1.isDefault != plan2.isDefault {
                return plan1.isDefault
            }
            // Then by start date (newest first)
            if let date1 = plan1.planStartDate, let date2 = plan2.planStartDate {
                return date1 > date2
            }
            // Then alphabetically
            return plan1.name < plan2.name
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerView
                    
                    if !allPlans.isEmpty {
                        plansSection
                    } else {
                        emptyStateView
                    }
                    
                    Spacer(minLength: 32)
                }
                .padding()
            }
            .background(Color.churOffWhite)
            .navigationTitle("Reward Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.bold)
                        .foregroundStyle(Color.churOlive)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        VStack(spacing: 8) {
            Text("🎯")
                .font(.churBigTitle1())

            if card.hasMultiplePlans {
                Text("Select which reward structure to use for this card. You can switch between plans at any time.")
                    .font(.churCaptionRegular())
                    .foregroundStyle(Color.churMediumGray)
                    .multilineTextAlignment(.center)
            } else {
                Text("This card has one reward plan available.")
                    .font(.churCaptionRegular())
                    .foregroundStyle(Color.churMediumGray)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 8)
    }
    
    // MARK: - Plans Section
    
    private var plansSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("AVAILABLE PLANS")
                .font(.churSmallBold())
                .foregroundStyle(Color.churOlive)
                .tracking(0.5)
            
            VStack(spacing: 0) {
                ForEach(allPlans, id: \.id) { plan in
                    PlanRow(
                        plan: plan,
                        isSelected: isSelected(plan: plan)
                    ) {
                        selectPlan(plan)
                    }
                    
                    if plan.id != allPlans.last?.id {
                        Divider().padding(.horizontal, 16).opacity(0.5)
                    }
                }
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.churBigTitle1())
                .foregroundStyle(Color.churMediumGray)
            
            Text("No plans available")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.churDarkGray)
            
            Text("This card doesn't have any reward plans configured yet.")
                .font(.churCaptionRegular())
                .foregroundStyle(Color.churMediumGray)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    // MARK: - Logic
    
    private func isSelected(plan: RewardPlan) -> Bool {
        // If no plan is explicitly selected, the default plan is active
        if card.selectedPlanID == nil {
            return plan.isDefault
        }
        return card.selectedPlanID == plan.id
    }
    
    private func selectPlan(_ plan: RewardPlan) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            // If selecting the default plan, clear the selection (nil = use default)
            if plan.isDefault {
                card.selectedPlanID = nil
            } else {
                card.selectedPlanID = plan.id
            }
        }
    }
}

// MARK: - Plan Row

private struct PlanRow: View {
    let plan: RewardPlan
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    // Plan name
                    Text(plan.name)
                        .font(.churRowText())
                        .foregroundStyle(Color.churDarkGray)
                        .multilineTextAlignment(.leading)
                    
                    // Date range
                    if let dateRange = plan.dateRangeText {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.churSmall())
                            Text(dateRange)
                                .font(.churSmall())
                        }
                        .foregroundStyle(Color.churMediumGray)
                    }
                    
                    // Badges
                    HStack(spacing: 6) {
                        if plan.isDefault {
                            badge(text: "Default", color: .churOlive)
                        }
                        
                        if plan.isPromo {
                            badge(text: "Promo", color: .blue)
                        }
                        
                        if plan.isCustomPlan {
                            badge(text: "Custom", color: .churInfo)
                        }
                        
                        if !plan.isAvailableForNewUsers && !plan.isCustomPlan {
                            badge(text: "Legacy", color: .churMediumGray)
                        }
                        
                        if let endDate = plan.planEndDate, endDate < Date() {
                            badge(text: "Expired", color: .churError)
                        }
                    }
                }
                
                Spacer()
                
                // Checkmark
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.churOlive : Color.churLightGray.opacity(0.5))
                    .font(.churBigTitle4())
            }
            .padding(16)
        }
        .buttonStyle(.plain)
    }
    
    private func badge(text: String, color: Color) -> some View {
        Text(text)
            .font(.churBadgeBold())
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color)
            .clipShape(Capsule())
    }
}
