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

    private var topLevelParent: SpendingCategory? {
        guard let category = merchantCategory else { return nil }
        var current = category
        var topParent: SpendingCategory? = nil
        while let parentID = current.parentCategoryID,
              let parent = categories.first(where: { $0.id == parentID }) {
            topParent = parent
            current = parent
        }
        return topParent
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
                    
                    HStack(spacing: 4) {
                        if let parent = topLevelParent, let category = merchantCategory {
                            Text(parent.displayName)
                                .font(.churSmallMedium())
                            Text("·")
                                .font(.churSmallMedium())
                            Text(category.displayName)
                                .font(.churSmallMedium())
                        } else if let category = merchantCategory {
                            Text(category.displayName)
                                .font(.churSmallMedium())
                        }
                    }
                    .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.churSmallBold())
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.churTileWhiteBg)
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

