//
//  OnlineMerchantRow.swift
//  Chur
//
//  Row view for a single online merchant in the search results list.
//  Shows merchant info only — card matching is deferred to the detail popup.
//

import SwiftUI
import SwiftData

struct OnlineMerchantRow: View {
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
            HStack(spacing: 12) {
                // Merchant Icon
                MerchantIconView(iconName: merchant.merchantIconName, category: merchantCategory)
                    .frame(width: 56, height: 36)
                
                // Merchant Details
                VStack(alignment: .leading, spacing: 4) {
                    Text(merchant.name)
                        .font(.churSectionHeader())
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    
                    HStack(spacing: 6) {
                        if let category = merchantCategory {
                            Text(category.displayName)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                        }
                        if let domain = merchant.domain, !domain.isEmpty {
                            Text("·")
                            Text(domain)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .lineLimit(1)
                        }
                    }
                    .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.churTiles)
            )
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

// MARK: - Merchant Icon View

/// Displays a merchant's brand icon if available, otherwise falls back to the category icon/emoji.
/// Uses `.scaledToFit()` so wide wordmark logos (Amazon, Costco, etc.) are fully visible.
struct MerchantIconView: View {
    let iconName: String?
    let category: SpendingCategory?
    
    var body: some View {
        if let iconName, let uiImage = UIImage(named: iconName) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
        } else if let category {
            CategoryIconView(category: category, font: .system(size: 20))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Image(systemName: "storefront")
                .font(.churBigTitle4())
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
