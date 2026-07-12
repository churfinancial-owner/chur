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

    private struct ExpiringEntry: Identifiable {
        let card: CreditCard
        let benefit: Benefit
        let remainingBalance: Int?
        let expiryDate: Date
        var id: String { "\(card.id).\(benefit.id)" }
    }

    /// Cards with their expiring benefits, soonest expiry first.
    /// Mirrors BenefitRowViewModel.shouldShowExpiryWarning so the list
    /// matches the ⏰ badges and the notification schedule.
    private var groups: [(card: CreditCard, entries: [ExpiringEntry])] {
        let now = Date.current()
        var result: [(card: CreditCard, entries: [ExpiringEntry])] = []

        for card in cards where card.status == "active" {
            let anniversary = Calendar.current.date(from: DateComponents(
                year: card.approvedYear, month: max(1, min(12, card.approvedMonth)), day: 1
            ))
            var entries: [ExpiringEntry] = []

            for benefit in card.benefits {
                guard benefit.isCurrentlyActive, !benefit.isMuted,
                      !benefit.isLocked(approvedMonth: card.approvedMonth, approvedYear: card.approvedYear),
                      let expiry = benefit.effectiveExpiryDate(cardAnniversaryDate: anniversary)
                else { continue }

                let analyzer = BenefitUsageAnalyzer(benefit: benefit, approvedMonth: card.approvedMonth)
                let remaining = analyzer.remainingBalance(on: now)
                guard (remaining ?? 0) > 0,
                      ReminderTiming.isInWarningWindow(expiry: expiry, frequency: benefit.frequency, now: now)
                else { continue }

                entries.append(ExpiringEntry(
                    card: card,
                    benefit: benefit,
                    remainingBalance: analyzer.isValueBased ? remaining : nil,
                    expiryDate: expiry
                ))
            }

            if !entries.isEmpty {
                entries.sort { $0.expiryDate < $1.expiryDate }
                result.append((card: card, entries: entries))
            }
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

    private func cardSection(card: CreditCard, entries: [ExpiringEntry]) -> some View {
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

    private func entryRow(_ entry: ExpiringEntry) -> some View {
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
