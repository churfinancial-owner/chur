//
//  NearbyListPopup.swift
//  Chur
//
//  Created by Pak Ho on 4/8/26.
//

import SwiftUI

struct NearbyListPopup: View {
    let merchants: [NearbyMerchant]
    let cards: [CreditCard]
    let categories: [SpendingCategory]
    let boostEnrollments: [String: String]
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(merchants) { merchant in
                        NearbyPlaceRow(
                            merchant: merchant,
                            categories: categories,
                            cards: cards,
                            boostEnrollments: boostEnrollments
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .navigationTitle("Nearby")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.churBigTitle4())
                            .foregroundStyle(Color.churMediumGray)
                    }
                }
            }
        }
    }
}
