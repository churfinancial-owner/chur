//
//  GoToCardSheet.swift
//  Chur
//
//  Sheet for quickly jumping to a card in the wallet carousel.
//  Supports deep search across card name, rewards, benefits, and features,
//  with results grouped by what matched. Includes an issuer dropdown filter.
//

import SwiftUI

// MARK: - Search Models

private enum SearchSection: String, CaseIterable {
    case cards    = "Cards"
    case rewards  = "Rewards"
    case benefits = "Benefits"
    case features = "Features"

    var icon: String {
        switch self {
        case .cards:    return "creditcard"
        case .rewards:  return "star"
        case .benefits: return "checkmark.seal"
        case .features: return "sparkles"
        }
    }
}

private struct SearchResult: Identifiable {
    let id = UUID()      // unique per result — same card can appear in multiple sections
    let card: CreditCard
    let matchedText: String  // e.g. "4x Ultimate Rewards on Airlines" or "DoorDash Credits"
}

// MARK: - Sheet View

struct GoToCardSheet: View {
    @Environment(\.dismiss) private var dismiss

    let sortedCards: [CreditCard]
    let onSelect: (String) -> Void

    @State private var searchText = ""
    @State private var selectedIssuer: String? = nil
    @FocusState private var isSearchFocused: Bool

    // Benefit types that live in the Benefits tab (vs Features tab)
    private let benefitBenefitTypes: Set<String> = ["credit", "lounge_access", "ttp"]

    // Sentinel value for the "Other" bucket
    private let otherBucket = "__other__"

    // MARK: - Derived Data

    /// Issuers in the wallet that are "popular" (have popularIn set in IssuerDatabase), sorted by sortOrder.
    private var popularWalletIssuers: [String] {
        let walletIssuers = Set(sortedCards.map { $0.issuer })
        return walletIssuers
            .filter { IssuerDatabase.byName[$0]?.popularIn.isEmpty == false }
            .sorted { (a, b) in
                let aOrder = IssuerDatabase.byName[a]?.sortOrder ?? Int.max
                let bOrder = IssuerDatabase.byName[b]?.sortOrder ?? Int.max
                return aOrder < bOrder
            }
    }

    /// Wallet issuers that are NOT in the popular list.
    private var otherWalletIssuers: Set<String> {
        let popular = Set(popularWalletIssuers)
        return Set(sortedCards.map { $0.issuer }).subtracting(popular)
    }

    /// Cards after applying the issuer filter (handles the "Other" bucket).
    private var issuerFiltered: [CreditCard] {
        guard let selected = selectedIssuer else { return sortedCards }
        if selected == otherBucket {
            return sortedCards.filter { otherWalletIssuers.contains($0.issuer) }
        }
        return sortedCards.filter { $0.issuer == selected }
    }

    /// Deep search across card name → rewards → benefits → features.
    /// All sections are fully independent — a card can appear in multiple sections
    /// if it matches in each (e.g. "amazon" surfaces the Amazon card by name AND
    /// any card with an Amazon reward rate AND any card with an Amazon benefit).
    private var deepResults: [(section: SearchSection, results: [SearchResult])] {
        guard !searchText.isEmpty else { return [] }

        var cards:    [SearchResult] = []
        var rewards:  [SearchResult] = []
        var benefits: [SearchResult] = []
        var features: [SearchResult] = []

        for card in issuerFiltered {

            // 1. Card name / issuer
            if card.name.localizedCaseInsensitiveContains(searchText) ||
               card.issuer.localizedCaseInsensitiveContains(searchText) {
                cards.append(.init(card: card, matchedText: card.name))
            }

            // 2. Rewards
            if let reward = card.activeRewards.first(where: { rewardMatches($0) }) {
                rewards.append(.init(card: card, matchedText: rewardLabel(reward)))
            }

            // 3. Benefits
            let cardBenefits = card.benefits.filter { benefitBenefitTypes.contains($0.benefitType.lowercased()) }
            if let benefit = cardBenefits.first(where: { benefitMatches($0) }) {
                benefits.append(.init(card: card, matchedText: benefit.displayName))
            }

            // 4. Features
            let cardFeatures = card.benefits.filter { !benefitBenefitTypes.contains($0.benefitType.lowercased()) }
            if let feature = cardFeatures.first(where: { benefitMatches($0) }) {
                features.append(.init(card: card, matchedText: feature.displayName))
            }
        }

        return [
            (.cards,    cards),
            (.rewards,  rewards),
            (.benefits, benefits),
            (.features, features),
        ].filter { !$0.results.isEmpty }
    }

    // MARK: - Match Helpers

    private func rewardMatches(_ reward: RewardRate) -> Bool {
        if reward.rewardProgramName.localizedCaseInsensitiveContains(searchText) { return true }
        if let m = reward.merchantName, m.localizedCaseInsensitiveContains(searchText) { return true }
        if let cats = reward.categories {
            for cat in cats where cat.localizedCaseInsensitiveContains(searchText) { return true }
        }
        if let notes = reward.rewardNotes, notes.localizedCaseInsensitiveContains(searchText) { return true }
        if let opts = reward.configurableOptions {
            for opt in opts where opt.localizedCaseInsensitiveContains(searchText) { return true }
        }
        return false
    }

