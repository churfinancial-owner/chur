//
//  ExpiringSoonHomeSection.swift
//  Chur
//
//  Compact Home preview of ExpiringBenefits — same source of truth as
//  ExpiringBenefitsView and the digest notification, so the numbers always
//  agree. Shows the soonest few entries; "See all" opens the full sheet.
//

import SwiftUI

struct ExpiringSoonHomeSection: View {
    let cards: [CreditCard]
    @State private var showAll = false
    @State private var detailTarget: BenefitDeepLinkTarget?

    private var entries: [ExpiringBenefitEntry] {
        ExpiringBenefits.entries(cards: cards).sorted { $0.expiryDate < $1.expiryDate }
    }

    private var previewEntries: [ExpiringBenefitEntry] {
        Array(entries.prefix(3))
    }

    var body: some View {
        if !entries.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                headerView

                VStack(spacing: 0) {
                    ForEach(previewEntries) { entry in
                        Button {
                            detailTarget = BenefitDeepLinkTarget(card: entry.card, benefit: entry.benefit)
                        } label: {
                            row(entry)
                        }
                        .buttonStyle(.plain)

                        if entry.id != previewEntries.last?.id {
                            Divider().padding(.horizontal, 16).opacity(0.5)
                        }
                    }
                }
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .sheet(isPresented: $showAll) {
                ExpiringBenefitsView()
            }
            .sheet(item: $detailTarget) { target in
                BenefitReminderDeepLinkSheet(benefit: target.benefit, card: target.card)
            }
        }
    }

    private var headerView: some View {
        HStack {
            Text("⏰ EXPIRING SOON")
                .font(.churHeadline())
                .foregroundStyle(Color.churOlive)
            Spacer()
            OliveRingIconButton(icon: "arrow.right") { showAll = true }
        }
    }

    private func row(_ entry: ExpiringBenefitEntry) -> some View {
        HStack(spacing: 12) {
            CardArtView(imageName: entry.card.imageName, contentMode: .fit, placeholderCornerRadius: 4)
                .frame(width: 42, height: 28)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.black.opacity(0.06), lineWidth: 0.5))

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.benefit.displayName)
                    .font(.churRowText())
                    .foregroundStyle(Color.churDarkGray)
                    .lineLimit(1)
                Text("Expires \(entry.expiryDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.churSmall())
                    .foregroundStyle(Color.churWarning)
            }
            Spacer()
            if let remaining = entry.remainingBalance {
                Text("\(entry.benefit.valueCurrency.currencySymbol)\(remaining) left")
                    .font(.churSmallBold())
                    .foregroundStyle(Color.churOlive)
            }
            Image(systemName: "chevron.right")
                .font(.churSmall())
                .foregroundStyle(Color.churMediumGray)
        }
        .padding(16)
        .contentShape(Rectangle())
    }
}
