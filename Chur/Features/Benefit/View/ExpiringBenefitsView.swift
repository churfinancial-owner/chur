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
            (card: group[0].card, entries: group.sorted {
                ($0.expiryDate, $0.benefit.id) < ($1.expiryDate, $1.benefit.id)
            })
        }
        // Secondary key (card.id) keeps ordering deterministic across
        // re-renders — card.benefits is a to-many relationship with no
        // guaranteed fetch order, so ties in expiryDate alone can silently
        // reshuffle the list on every re-render.
        result.sort {
            let lhs = ($0.entries.first?.expiryDate ?? .distantFuture, $0.card.id)
            let rhs = ($1.entries.first?.expiryDate ?? .distantFuture, $1.card.id)
            return lhs < rhs
        }
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
                            ExpiringBenefitCardGroupRow(
                                card: group.card,
                                entries: group.entries,
                                detailTarget: $detailTarget
                            )
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
}

// MARK: - Card Group Row

/// Collapsible per-card group, styled to match BenefitGroupRow
/// (GroupingDetailSheet_Components.swift) used by the wallet summary
/// month/year sheets — card icon, chevron rotates on expand, collapsed
/// by default.
private struct ExpiringBenefitCardGroupRow: View {
    let card: CreditCard
    let entries: [ExpiringBenefitEntry]
    @Binding var detailTarget: BenefitDeepLinkTarget?
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(card.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 42, height: 28)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.black.opacity(0.06), lineWidth: 0.5))

                VStack(alignment: .leading, spacing: 2) {
                    Text(card.name)
                        .font(.churSmallBold())
                        .foregroundStyle(Color.churDarkGray)
                        .lineLimit(1)
                    Text(card.issuer)
                        .font(.churSmall())
                        .foregroundStyle(Color.churMediumGray)
                        .lineLimit(1)
                }

                Spacer()

                Text("^[\(entries.count) benefit](inflect: true)")
                    .font(.churSmall())
                    .foregroundStyle(Color.churMediumGray)

                Image(systemName: "chevron.right")
                    .font(.churSmall())
                    .foregroundStyle(Color.churMediumGray)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
            .padding(16)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.snappy(duration: 0.3)) {
                    isExpanded.toggle()
                }
            }

            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(entries) { entry in
                        Divider().padding(.horizontal, 16).opacity(0.5)

                        Button {
                            detailTarget = BenefitDeepLinkTarget(card: entry.card, benefit: entry.benefit)
                        } label: {
                            entryRow(entry)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
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
