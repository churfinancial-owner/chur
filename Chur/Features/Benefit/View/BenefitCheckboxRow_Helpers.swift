//
//  BenefitCheckboxRow_Helpers.swift
//  Chur
//
//  Created by Pak Ho on 3/10/26.
//
//  Description: Extension for BenefitCheckboxRow containing complex
//               ViewBuilders for the title button and detail sheet.
//



import SwiftUI

extension BenefitCheckboxRow {
    @ViewBuilder
    func titleButton(_ vm: BenefitRowViewModel) -> some View {
        Button {
            if vm.needsActivation { showingActivationConfirmation = true }
            else if !vm.isLocked { showingDetail = true }
        } label: {
            HStack(spacing: 4) {
                if let prefix = vm.valuePrefixLabel, !vm.isLocked {
                    Text(prefix)
                        .font(.churRowText())
                        .foregroundStyle(vm.isUsedInPeriod ? Color.churMediumGray : Color.churDarkGray)
                }
                Text(benefit.displayName)
                    .font(.churRowText())
                    .foregroundStyle(vm.isLocked || vm.isUsedInPeriod ? Color.churMediumGray : Color.churDarkGray)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }

    // Sheet assembly lives in BenefitDetailSheetHost so the reminder
    // deep-link path presents the exact same detail experience.
    @ViewBuilder
    func detailView(_ vm: BenefitRowViewModel) -> some View {
        BenefitDetailSheetHost(benefit: benefit, vm: vm)
    }
}
