//
//  Search_Map_View.swift
//  Chur
//
//  Map + draggable bottom sheet view showing nearby places.
//  Map displays brand icons or emoji pins for each merchant; tapping a pin scrolls the sheet to that row.
//  Card matching is deferred to the detail popup opened on tap.
//
//  Created by Pak Ho on 3/1/26.
//

import SwiftUI
import SwiftData
import MapKit

// MARK: - Nearby Places List View

struct NearbyPlacesListView: View {
    
    // MARK: - SwiftData Queries
    @Query private var cards: [CreditCard]
    @Query private var categories: [SpendingCategory]
    @Query private var users: [User]
    
    private var boostEnrollments: [String: String] { users.first?.boostEnrollments ?? [:] }
    
    // MARK: - Location
    @StateObject private var locationManager = LocationManager()
    
    // MARK: - ViewModel
    @State private var vm: SearchMapViewModel
    
    @FocusState private var isSearchFocused: Bool
    
    var onModeChange: ((SearchMode) -> Void)? = nil
    
    // MARK: - Initializers
    
    init(initialMode: SearchMode = .online, onModeChange: ((SearchMode) -> Void)? = nil) {
        _vm = State(initialValue: SearchMapViewModel(initialMode: initialMode))
        self.onModeChange = onModeChange
    }
    
    init(initialMerchants: [NearbyMerchant], initialMode: SearchMode = .online, onModeChange: ((SearchMode) -> Void)? = nil) {
        _vm = State(initialValue: SearchMapViewModel(initialMerchants: initialMerchants, initialMode: initialMode))
        self.onModeChange = onModeChange
    }
    
    // MARK: - Convenience
    
    private var filteredMerchants: [NearbyMerchant] {
        vm.filteredMerchants(categories: categories)
    }
    
    private func triggerSearch() {
        vm.cancelAndSearch()
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 8) {
                Color.clear.frame(height: 140)
                
                // MARK: Top — Toggle + Search bar
                VStack(spacing: 0) {
                    HStack(spacing: 10) {
                        SearchModeToggle(selectedMode: $vm.searchMode)
                        
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color.churMediumGray)
                            
                            TextField(
                                vm.searchMode == .map ? "Search nearby..." : "Search online...",
                                text: $vm.searchText
                            )
                            .font(.churCaptionMedium())
                            .focused($isSearchFocused)
                            .autocorrectionDisabled()
                            .onSubmit {
                                if vm.searchMode == .map {
                                    vm.selectedFilter = .all
                                    triggerSearch()
                                }
                            }
                            .onChange(of: vm.searchText) { _, newValue in
                                if vm.searchMode == .map && !newValue.isEmpty {
                                    vm.selectedFilter = .all
                                }
                            }
                            
                            if !vm.searchText.isEmpty {
                                Button {
                                    vm.searchText = ""
                                    if vm.searchMode == .map {
                                        triggerSearch()
                                    }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.churFootnote())
                                        .foregroundStyle(Color.churMediumGray)
                                }
                            } else if vm.isSearching && vm.searchMode == .map {
                                ProgressView().scaleEffect(0.6)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.churTiles)
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    
                    // Subtle divider
                    Rectangle()
                        .fill(Color(.separator).opacity(0.3))
                        .frame(height: 0.5)
                }
                
                if vm.searchMode == .map {
                    mapContentView
                        .transition(.opacity)
                } else {
                    OnlineSearchView(searchText: $vm.searchText)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: vm.searchMode)
            .background(Color.churOffWhite)
            
            CurvedHeaderBackgroundView(waveStyle: .search)
            
