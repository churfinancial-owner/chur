//
//  ExpiringBenefitsView.swift
//  Chur
//
//  Global "Expiring soon" list: every benefit across active wallet cards
//  that is inside its warning window with balance remaining, grouped by
//  card. Presented when the user taps a digest notification.
//

import SwiftUI
import SwiftData

struct ExpiringBenefitsView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var cards: [CreditCard]
    @State private var detailTarget: BenefitDeepLinkTarget?

    /// Cards with their expiring benefits, soonest expiry first. The entry
    /// query lives in ExpiringBenefits so this list and the digest
    /// notification body always count the same set.
    private var groups: [(card: CreditCard, entries: [ExpiringBenefitEntry])] {
        let byCard = Dictionary(grouping: ExpiringBenefits.entries(cards: cards)) { $0.card.id }
        var result = byCard.values.map { group in
            (card: group[0].card, entries: group.sorted { $0.expiryDate < $1.expiryDate })
        }
        result.sort { ($0.entries.first?.expiryDate ?? .distantFuture) < ($1.entries.first?.expiryDate ?? .distantFuture) }
        return result
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if groups.isEmpty {
                        EmptyStatePlaceholder(
                            icon: "checkmark.circle",
                            title: "Nothing expiring soon",
                            subtitle: "Benefits show up here when they enter their reminder window with value left to use."
                        )
                    } else {
                        summaryHeader
                        ForEach(groups, id: \.card.id) { group in
                            cardSection(card: group.card, entries: group.entries)
                        }
                    }
                }
                .padding()
            }
            .background(Color.churOffWhite)
            .navigationTitle("Expiring Soon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .font(.churRowText())
                        .fontWeight(.bold)
                        .foregroundStyle(Color.churOlive)
                }
            }
        }
        .sheet(item: $detailTarget) { target in
            BenefitReminderDeepLinkSheet(benefit: target.benefit, card: target.card)
        }
    }

    private var summaryHeader: some View {
        let benefitCount = groups.reduce(0) { $0 + $1.entries.count }
        return Text("^[\(benefitCount) benefits](inflect: true) expiring across ^[\(groups.count) cards](inflect: true)")
            .font(.churSmallMedium())
            .foregroundStyle(Color.churMediumGray)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func cardSection(card: CreditCard, entries: [ExpiringBenefitEntry]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(card.name.uppercased())
                .font(.churSmallBold())
                .foregroundStyle(Color.churOlive)
                .tracking(0.5)

            VStack(spacing: 0) {
                ForEach(entries) { entry in
                    Button {
                        detailTarget = BenefitDeepLinkTarget(card: entry.card, benefit: entry.benefit)
                    } label: {
                        entryRow(entry)
                    }
                    .buttonStyle(.plain)

                    if entry.id != entries.last?.id {
                        Divider().padding(.horizontal, 16).opacity(0.5)
                    }
                }
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
        }
    }

    private func entryRow(_ entry: ExpiringBenefitEntry) -> some View {
        HStack(spacing: 12) {
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
