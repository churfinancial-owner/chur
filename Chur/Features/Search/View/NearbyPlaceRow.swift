//
//  NearbyPlaceRow.swift
//  Chur
//
//  Row view for a single nearby merchant in the search results list.
//  Shows merchant info only — card matching is deferred to the detail popup.
//

import SwiftUI
import SwiftData

struct NearbyPlaceRow: View {
    let merchant: NearbyMerchant
    let categories: [SpendingCategory]
    let cards: [CreditCard]
    let boostEnrollments: [String: String]
    var isSelected: Bool = false
    
    @State private var showDetailPopup = false
    
    private var merchantCategory: SpendingCategory? {
        categories.first(where: { $0.id == merchant.categoryID })
    }
    
    private var brandIconName: String? {
        OnlineMerchantDatabase.brandIconName(forCategory: merchant.categoryID)
    }
    
    var body: some View {
        Button {
            showDetailPopup = true
        } label: {
            HStack(spacing: 12) {
                // Brand icon if available, otherwise category icon/emoji
                if let iconName = brandIconName, let uiImage = UIImage(named: iconName) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40)
                } else if let category = merchantCategory {
                    CategoryIconView(category: category, font: .churHeadline())
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(Color.churTileWhiteBg)
                        )
                } else {
                    Circle()
                        .fill(Color.churTileWhiteBg)
                        .frame(width: 40, height: 40)
                        .overlay(Text("📍").font(.churBigTitle4()))
                }
                
                // Merchant Details
                VStack(alignment: .leading, spacing: 4) {
                    Text(merchant.name)
                        .font(.churSectionHeader())
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    
                    HStack(spacing: 6) {
                        if let category = merchantCategory {
                            Text(category.displayName)
                                .font(.churSmallMedium())
                        }
                        Text("·")
                        Text(String(format: "%.2f mi", merchant.distance))
                            .font(.churSmallMedium())
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
                    .fill(isSelected ? Color.churOlive.opacity(0.08) : Color.churTileWhiteBg)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.churOlive : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showDetailPopup) {
            if let category = merchantCategory {
                MerchantDetailSheet(
                    merchant: merchant,
                    category: category,
                    cards: cards,
                    allCategories: categories,
                    boostEnrollments: boostEnrollments
                )
            }
        }
    }
}
