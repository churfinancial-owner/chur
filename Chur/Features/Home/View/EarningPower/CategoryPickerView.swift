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
            VStack(spacing: 0) {
                // MARK: - Chur Standardized Header
                // Replaces .navigationTitle for a more custom look
                Text("Customize Categories")
                    .font(.churTitle())
                    .foregroundStyle(Color.churDarkGray)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                
                List {
                    Section {
                        ForEach(viewModel.visibleCategories, id: \.id) { category in
                            SimpleCategoryRow(
                                category: category,
                                isSelected: viewModel.tempSelection.contains(category.id),
                                isHighlighted: false,
                                onToggle: { viewModel.toggleCategory(category.id) }
                            )
                            .listRowBackground(Color.white)
                        }
                    } header: {
                        headerView // The "Categories (X selected)" sub-header
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden) // Essential to see churOffWhite
            }
            .background(Color.churOffWhite)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.red)
                        .fontWeight(.bold)
                        .font(.churRowText())
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { // Uppercase to match Add Card UI
                        viewModel.save()
                        dismiss()
                    }
                    .font(.churRowText())
                    .fontWeight(.bold)
                    .foregroundStyle(Color.churOlive)
                }
            }
        }
    }
    
    private var headerView: some View {
        HStack {
            Text("YOUR SPENDING (\(viewModel.selectionCount))")
                .font(.churMicroBold())
                .foregroundStyle(Color.churDarkGray.opacity(0.6))
            
            Spacer()
            
            // MARK: - Premium Pill Button
            Button {
                withAnimation(.snappy) {
                    viewModel.cycleSelection()
                }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                HStack(spacing: 6) {
                    // Dynamic icon based on state
                    Image(systemName: "arrowshape.right.fill")
                        .font(.churBadgeBold())
                    Text(viewModel.cycleButtonLabel)
                        .font(.churBadgeBold())
                }
                .foregroundStyle(Color.churOlive)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Capsule().fill(Color.churOlive.opacity(0.12))) // The "Premium" background
            }
        }
        .textCase(nil)
        .padding(.leading, -16)
    }
}
