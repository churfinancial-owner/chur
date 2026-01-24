//
//  LocationManager.swift
//  Chur
//
//  Manages user location permissions and access to current location.
//  Provides observable properties for SwiftUI integration.
//
//  Created by Pak Ho on 2/28/26.
//

import Foundation
import CoreLocation
import Combine

/// Observable location manager that handles permissions and location updates
@MainActor
class LocationManager: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    
    /// Current user location (nil if not available)
    @Published var location: CLLocation?
    
    /// Authorization status for location services
    @Published var authorizationStatus: CLAuthorizationStatus
    
    /// Whether location services are currently loading
    @Published var isLoading: Bool = false
    
    /// Error message if location access fails
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    
    private let locationManager: CLLocationManager
    private var loadingTimeoutTask: Task<Void, Never>?
    
    // MARK: - Computed Properties
    
    /// Whether the app has location permission
    var hasPermission: Bool {
        switch authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            return true
        default:
            return false
        }
    }
    
    /// Whether we should show a permission request prompt
    var shouldRequestPermission: Bool {
        authorizationStatus == .notDetermined
    }
    
    // MARK: - Initialization
    
    override init() {
        locationManager = CLLocationManager()
        authorizationStatus = locationManager.authorizationStatus
        
        super.init()
        
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.distanceFilter = 100 // Update every 100 meters
        
        // Start monitoring if we already have permission
        if hasPermission {
            startUpdatingLocation()
        }
    }
    
    // MARK: - Public Methods
    
    /// Request location permission from the user
    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    /// Start updating location
    func startUpdatingLocation() {
        guard hasPermission else {
            errorMessage = "Location permission not granted"
            return
        }
        
        beginLoadingWithTimeout()
        errorMessage = nil
        locationManager.startUpdatingLocation()
    }
    
    /// Stop updating location to save battery
    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
        endLoading()
    }
    
    /// Request a one-time location update
    func requestLocation() {
        guard hasPermission else {
            errorMessage = "Location permission not granted"
            return
        }
        
        beginLoadingWithTimeout()
        errorMessage = nil
        locationManager.requestLocation()
    }

    private func beginLoadingWithTimeout(seconds: TimeInterval = 12) {
        isLoading = true
        loadingTimeoutTask?.cancel()
        loadingTimeoutTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self.isLoading = false
            if self.location == nil {
                self.errorMessage = "Unable to get location right now. Try refresh again."
            }
        }
    }

    private func endLoading() {
        loadingTimeoutTask?.cancel()
        loadingTimeoutTask = nil
        isLoading = false
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationManager: CLLocationManagerDelegate {
    
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            self.endLoading()
            guard let newLocation = locations.last else {
                self.errorMessage = "No location data received. Try refresh again."
                return
            }
            
            // Only update if location is recent (within 30 seconds)
            let age = abs(newLocation.timestamp.timeIntervalSinceNow)
            guard age < 30 else {
                self.errorMessage = "Location is stale. Try refresh again."
                return
            }
            
            // Only update if accuracy is reasonable
            guard newLocation.horizontalAccuracy >= 0 && newLocation.horizontalAccuracy <= 1000 else {
                self.errorMessage = "Location accuracy is low. Try refresh again."
                return
            }
            
            self.location = newLocation
            self.errorMessage = nil
            
            #if DEBUG
            print("📍 Location updated: \(newLocation.coordinate.latitude), \(newLocation.coordinate.longitude)")
            print("   Accuracy: \(newLocation.horizontalAccuracy)m")
            #endif
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.endLoading()
            
            // Handle specific location errors
            if let clError = error as? CLError {
                switch clError.code {
                case .denied:
                    self.errorMessage = "Location access denied. Enable in Settings."
                case .network:
                    self.errorMessage = "Network error. Check your connection."
                case .locationUnknown:
                    // This is often temporary, don't show error
                    #if DEBUG
                    print("⚠️ Location temporarily unknown")
                    #endif
                default:
                    self.errorMessage = "Unable to get location: \(clError.localizedDescription)"
                }
            } else {
                self.errorMessage = "Unable to get location: \(error.localizedDescription)"
            }
            
            #if DEBUG
            print("❌ Location error: \(error.localizedDescription)")
            #endif
        }
    }
    
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            let newStatus = manager.authorizationStatus
            self.authorizationStatus = newStatus
            
            #if DEBUG
            print("🔐 Authorization status changed: \(newStatus.debugDescription)")
            #endif
            
            // Start updating location if permission was just granted
            if self.hasPermission {
                self.startUpdatingLocation()
            } else if newStatus == .denied || newStatus == .restricted {
                self.endLoading()
                self.errorMessage = "Location access denied. Enable in Settings."
            }
        }
    }
}

// MARK: - CLAuthorizationStatus Extension

extension CLAuthorizationStatus {
    var debugDescription: String {
        switch self {
        case .notDetermined: return "Not Determined"
        case .restricted: return "Restricted"
        case .denied: return "Denied"
        case .authorizedAlways: return "Authorized Always"
        case .authorizedWhenInUse: return "Authorized When In Use"
        @unknown default: return "Unknown"
        }
    }
}
