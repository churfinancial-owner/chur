//
//  CategoryPickerViewModel.swift
//  Chur
//
//  Created by Pak Ho on 3/18/26.
//

import SwiftUI
import SwiftData

@Observable
class CategoryPickerViewModel {
    var user: User
    let categories: [SpendingCategory]
    let availableCategoryIDs: Set<String>
    let directlyRewardedCategoryIDs: Set<String>
    
    var tempSelection: Set<String>
    var toggledCategoryIDs: Set<String> = []
    
    init(user: User, categories: [SpendingCategory], availableCategoryIDs: Set<String>, directlyRewardedCategoryIDs: Set<String>) {
        self.user = user
        self.categories = categories
        self.availableCategoryIDs = availableCategoryIDs
        self.directlyRewardedCategoryIDs = directlyRewardedCategoryIDs
        
        let selectedIDs = Set(user.selectedCategories)
        let selectedChildren = categories.filter {
            selectedIDs.contains($0.id) && $0.level == .child
        }
        let selectedParentIDsWithChildSelected = Set(selectedChildren.compactMap(\.parentCategoryID))
        let explicitParentIDs = Set(user.explicitlySelectedParentCategories)
        
        let inferredParentSelections = Set(
            categories.compactMap { category -> String? in
                guard category.level == .parent else { return nil }
                guard selectedParentIDsWithChildSelected.contains(category.id) else { return nil }
                guard !directlyRewardedCategoryIDs.contains(category.id) else { return nil }
                guard !explicitParentIDs.contains(category.id) else { return nil }
                return category.id
            }
        )
        
        self.tempSelection = selectedIDs.subtracting(inferredParentSelections)
    }
    
    // MARK: - Computed Properties
    var selectionCount: Int {
        selectedVisibleCategories.count
    }
    
    var selectedVisibleCategories: [SpendingCategory] {
        let selectedIDs = displayedSelectedParentIDs
        return visibleCategories.filter { selectedIDs.contains($0.id) }
    }
    
    var visibleCategories: [SpendingCategory] {
        categories
            .filter {
                $0.level == .parent &&
                $0.visibility?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() != "hidden"
            }
            .sorted {
                $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            }
    }
    
    var allVisibleCategoryIDs: Set<String> {
        Set(visibleCategories.map { $0.id })
    }
    
    var displayedSelectedParentIDs: Set<String> {
        let selectedIDs = Set(tempSelection)
        let explicitlySelectedParentIDs = Set(categories.filter { selectedIDs.contains($0.id) && $0.level == .parent }.map(\.id))
        let inferredParentIDsFromChildren = Set(categories.filter { selectedIDs.contains($0.id) && $0.level == .child }.compactMap(\.parentCategoryID))
        
        return explicitlySelectedParentIDs.union(inferredParentIDsFromChildren).intersection(allVisibleCategoryIDs)
    }
    
    var allCategoriesSelected: Bool {
        let visibleIDs = allVisibleCategoryIDs
        return !visibleIDs.isEmpty && visibleIDs.isSubset(of: displayedSelectedParentIDs)
    }
    
    var walletCategoriesSelected: Bool {
        let walletIDs = walletCategoryIDs
        guard !walletIDs.isEmpty else { return false }
        return walletIDs == displayedSelectedParentIDs.intersection(allVisibleCategoryIDs)
    }
    
    var walletCategoryIDs: Set<String> {
        var ids = allVisibleCategoryIDs.intersection(availableCategoryIDs)
        if allVisibleCategoryIDs.contains("everything") { ids.insert("everything") }
        return ids
    }
    
    var cycleButtonLabel: String {
        if allCategoriesSelected { return "All" }
        else if walletCategoriesSelected { return "Wallet Specific" }
        else { return "None" }
    }
    
    // MARK: - Actions
    func toggleCategory(_ id: String) {
        toggledCategoryIDs.insert(id)
        if tempSelection.contains(id) {
            tempSelection.remove(id)
        } else {
            tempSelection.insert(id)
        }
    }
    
    func cycleSelection() {
        let visibleIDs = allVisibleCategoryIDs
        let childIDsUnderVisibleParents = Set(categories.filter { $0.level == .child && visibleIDs.contains($0.parentCategoryID ?? "") }.map(\.id))
        
        if allCategoriesSelected {
            tempSelection.subtract(visibleIDs.union(childIDsUnderVisibleParents))
        } else if walletCategoriesSelected {
            tempSelection.formUnion(visibleIDs)
        } else {
            tempSelection.subtract(visibleIDs.union(childIDsUnderVisibleParents))
            tempSelection.formUnion(walletCategoryIDs)
        }
    }
    
    func save() {
        let previouslySelected = Set(user.selectedCategories)
        let newlyDeselected = previouslySelected.subtracting(tempSelection)
        
        user.deselectedCategories.append(contentsOf: Array(newlyDeselected))
        user.deselectedCategories = Array(Set(user.deselectedCategories))
        user.selectedCategories = Array(tempSelection)
        
        let parentIDs = Set(categories.filter { $0.level == .parent }.map(\.id))
        var explicitParents = Set(user.explicitlySelectedParentCategories)
        explicitParents = explicitParents.intersection(parentIDs).intersection(tempSelection)
        
        let newlyExplicitParents = toggledCategoryIDs.filter { id in
            parentIDs.contains(id) && tempSelection.contains(id)
        }
        explicitParents.formUnion(newlyExplicitParents)
        user.explicitlySelectedParentCategories = Array(explicitParents)
    }
}
