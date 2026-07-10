//
//  ChurSchema.swift
//  Chur
//
//  Versioned schema snapshots and migration plan for SwiftData.
//
//  HOW TO ADD A NEW SCHEMA VERSION
//  ────────────────────────────────
//  1. Add a new enum `ChurSchemaVX_Y: VersionedSchema` below with the bumped version
//     identifier and the updated models array.
//  2. Append it to `ChurMigrationPlan.schemas` (keep oldest → newest order).
//  3. Add a `MigrationStage` to `ChurMigrationPlan.stages` if the change is
//     non-lightweight (renamed field, removed field, type change).
//     Lightweight changes (new optional field, new model) need no stage.
//  4. Bump `Schema.Version` in ChurApp.swift to match.
//  5. Follow the full schema change protocol in data_architecture.md.

import SwiftData

// MARK: - v1.10 — baseline schema established 2026-05-09

enum ChurSchemaV1_10: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 10, 0)

    static var models: [any PersistentModel.Type] = [
        CreditCard.self,
        User.self,
        RewardRate.self,
        RewardPlan.self,
        Benefit.self,
        BenefitUsageRecord.self,
        SpendingCategory.self,
    ]
}

// MARK: - v1.11 — adds RewardRate.groupLabel (optional, display-only)

enum ChurSchemaV1_11: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 11, 0)

    static var models: [any PersistentModel.Type] = [
        CreditCard.self,
        User.self,
        RewardRate.self,
        RewardPlan.self,
        Benefit.self,
        BenefitUsageRecord.self,
        SpendingCategory.self,
    ]
}

// MARK: - Migration Plan

enum ChurMigrationPlan: SchemaMigrationPlan {
    /// All known schema versions, oldest first.
    static var schemas: [any VersionedSchema.Type] = [
        ChurSchemaV1_10.self,
        ChurSchemaV1_11.self,
    ]

    /// Lightweight migrations (new optional fields, new models) still need a
    /// lightweight stage to link consecutive versions in the plan; custom stages
    /// are only for non-lightweight changes (renames, removals, type changes).
    static var stages: [MigrationStage] = [
        .lightweight(fromVersion: ChurSchemaV1_10.self, toVersion: ChurSchemaV1_11.self),
    ]
}
