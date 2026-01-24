//
//  View_MerchantCategoryNotFound.swift
//  Chur
//
//  Shown when a merchant's category doesn't exist in the spending categories database.
//  Uses the same visual style as CalculatorPopup so it doesn't feel like an error screen.
//

import SwiftUI

struct MerchantCategoryNotFoundSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    let merchant: NearbyMerchant
    let categoryID: String
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    
                    // MARK: - Merchant Header (same style as CalculatorPopup)
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("MERCHANT")
                                    .font(.churMicroBold())
                                    .foregroundStyle(Color.churMediumGray)
                                    .tracking(0.5)
                                
                                Text(merchant.name)
                                    .font(.churTitle2())
                                    .foregroundStyle(Color.churDarkGray)
                                
                                HStack(spacing: 8) {
                                    if let region = merchant.region {
                                        HStack(spacing: 4) {
                                            Image(systemName: "location.fill")
                                                .font(.churBadge())
                                            Text(region)
                                                .font(.system(size: 13, weight: .medium))
                                        }
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(Color.churOlive)
                                        .clipShape(Capsule())
                                    }
                                    
                                    if !merchant.address.isEmpty {
                                        Text(merchant.address)
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundStyle(Color.churMediumGray)
                                            .lineLimit(1)
                                    }
                                }
                                
                                HStack(spacing: 4) {
                                    Image(systemName: "location.fill")
                                        .font(.churBadge())
                                    Text(String(format: "%.2f mi away", merchant.distance))
                                        .font(.system(size: 13, weight: .medium))
                                }
                                .foregroundStyle(Color.churMediumGray)
                            }
                            
                            Spacer()
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.churOffWhite)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    
                    // MARK: - Category Not Found Info
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.churBigTitle4())
                                .foregroundStyle(.orange)
                            
                            Text("Category Not Found")
                                .font(.churHeadline())
                                .foregroundStyle(Color.churDarkGray)
                        }
                        
                        Text("This merchant's category \"\(categoryID)\" isn't in Chur's database yet, so we can't calculate card recommendations for it.")
                            .font(.churCaptionRegular())
                            .foregroundStyle(Color.churMediumGray)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        // Show the raw category ID and Apple POI for reference
                        VStack(alignment: .leading, spacing: 8) {
                            Text("CATEGORY ID")
                                .font(.churMicroBold())
                                .foregroundStyle(Color.churMediumGray)
                                .tracking(0.5)
                            
                            HStack(spacing: 8) {
                                Text(categoryID)
                                    .font(.churCaptionMedium())
                                    .foregroundStyle(Color.churDarkGray)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.churOffWhite)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                
                                if let poi = merchant.poiCategory {
                                    Text(poi.replacingOccurrences(of: "MKPOICategory", with: ""))
                                        .font(.churSmall())
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.blue.opacity(0.6))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white)
                            .shadow(color: Color.orange.opacity(0.1), radius: 8, x: 0, y: 4)
                    )
                    
                    // MARK: - Tip
                    HStack(spacing: 10) {
                        Image(systemName: "lightbulb.fill")
                            .font(.churCaptionRegular())
                            .foregroundStyle(Color.churOlive)
                        
                        Text("Use your general \"everything\" card for the best base rate at this merchant.")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.churMediumGray)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.churOliveLight.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(20)
            }
            .background(Color.white)
            .navigationTitle("Card Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.churBigTitle4())
                            .foregroundStyle(Color.churMediumGray)
                    }
                }
            }
        }
    }
}
