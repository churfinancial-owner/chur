//
//  CategoryPickerView2.swift
//  Chur
//
//  Created by Pak Ho on 3/18/26.
//

import SwiftUI

struct CategoryPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: CategoryPickerViewModel

    init(user: User, categories: [SpendingCategory], availableCategoryIDs: Set<String>, directlyRewardedCategoryIDs: Set<String>) {
        _viewModel = State(initialValue: CategoryPickerViewModel(
            user: user,
            categories: categories,
            availableCategoryIDs: availableCategoryIDs,
            directlyRewardedCategoryIDs: directlyRewardedCategoryIDs
        ))
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(viewModel.visibleCategories, id: \.id) { category in
                        SimpleCategoryRow(
                            category: category,
                            isSelected: viewModel.tempSelection.contains(category.id),
                            isHighlighted: false,
                            onToggle: { viewModel.toggleCategory(category.id) }
                        )
                    }
                } header: {
                    headerView
                }
            }
            .navigationTitle("Customize Categories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(.red)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        viewModel.save()
                        dismiss()
                    }
                    .foregroundStyle(Color.churOlive)
                    .fontWeight(.bold)
                }
            }
        }
    }

    private var headerView: some View {
        HStack {
            // Updated to use viewModel properties
            Text("Categories (\(viewModel.selectionCount) selected)")
            Spacer()
            Button(viewModel.cycleButtonLabel) {
                viewModel.cycleSelection()
            }
            .font(.churCaptionRegular())
            .foregroundStyle(Color.churOlive)
        }
        .textCase(nil)
    }
}
