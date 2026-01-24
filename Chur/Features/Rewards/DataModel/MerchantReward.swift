//
//  MerchantReward.swift
//  Chur
//
//  Created by Pak Ho on 1/17/26.
//


import Foundation
import SwiftData

// MARK: - Merchant Reward Model
@Model
class MerchantReward {
    var merchantName: String          // "Amazon", "Target", "Whole Foods"
    var rate: Double                  // 5.0 for 5%
    var pointType: String             // "Cash", "UR", "MR"
    var isTemporary: Bool             // For limited-time offers
    var startDate: Date?              // When offer started
    var endDate: Date?                // When offer ends
    var notes: String?                // "Amex Offer: Spend $50, get $10 back"
    var merchantCategory: String?     // "Online Retailer", "Grocery", etc.
    
    init(merchantName: String, rate: Double, pointType: String, isTemporary: Bool = false, 
         startDate: Date? = nil, endDate: Date? = nil, notes: String? = nil, merchantCategory: String? = nil) {
        self.merchantName = merchantName
        self.rate = rate
        self.pointType = pointType
        self.isTemporary = isTemporary
        self.startDate = startDate
        self.endDate = endDate
        self.notes = notes
        self.merchantCategory = merchantCategory
    }
}

