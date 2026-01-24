//
//  CategorySyncService.swift
//  Chur
//
//  Syncs persisted SpendingCategory records with the latest bundle
//  JSON templates. Adds new categories, updates changed fields,
//  and deactivates removed ones — while preserving user references
//  (User.selectedCategories, deselectedCategories, etc.).

import Foundation
import SwiftData

struct CategorySyncService {

    // MARK: - Public API

    /// Syncs every persisted `SpendingCategory` against the latest
    /// `SeedDataCategories_*.json` bundle files.
    /// Call after `SeedDataLoader.loadCategories()` or on app launch.
    @discardableResult
    static func syncCategories(modelContext: ModelContext) -> SyncResult {
        // 1. Load templates from bundle
        let templates = SeedDataLoader.loadCategoryTemplates()
        guard !templates.isEmpty else {
            #if DEBUG
            print("⚠️ CategorySync: No templates found in bundle — skipping sync")
            #endif
            return SyncResult()
        }

        // 2. Fetch persisted categories
        let persisted: [SpendingCategory]
        do {
            persisted = try modelContext.fetch(FetchDescriptor<SpendingCategory>())
        } catch {
            #if DEBUG
            print("❌ CategorySync: Failed to fetch categories: \(error)")
            #endif
            return SyncResult()
        }

        // 3. Build lookup maps
        let persistedByID = Dictionary(
            persisted.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let templateByID = Dictionary(
            templates.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        let persistedIDs = Set(persistedByID.keys)
        let templateIDs = Set(templateByID.keys)

        var result = SyncResult()

        // 4. ADD new categories from templates
        for id in templateIDs.subtracting(persistedIDs) {
            guard let t = templateByID[id] else { continue }
            let category = makeCategory(from: t)
            modelContext.insert(category)
            result.added += 1
        }

        // 5. UPDATE existing categories
        for id in templateIDs.intersection(persistedIDs) {
            guard let existing = persistedByID[id],
                  let t = templateByID[id] else { continue }
            if syncFields(category: existing, template: t) {
                result.updated += 1
            }
        }

        // 6. DEACTIVATE orphaned categories (keep record for user references)
        for id in persistedIDs.subtracting(templateIDs) {
            guard let existing = persistedByID[id], existing.isActive else { continue }
            existing.isActive = false
            result.deactivated += 1
        }

        // 7. Save
        if result.hasChanges {
            do {
                try modelContext.save()
            } catch {
                #if DEBUG
                print("❌ CategorySync: Failed to save: \(error)")
                #endif
            }
        }

        #if DEBUG
        if result.hasChanges {
            print("✅ CategorySync: \(result)")
        } else {
            print("✅ CategorySync: Everything up to date")
        }
        #endif

        return result
    }

    // MARK: - Create Category from Template

    private static func makeCategory(from t: CategoryJSON) -> SpendingCategory {
        let level = t.level.flatMap { CategoryLevel(rawValue: $0) }
        return SpendingCategory(
            id: t.id,
            nameEN: t.nameEN,
            nameZH_Hans: t.nameZH_Hans,
            nameZH_HK: t.nameZH_HK,
            nameZH_TW: t.nameZH_TW,
            emoji: t.emoji,
            iconName: t.iconName,
            sortOrder: t.sortOrder,
            isDefault: t.isDefault,
            parentCategoryID: t.parentCategoryID,
            level: level,
            categoryLinks: t.categoryLinks,
            excludeFromParent: t.excludeFromParent ?? false,
            cardFilter: t.cardFilter,
            excludedPaymentMethods: t.excludedPaymentMethods,
            channels: t.channels,
            visibility: t.visibility
        )
    }

    // MARK: - Field Sync

    /// Patches all template-sourced fields on a persisted category.
    /// Returns `true` if any field was changed.
    private static func syncFields(
        category: SpendingCategory,
        template: CategoryJSON
    ) -> Bool {
        var changed = false

        if category.nameEN != template.nameEN {
            category.nameEN = template.nameEN; changed = true
        }
        if category.nameZH_Hans != template.nameZH_Hans {
            category.nameZH_Hans = template.nameZH_Hans; changed = true
        }
        if category.nameZH_HK != template.nameZH_HK {
            category.nameZH_HK = template.nameZH_HK; changed = true
        }
        if category.nameZH_TW != template.nameZH_TW {
            category.nameZH_TW = template.nameZH_TW; changed = true
        }
        if category.emoji != template.emoji {
            category.emoji = template.emoji; changed = true
        }
        if category.iconName != template.iconName {
            category.iconName = template.iconName; changed = true
        }
        if category.sortOrder != template.sortOrder {
            category.sortOrder = template.sortOrder; changed = true
        }
        if category.isDefault != template.isDefault {
            category.isDefault = template.isDefault; changed = true
        }

        let templateExclude = template.excludeFromParent ?? false
        if category.excludeFromParent != templateExclude {
            category.excludeFromParent = templateExclude; changed = true
        }

        if category.parentCategoryID != template.parentCategoryID {
            category.parentCategoryID = template.parentCategoryID; changed = true
        }

        let templateLevel = template.level.flatMap { CategoryLevel(rawValue: $0) }
        if category.level != templateLevel {
            category.level = templateLevel; changed = true
        }

        if category.channels != template.channels {
            category.channels = template.channels; changed = true
        }
        if category.excludedPaymentMethods != template.excludedPaymentMethods {
            category.excludedPaymentMethods = template.excludedPaymentMethods; changed = true
        }
        if category.visibility != template.visibility {
            category.visibility = template.visibility; changed = true
        }

        // Re-activate categories that reappear in templates
        if !category.isActive {
            category.isActive = true; changed = true
        }

        // JSON-backed fields: encode template values with sorted keys,
        // normalize persisted values the same way, then compare strings.
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys

        let templateLinksJSON = encodeToJSONString(template.categoryLinks, encoder: encoder)
        let normalizedPersistedLinks = normalizeJSONString(
            category.categoryLinksJSON,
            as: [CategoryLink].self,
            encoder: encoder
        )
        if normalizedPersistedLinks != templateLinksJSON {
            category.categoryLinksJSON = templateLinksJSON
            changed = true
        }

        let templateFilterJSON = encodeToJSONString(template.cardFilter, encoder: encoder)
        let normalizedPersistedFilter = normalizeJSONString(
            category.cardFilterJSON,
            as: CardFilter.self,
            encoder: encoder
        )
        if normalizedPersistedFilter != templateFilterJSON {
            category.cardFilterJSON = templateFilterJSON
            changed = true
        }

        return changed
    }

    // MARK: - JSON Helpers

    private static func encodeToJSONString<T: Encodable>(_ value: T?, encoder: JSONEncoder) -> String? {
        guard let value else { return nil }
        guard let data = try? encoder.encode(value) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Decodes then re-encodes a persisted JSON string for normalized comparison.
    private static func normalizeJSONString<T: Codable>(
        _ jsonString: String?,
        as type: T.Type,
        encoder: JSONEncoder
    ) -> String? {
        guard let jsonString, let data = jsonString.data(using: .utf8) else { return nil }
        guard let decoded = try? JSONDecoder().decode(T.self, from: data) else { return jsonString }
        guard let reEncoded = try? encoder.encode(decoded) else { return jsonString }
        return String(data: reEncoded, encoding: .utf8)
    }

    // MARK: - Result

    struct SyncResult: CustomStringConvertible {
        var added = 0
        var updated = 0
        var deactivated = 0

        var hasChanges: Bool {
            added > 0 || updated > 0 || deactivated > 0
        }

        var description: String {
            "+\(added) added, ~\(updated) updated, -\(deactivated) deactivated"
        }
    }
}