    private func benefitMatches(_ benefit: Benefit) -> Bool {
        if benefit.displayName.localizedCaseInsensitiveContains(searchText) { return true }
        if let p = benefit.partnerName, p.localizedCaseInsensitiveContains(searchText) { return true }
        if let n = benefit.benefitNotes, n.localizedCaseInsensitiveContains(searchText) { return true }
        return false
    }

    private func rewardLabel(_ reward: RewardRate) -> String {
        let rateStr = reward.rate == reward.rate.rounded()
            ? "\(Int(reward.rate))x"
            : String(format: "%.1fx", reward.rate)
        var parts = [rateStr, reward.rewardProgramName]
        if let merchant = reward.merchantName {
            parts.append("at \(merchant)")
        } else if let cats = reward.categories, !cats.isEmpty {
            let display = cats
                .map { $0.replacingOccurrences(of: "_", with: " ").capitalized }
                .joined(separator: ", ")
            parts.append("on \(display)")
        }
        return parts.joined(separator: " ")
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Text("Go To Card")
                    .font(.churTitle())
                    .foregroundStyle(Color.churDarkGray)
                    .padding(.top, 8)
                    .padding(.bottom, 12)

                // Search bar
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Color.churMediumGray)

                    TextField("Search cards, rewards, benefits...", text: $searchText)
                        .font(.system(size: 15, design: .rounded))
                        .focused($isSearchFocused)

                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                            isSearchFocused = false
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(Color.churMediumGray)
                        }
                    }
                }
                .padding(12)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

                // Issuer chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        BankPill(title: "All", isSelected: selectedIssuer == nil) {
                            selectedIssuer = nil
                        }
                        ForEach(popularWalletIssuers, id: \.self) { issuer in
                            let info = IssuerDatabase.byName[issuer]
                            BankPill(
                                title: info?.shortName ?? issuer,
                                logoImageName: info?.logoImageName,
                                isSelected: selectedIssuer == issuer
                            ) {
                                selectedIssuer = selectedIssuer == issuer ? nil : issuer
                            }
                        }
                        if !otherWalletIssuers.isEmpty {
                            BankPill(
                                title: "Other",
                                isSelected: selectedIssuer == otherBucket
                            ) {
                                selectedIssuer = selectedIssuer == otherBucket ? nil : otherBucket
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
                }

                Divider()

                // Card list — flat when no search, sectioned when searching
                ScrollView {
                    if searchText.isEmpty {
                        flatList
                    } else {
                        sectionedList
                    }
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .background(Color.churOffWhite)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.red)
                }
            }
        }
    }

    // MARK: - Flat List (no search text)

    @ViewBuilder
    private var flatList: some View {
        if issuerFiltered.isEmpty {
            emptyState
        } else {
            LazyVStack(spacing: 12) {
                ForEach(issuerFiltered) { card in
                    GoToCardRow(card: card)
                        .onTapGesture { navigate(to: card.id) }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Sectioned List (with search text)

    @ViewBuilder
    private var sectionedList: some View {
        if deepResults.isEmpty {
            emptyState
        } else {
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(deepResults, id: \.section.rawValue) { entry in
                    // Section header
                    HStack(spacing: 6) {
                        Image(systemName: entry.section.icon)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.churOlive)
                        Text(entry.section.rawValue.uppercased())
                            .font(.churHeadline())
                            .foregroundStyle(Color.churOlive)
                            .tracking(0.5)
                        Spacer()
                        Text("\(entry.results.count)")
                            .font(.churSmallBold())
                            .foregroundStyle(Color.churMediumGray)
                    }
                    .padding(.top, entry.section == deepResults.first?.section ? 12 : 4)

                    // Rows for this section
                    ForEach(entry.results) { result in
                        GoToCardRow(card: result.card, matchedText: result.matchedText)
                            .onTapGesture { navigate(to: result.card.id) }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "creditcard")
                .font(.churBigTitle())
                .foregroundStyle(Color.churOlive.opacity(0.5))
            Text("No cards found")
                .font(.churSubheadline())
                .foregroundStyle(Color.churDarkGray)
            Text("Try adjusting your search or filter.")
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(Color.churMediumGray)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
        .padding(.top, 40)
    }

    // MARK: - Navigation

    private func navigate(to cardID: String) {
        onSelect(cardID)
        dismiss()
    }
}

// MARK: - Row

private struct GoToCardRow: View {
    let card: CreditCard
    var matchedText: String? = nil

    private var cardColor: Color {
        .cardColor(for: card.issuer)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Card image with colored fallback
            if let uiImage = UIImage(named: card.imageName) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 38)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(cardColor)
                    .frame(width: 60, height: 38)
                    .overlay {
                        VStack(spacing: 2) {
                            Text(card.issuer)
                                .font(.churBadge())
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                            Text(card.network)
                                .font(.churBadge())
                                .foregroundStyle(.white.opacity(0.8))
                        }
                    }
            }

            // Card name + issuer + optional match context
            VStack(alignment: .leading, spacing: 3) {
                Text(card.name)
                    .font(.churCaption())
                    .foregroundStyle(Color.churDarkGray)
                    .lineLimit(1)
                Text(card.issuer)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(Color.churMediumGray)
                if let matchedText {
                    Text(matchedText)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.churOlive.opacity(0.85))
                        .lineLimit(1)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.churMediumGray)
        }
        .padding()
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 1)
    }
}
