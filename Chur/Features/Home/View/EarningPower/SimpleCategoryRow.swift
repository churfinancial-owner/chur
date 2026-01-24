//
//  SimpleCategoryRow.swift
//  Chur
//
//  Created by Pak Ho on 2/12/26.
//
//


import SwiftUI
import SwiftData

// MARK: - Simple Category Row (Parent-only, no expansion)
struct SimpleCategoryRow: View {
    let category: SpendingCategory
    let isSelected: Bool
    let isHighlighted: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                onToggle()
            }
        } label: {
            HStack(spacing: 12) {
                CategoryIconView(category: category, font: .title2)
                    .frame(width: 32, height: 32)
                
                Text(category.displayName)
                    .font(.churHeadline())
                    .foregroundStyle(Color.churDarkGray)
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.churOlive : Color.churLightGray)
                    .font(.title3)
                    .frame(width: 32, height: 32)
                    .padding(.trailing, 4)
            }
            .contentShape(Rectangle())
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
        }
        .buttonStyle(.plain)
        .background(
            isHighlighted ? Color.churOlive.opacity(0.1) :
            isSelected ? Color.churOlive.opacity(0.05) : Color.clear
        )
    }
}
