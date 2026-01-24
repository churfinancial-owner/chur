//
//  NearbyFilter.swift
//  Chur
//
//  Filter enum for nearby map search categories and the associated chip view.
//

import SwiftUI
import MapKit

// MARK: - Nearby Place Filter

enum NearbyFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case dining = "Dining"
    case grocery = "Grocery"
    case gas = "Fuel/Charge"
    case shopping = "Shopping"
    
    var id: String { rawValue }
    
    var emoji: String {
        switch self {
        case .all: return "📍"
        case .dining: return "🍽️"
        case .grocery: return "🛒"
        case .gas: return "🚙"
        case .shopping: return "🛍️"
        }
    }
    
    var poiCategories: [MKPointOfInterestCategory]? {
        switch self {
        case .all:
            return nil
        case .dining:
            return [.restaurant, .cafe, .bakery, .brewery, .winery, .nightlife, .distillery]
        case .grocery:
            return [.foodMarket]
        case .gas:
            return [.gasStation, .evCharger]
        case .shopping:
            return [.store, .foodMarket, .pharmacy]
        }
    }
    
    private var rootCategoryIDs: Set<String> {
        switch self {
        case .all: return []
        case .dining: return ["dining"]
        case .grocery: return ["groceries"]
        case .gas: return ["gas"]
        case .shopping: return ["retail", "wholesale"]
        }
    }
    
    func matches(_ merchant: NearbyMerchant, categories: [SpendingCategory]) -> Bool {
        if self == .all { return true }
        let roots = rootCategoryIDs
        var visited = Set<String>()
        var currentID: String? = merchant.categoryID
        
        while let id = currentID, !visited.contains(id) {
            if roots.contains(id) { return true }
            visited.insert(id)
            guard let category = categories.first(where: { $0.id == id }) else { break }
            if let links = category.categoryLinks, links.contains(where: { roots.contains($0.id) }) {
                return true
            }
            currentID = category.parentCategoryID
        }
        return false
    }
}

// MARK: - Filter Chip View

struct NearbyFilterChip: View {
    let filter: NearbyFilter
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if !filter.emoji.isEmpty {
                    Text(filter.emoji)
                }
                Text(filter.rawValue)
                    .font(.system(size: 15, weight: isSelected ? .bold : .medium, design: .rounded))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(isSelected ? Color.churOlive : Color.gray.opacity(0.1))
            )
            .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}