            GeometryReader { geometry in
                VStack(alignment: .leading, spacing: 0) {
                    Text("Search")
                        .font(.churHero())
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                    Spacer()
                }
                .padding(.top, geometry.safeAreaInsets.top + 70)
                .padding(.horizontal, 10)
            }
            .frame(height: 160)
        }
        .edgesIgnoringSafeArea(.top)
        .onAppear {
            vm.setupInitialState(locationManager: locationManager)
            if vm.hasPerformedInitialSearch && !vm.wasPreloaded {
                triggerSearch()
            }
        }
        .onChange(of: locationManager.location) { _, newLocation in
            let wasReady = vm.hasPerformedInitialSearch
            vm.handleLocationUpdate(newLocation, locationManager: locationManager)
            // Only trigger search if handleLocationUpdate just set the flag for the first time
            if !wasReady && vm.hasPerformedInitialSearch {
                triggerSearch()
            }
        }
        .onChange(of: vm.selectedMerchantID) { _, _ in
            vm.zoomToSelection()
        }
        .onChange(of: vm.selectedFilter) { _, _ in
            triggerSearch()
        }
        .onChange(of: vm.searchMode) { _, newMode in
            onModeChange?(newMode)
        }
    }
    
    // MARK: - Map Content
    
    @ViewBuilder
    private var mapContentView: some View {
        ZStack(alignment: .top) {
            Map(position: $vm.mapPosition) {
                UserAnnotation()
                
                ForEach(filteredMerchants) { merchant in
                    let category = categories.first(where: { $0.id == merchant.categoryID })
                    
                    Annotation(
                        merchant.name,
                        coordinate: CLLocationCoordinate2D(
                            latitude: merchant.latitude,
                            longitude: merchant.longitude
                        )
                    ) {
                        NearbyMapPin(
                            category: category,
                            isSelected: vm.selectedMerchantID == merchant.id
                        )
                        .onTapGesture {
                            withAnimation {
                                vm.selectedMerchantID = merchant.id
                            }
                        }
                    }
                }
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .mapControls {
                MapUserLocationButton()
                MapCompass()
            }
            .onMapCameraChange(frequency: .onEnd) { context in
                vm.handleCameraChange(context)
            }
            
            searchThisAreaButton
        }
        .frame(height: 280)
        
        VStack(alignment: .leading, spacing: 0) {
            filterScrollHeader
            resultsList
        }
        .background(Color.churOffWhite)
    }
    
    // MARK: - Search This Area Button
    
    private var searchThisAreaButton: some View {
        let query = vm.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let buttonLabel = query.isEmpty ? "Search this area" : "Search \"\(query)\" here"
        
        return Button {
            triggerSearch()
        } label: {
            HStack(spacing: 6) {
                if vm.isSearching {
                    ProgressView().scaleEffect(0.7).tint(.white)
                } else {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13, weight: .bold))
                }
                Text(buttonLabel)
                    .font(.churCaption())
                    .lineLimit(1)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(Color.churOlive)
                    .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 3)
            )
        }
        .disabled(vm.isSearching)
        .padding(.top, 8)
    }
    
    // MARK: - Filter Header
    
    private var filterScrollHeader: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(NearbyFilter.allCases) { filter in
                    NearbyFilterChip(
                        filter: filter,
                        isSelected: vm.selectedFilter == filter
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            vm.selectedFilter = filter
                        }
                    }
                    .disabled(vm.hasTextQuery)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .opacity(vm.hasTextQuery ? 0.4 : 1.0)
        }
    }
    
    // MARK: - Results List
    
    private var resultsList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(filteredMerchants) { merchant in
                        NearbyPlaceRow(
                            merchant: merchant,
                            categories: categories,
                            cards: cards,
                            boostEnrollments: boostEnrollments,
                            isSelected: vm.selectedMerchantID == merchant.id
                        )
                        .id(merchant.id)
                        .onTapGesture {
                            vm.selectedMerchantID = merchant.id
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 26)
            }
            .onChange(of: vm.selectedMerchantID) { _, newID in
                if let newID {
                    withAnimation {
                        proxy.scrollTo(newID, anchor: .center)
                    }
                }
            }
        }
    }
}

