//
//  Search_Map_ViewModel.swift
//  Chur
//
//  Manages search state, location tracking, and map camera coordination
//  for the nearby places search feature.
//

import SwiftUI
import MapKit

@MainActor
@Observable
final class SearchMapViewModel {
    
    // MARK: - Search State
    
    var merchants: [NearbyMerchant] = []
    var isSearching = false
    var hasPerformedInitialSearch = false
    
    // MARK: - Map State
    
    var mapPosition: MapCameraPosition = .automatic
    var selectedMerchantID: String?
    
    // MARK: - Filter & Search Text
    
    var selectedFilter: NearbyFilter = .all
    var searchText = ""
    var searchMode: SearchMode = .online
    
    // MARK: - Private
    
    private var lastSearchedCenter: CLLocationCoordinate2D?
    private var pendingSearchCenter: CLLocationCoordinate2D?
    private var pendingSearchRadius: CLLocationDistance = 1000
    private let placesService = NearbyPlacesService()
    private var currentSearchTask: Task<Void, Never>?
    
    // MARK: - Initial Merchants
    
    private let initialMerchants: [NearbyMerchant]
    var wasPreloaded: Bool { !initialMerchants.isEmpty }
    
    init(initialMerchants: [NearbyMerchant] = [], initialMode: SearchMode = .online) {
        self.initialMerchants = initialMerchants
        self.searchMode = initialMode
    }
    
    // MARK: - Filtered Results
    
    func filteredMerchants(categories: [SpendingCategory]) -> [NearbyMerchant] {
        merchants.filter { selectedFilter.matches($0, categories: categories) }
    }
    
    var hasTextQuery: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    // MARK: - Setup & Location Handling
    
    func setupInitialState(locationManager: LocationManager) {
        if !initialMerchants.isEmpty {
            merchants = initialMerchants
            if let region = initialRegion { mapPosition = .region(region) }
            if let first = initialMerchants.first {
                let center = CLLocationCoordinate2D(latitude: first.latitude, longitude: first.longitude)
                lastSearchedCenter = center
                pendingSearchCenter = center
            }
            hasPerformedInitialSearch = true
        } else if locationManager.hasPermission, let location = locationManager.location {
            let center = location.coordinate
            pendingSearchCenter = center
            pendingSearchRadius = NearbyPlacesService.defaultRadius
            mapPosition = .region(MKCoordinateRegion(center: center, latitudinalMeters: 2000, longitudinalMeters: 2000))
            hasPerformedInitialSearch = true
        }
    }
    
    /// Called when LocationManager publishes a new location.
    /// Only acts once — for the initial search when location wasn't available at setup time.
    func handleLocationUpdate(
        _ location: CLLocation?,
        locationManager: LocationManager
    ) {
        guard !hasPerformedInitialSearch, initialMerchants.isEmpty, let location else { return }
        let center = location.coordinate
        pendingSearchCenter = center
        pendingSearchRadius = NearbyPlacesService.defaultRadius
        mapPosition = .region(MKCoordinateRegion(center: center, latitudinalMeters: 2000, longitudinalMeters: 2000))
        hasPerformedInitialSearch = true
    }
    
    // MARK: - Map Camera
    
    func handleCameraChange(_ context: MapCameraUpdateContext) {
        let newCenter = context.camera.centerCoordinate
        let radiusMeters = context.region.span.latitudeDelta * 111_320 / 2
        pendingSearchCenter = newCenter
        pendingSearchRadius = min(max(radiusMeters, 500), 20000)
    }
    
    func zoomToSelection() {
        if let id = selectedMerchantID,
           let merchant = merchants.first(where: { $0.id == id }) {
            withAnimation {
                mapPosition = .region(MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: merchant.latitude, longitude: merchant.longitude),
                    span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                ))
            }
        }
    }
    
    // MARK: - Search
    
    /// Cancels any in-flight search and starts a new one.
    func cancelAndSearch() {
        currentSearchTask?.cancel()
        currentSearchTask = Task {
            // Wait 0.8 seconds before starting the actual search
            try? await Task.sleep(nanoseconds: 800_000_000)
            guard !Task.isCancelled else { return }
            
            await searchCurrentArea()
        }
    }
    
    private func searchCurrentArea() async {
        guard let center = pendingSearchCenter else { return }
        isSearching = true
        
        defer { isSearching = false }
        
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        do {
            if !query.isEmpty {
                let results = try await placesService.searchSimple(
                    location: center,
                    query: query,
                    radius: pendingSearchRadius
                )
                guard !Task.isCancelled else { return }
                let sorted = results.sorted { $0.distance < $1.distance }
                withAnimation(.spring()) { merchants = sorted }
            } else {
                let stream = try await placesService.searchNearby(
                    location: center,
                    radius: pendingSearchRadius,
                    poiCategories: selectedFilter.poiCategories
                )
                for await results in stream {
                    guard !Task.isCancelled else { return }
                    let sorted = results.sorted { $0.distance < $1.distance }
                    withAnimation(.spring()) { merchants = sorted }
                }
            }
            guard !Task.isCancelled else { return }
            lastSearchedCenter = center
        }
        // In Search_Map_ViewModel.swift
        catch {
            if !Task.isCancelled {
                print("❌ Search Error: \(error)")
                self.isSearching = false // Ensure this is reset immediately on failure
                // self.errorMessage = error.localizedDescription // Trigger the ErrorView
            }
        }
        
        // Only clear isSearching if this task wasn't cancelled
        // (a cancelled task means a newer search took over)
        if !Task.isCancelled {
            isSearching = false
        }
    }
    
    // MARK: - Private Helpers
    
    private var initialRegion: MKCoordinateRegion? {
        guard !merchants.isEmpty else { return nil }
        let lats = merchants.map { $0.latitude }
        let lons = merchants.map { $0.longitude }
        guard let minLat = lats.min(), let maxLat = lats.max(),
              let minLon = lons.min(), let maxLon = lons.max() else { return nil }
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.4, 0.005),
            longitudeDelta: max((maxLon - minLon) * 1.4, 0.005)
        )
        return MKCoordinateRegion(center: center, span: span)
    }
}
