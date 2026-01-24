//
//  BadgeCategoryPicker.swift
//  Chur
//
//  Created by Pak Ho on 3/9/26.
//

import SwiftUI

struct BadgeCategoryPicker: View {
    @Binding var selectedCategory: BadgeCategory
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(BadgeDatabase.getAllCategories(), id: \.self) { category in
                    categoryButton(category)
                }
            }
            .padding(.horizontal)
        }
    }
    
    private func categoryButton(_ category: BadgeCategory) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedCategory = category
            }
        } label: {
            Text(category.displayName)
                .font(.churMicroBold())
                .foregroundStyle(selectedCategory == category ? .white : Color.churMediumGray)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(selectedCategory == category ? Color.churOlive : Color.churLightGray.opacity(0.3))
                )
        }
    }
}
