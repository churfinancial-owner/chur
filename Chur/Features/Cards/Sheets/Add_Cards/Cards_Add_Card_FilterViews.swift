//
//  Cards_Add_Card_FilterViews.swift
//  Chur
//
// • Card​Add​Filter​Section - Main filter container
// • Card​Add​Search​Bar - Search field
// • Region​Selector - Country picker bubble (🇺🇸/🇭🇰)
// • Card​Type​Selector - Card type picker bubble (All Types/Personal/Business)
// • Bank​Filter​Selector - Bank filter picker bubble (Popular/All/Bank names)
// • Filter​Pill - Individual pill view (deprecated)
//
//  Created by Pak Ho on 1/22/26.
//

import SwiftUI

// MARK: - Filter Section
struct CardAddFilterSection: View {
    @Bindable var filterState: CardAddFilterState
    @FocusState.Binding var isSearchFocused: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            // Search bar
            CardAddSearchBar(
                searchText: $filterState.searchText,
                isSearchFocused: $isSearchFocused,
                onSearchChange: filterState.handleSearchChange
            )
            
            // Row 1: Region + Card Type
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    RegionSelector(filterState: filterState)
                    CardTypeSelector(filterState: filterState)
                }
                .padding(.horizontal)
            }
            
            // Row 2: Bank filter pills
            BankFilterPillRow(filterState: filterState)
        }
        .padding(.vertical, 8)
        .background(Color.churOffWhite)
    }
}

// MARK: - Search Bar
struct CardAddSearchBar: View {
    @Binding var searchText: String
    @FocusState.Binding var isSearchFocused: Bool
    let onSearchChange: (String, String) -> Void
    
    @State private var searchTask: Task<Void, Never>?
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.churMediumGray)
            TextField("Search cards...", text: $searchText)
                .font(.churBody())
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(.search)
                .focused($isSearchFocused)
                .onChange(of: searchText) { oldValue, newValue in
                    // Cancel previous search task
                    searchTask?.cancel()
                    
                    // Create new debounced search task
                    searchTask = Task {
                        // Wait 300ms before triggering search
                        try? await Task.sleep(for: .milliseconds(300))
                        
                        // Only execute if task wasn't cancelled
                        guard !Task.isCancelled else { return }
                        
                        onSearchChange(oldValue, newValue)
                    }
                }
            
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.churMediumGray)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
    }
}

// MARK: - Region Selector
struct RegionSelector: View {
    @Bindable var filterState: CardAddFilterState
    
    private var availableRegions: [Region] {
        RegionDatabase.activeRegions
    }
    
