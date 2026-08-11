//
//  SchemaFingerprint.swift
//  Chur
//
//  DEBUG-only drift detector for the SwiftData schema.
//
//  WHY THIS EXISTS
//  ───────────────
//  The v1.10 … v1.14 migration bug (see ChurSchema.swift header) was not caused
//  by a hard problem. It was caused by an easy thing to forget: editing a
//  @Model without freezing the old shape into a VersionedSchema first. Nothing
//  in the compiler notices, and the damage only appears on a real user's device
//  after the update ships.
//
//  This fingerprints the live schema — entity names, attribute names and types,
//  relationship names and destinations — and compares it against a recorded
//  constant. Edit a model without bumping the version and the next DEBUG launch
//  fails an assertion with the exact recipe, instead of a silent time bomb.
//
//  It is a tripwire, not a validator. It cannot tell you whether your migration
//  stage is CORRECT — only that you owe one.
//

import Foundation
import SwiftData
#if DEBUG
import CryptoKit
#endif

enum SchemaFingerprint {

    /// SHA-256 of the canonical form of `ChurSchemaCurrent`, recorded by hand.
    ///
    /// Empty means "not yet recorded" — the first DEBUG launch prints the value
    /// to paste here. Update it in the same commit as any schema version bump.
    ///
    /// v2.0 — pending first run (see console on launch).
    static let recorded = ""

    #if DEBUG

    /// Compares the live schema against `recorded`. Call once at container setup.
    ///
    /// - Empty `recorded`: prints the value to paste, no failure. This is the
    ///   expected state immediately after a version bump.
    /// - Mismatch: `assertionFailure` — a model changed without a new
    ///   `VersionedSchema`, which is the bug this file guards against.
    static func verify(_ schema: Schema) {
        let current = compute(schema)

        guard !recorded.isEmpty else {
            print("""

            ┌─ SCHEMA FINGERPRINT NOT RECORDED ──────────────────────────────
            │ Paste this into SchemaFingerprint.recorded:
            │
            │     static let recorded = "\(current)"
            │
            └────────────────────────────────────────────────────────────────

            """)
            return
        }

        guard current != recorded else { return }

        assertionFailure("""

        ┌─ SCHEMA DRIFT ─────────────────────────────────────────────────────
        │ A @Model changed but the schema version did not.
        │
        │   recorded: \(recorded)
        │   current:  \(current)
        │
        │ Shipping this overwrites the only description of the old shape, so
        │ SwiftData cannot migrate existing stores and the app crashes on
        │ launch for every user who updates.
        │
        │ Fix: follow "HOW TO MAKE A SCHEMA CHANGE" in ChurSchema.swift —
        │ freeze the old model into ChurSchemaV2_0 as a nested copy, add the
        │ next VersionedSchema + MigrationStage, then record the new value.
        │
        │ If the change is genuinely intentional AND already versioned, just
        │ update `recorded` to the current value above.
        └────────────────────────────────────────────────────────────────────

        """)
    }

    /// SHA-256 of `canonicalForm`, truncated to 16 hex chars — enough to make a
    /// collision irrelevant for a schema with a few dozen entities.
    private static func compute(_ schema: Schema) -> String {
        let digest = SHA256.hash(data: Data(canonicalForm(of: schema).utf8))
        return String(digest.map { String(format: "%02x", $0) }.joined().prefix(16))
    }

    /// Stable text form of the schema.
    ///
    /// Everything is sorted because SwiftData makes no ordering guarantee for
    /// `entities` or a given entity's properties — unsorted input would produce
    /// a different hash run to run and cry wolf on every launch.
    ///
    /// Catches: added, removed and renamed properties; attribute type changes;
    /// retargeted relationships; added and removed models.
    /// Misses: `deleteRule` changes, and uniqueness/index attribute options —
    /// both of which still need a migration stage, so treat this as a floor.
    private static func canonicalForm(of schema: Schema) -> String {
        schema.entities
            .sorted { $0.name < $1.name }
            .map { entity in
                let attributes = entity.attributes
                    .map { "\($0.name):\($0.valueType)" }
                    .sorted()
                    .joined(separator: ",")
                let relationships = entity.relationships
                    .map { "\($0.name)->\($0.destination)" }
                    .sorted()
                    .joined(separator: ",")
                return "\(entity.name)|A[\(attributes)]|R[\(relationships)]"
            }
            .joined(separator: "\n")
    }

    #endif
}
