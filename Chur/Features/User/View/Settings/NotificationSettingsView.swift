//
//  NotificationSettingsView.swift
//  Chur
//

import SwiftUI
import SwiftData

struct NotificationSettingsView: View {
    @AppStorage("expiryWarningDays") private var expiryWarningDays: Int = 3
    @Query(sort: \CreditCard.dateAdded) private var cards: [CreditCard]

    // Track which cards the user has manually collapsed; all start expanded.
    @State private var collapsedCards: Set<String> = []

    private var cardsWithBenefits: [CreditCard] {
        cards.filter { !$0.benefits.filter { $0.isActive && $0.isRemindable }.isEmpty }
    }

    var body: some View {
        List {
            // MARK: - Warning Timing
            Section {
                Stepper(
                    "Expiry warning: \(expiryWarningDays) day\(expiryWarningDays == 1 ? "" : "s") before",
                    value: $expiryWarningDays,
                    in: 1...30
                )
            } header: {
                Text("WARNING TIMING")
            }

            // MARK: - Per-Benefit Mute Controls
            if cardsWithBenefits.isEmpty {
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "bell.badge")
                                .font(.churBigTitle3())
                                .foregroundStyle(Color.churMediumGray)
                            Text("Add cards to manage benefit reminders")
                                .font(.churFootnote())
                                .foregroundStyle(Color.churMediumGray)
                                .multilineTextAlignment(.center)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 16)
                    .listRowBackground(Color.clear)
                }
            } else {
                Section {
                    ForEach(cardsWithBenefits) { card in
                        cardDisclosureGroup(card)
                    }
                } header: {
                    Text("BENEFIT REMINDERS")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.churOffWhite)
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func cardDisclosureGroup(_ card: CreditCard) -> some View {
        let isExpanded = !collapsedCards.contains(card.id)
        let activeBenefits = card.benefits
            .filter { $0.isActive && $0.isRemindable }
            .sorted { $0.displayOrder < $1.displayOrder }

        DisclosureGroup(
            isExpanded: Binding(
                get: { isExpanded },
                set: { expanded in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        if expanded {
                            collapsedCards.remove(card.id)
                        } else {
                            collapsedCards.insert(card.id)
                        }
                    }
                }
            )
        ) {
            ForEach(activeBenefits, id: \.id) { benefit in
                BenefitMuteRow(benefit: benefit)
            }
        } label: {
            Text(card.name)
                .font(.churRowTextMedium())
                .foregroundStyle(Color.churDarkGray)
        }
    }
}

// MARK: - Benefit Mute Row

private struct BenefitMuteRow: View {
    @Bindable var benefit: Benefit

    var body: some View {
        HStack {
            Text(benefit.displayName)
                .font(.churRowText())
                .foregroundStyle(Color.churDarkGray)
                .lineLimit(1)

            Spacer()

            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    benefit.isMuted.toggle()
                }
            } label: {
                Image(systemName: benefit.isMuted ? "bell.slash.fill" : "bell.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(benefit.isMuted ? Color.churMediumGray : Color.churOlive)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
        }
        .listRowBackground(Color.white)
    }
}

