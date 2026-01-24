//
//  Benefit_Validations.swift
//  Chur
//
//  Created by Pak Ho on 3/13/26.
//
/// Checks if the benefit is eligible for a specific card, considering card-relative constraints.
/// This extends `isCurrentlyActive` by also checking `activationDelayPeriods`.
///
/// - Parameters:
///   - approvedMonth: The month (1-12) when the card was approved
///   - approvedYear: The year when the card was approved (required)
/// - Returns: `true` if the benefit is currently active AND the activation delay has passed
///
import Foundation

extension Benefit {
    
    func isActiveForCard(approvedMonth: Int, approvedYear: Int) -> Bool {
        // First check standard active constraints
        guard isCurrentlyActive else { return false }
        
        // If no activation delay, benefit is eligible
        guard let delayPeriods = activationDelayPeriods, delayPeriods > 0 else {
            return true
        }
        
        // Only check delay for recurring benefits (non-recurring benefits ignore this field)
        guard isRecurring else { return true }
        
        // Calculate which period we're currently in
        let currentPeriod = calculateCurrentPeriod(approvedMonth: approvedMonth, approvedYear: approvedYear)
        
        // Benefit is available starting period (delayPeriods + 1)
        // Example: delayPeriods = 1 means available starting period 2
        return currentPeriod > delayPeriods
    }
    
    /// Calculates which period number we're currently in based on card approval and benefit frequency.
    /// Period 1 = first period after card approval, Period 2 = second period, etc.
    ///
    /// - Parameters:
    ///   - approvedMonth: The month (1-12) when the card was approved
    ///   - approvedYear: The year when the card was approved (required)
    /// - Returns: The current period number (1, 2, 3, ...)
    private func calculateCurrentPeriod(approvedMonth: Int, approvedYear: Int) -> Int {
        let calendar = Calendar.current
        let now = Date.current()
        let currentMonth = calendar.component(.month, from: now)
        let currentYear = calendar.component(.year, from: now)
        
        // Calculate based on frequency
        switch BenefitFrequency(rawValue: frequency) {
        case .annual:
            // How many complete years have passed since approval?
            let yearsSinceApproval = currentYear - approvedYear
            // Are we past the anniversary month this year?
            let pastAnniversaryThisYear = currentMonth >= approvedMonth
            return pastAnniversaryThisYear ? yearsSinceApproval + 1 : yearsSinceApproval
            
        case .monthly:
            // Calculate total months since approval
            let monthsSinceApproval = (currentYear - approvedYear) * 12 + (currentMonth - approvedMonth)
            return max(1, monthsSinceApproval + 1)
            
        case .quarterly:
            // Calculate which quarter the approval month is in
            let approvalQuarter = (approvedMonth - 1) / 3 + 1
            let currentQuarter = (currentMonth - 1) / 3 + 1
            let yearDiff = currentYear - approvedYear
            let quartersSinceApproval = yearDiff * 4 + (currentQuarter - approvalQuarter)
            return max(1, quartersSinceApproval + 1)
            
        case .semiAnnual:
            // Two periods per year
            let approvalHalf = approvedMonth <= 6 ? 1 : 2
            let currentHalf = currentMonth <= 6 ? 1 : 2
            let yearDiff = currentYear - approvedYear
            let halfYearsSinceApproval = yearDiff * 2 + (currentHalf - approvalHalf)
            return max(1, halfYearsSinceApproval + 1)
            
        case .quadrennial:
            // One period every 4 years
            let totalMonthsSinceApproval = (currentYear - approvedYear) * 12 + (currentMonth - approvedMonth)
            let quadrennialPeriods = totalMonthsSinceApproval / 48
            return max(1, quadrennialPeriods + 1)
            
        default:
            // For one-time and ongoing benefits, always return period 1
            return 1
        }
    }
    
    /// Returns the estimated date when this benefit will become available for a specific card.
    /// Returns `nil` if already available or if the benefit has no activation delay.
    ///
    /// - Parameters:
    ///   - approvedMonth: The month (1-12) when the card was approved
    ///   - approvedYear: The year when the card was approved (required)
    /// - Returns: The estimated activation date, or nil if already available
    func estimatedActivationDate(approvedMonth: Int, approvedYear: Int) -> Date? {
        // If already active, return nil
        guard !isActiveForCard(approvedMonth: approvedMonth, approvedYear: approvedYear) else {
            return nil
        }
        
        // If no delay, return nil
        guard let delayPeriods = activationDelayPeriods, delayPeriods > 0, isRecurring else {
            return nil
        }
        
        let calendar = Calendar.current
        
        // Calculate activation date based on frequency
        switch BenefitFrequency(rawValue: frequency) {
        case .annual:
            // Add delay years to approval year
            let activationYear = approvedYear + delayPeriods
            var components = DateComponents()
            components.year = activationYear
            components.month = approvedMonth
            components.day = 1
            return calendar.date(from: components)
            
        case .monthly:
            // Add delay months to approval month
            var components = DateComponents()
            components.year = approvedYear
            components.month = approvedMonth + delayPeriods
            components.day = 1
            return calendar.date(from: components)
            
        case .quarterly:
            // Add delay quarters (3 months each)
            var components = DateComponents()
            components.year = approvedYear
            components.month = approvedMonth + (delayPeriods * 3)
            components.day = 1
            return calendar.date(from: components)
            
        case .semiAnnual:
            // Add delay half-years (6 months each)
            var components = DateComponents()
            components.year = approvedYear
            components.month = approvedMonth + (delayPeriods * 6)
            components.day = 1
            return calendar.date(from: components)
            
        case .quadrennial:
            // Add delay quadrennials (48 months each)
            var components = DateComponents()
            components.year = approvedYear
            components.month = approvedMonth + (delayPeriods * 48)
            components.day = 1
            return calendar.date(from: components)
            
        default:
            return nil
        }
    }
    
    // MARK: - Visibility Control
    
    /// Checks if the benefit should be visible based on `isActive` and date range constraints.
    /// Returns `true` only if:
    /// 1. `isActive` is `true` (master toggle)
    /// 2. Current date is on or after `activeFromDate` (if set)
    /// 3. Current date is before or on `activeToDate` (if set)
    ///
    /// Use this computed property in your filtering logic to automatically hide benefits
    /// that are outside their active date range.
    var isCurrentlyActive: Bool {
        // Master toggle check
        guard isActive else { return false }
        
        let now = Date.current()
        
        // Check start date constraint
        if let fromDate = activeFromDate, now < fromDate {
            return false
        }
        
        // Check end date constraint
        if let toDate = activeToDate, now > toDate {
            return false
        }
        
        return true
    }

    // MARK: - Geographic Restrictions
    
    /// Helper to check if benefit is valid in a country
    func isValidInCountry(_ countryCode: String) -> Bool {
        // If validCountries is nil, benefit is worldwide
        if let valid = validCountries {
            if !valid.contains(countryCode) { return false }
        }
        
        // Check exclusions
        if let excluded = excludedCountries {
            if excluded.contains(countryCode) { return false }
        }
        
        return true
    }
    
}
