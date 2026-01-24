//
//  RewardRelevantPOICategories.swift
//  Chur
//
//  Defines the MapKit Point of Interest categories that are relevant for credit card rewards.
//  This list filters which types of places are requested from MapKit when searching nearby.
//
//  Note: These categories are mapped to internal category IDs in MerchantCategoryMapper.
//  When adding new categories here, make sure to update MerchantCategoryMapper.mapPOICategory() accordingly.
//
//  Created by Pak Ho on 3/1/26.
//

import MapKit

// MARK: - Reward-Relevant POI Categories

extension NearbyPlacesService {
    
    /// Commonly used POI categories for credit card rewards
    /// Note: These categories are mapped to internal category IDs in MerchantCategoryMapper
    static let rewardRelevantCategories: [MKPointOfInterestCategory] = [
        // Dining & Food
        .restaurant,
        .cafe,
        .bakery,
        .brewery,
        .winery,
        .nightlife,     // Bars, pubs, clubs
        .distillery,    // Distilleries
        .foodMarket,    // Grocery stores, supermarkets
        
        // Gas & Transportation
        .gasStation,
        .evCharger,
        .publicTransport,
        .parking,
        .carRental,
        
        // Retail & Shopping
        .pharmacy,
        
        // Travel & Lodging
        .hotel,
        
        // Entertainment & Recreation
        .theater,
        .movieTheater,
        .amusementPark,
        .museum,
        .aquarium,
        .zoo,
        .nationalPark,
        .stadium,
        .campground,
        .musicVenue,    // Concerts, live music
        .marina,        // Marina fees, boat rentals
        
        // Fitness & Health
        .fitnessCenter,
        .golf,
        .miniGolf,
        .bowling,
        .skiing,
        
        // Services
        .laundry,
        .hospital,
        .spa,
        .beauty,
        .animalService,
        .postOffice,
        
        // Automotive
        .automotiveRepair,
        
        // Education
        .university,     // Tuition payments, bookstore purchases
        
        // Stores
        .store
    ]
}