    var body: some View {
        Menu {
            ForEach(availableRegions) { region in
                Button {
                    filterState.selectedCountry = region.id
                    if filterState.selectedFilter != "Popular Cards" && filterState.selectedFilter != "All Cards" {
                        filterState.selectedFilter = "Popular Cards"
                    }
                    filterState.updateFilterOptionsCache()
                    filterState.updateFilters(persistSelections: true)
                } label: {
                    if region.id == filterState.selectedCountry {
                        Label("\(region.flag) \(region.name)", systemImage: "checkmark")
                            .symbolRenderingMode(.monochrome)
                            .foregroundStyle(Color.churOlive)
                    } else {
                        Text("\(region.flag) \(region.name)")
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(RegionDatabase.byID[filterState.selectedCountry]?.flag ?? "🌍")
                    .font(.churBigTitle4())
                Image(systemName: "chevron.down")
                    .font(.churBadge())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.churLightGray.opacity(0.2))
            .foregroundStyle(Color.churDarkGray)
            .clipShape(Capsule())
        }
    }
}

// MARK: - Card Type Selector
struct CardTypeSelector: View {
    @Bindable var filterState: CardAddFilterState
    
    let availableCardTypes = ["All Types", "Personal", "Business"]
    
    var body: some View {
        Menu {
            ForEach(availableCardTypes, id: \.self) { cardType in
                Button {
                    filterState.selectedCardType = cardType
                    filterState.updateFilters(persistSelections: true)
                } label: {
                    if cardType == filterState.selectedCardType {
                        Label(cardType, systemImage: "checkmark")
                            .symbolRenderingMode(.monochrome)
                            .foregroundStyle(Color.churOlive)
                    } else {
                        Text(cardType)
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(filterState.selectedCardType)
                    .font(.churSubheadline())
                Image(systemName: "chevron.down")
                    .font(.churBadge())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.churLightGray.opacity(0.2))
            .foregroundStyle(Color.churDarkGray)
            .clipShape(Capsule())
        }
    }
}

// MARK: - Bank Filter Pill Row
struct BankFilterPillRow: View {
    @Bindable var filterState: CardAddFilterState
    
    /// Popular bank names only (excludes meta filters and "Other" issuers)
    private var popularBankNames: [String] {
        filterState.cachedPopularIssuers
    }
    
    /// Whether there are non-popular issuers available
    private var hasOtherIssuers: Bool {
        !filterState.cachedOtherIssuers.isEmpty
    }
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Popular Cards pill
                BankPill(
                    title: "Popular",
                    isSelected: filterState.selectedFilter == "Popular Cards"
                ) {
                    if filterState.selectedFilter == "Popular Cards" {
                        filterState.selectedFilter = "All Cards"
                    } else {
                        filterState.selectedFilter = "Popular Cards"
                    }
                    filterState.updateFilters(persistSelections: true)
                }
                
                // Individual popular bank pills
                ForEach(popularBankNames, id: \.self) { bank in
                    let issuer = IssuerDatabase.byName[bank]
                    BankPill(
                        title: issuer?.shortName ?? bank,
                        logoImageName: issuer?.logoImageName,
                        isSelected: filterState.selectedFilter == bank
                    ) {
                        if filterState.selectedFilter == bank {
                            filterState.selectedFilter = "All Cards"
                        } else {
                            filterState.selectedFilter = bank
                        }
                        filterState.updateFilters(persistSelections: true)
                    }
                }
                
                // "Other" pill for remaining issuers
                if hasOtherIssuers {
                    BankPill(
                        title: "Other",
                        isSelected: filterState.selectedFilter == "Other"
                    ) {
                        if filterState.selectedFilter == "Other" {
                            filterState.selectedFilter = "All Cards"
                        } else {
                            filterState.selectedFilter = "Other"
                        }
                        filterState.updateFilters(persistSelections: true)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
    }
}

// MARK: - Bank Pill
struct BankPill: View {
    let title: String
    var logoImageName: String? = nil
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let logoImageName, let _ = UIImage(named: logoImageName) {
                    Image(logoImageName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                        .clipShape(Circle())
                }
                Text(title)
                    .font(.churSubheadline())
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.churOlive : Color.churLightGray.opacity(0.2))
            .foregroundStyle(isSelected ? .white : Color.churDarkGray)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Filter Pills (Deprecated - keeping for reference)
struct CardFilterPills: View {
    @Bindable var filterState: CardAddFilterState
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterPill(title: "Popular Cards", filterState: filterState)
                FilterPill(title: "All Cards", filterState: filterState)
                
                if filterState.selectedFilter == "All Cards" ||
                   (filterState.selectedFilter != "Popular Cards" && filterState.selectedFilter != "All Cards") {
                    ForEach(Array(filterState.cachedFilterOptions.dropFirst(2)), id: \.self) { bank in
                        FilterPill(title: bank, filterState: filterState)
                    }
                }
            }
        }
    }
}

struct FilterPill: View {
    let title: String
    @Bindable var filterState: CardAddFilterState
    
    var body: some View {
        Button {
            filterState.selectedFilter = title
            filterState.updateFilters(persistSelections: true)
        } label: {
            Text(title)
                .font(.churSubheadline())
                .lineLimit(1)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(filterState.selectedFilter == title ? Color.churOlive : Color.churLightGray.opacity(0.2))
                .foregroundStyle(filterState.selectedFilter == title ? .white : Color.churDarkGray)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
