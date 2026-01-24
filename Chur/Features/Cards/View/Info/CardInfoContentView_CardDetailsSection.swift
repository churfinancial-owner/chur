//
//  CardInfoContentView_CardDetailsSection.swift
//  Chur
//
//  Created by Pak Ho on 3/16/26.
//

import SwiftUI

struct CardDetailsSection: View {
    let card: CreditCard
    let categories: [SpendingCategory]
    let user: User?
    @Binding var activeSheet: CardInfoContentView.ActiveSheet?

    // String formatting logic from your original file
    var foreignFeeDisplay: String {
        if !card.hasForeignTransactionFee { return "None" }
        return card.foreignTransactionFeeRate?.formatted(.percent.precision(.fractionLength(0...2))) ?? "Yes"
    }
    
    var approvedDateDisplay: String {
        let monthNames = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12"]
        let safeMonth = max(1, min(card.approvedMonth, 12))
        return "\(monthNames[safeMonth - 1])-\(card.approvedYear)"
    }

    var rewardPlanDisplay: String {
        card.activePlan?.name ?? (card.rewards.isEmpty ? "No plan selected" : "Current Rewards")
    }

    var boostDisplay: String {
        guard let program = card.boostProgram, let tier = user?.boostEnrollments[program.id] else { return "Not enrolled" }
        let pct = Int((BoostProgramDatabase.multiplier(programID: program.id, tierName: tier) - 1.0) * 100)
        return "\(tier) (+\(pct)%)"
    }

    var uniqueProgramSummary: String {
        let groups = Dictionary(grouping: card.activeRewards, by: { $0.rewardProgramName })
        return groups.compactMap { (name, rewards) -> String? in
            guard let val = rewards.first?.pointCashValue else { return nil }
            let isCustom = !RewardProgramDefaults.isDefault(programName: name, pointCashValue: val)
            let formatted = (val * 100).truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", val * 100) : String(format: "%.2f", val * 100)
            return "\(name): \(formatted)¢\(isCustom ? " ✎" : "")"
        }.sorted().joined(separator: "  ·  ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header("CARD DETAILS")
            
            VStack(spacing: 0) {
                // FEES SUB-SECTION
                subHeader("FEES & TERMS")
                DetailRow(label: "Annual Fee", value: "$\(card.annualFee)", isEditable: true) { activeSheet = .annualFee }
                rowDivider
                DetailRow(label: "Foreign Transaction Fee", value: foreignFeeDisplay, isEditable: true) { activeSheet = .foreignFee }
                rowDivider
                DetailRow(label: "Approved Date", value: approvedDateDisplay, isEditable: true) { activeSheet = .approvedDate }
                
                Divider().padding(.vertical, 10)
                
                // REWARDS SUB-SECTION
                subHeader("REWARD SETUP")
                if card.activeRewards.contains(where: { $0.isUserConfigurable }) {
                    configurableRow
                    rowDivider
                }
                
                DetailRow(label: "Reward Plan", value: rewardPlanDisplay, isEditable: card.hasMultiplePlans) { activeSheet = .rewardPlan }
                rowDivider
                DetailRow(label: "Point Values", value: uniqueProgramSummary, isEditable: true) { activeSheet = .pointValues }

                if card.boostProgram != nil {
                    rowDivider
                    DetailRow(label: "Relationship Boost", value: boostDisplay, isEditable: true) { activeSheet = .boost }
                }
            }
            .padding(20)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // Small UI Helpers
    private func header(_ title: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title).font(.churSmallBold()).foregroundStyle(Color.churOlive).tracking(1.0)
                .padding([.horizontal, .top], 20).padding(.bottom, 12)
            Divider().padding(.horizontal, 20)
        }
    }

    private func subHeader(_ title: String) -> some View {
        Text(title).font(.churMicroBold())
            .foregroundStyle(Color.churOlive).tracking(0.8).padding(.bottom, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var rowDivider: some View { Divider().padding(.horizontal, 4).opacity(0.4) }

    private var configurableRow: some View {
        let configured = card.activeRewards.filter { $0.isUserConfigurable && !($0.categories?.isEmpty ?? true) }
        let total = card.activeRewards.filter { $0.isUserConfigurable }.count
        
        return Group {
            if configured.isEmpty {
                DetailRow(label: "Bonus Categories", value: "0/\(total) configured", isEditable: true) { activeSheet = .configurableRewards }
            } else {
                Button { activeSheet = .configurableRewards } label: {
                    HStack {
                        Text("Bonus Categories").font(.churRowText()).foregroundStyle(Color.churDarkGray)
                        Spacer()
                        HStack(spacing: 4) {
                            ForEach(configured.compactMap { r in categories.first { $0.id == r.categories?.first } }, id: \.id) { cat in
                                CategoryIconView(category: cat, font: .system(size: 16)).frame(width: 24, height: 24)
                            }
                        }
                        Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundStyle(Color.churMediumGray).padding(.leading, 4)
                    }.padding(.vertical, 16)
                }.buttonStyle(.plain)
            }
        }
    }
}
