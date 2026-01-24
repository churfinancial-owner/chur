//
//  Search_Online_View.swift
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
    
    // MARK: - Data
    
    private var featuredMerchants: [OnlineMerchant] {
        OnlineMerchantDatabase.featured(forCountry: userCountry, limit: 9)
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
                        featuredSection
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
    }
    
    // MARK: - Featured Section
    
    private let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)
    
    private var featuredSection: some View {
        LazyVGrid(columns: gridColumns, spacing: 8) {
            ForEach(featuredMerchants) { merchant in
                FeaturedMerchantTile(
                    merchant: merchant,
                    categories: categories,
                    cards: cards,
                    boostEnrollments: boostEnrollments
                )
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(height: 280)
    }
}

// MARK: - Featured Merchant Tile

private struct FeaturedMerchantTile: View {
    let merchant: OnlineMerchant
    let categories: [SpendingCategory]
    let cards: [CreditCard]
    let boostEnrollments: [String: String]
    
    @State private var showDetailPopup = false
    
    private var merchantCategory: SpendingCategory? {
        categories.first(where: { $0.id == merchant.category })
    }
    
    var body: some View {
        Button {
            showDetailPopup = true
        } label: {
            MerchantIconView(iconName: merchant.merchantIconName, category: merchantCategory)
                .padding(8)
                .frame(maxWidth: .infinity)
                .frame(height: 82)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.churTiles)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showDetailPopup) {
            if let category = merchantCategory {
                MerchantDetailSheet(
                    merchant: OnlineMerchantDatabase.toNearbyMerchant(merchant),
                    category: category,
                    cards: cards,
                    allCategories: categories,
                    boostEnrollments: boostEnrollments,
                    channel: "online"
                )
            }
        }
    }
}
