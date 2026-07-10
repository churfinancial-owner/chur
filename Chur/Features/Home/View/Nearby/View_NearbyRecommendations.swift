
//
//  View_NearbyRecommendations.swift
//  Chur
//
//  Created by Pak Ho on 4/8/26.
//

import SwiftUI
import SwiftData
import CoreLocation
import MapKit

struct NearbyRecommendationsSection: View {
    let cards: [CreditCard]
    let categories: [SpendingCategory]
    let boostEnrollments: [String: String]
    var initialMerchants: [NearbyMerchant] = []
    var onOpenSearch: (() -> Void)? = nil
    var onLocationResolved: ((String?, String?) -> Void)? = nil
    
    @Query private var users: [User]
    @StateObject private var locationManager = LocationManager()
    @State private var nearbyMerchants: [NearbyMerchant] = []
    @State private var isSearching: Bool = false
    @State private var isRefreshing: Bool = false
    @State private var searchError: String?
    @State private var locationLabel: String?
    @State private var currentSearchTask: Task<Void, Never>?
    
    private let placesService = NearbyPlacesService()
    
    private var recommendations: [NearbyRecommendation] {
        let engine = NearbyRecommendationEngine(
            cards: cards,
            allCategories: categories,
            boostEnrollments: boostEnrollments
        )
        
        return engine.recommendAll(for: nearbyMerchants)
            .sorted { $0.merchant.distance < $1.merchant.distance }
            .prefix(10)
            .map { $0 }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            headerView
            
            if cards.isEmpty {
                NearbyWalletEmptyState()
            } else if locationManager.shouldRequestPermission {
                LocationPermissionPrompt { locationManager.requestPermission() }
            } else if !locationManager.hasPermission {
                LocationPermissionDenied(errorMessage: locationManager.errorMessage)
            } else if let error = searchError {
                LocationErrorView(errorMessage: error) {
                    Task { await searchNearbyPlaces() }
                }
            } else if recommendations.isEmpty && !isSearching {
                LocationEmptyState()
            } else {
                horizontalScrollView
            }
        }
        .task {
            // If the search tab already has results, use those instead of running a fresh search
            if !initialMerchants.isEmpty && nearbyMerchants.isEmpty {
                nearbyMerchants = initialMerchants
                return
            }
            if !cards.isEmpty && locationManager.hasPermission && nearbyMerchants.isEmpty {
                currentSearchTask?.cancel()
                currentSearchTask = Task { await searchNearbyPlaces() }
            }
        }
        .onChange(of: locationManager.location) { _, newLocation in
            guard !cards.isEmpty, let newLocation else { return }
            // Reject low-accuracy or stale fixes (negative accuracy = invalid)
            guard newLocation.horizontalAccuracy > 0, newLocation.horizontalAccuracy < 100 else { return }
            currentSearchTask?.cancel()
            currentSearchTask = Task {
                await resolveLocationContext(for: newLocation)
                await searchNearbyPlaces()
            }
        }

    }
    
    // MARK: - Subviews
    
    private var headerView: some View {
        HStack {
            Text("📍 NEARBY")
                .font(.churHeadline())
                .foregroundStyle(Color.churOlive)
                .tracking(0.5)
            
            if let locationLabel {
                Text(locationLabel)
                    .font(.churFootnoteMedium())
                    .foregroundStyle(Color.churMediumGray)
            }
            
            if !cards.isEmpty && locationManager.hasPermission {
                refreshButton
            }

            Spacer()
            
            if !cards.isEmpty && !recommendations.isEmpty {
                listPopupButton
            }
        }
    }
    
    private var refreshButton: some View {
        Button {
            Task { await refreshNearbyPlaces() }
        } label: {
            if isRefreshing {
                ProgressView()
            } else {
                Image(systemName: "arrow.trianglehead.2.clockwise")
                    .font(.churFootnote())
                    .foregroundStyle(Color.churMediumGray)
            }
        }
        .disabled(isRefreshing)
    }
    
    private var listPopupButton: some View {
        OliveIconButton(icon: "signpost.right.and.left") { onOpenSearch?() }
    }
    
    private var horizontalScrollView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(recommendations) { recommendation in
                    RecommendationCard(recommendation: recommendation)
                }
            }
            .padding(.vertical, 10)
        }
    }
    
    // MARK: - Core Logic (Private)
    
    private func searchNearbyPlaces() async {
        guard let location = locationManager.location else {
            locationManager.requestLocation()
            return
        }

        // Reject low-accuracy or invalid fixes before kicking off a MapKit search
        guard location.horizontalAccuracy > 0, location.horizontalAccuracy < 100 else {
            locationManager.requestLocation()
            return
        }

        isSearching = true
        searchError = nil

        do {
            let stream = try await placesService.searchNearby(
                location: location.coordinate,
                radius: NearbyPlacesService.defaultRadius
            )

            for await merchants in stream {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        self.nearbyMerchants = merchants
                    }
                }
            }

            guard !Task.isCancelled else { return }

            if nearbyMerchants.isEmpty {
                let fallback = try await placesService.searchSimple(
                    location: location.coordinate,
                    query: "restaurants stores shops"
                )
                guard !Task.isCancelled else { return }
                await MainActor.run { self.nearbyMerchants = fallback }
            }
            isSearching = false
        } catch {
            if !Task.isCancelled {
                await MainActor.run {
                    self.searchError = error.localizedDescription
                    self.isSearching = false
                }
            }
        }
    }

    private func refreshNearbyPlaces() async {
        guard !isRefreshing else { return }
        currentSearchTask?.cancel()
        isRefreshing = true
        nearbyMerchants = []
        searchError = nil
        locationManager.requestLocation()
        await searchNearbyPlaces()
        isRefreshing = false
    }

    private func resolveLocationContext(for location: CLLocation) async {
        do {
            let placemarks = try await CLGeocoder().reverseGeocodeLocation(location)
            guard let placemark = placemarks.first else { return }
            
            let locality = placemark.locality
            let admin = placemark.administrativeArea
            let country = placemark.isoCountryCode?.uppercased()
            
            let resolvedLabel = (locality != nil && admin != nil) ? "\(locality!), \(admin!)" : locality
            
            await MainActor.run {
                self.locationLabel = resolvedLabel
                onLocationResolved?(resolvedLabel, country)
            }
        } catch {
            print("⚠️ Reverse geocode failed: \(error)")
        }
    }
}
