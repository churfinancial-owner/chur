
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
    var onOpenSearch: (() -> Void)? = nil
    var onLocationResolved: ((String?, String?) -> Void)? = nil
    
    @Query private var users: [User]
    @StateObject private var locationManager = LocationManager()
    @State private var nearbyMerchants: [NearbyMerchant] = []
    @State private var isSearching: Bool = false
    @State private var isRefreshing: Bool = false
    @State private var searchError: String?
    @State private var locationLabel: String?
    
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
            if !cards.isEmpty && locationManager.hasPermission && nearbyMerchants.isEmpty {
                await searchNearbyPlaces()
            }
        }
        .onChange(of: locationManager.location) { _, newLocation in
            if !cards.isEmpty, let newLocation {
                Task {
                    await resolveLocationContext(for: newLocation)
                    await searchNearbyPlaces()
                }
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
        Button { onOpenSearch?() } label: {
            ZStack {
                Circle()
                    .fill(Color.churOliveLight)
                    .frame(width: 32, height: 32)
                Image(systemName: "signpost.right.and.left")
                    .font(.churImageMedium())
                    .foregroundStyle(.churDarkOlive)
            }
        }
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
        
        isSearching = true
        searchError = nil
        
        do {
            let stream = try await placesService.searchNearby(
                location: location.coordinate,
                radius: NearbyPlacesService.defaultRadius
            )
            
            for await merchants in stream {
                await MainActor.run {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        self.nearbyMerchants = merchants
                    }
                }
            }
            
            if nearbyMerchants.isEmpty {
                let fallback = try await placesService.searchSimple(
                    location: location.coordinate,
                    query: "restaurants stores shops"
                )
                await MainActor.run { self.nearbyMerchants = fallback }
            }
            isSearching = false
        } catch {
            await MainActor.run {
                self.searchError = error.localizedDescription
                self.isSearching = false
            }
        }
    }

    private func refreshNearbyPlaces() async {
        guard !isRefreshing else { return }
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
