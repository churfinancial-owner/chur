//
//  Cards_Add_Card_ViewModel.swift
//  Chur
//
// • @​Observable class managing all filter state
// • Handles filtering logic
// • Persists filter preferences to UserDefaults
// • Contains bank issuer data per country
//
//  Created by Pak Ho on 1/22/26.
//

import SwiftUI

@Observable
class CardAddFilterState {
    var searchText = ""
    var selectedCountry: String
    var selectedCardType: String
    var selectedFilter: String
    
    var allTemplates: [CardTemplate] = [] {
        didSet {
            rebuildTemplateIndexes()
        }
    }
    var filteredTemplates: [CardTemplate] = []
    var cachedFilterOptions: [String] = ["Popular Cards", "All Cards"]
    var cachedPopularIssuers: [String] = []
    var cachedOtherIssuers: Set<String> = []

    private var templatesByCountry: [String: [CardTemplate]] = [:]
    private var templatesByCountryAndType: [String: [CardTemplate]] = [:]
    
    // Issuer metadata (loaded from SeedDataIssuers.json)
    private let issuersByName: [String: Issuer] = IssuerDatabase.byName
    
    init(userCountry: String = "US") {
        // Load from UserDefaults
        self.selectedCountry = UserDefaults.standard.string(forKey: "addCard_selectedCountry") ?? userCountry
        self.selectedCardType = UserDefaults.standard.string(forKey: "addCard_selectedCardType") ?? "All Types"
        self.selectedFilter = UserDefaults.standard.string(forKey: "addCard_selectedFilter") ?? "All Cards"
    }

    private func rebuildTemplateIndexes() {
        templatesByCountry.removeAll(keepingCapacity: true)
        templatesByCountryAndType.removeAll(keepingCapacity: true)

        for template in allTemplates {
            templatesByCountry[template.country, default: []].append(template)
            let countryTypeKey = "\(template.country)|\(template.cardType.lowercased())"
            templatesByCountryAndType[countryTypeKey, default: []].append(template)
        }

        // Pre-sort each bucket so updateFilters() can skip sorting for most cases
        let issuerNameOrder: (CardTemplate, CardTemplate) -> Bool = { a, b in
            if a.issuer != b.issuer { return a.issuer < b.issuer }
            return a.name < b.name
        }
        for key in templatesByCountry.keys {
            templatesByCountry[key]?.sort(by: issuerNameOrder)
        }
        for key in templatesByCountryAndType.keys {
            templatesByCountryAndType[key]?.sort(by: issuerNameOrder)
        }
    }
    
    func updateFilterOptionsCache() {
        let allAvailable = Set((templatesByCountry[selectedCountry] ?? []).map(\.issuer))
        
        // Popular issuers from JSON, sorted by sortOrder, filtered to those with cards
        let popular = IssuerDatabase.popularIssuers(for: selectedCountry)
        let popularNames = Set(popular.map(\.name))
        
        cachedPopularIssuers = popular.map(\.name).filter { allAvailable.contains($0) }
        // Non-popular issuers grouped under "Other"
        cachedOtherIssuers = allAvailable.subtracting(popularNames)
        
        cachedFilterOptions = ["Popular Cards", "All Cards"] + cachedPopularIssuers + (cachedOtherIssuers.isEmpty ? [] : ["Other"])
    }
    
    func updateFilters(persistSelections: Bool = false) {
        let baseResults: [CardTemplate]
        if selectedCardType == "All Types" {
            baseResults = templatesByCountry[selectedCountry] ?? []
        } else {
            let countryTypeKey = "\(selectedCountry)|\(selectedCardType.lowercased())"
            baseResults = templatesByCountryAndType[countryTypeKey] ?? []
        }

        var results = baseResults
        
        // 3. Apply selected filter
        if selectedFilter == "Popular Cards" {
            results = results.filter { $0.isPopular }
        } else if selectedFilter == "Other" {
            results = results.filter { cachedOtherIssuers.contains($0.issuer) }
        } else if selectedFilter != "All Cards" {
            results = results.filter { $0.issuer == selectedFilter }
        }
        
        // 4. Filter by search text
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            results = results.filter { template in
                template.name.lowercased().contains(query) ||
                template.issuer.lowercased().contains(query)
            }
        }
        
        // 5. Sort — only needed for "Popular Cards" which has a custom order.
        //    Other filters use the pre-sorted index order (issuer → name).
        if selectedFilter == "Popular Cards" {
            results.sort { a, b in
                if a.popularSortOrder != b.popularSortOrder {
                    return a.popularSortOrder < b.popularSortOrder
                }
                if a.issuer != b.issuer { return a.issuer < b.issuer }
                return a.name < b.name
            }
        }
        
        filteredTemplates = results
        
        // Reset filter if not available
        if selectedFilter != "Popular Cards" && selectedFilter != "All Cards" {
            if !cachedFilterOptions.contains(selectedFilter) {
                selectedFilter = "All Cards"
            }
        }
        
        if persistSelections {
            saveSelectionsToDefaults()
        }
    }
    
    func handleSearchChange(oldValue: String, newValue: String) {
        if !newValue.isEmpty {
            // Only widen the bank filter — keep country and card type as the user set them.
            // "Popular Cards" is too narrow for search, so switch to "All Cards".
            if selectedFilter == "Popular Cards" {
                selectedFilter = "All Cards"
            }
        }
        
        if newValue.isEmpty && !oldValue.isEmpty {
            // When user clears search, restore default view
            selectedFilter = "All Cards"
        }
        
        updateFilters()
    }

    func saveSelectionsToDefaults() {
        UserDefaults.standard.set(selectedCountry, forKey: "addCard_selectedCountry")
        UserDefaults.standard.set(selectedCardType, forKey: "addCard_selectedCardType")
        UserDefaults.standard.set(selectedFilter, forKey: "addCard_selectedFilter")
    }
}
