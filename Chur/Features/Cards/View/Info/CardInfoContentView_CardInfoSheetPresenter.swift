//
//  CardInfoContentView_CardInfoSheetPresenter.swift
//  Chur
//
//  Created by Pak Ho on 3/16/26.
//

import SwiftUI

struct CardInfoSheetPresenter: View {
    let sheet: CardInfoContentView.ActiveSheet
    let card: CreditCard

    var body: some View {
        switch sheet {
        case .annualFee: AnnualFeePickerSheet(card: card)
        case .approvedDate: ApprovedDatePickerSheet(card: card)
        case .foreignFee: ForeignFeePickerSheet(card: card)
        case .pointValues: RewardProgramEditorSheet(card: card)
        case .configurableRewards: UserConfigurableRewardsSheet(card: card)
        case .boost(let programID): BoostProgramPickerSheet(card: card, programID: programID)
        case .rewardPlan: RewardPlanPickerSheet(card: card)
        case .transferPartners(let programName): PointTransferView(preselectedProgramName: programName)
        case .network: NetworkPickerSheet(card: card)
        case .cardType: CardTypePickerSheet(card: card)
        case .userNote: CardsUserNoteSheet(card: card)
        case .cardStatus: CardStatusSheet(card: card)
        }
    }
}
