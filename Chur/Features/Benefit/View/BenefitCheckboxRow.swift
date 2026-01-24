//  Benefit/View/BenefitCheckboxRow.swift

import SwiftUI
import SwiftData

struct BenefitCheckboxRow: View {
    @Bindable var benefit: Benefit
    let approvedMonth: Int
    let approvedYear: Int

    @Environment(\.modelContext) var modelContext
    @State private var viewModel: BenefitRowViewModel?
    
    @State var showingDetail = false
    @State var showingWipeConfirmation = false
    @State var showingActivationConfirmation = false
    @State private var pillExpanded = false // Track expansion state
    
    var body: some View {
        Group {
            if let vm = viewModel {
                HStack(alignment: .center, spacing: 14) {
                    BenefitCheckboxButton(
                        isLocked: vm.isLocked,
                        needsActivation: vm.needsActivation,
                        isUsed: vm.isUsedInPeriod,
                        isUnlimited: vm.isUnlimited,
                        isCountLimited: vm.isCountLimited,
                        isFullyRedeemed: vm.isFullyRedeemed
                    ) {
                        if vm.needsActivation {
                            showingActivationConfirmation = true
                        } else if !vm.isLocked {
                            vm.handleToggle { showingWipeConfirmation = true }
                        }
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .center) {
                            titleButton(vm)
                            if vm.isUnlimited && vm.usageCountThisPeriod > 0 {
                                Text("x\(vm.usageCountThisPeriod)")
                                    .font(.churFootnoteBold())
                                    .foregroundStyle(Color.churOlive)
                            }
                            if vm.isCountLimited, let limit = benefit.usageLimit, vm.usageCountThisPeriod > 0 {
                                Text("\(vm.usageCountThisPeriod)/\(limit)")
                                    .font(.churFootnoteBold())
                                    .foregroundStyle(vm.isFullyRedeemed ? Color.churMediumGray : Color.churOlive)
                            }
                            Spacer()
                            
                            if vm.isWithinExpiryWarning {
                                Text("⏰").font(.churSmall())
                            }
                            
                            // Enhanced Interactive Pill
                            ChurStatusPill(
                                label: benefit.frequency.uppercased(),
                                color: ChurStatusPill.color(for: benefit.frequency, default: .gray),
                                style: .filled(isUsed: vm.isUsedInPeriod),
                                compact: true,
                                isCollapsed: !pillExpanded // Collapsed by default
                            )
                            .onTapGesture {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                    pillExpanded.toggle()
                                }
                            }
                        }
                        
                        if let label = vm.unlockLabel {
                            Text(label)
                                .font(.churSmall())
                                .foregroundStyle(Color.churMediumGray)
                        }
                    }
                }
                .opacity(vm.isLocked || (!vm.isUnlimited && vm.isUsedInPeriod) || (vm.isCountLimited && vm.isFullyRedeemed) ? 0.45 : 1.0)
                .sheet(isPresented: $showingDetail) {
                    detailView(vm)
                }
            } else {
                Color.clear.frame(height: 50)
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = BenefitRowViewModel(
                    benefit: benefit,
                    approvedMonth: approvedMonth,
                    approvedYear: approvedYear,
                    modelContext: modelContext
                )
            }
            viewModel?.attemptAutoApply()
        }
        .alert("Unlock Benefit?", isPresented: $showingActivationConfirmation) {
            Button("Unlock") {
                if benefit.activationMode == "lockonce" {
                    benefit.isActivatedByUser = true
                } else {
                    benefit.activatedAt = Date.current()
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(benefit.activationInstructions ?? "Unlock to start tracking.")
        }
        .alert("Delete Records?", isPresented: $showingWipeConfirmation) {
            Button("Delete", role: .destructive) { viewModel?.reverseUsage() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Unchecking will delete all records in this period.")
        }
    }
}
