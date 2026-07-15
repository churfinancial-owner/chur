//
//  Mapkit_NearbyPlacesService.swift
//  Chur
//
//  Service for searching nearby places using MapKit's local search.
//  Uses a parallelized bucket strategy to ensure diverse results across categories.
//  See Chur/MAP_SEARCH_REFERENCE.md for the bucket design and known gotchas.
//
//  Created by Pak Ho on 2/28/26.

import Foundation
import MapKit
import CoreLocation
import Contacts

struct NearbyPlacesService {

    // MARK: - Constants
    static let defaultRadius: CLLocationDistance = 8047 // ~5 miles
    static let maxMerchantsToProcess = 40 // Cap to keep the recommendation engine fast

    // MARK: - Search Buckets
    // Each bucket gets its own 10-result cap, so buckets should group POI categories
    // that don't crowd each other out (e.g. groceries live in retailBuckets, not diningBuckets).
    private static let diningBuckets: [MKPointOfInterestCategory] = [.restaurant, .cafe, .bakery]
    private static let nightlifeBuckets: [MKPointOfInterestCategory] = [.brewery, .winery, .distillery, .nightlife]
    private static let transportBuckets: [MKPointOfInterestCategory] = [.gasStation, .evCharger, .publicTransport, .parking, .carRental]
    private static let retailBuckets: [MKPointOfInterestCategory] = [.store, .pharmacy, .foodMarket]
    private static let travelBuckets: [MKPointOfInterestCategory] = [.hotel, .hospital, .postOffice, .university]
    private static let entertainmentBuckets: [MKPointOfInterestCategory] = [.theater, .movieTheater, .amusementPark, .museum, .fitnessCenter, .golf, .spa, .beauty, .stadium, .musicVenue]

    // MARK: - Public Search Methods

