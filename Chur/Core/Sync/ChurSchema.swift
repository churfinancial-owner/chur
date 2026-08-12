//
//  ChurSchema.swift
//  Chur
//
//  Versioned schema snapshots and migration plan for SwiftData.
//
//  ═══════════════════════════════════════════════════════════════════════════
//  READ THIS BEFORE CHANGING ANY @Model
//  ═══════════════════════════════════════════════════════════════════════════
//
//  THE RULE
//  ────────
//  A `VersionedSchema` must be a PHOTOGRAPH of the models at a point in time.
//  It must never be a POINTER to the live classes.
//
//  History: v1.10 … v1.14 were all pointers — every enum listed the same live
//  `CreditCard.self`, `User.self`, … So when a model gained a field, all five
//  "versions" silently described the NEW shape at once. SwiftData then had no
//  description of the OLD shape to migrate from, `ModelContainer` init threw,
//  and the app hard-crashed. The only fix in the field was delete-and-reinstall,
//  which destroys the user's wallet, notes and benefit usage history.
//
//  Because nothing had shipped, that fake ladder was collapsed into the single
//  frozen baseline `ChurSchemaV2_0` below (2026-08-11).
//
//  BEFORE THE FIRST APP STORE RELEASE — READ THIS FIRST
//  ────────────────────────────────────────────────────
//  While nothing has shipped, no user store exists at any version, so there is
//  nothing to migrate FROM. Do NOT add a version for every model change during
//  development — you would rebuild the fake ladder this file was rewritten to
//  delete.
//
//  Pre-launch workflow for a model change:
//    1. Edit the live model freely. Keep editing `ChurSchemaV2_0` in place.
//    2. `SchemaFingerprint` will fail its DEBUG assertion. That is expected —
//       paste the new value it prints into `SchemaFingerprint.recorded`.
//    3. Delete the app from the simulator, or let `ChurStoreRecovery` quarantine
//       the old store on next launch. Both are fine; no user is affected.
//
//  The moment v1.0 is on the App Store, that stops being true and the procedure
//  below becomes mandatory for every single model change. Bump this note to say
//  "SHIPPED — full procedure required" on release day so the switch is explicit
//  rather than remembered.
//
//  HOW TO MAKE A SCHEMA CHANGE (required once shipped)
//  ──────────────────────────────────────────────────
//  Say you want to add `User.spendProfile` (a P3 requirement).
//
//  1. FREEZE THE OLD SHAPE FIRST — before touching `User.swift`.
//     Copy the CURRENT `User` class body into `ChurSchemaV2_0` as a nested
//     class, and point `ChurSchemaV2_0.models` at the nested copy:
//
//         enum ChurSchemaV2_0: VersionedSchema {
//             static var versionIdentifier = Schema.Version(2, 0, 0)
//             static var models: [any PersistentModel.Type] = [
//                 CreditCard.self,          // unchanged → live class is fine
//                 ChurSchemaV2_0.User.self, // CHANGED   → frozen copy
//                 ...
//             ]
//
//             // Frozen 2026-08-11. Never edit. Not the live `User`.
//             @Model final class User {
//                 var firstName: String
//                 ...                      // exactly as it was, no spendProfile
//                 init(...) { ... }
//             }
//         }
//
//     Nested `@Model` types keep their simple name ("User") as the SwiftData
//     entity name, so the frozen copy still matches the rows already on disk.
//     Only freeze the models that actually CHANGED — unchanged ones can keep
//     referencing the live class in both versions.
//
//  2. Now edit the live `User` and add `spendProfile`.
//
//  3. Add the new version, pointing at the live classes:
//
//         enum ChurSchemaV2_1: VersionedSchema {
//             static var versionIdentifier = Schema.Version(2, 1, 0)
//             static var models: [any PersistentModel.Type] = [ ...all live... ]
//         }
//
//  4. Append it to `ChurMigrationPlan.schemas` and add a stage:
//       • `.lightweight` — new optional field, new model, new field with a
//         default value. No code runs.
//       • `.custom`      — rename, removal, type change, or anything needing
//         data rewritten. Use `willMigrate` / `didMigrate`.
//
//  5. Point `ChurApp.swift` at the new version (schema + versionIdentifier).
//
//  6. Update `SchemaFingerprint.recorded` — the DEBUG guard will print the new
//     value on first run and tell you exactly what to paste.
//
//  7. Update `DataDictionary.md` (models + audit notes).
//
//  THE ALWAYS-LIVE INVARIANT
//  ─────────────────────────
//  Only the NEWEST version may reference the live top-level classes. Every
//  older version must own frozen copies of whatever changed. If two versions
//  in `schemas` describe an identical set of entities, the stage between them
//  is a no-op and you have reintroduced the original bug.
//  `SchemaFingerprint` (DEBUG) exists to catch exactly that.
//

import SwiftData

// MARK: - v2.0 — frozen baseline established 2026-08-11
//
// Collapses the non-functional v1.10 … v1.14 ladder (see header). This is the
// first version that will actually ship, so it is the first shape any real
// user store can hold. Nothing migrates INTO it — there is no earlier shipped
// version — which is why `ChurMigrationPlan.stages` is empty.
//
// Dev stores stamped v1.14 have no path here by design. They hit the recovery
// path in `ChurApp.swift`, which quarantines the old store and starts fresh.

enum ChurSchemaV2_0: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] = [
        CreditCard.self,
        User.self,
        RewardRate.self,
        RewardPlan.self,
        Benefit.self,
        BenefitUsageRecord.self,
        SpendingCategory.self,
        CardProductChangeEvent.self,
    ]

    // No frozen copies yet — v2.0 IS the live shape. The first model change
    // after this ships must add them here per step 1 in the header.
    //
    // `MerchantReward` stays deliberately unregistered (DataDictionary audit
    // note 4). Registering it is itself a schema change and needs a new version.
}

// MARK: - Current

/// The schema version the app opens its store with. `ChurApp.swift` and
/// `SchemaFingerprint` both read this, so a version bump only needs editing here.
typealias ChurSchemaCurrent = ChurSchemaV2_0

// MARK: - Migration Plan

enum ChurMigrationPlan: SchemaMigrationPlan {
    /// All shipped schema versions, oldest first.
    static var schemas: [any VersionedSchema.Type] = [
        ChurSchemaV2_0.self,
    ]

    /// One stage per consecutive pair in `schemas`. Empty while there is only
    /// one shipped version — a single-version plan has nothing to migrate.
    ///
    /// Do not add a stage between two versions that describe identical
    /// entities; that is a no-op and the bug this file was rewritten to fix.
    static var stages: [MigrationStage] = []
}
