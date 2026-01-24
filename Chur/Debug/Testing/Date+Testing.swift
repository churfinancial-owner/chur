//
//  Date+Testing.swift
//  Chur
//
//  Created by Pak Ho on 2/3/26.
//
//  Extension to support time travel for testing time-dependent features.

import Foundation

extension Date {
    /// Returns the current date, or a mocked date if set in DEBUG mode.
    /// Use this instead of `Date()` throughout the app to enable time travel testing.
    static func current() -> Date {
        #if DEBUG
        return TestDataConfiguration.mockCurrentDate ?? Date()
        #else
        return Date()
        #endif
    }
}
