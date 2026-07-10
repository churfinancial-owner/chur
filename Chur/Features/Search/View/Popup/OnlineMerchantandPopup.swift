//
//  OnlineMerchantandPopup.swift
//  Chur
//
//  Online merchant search view with a featured merchant grid and
//  discovery-only search list. Card matching is deferred to the detail popup.
//

import SwiftUI
import SwiftData

struct OnlineSearchView: View {
    /// Search text driven by the parent's shared search bar
    @Binding var searchText: String

    @Query private var cards: [CreditCard]
    @Query private var categories: [SpendingCategory]
    @Query private var users: [User]

    private var userCountry: String { users.first?.country ?? "US" }
    private var boostEnrollments: [String: String] { users.first?.boostEnrollments ?? [:] }

    @State private var selectedFeaturedMerchant: OnlineMerchant? = nil

    // MARK: - Data

    private var featuredMerchants: [OnlineMerchant] {
        OnlineMerchantDatabase.featured(forCountry: userCountry, limit: Int.max)
            .sorted { lhs, rhs in
                let lHas = lhs.affiliateID != nil
                let rHas = rhs.affiliateID != nil
                if lHas != rHas { return lHas }
                return false
            }
    }

    private var listMerchants: [OnlineMerchant] {
        OnlineMerchantDatabase.search(query: searchText, country: userCountry)
    }

    private var hasSearchText: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    // Featured Grid — hidden when searching
                    if !hasSearchText {
                        FeaturedGridView(
                            merchants: featuredMerchants,
                            categories: Array(categories),
                            selection: $selectedFeaturedMerchant
                        )
                    }

                    // Merchant list
                    LazyVStack(spacing: 12) {
                        ForEach(listMerchants) { merchant in
                            OnlineMerchantRow(
                                merchant: merchant,
                                categories: categories,
                                cards: cards,
                                boostEnrollments: boostEnrollments
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 26)
                }
            }
        }
        .background(Color.churOffWhite)
        .sheet(item: $selectedFeaturedMerchant) { merchant in
            if let category = categories.first(where: { $0.id == merchant.category }) {
                MerchantDetailSheet(
                    merchant: OnlineMerchantDatabase.toNearbyMerchant(merchant),
                    category: category,
                    cards: cards,
                    allCategories: categories,
                    boostEnrollments: boostEnrollments,
                    channel: "online"
                )
                // Forces SwiftUI to create a fresh sheet for each merchant, preventing stale content.
                .id(merchant.id)
            }
        }
    }
}

// MARK: - Featured Grid View
//
// Extracted as a standalone struct so the TabView has a stable view identity that is
// independent of sheet state. When this lived as a computed var inside OnlineSearchView,
// every sheet open/close re-evaluated the var and rebuilt the TabView, resetting its
// internal page position and potentially freezing closure captures in non-visible pages.

private struct FeaturedGridView: View {
    let merchants: [OnlineMerchant]
    let categories: [SpendingCategory]
    @Binding var selection: OnlineMerchant?

    private let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
        let pages = stride(from: 0, to: merchants.count, by: 9)
            .map { Array(merchants[$0..<min($0 + 9, merchants.count)]) }

        TabView {
            ForEach(Array(pages.indices), id: \.self) { i in
                LazyVGrid(columns: gridColumns, spacing: 8) {
                    ForEach(pages[i]) { merchant in
                        FeaturedMerchantTile(merchant: merchant, categories: categories) {
                            selection = merchant
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.top, 8)
                .padding(.bottom, 36)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .automatic))
        .frame(height: 316)
    }
}

// MARK: - Featured Merchant Tile

private struct FeaturedMerchantTile: View {
    let merchant: OnlineMerchant
    let categories: [SpendingCategory]
    let onTap: () -> Void

    private var merchantCategory: SpendingCategory? {
        categories.first(where: { $0.id == merchant.category })
    }

    var body: some View {
        Button(action: onTap) {
            MerchantIconView(iconName: merchant.merchantIconName, category: merchantCategory)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(10)
                .frame(height: 82)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color.churTileWhiteBg))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
                .overlay(alignment: .topTrailing) {
                    if merchant.affiliateID != nil {
                        Image(systemName: "sparkle")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(5)
                            .background(Color.orange, in: Circle())
                            .offset(x: 4, y: -4)
                    }
                }
        }
        .contentShape(Rectangle())
        .buttonStyle(ScaleButtonStyle())
    }
}