    /// Main entry point for searching nearby.
    /// Returns an AsyncStream to yield results bucket-by-bucket for faster UI rendering.
    func searchNearby(
        location: CLLocationCoordinate2D,
        radius: CLLocationDistance = defaultRadius,
        poiCategories: [MKPointOfInterestCategory]? = nil
    ) async throws -> AsyncStream<[NearbyMerchant]> {
        
        return AsyncStream { continuation in
            let task = Task {
                // Scenario A: Specific Filter active (e.g. "Gas" chip selected)
                if let specific = poiCategories, !specific.isEmpty {
                    do {
                        let merchants = try await performSearch(location: location, radius: radius, categories: specific, limit: Self.maxMerchantsToProcess)
                        continuation.yield(deduplicateAndSort(merchants: merchants))
                    } catch { }
                    continuation.finish()
                    return
                }

                // Scenario B: "All" Search (Parallel Bucket Strategy)
                let bucketGroups = [
                    Self.diningBuckets,
                    Self.nightlifeBuckets,
                    Self.transportBuckets,
                    Self.retailBuckets,
                    Self.travelBuckets,
                    Self.entertainmentBuckets
                ]

                var allMerchants: [NearbyMerchant] = []
                
                try? await withThrowingTaskGroup(of: [NearbyMerchant].self) { group in
                    for bucket in bucketGroups {
                        group.addTask {
                            // Capping each bucket at 10 to ensure diversity without overwhelming volume
                            try await performSearch(location: location, radius: radius, categories: bucket, limit: 10)
                        }
                    }

                    for try await bucketResults in group {
                        allMerchants.append(contentsOf: bucketResults)
                    }
                }
                // Yield once after all buckets complete — prevents incremental UI flicker
                let sortedUnique = deduplicateAndSort(merchants: allMerchants)
                continuation.yield(Array(sortedUnique.prefix(Self.maxMerchantsToProcess)))
                continuation.finish()
            }
            
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    /// Natural Language Fallback
    func searchSimple(
        location: CLLocationCoordinate2D,
        query: String = "nearby",
        radius: CLLocationDistance = defaultRadius
    ) async throws -> [NearbyMerchant] {
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = MKCoordinateRegion(center: location, latitudinalMeters: radius, longitudinalMeters: radius)
        
        let response = try await runSearch(request)
        let merchants = response.mapItems.compactMap { convertToMerchant(mapItem: $0, userLocation: location) }
        return Array(merchants.prefix(Self.maxMerchantsToProcess))
    }

    // MARK: - Private Core Logic

    /// Runs an `MKLocalSearch` request, retrying once after a brief delay if Apple's
    /// undocumented rate limit kicks in (`MKError.loadingThrottled`), so a burst of
    /// searches (e.g. driving, or bouncing between screens) surfaces as a short delay
    /// instead of a hard "search failed" error.
    private func runSearch(_ request: MKLocalSearch.Request) async throws -> MKLocalSearch.Response {
        do {
            return try await MKLocalSearch(request: request).start()
        } catch let error as MKError where error.code == .loadingThrottled {
            try await Task.sleep(nanoseconds: 2_000_000_000)
            return try await MKLocalSearch(request: request).start()
        }
    }

    private func performSearch(
        location: CLLocationCoordinate2D,
        radius: CLLocationDistance,
        categories: [MKPointOfInterestCategory],
        limit: Int = 20
    ) async throws -> [NearbyMerchant] {
        
        let request = MKLocalSearch.Request()
        request.region = MKCoordinateRegion(center: location, latitudinalMeters: radius, longitudinalMeters: radius)
        
        if #available(iOS 18.0, *) {
            request.regionPriority = .required
        }
        
        request.pointOfInterestFilter = MKPointOfInterestFilter(including: categories)
        request.resultTypes = .pointOfInterest
        request.naturalLanguageQuery = nil
        
        let response = try await runSearch(request)

        // MKLocalSearch results are relevance-ordered, not distance-ordered — sort
        // before truncating or the true closest results in this bucket can get cut.
        let merchants = response.mapItems
            .compactMap { convertToMerchant(mapItem: $0, userLocation: location) }
            .sorted { $0.distance < $1.distance }
        return Array(merchants.prefix(limit))
    }
    
    private func deduplicateAndSort(merchants: [NearbyMerchant]) -> [NearbyMerchant] {
        var unique: [String: NearbyMerchant] = [:]
        for m in merchants {
            let key = "\(m.name.lowercased())-\(String(format: "%.4f", m.latitude))-\(String(format: "%.4f", m.longitude))"
            if unique[key] == nil { unique[key] = m }
        }
        return unique.values.sorted { $0.distance < $1.distance }
    }
    
    private func convertToMerchant(mapItem: MKMapItem, userLocation: CLLocationCoordinate2D) -> NearbyMerchant? {
        guard let name = mapItem.name, let itemLoc = mapItem.placemark.location else { return nil }
        
        let distance = calculateDistance(from: userLocation, to: itemLoc.coordinate)
        let categoryID = MerchantCategoryMapper.mapToCategory(
            merchantName: name,
            poiCategory: mapItem.pointOfInterestCategory?.rawValue
        )
        
        return NearbyMerchant(
            id: mapItem.identifier?.rawValue ?? "m-\(name)-\(itemLoc.coordinate.latitude)",
            name: name,
            categoryID: categoryID,
            latitude: itemLoc.coordinate.latitude,
            longitude: itemLoc.coordinate.longitude,
            distance: distance,
            address: formatAddress(mapItem.placemark),
            region: mapItem.placemark.isoCountryCode,
            poiCategory: mapItem.pointOfInterestCategory?.rawValue,
            paymentMethods: nil
        )
    }

    private func calculateDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let fromLoc = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLoc = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return fromLoc.distance(from: toLoc) / 1609.34
    }
    
    private func formatAddress(_ placemark: CLPlacemark) -> String {
        guard let postalAddress = placemark.postalAddress else {
            return [placemark.subThoroughfare, placemark.thoroughfare, placemark.locality]
                .compactMap { $0 }
                .joined(separator: " ")
        }
        return CNPostalAddressFormatter().string(from: postalAddress).replacingOccurrences(of: "\n", with: ", ")
    }
}
