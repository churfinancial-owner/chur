//
//  BadgeDatabase.swift
//  Chur
//
//  Created by Pak Ho on 2/2/26.
//
//  Static catalog of all badges, loaded once from the bundled JSON seed file.

import Foundation

// MARK: - Badge Database

/// Static catalog — call `getAllBadges()` to get every badge.
/// Results are cached after the first parse so repeated calls are free.
struct BadgeDatabase {
    
    // MARK: - Public API
    
    /// Returns every badge in the seed data as a lightweight Badge struct.
    static func getAllBadges() -> [Badge] {
        return cachedBadges
    }
    
    /// Convenience: look up a single badge by ID.
    static func getBadge(id: String) -> Badge? {
        return cachedBadges.first { $0.id == id }
    }
    
    /// Get badges by category
    static func getBadges(for category: BadgeCategory) -> [Badge] {
        return cachedBadges.filter { $0.category == category }
            .sorted { $0.sortOrder < $1.sortOrder }
    }
    
    /// Get all categories with badges
    static func getAllCategories() -> [BadgeCategory] {
        let categories = Set(cachedBadges.map { $0.category })
        return categories.sorted { $0.displayName < $1.displayName }
    }
    
    /// Reload badge data from the bundle JSON
    static func reloadFromBundle() {
        cachedBadges = loadCachedBadges()
    }

    // MARK: - Cached parsing
    
    private static var cachedBadges: [Badge] = loadCachedBadges()

    private static func loadCachedBadges() -> [Badge] {
        guard let url = Bundle.main.url(forResource: "SeedDatabadges", withExtension: "json") else {
            return []
        }
        
        do {
            let data = try Data(contentsOf: url)
            let badges = try JSONDecoder().decode([Badge].self, from: data)
            return badges.sorted { $0.sortOrder < $1.sortOrder }
        } catch {
            return []
        }
    }
}
