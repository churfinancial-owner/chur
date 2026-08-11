//
//  ChurStoreRecovery.swift
//  Chur
//
//  Builds the app's ModelContainer, and survives the case where it can't.
//
//  WHY THIS EXISTS
//  ───────────────
//  `ChurApp` used to `fatalError` when `ModelContainer` init threw. In DEBUG
//  that's a fine dev signal ("delete the app from the simulator"). In release
//  it is an unrecoverable launch crash: the user cannot delete-and-reinstall
//  without losing everything, and cannot even reach the screen that would let
//  them restore from Google Drive.
//
//  A store can fail to open for reasons that are nobody's fault — disk
//  corruption, a killed migration, an interrupted restore — so a correct
//  migration plan is necessary but not sufficient. This is the net under it:
//
//      open store  →  fails  →  quarantine it  →  open a fresh one
//                                    ↓
//                         RootView shows a recovery notice
//                                    ↓
//                    sign in with Google → BackupRestoreService restores
//
//  The old store is MOVED, never deleted. If a restore turns out to be
//  incomplete, the bytes are still on disk and a future version can mine them.
//
//  LIMITS — worth being honest about
//  ─────────────────────────────────
//  Restore only exists for Google Sign-In users. Anonymous users (sign-in is
//  skippable) and Apple Sign In users (no cloud backup yet — DataDictionary
//  audit note 3) have no second copy, so for them this converts a crash into
//  a clean but empty start. That is strictly better than a crash, and strictly
//  worse than not needing it — which is why the migration plan itself has to
//  be right rather than leaning on this.
//

import Foundation
import SwiftData

enum ChurStoreRecovery {

    // MARK: - Recovery State

    /// True when the primary store failed to open and was quarantined.
    /// Read by `RootView` to explain the empty state instead of silently
    /// presenting first-run onboarding to someone who had a wallet.
    private(set) static var didResetStore = false

    /// Where the unreadable store was moved, if it was.
    private(set) static var quarantineURL: URL?

    /// Description of the failure that triggered recovery. Diagnostics only.
    private(set) static var failureDescription: String?

    // MARK: - Container

    /// Opens the store, recovering if it can't be opened.
    ///
    /// Recovery runs in DEBUG too — it removes the manual delete-the-app step,
    /// and means the path is exercised continuously during development rather
    /// than running for the first time on a user's device.
    static func makeContainer() -> ModelContainer {
        let schema = Schema(ChurSchemaCurrent.models, version: ChurSchemaCurrent.versionIdentifier)

        #if DEBUG
        SchemaFingerprint.verify(schema)
        #endif

        let config = ModelConfiguration("Chur", schema: schema, isStoredInMemoryOnly: false)

        do {
            let container = try ModelContainer(
                for: schema,
                migrationPlan: ChurMigrationPlan.self,
                configurations: [config]
            )
            purgeStaleQuarantines(near: config.url)
            return container
        } catch {
            return recover(from: error, schema: schema, config: config)
        }
    }

    // MARK: - Recovery

    private static func recover(
        from error: Error,
        schema: Schema,
        config: ModelConfiguration
    ) -> ModelContainer {
        failureDescription = String(describing: error)

        print("""

        ┌─ STORE FAILED TO OPEN ─────────────────────────────────────────────
        │ \(error)
        │
        │ Quarantining the store and starting fresh. If this happened after a
        │ model change, the migration plan is missing a stage — see
        │ ChurSchema.swift.
        └────────────────────────────────────────────────────────────────────

        """)

        do {
            quarantineURL = try quarantine(storeAt: config.url)
        } catch {
            // Quarantine failed (permissions, disk full). Fall through and let
            // the retry below try anyway — it will fail again if the old files
            // are still readable-but-broken, and we end at the fatalError with
            // both errors reported.
            print("⚠️ Could not quarantine the old store: \(error)")
        }

        didResetStore = true

        do {
            return try ModelContainer(
                for: schema,
                migrationPlan: ChurMigrationPlan.self,
                configurations: [config]
            )
        } catch {
            // A fresh store on a clean path failed. Nothing left to fall back
            // to — an in-memory container would launch but silently discard
            // everything the user did, which is worse than an honest crash.
            fatalError("""
                ModelContainer could not be created even after recovery.
                Original failure: \(failureDescription ?? "unknown")
                Recovery failure: \(error)
                """)
        }
    }

    /// Moves the store and its SQLite sidecars into a timestamped subfolder.
    /// Returns the folder they were moved to.
    private static func quarantine(storeAt storeURL: URL) throws -> URL? {
        let fm = FileManager.default
        let directory = storeURL.deletingLastPathComponent()
        let storeName = storeURL.lastPathComponent

        // Plain `Date()` rather than `Date.current()`: this runs before the
        // time-travel debug tool is live, and a mocked date would produce
        // colliding or misleading folder names.
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let stamp = formatter.string(from: Date())

        let destination = directory
            .appendingPathComponent(quarantineFolderName, isDirectory: true)
            .appendingPathComponent(stamp, isDirectory: true)

        var movedAnything = false
        for suffix in ["", "-shm", "-wal"] {
            let source = directory.appendingPathComponent(storeName + suffix)
            guard fm.fileExists(atPath: source.path) else { continue }
            if !movedAnything {
                try fm.createDirectory(at: destination, withIntermediateDirectories: true)
                movedAnything = true
            }
            try fm.moveItem(at: source, to: destination.appendingPathComponent(storeName + suffix))
        }

        return movedAnything ? destination : nil
    }

    // MARK: - Housekeeping

    private static let quarantineFolderName = "QuarantinedStores"

    /// Quarantined stores are a diagnostic aid, not an archive — a wallet-sized
    /// store kept forever is dead weight on the user's disk. Anything older than
    /// this has long since been restored from or given up on.
    private static let quarantineRetention: TimeInterval = 30 * 24 * 60 * 60

    private static func purgeStaleQuarantines(near storeURL: URL) {
        let fm = FileManager.default
        let root = storeURL
            .deletingLastPathComponent()
            .appendingPathComponent(quarantineFolderName, isDirectory: true)

        guard let entries = try? fm.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        let cutoff = Date().addingTimeInterval(-quarantineRetention)
        for entry in entries {
            let created = (try? entry.resourceValues(forKeys: [.creationDateKey]))?.creationDate
            guard let created, created < cutoff else { continue }
            try? fm.removeItem(at: entry)
        }
    }
}
