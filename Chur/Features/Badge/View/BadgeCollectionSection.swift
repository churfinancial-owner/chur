//
//  BadgeCollectionSection.swift
//  ChurApp
//
//  Description: Main entry point for the Badge feature with the new Dimmer UI.
//

import SwiftUI

struct BadgeCollectionSection: View {
    let cards: [CreditCard]
    let selectedCategory: BadgeCategory?
    @State private var activeSheet: BadgeSheet? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            BadgeHorizontalShelf(
                cards: cards,
                selectedCategory: selectedCategory,
                onExpertAction: { present(.pointTransfer) },
                onLoungeAction: { present(.loungeAccess) },
                onHotelStatusAction: { present(.hotelStatus) },
                onTrustedTravelerAction: { present(.trustedTraveler) },
                onCarRentalAction: { present(.carRental) },
                onCouponingAction: { present(.couponing) },
                onCellPhoneProtectionAction: { present(.cellPhoneProtection) },
                onAutoRentalCoverageAction: { present(.autoRentalCoverage) }
            )
        }
        // Using item-based sheet is correct for Enums
        .sheet(item: $activeSheet) { sheet in
            NavigationStack {
                sheetView(for: sheet)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { activeSheet = nil }
                        }
                    }
            }
        }
    }

    // MARK: - Helper Methods

    /// Prevents crashes from rapid taps by checking if a sheet is already present
    private func present(_ sheet: BadgeSheet) {
        guard activeSheet == nil else { return }
        activeSheet = sheet
    }

    /// Clean switch logic moved out of the body for readability
    @ViewBuilder
    private func sheetView(for sheet: BadgeSheet) -> some View {
        switch sheet {
        case .pointTransfer:           PointTransferView()
        case .loungeAccess:            LoungeAccessView()
        case .hotelStatus:             HotelStatusView()
        case .trustedTraveler:         TrustedTravelerView()
        case .carRental:               CarRentalStatusView()
        case .couponing:               CouponingView()
        case .cellPhoneProtection:     CellPhoneProtectionView()
        case .autoRentalCoverage:      AutoRentalCoverageView()
        }
    }
}

// MARK: - Sheet Enum

private enum BadgeSheet: String, Identifiable {
    case pointTransfer
    case loungeAccess
    case hotelStatus
    case trustedTraveler
    case carRental
    case couponing
    case cellPhoneProtection
    case autoRentalCoverage

    var id: String { rawValue }
}
