//
//  BenefitDetailSheet_Header.swift
//  Chur
//
//  HEADER FREQ PILL AND EXPIRY PILL
//
//  Created by Pak Ho on 4/13/26.
//


import SwiftUI

// MARK: - Header & Info Cards
extension BenefitDetailSheet {

    var heroHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                if let frequency {
                    ChurStatusPill(label: frequency.uppercased(), color: frequencyColor)
                }

                // Anniversary reset-type pill — only for periodic, card-anniversary benefits
                if let freq = frequency?.lowercased(),
                   ["monthly", "quarterly", "semi-annual", "annual", "quadrennial"].contains(freq),
                   resetType == "card_anniversary" {
                    ChurStatusPill(label: "ANNIVERSARY", color: .purple, icon: "calendar.badge.clock", style: .tinted)
                }

                // Expiry countdown pill — only when expiry is upcoming
                if let expiryDate {
                    let today = Calendar.current.startOfDay(for: Date())
                    let expiry = Calendar.current.startOfDay(for: expiryDate)
                    let days = Calendar.current.dateComponents([.day], from: today, to: expiry).day ?? -1
                    if days >= 0 {
                        let expiryColor: Color = days <= 7 ? .red : .pink
                        ChurStatusPill(
                            label: days == 0 ? AppLocale.string("Last day") : AppLocale.string("\(days)d"),
                            color: expiryColor,
                            icon: "alarm",
                            style: .tinted
                        )
                    }
                }
            }

            HStack(alignment: .top, spacing: 10) {
                // Only reserve the slot when the partner actually resolves to an
                // icon — 81 of 276 benefits name no partner at all, and an empty
                // 32pt gutter on those reads as a missing image rather than as
                // "this perk has no brand". `IconArtView` fills it once the art
                // arrives; until then its Color.clear fallback holds the frame.
                if let partnerIconName {
                    IconArtView(imageName: partnerIconName)
                        .frame(width: 32, height: 32)
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                }

                Text(name)
                    .font(.churBigTitle3())
                    .foregroundStyle(Color.churDarkGray)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    func remainingBalanceRow(balance: Int) -> some View {
        let label = localIsFullyRedeemed ? AppLocale.string("Fully redeemed!") : (isValueBased ? AppLocale.string("\(valueCurrency!) \(balance) remaining") : AppLocale.string("\(balance) use\(balance == 1 ? "" : "s") remaining"))
        let rowColor: Color = localIsFullyRedeemed ? .gray : (balance == 0 ? .red : .churOlive)

        BenefitInfoRow(
            title: localIsFullyRedeemed ? AppLocale.string("FULLY REDEEMED THIS PERIOD ✓") : AppLocale.string("BALANCE REMAINING THIS PERIOD"),
            value: label,
            icon: localIsFullyRedeemed ? "checkmark.seal.fill" : "arrow.down.circle.fill",
            color: rowColor
        )
    }

    @ViewBuilder
    var expiryDateRow: some View {
        if let expiryDate {
            let now = Date.current()
            let formatted = expiryDate.formatted(date: .long, time: .omitted)
            let isExpiringSoon = (localRemainingBalance ?? 0) > 0
                && ReminderTiming.isInWarningWindow(expiry: expiryDate, now: now)

            BenefitInfoRow(
                title: "BENEFIT EXPIRY DATE",
                value: formatted,
                icon: "calendar.badge.exclamationmark",
                color: isExpiringSoon ? .red : .orange
            )
        }
    }

    var frequencyColor: Color {
        ChurStatusPill.color(for: frequency ?? "")
    }
}
