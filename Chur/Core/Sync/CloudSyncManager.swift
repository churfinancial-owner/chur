//
//  CloudSyncManager.swift
//  Chur
//
//  Local-first backup: encodes user wallet data and syncs to the user's
//  private Google Drive App Data folder (hidden from Drive UI, wiped on uninstall).
//
//  Requires the `drive.appdata` OAuth scope — request it during Google Sign-In.
//
//  Usage pattern (always call from @MainActor context, e.g. a SwiftUI view):
//
//    let backup = ChurBackup.snapshot(of: user, cards: cards)
//    try await CloudSyncManager.shared.uploadBackup(backup)
//

import Foundation
import GoogleSignIn

// MARK: - Backup Data Transfer Objects
//
// All DTOs are pure value types (structs) so their synthesised Codable conformances
// carry no actor isolation. Factory methods that read @MainActor-isolated SwiftData
// models are explicitly marked @MainActor and kept separate from the structs.

struct ChurBackup: Codable {
    // Increment this when the backup DTO shape changes in a breaking way.
    // Add a migration case to CloudSyncManager.migrate(_:) at the same time.
    // New fields added to any DTO must be optional so older backups decode safely.
    static let currentVersion = 1
    let version: Int
    let exportedAt: Date
    let user: UserBackup
    let cards: [CreditCardBackup]
}

struct UserBackup: Codable {
    let firstName: String
    let email: String
    let profileEmoji: String
    let country: String
    let selectedCategories: [String]
    let deselectedCategories: [String]
    let explicitlySelectedParentCategories: [String]
    let cardDisplayOrder: [String]
    let showEffectiveRate: Bool
    let boostEnrollments: [String: String]
    let strategyPreferences: [String]
    let earningPowerTravelModeEnabled: Bool
}

struct CreditCardBackup: Codable {
    // Identity
    let id: String
    let templateID: String?
    let name: String
    let issuer: String
    let network: String
    let imageName: String
    let cardType: String
    let isAuthorizedUser: Bool
    // User customizations
    let annualFee: Int
    let approvedMonth: Int
    let approvedDay: Int
    let approvedYear: Int
    let currency: String
    let country: String
    let status: String
    let hasForeignTransactionFee: Bool
    let foreignTransactionFeeRate: Double?
    let note: String
    let noteIsVisible: Bool?
    let selectedPlanID: String?
    let rewardProgramOverride: String?
    let hasCustomAnnualFee: Bool
    let hasCustomForeignFee: Bool
    // Configurable slot → selected label (e.g. "5pct_slot_1" → "Groceries")
    let slotSelections: [String: String]?
    // User-specific reward customizations (only rates with custom point values stored)
    let rewardUserData: [RewardUserData]
    // User-specific benefit state + usage history
    let benefitUserData: [BenefitUserData]
}

/// Lightweight snapshot of user-specific reward rate customizations.
/// Only rates with user-set point values are stored here.
/// Configurable category selections are stored in CreditCardBackup.slotSelections instead.
struct RewardUserData: Codable {
    let planID: String
    let rateIndex: Int
    let configurableSlot: String?   // used to find the right RewardRate for configurable rewards
    let hasCustomPointValue: Bool
    let pointCashValue: Double
}

/// User-specific state for a single benefit (template data excluded).
struct BenefitUserData: Codable {
    let benefitID: String
    let isActivatedByUser: Bool
    let activatedAt: Date?
    let autoApplyEnabled: Bool
    let autoApplyUntil: Date?
    let isActive: Bool
    let usageHistory: [BenefitUsageBackup]
}

struct BenefitUsageBackup: Codable {
    let id: String
    let redeemedAt: Date
    let periodKey: String
    let redeemedAmount: Int
    let isFullyRedeemed: Bool
    let notes: String?
    let source: String?
    let externalID: String?
}

// MARK: - @MainActor Snapshot Factories
//
// These methods read @MainActor-isolated SwiftData model properties and must be
// called from a @MainActor context (e.g. a SwiftUI view or @MainActor function).
// Keeping them as static factory methods (not initialisers) prevents the compiler
// from inferring actor isolation on the struct types themselves.

extension ChurBackup {
    @MainActor
    static func snapshot(of user: User, cards: [CreditCard]) -> ChurBackup {
        ChurBackup(
            version: currentVersion,
            exportedAt: Date(),
            user: UserBackup.snapshot(of: user),
            cards: cards.map { CreditCardBackup.snapshot(of: $0) }
        )
    }
}

extension UserBackup {
    @MainActor
    static func snapshot(of user: User) -> UserBackup {
        UserBackup(
            firstName: user.firstName,
            email: user.email,
            profileEmoji: user.profileEmoji,
            country: user.country,
            selectedCategories: user.selectedCategories,
            deselectedCategories: user.deselectedCategories,
            explicitlySelectedParentCategories: user.explicitlySelectedParentCategories,
            cardDisplayOrder: user.cardDisplayOrder,
            showEffectiveRate: user.showEffectiveRate,
            boostEnrollments: user.boostEnrollments,
            strategyPreferences: user.strategyPreferences,
            earningPowerTravelModeEnabled: user.earningPowerTravelModeEnabled
        )
    }
}

extension CreditCardBackup {
    @MainActor
    static func snapshot(of card: CreditCard) -> CreditCardBackup {
        // Only capture reward rates with user-set custom point values.
        // Configurable category choices are captured in slotSelections instead.
        let rewardUserData: [RewardUserData] = card.rewardPlans.flatMap { plan in
            plan.rewards.enumerated().compactMap { index, rate -> RewardUserData? in
                guard rate.hasCustomPointValue else { return nil }
                return RewardUserData(
                    planID: plan.id,
                    rateIndex: index,
                    configurableSlot: rate.configurableSlot,
                    hasCustomPointValue: true,
                    pointCashValue: rate.pointCashValue
                )
            }
        }

        return CreditCardBackup(
            id: card.id,
            templateID: card.templateID,
            name: card.name,
            issuer: card.issuer,
            network: card.network,
            imageName: card.imageName,
            cardType: card.cardType,
            isAuthorizedUser: card.isAuthorizedUser,
            annualFee: card.annualFee,
            approvedMonth: card.approvedMonth,
            approvedDay: card.approvedDay,
            approvedYear: card.approvedYear,
            currency: card.currency,
            country: card.country,
            status: card.status,
            hasForeignTransactionFee: card.hasForeignTransactionFee,
            foreignTransactionFeeRate: card.foreignTransactionFeeRate,
            note: card.note,
            noteIsVisible: card.noteIsVisible,
            selectedPlanID: card.selectedPlanID,
            rewardProgramOverride: card.rewardProgramOverride,
            hasCustomAnnualFee: card.hasCustomAnnualFee,
            hasCustomForeignFee: card.hasCustomForeignFee,
            slotSelections: card.slotSelections.isEmpty ? nil : card.slotSelections,
            rewardUserData: rewardUserData,
            benefitUserData: card.benefits.map { BenefitUserData.snapshot(of: $0) }
        )
    }
}

extension BenefitUserData {
    @MainActor
    static func snapshot(of benefit: Benefit) -> BenefitUserData {
        BenefitUserData(
            benefitID: benefit.id,
            isActivatedByUser: benefit.isActivatedByUser,
            activatedAt: benefit.activatedAt,
            autoApplyEnabled: benefit.autoApplyEnabled,
            autoApplyUntil: benefit.autoApplyUntil,
            isActive: benefit.isActive,
            usageHistory: benefit.usageHistory.map { BenefitUsageBackup.snapshot(of: $0) }
        )
    }
}

extension BenefitUsageBackup {
    @MainActor
    static func snapshot(of record: BenefitUsageRecord) -> BenefitUsageBackup {
        BenefitUsageBackup(
            id: record.id,
            redeemedAt: record.redeemedAt,
            periodKey: record.periodKey,
            redeemedAmount: record.redeemedAmount,
            isFullyRedeemed: record.isFullyRedeemed,
            notes: record.notes,
            source: record.source,
            externalID: record.externalID
        )
    }
}

// MARK: - CloudSyncManager

/// Manages upload, download, and deletion of `chur_backup.json` in the user's
/// private Google Drive App Data folder. The folder is invisible in Drive UI
/// and is automatically purged when the user uninstalls the app.
///
/// Build the `ChurBackup` snapshot on the `@MainActor` before calling into this actor:
///
///     let backup = ChurBackup.snapshot(of: user, cards: cards)
///     try await CloudSyncManager.shared.uploadBackup(backup)
actor CloudSyncManager {

    static let shared = CloudSyncManager()

    /// Use this key with `@AppStorage` or `UserDefaults` to observe the last sync time in your UI:
    ///
    ///     @AppStorage(CloudSyncManager.lastSyncedAtKey) private var lastSyncedAt: Double = 0
    static let lastSyncedAtKey = "cloudSync.lastSyncedAt"

    private let driveFilesURL  = "https://www.googleapis.com/drive/v3/files"
    private let driveUploadURL = "https://www.googleapis.com/upload/drive/v3/files"
    private let backupFileName = "chur_backup.json"

    private init() {}

    // MARK: - Public State

    /// Most recent successful sync timestamp. Readable without `await` from any context.
    nonisolated var lastSyncedAt: Date? {
        UserDefaults.standard.object(forKey: Self.lastSyncedAtKey) as? Date
    }

    // MARK: - Errors

    enum SyncError: LocalizedError {
        case notSignedIn
        case tokenRefreshFailed
        case encodingFailed
        case decodingFailed
        case noBackupFound
        case serverError(Int, String)

        var errorDescription: String? {
            switch self {
            case .notSignedIn:               return "Not signed in with Google"
            case .tokenRefreshFailed:        return "Failed to refresh Google access token"
            case .encodingFailed:            return "Failed to encode backup data"
            case .decodingFailed:            return "Failed to decode backup from Drive"
            case .noBackupFound:             return "No existing backup found on Google Drive"
            case .serverError(let c, let m): return "Drive API error \(c): \(m)"
            }
        }
    }

    // MARK: - Upload

    /// Encodes the pre-built backup snapshot and saves it to the user's Drive App Data folder.
    /// Creates the file on first run; patches it in place on subsequent syncs.
    ///
    /// Build the snapshot on the main actor first:
    ///
    ///     let backup = ChurBackup.snapshot(of: user, cards: cards)
    ///     try await CloudSyncManager.shared.uploadBackup(backup)
    func uploadBackup(_ backup: ChurBackup) async throws {
        let token = try await freshAccessToken()

        // Encode on the main actor — satisfies the @MainActor-inferred Encodable conformance
        // that the compiler applies to DTO types that have @MainActor snapshot factory methods.
        let payload = try await MainActor.run { () -> Data in
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            guard let data = try? encoder.encode(backup) else {
                throw SyncError.encodingFailed
            }
            return data
        }

        if let existingID = try await findBackupFileID(token: token) {
            try await patchFile(fileID: existingID, data: payload, token: token)
        } else {
            try await createFile(data: payload, token: token)
        }

        UserDefaults.standard.set(Date(), forKey: Self.lastSyncedAtKey)
    }

    // MARK: - Download

    /// Downloads the backup from Drive, migrates it to the current version if needed,
    /// and returns the decoded `ChurBackup`.
    /// Throws `SyncError.noBackupFound` if no file exists yet (e.g. first install).
    func downloadBackup() async throws -> ChurBackup {
        let token = try await freshAccessToken()

        guard let fileID = try await findBackupFileID(token: token) else {
            throw SyncError.noBackupFound
        }

        let url = URL(string: "\(driveFilesURL)/\(fileID)?alt=media")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)

        // Decode on the main actor — mirrors the @MainActor isolation applied to encoding.
        let backup = try await MainActor.run { () -> ChurBackup in
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            guard let result = try? decoder.decode(ChurBackup.self, from: data) else {
                throw SyncError.decodingFailed
            }
            return result
        }

        UserDefaults.standard.set(Date(), forKey: Self.lastSyncedAtKey)
        return Self.migrate(backup)
    }

    // MARK: - Backup Version Migration
    //
    // HOW TO ADD A NEW BACKUP VERSION
    // ─────────────────────────────────
    // 1. Increment ChurBackup.currentVersion.
    // 2. Add new fields to the relevant DTO structs as OPTIONAL properties.
    //    Non-optional new fields will break decoding of older backups.
    // 3. Add a case below: if result.version == N { upgrade fields, set version to N+1 }.
    // 4. Update DataDictionary.md to reflect the new fields.

    private static func migrate(_ backup: ChurBackup) -> ChurBackup {
        guard backup.version < ChurBackup.currentVersion else { return backup }
        // No migrations needed yet — we are at version 1 (the baseline).
        // Future example:
        //   var result = backup
        //   if result.version == 1 {
        //       result = ChurBackup(version: 2, exportedAt: result.exportedAt,
        //                           user: result.user, cards: result.cards)
        //   }
        //   return result
        return backup
    }

    // MARK: - Delete

    /// Permanently removes the backup file from the user's Drive App Data folder.
    /// Safe to call when no backup exists — returns silently (idempotent).
    func deleteBackup() async throws {
        let token = try await freshAccessToken()

        guard let fileID = try await findBackupFileID(token: token) else {
            return
        }

        let url = URL(string: "\(driveFilesURL)/\(fileID)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (responseData, response) = try await URLSession.shared.data(for: request)

        // 204 No Content is the expected success code for DELETE
        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) || http.statusCode == 204 else {
            let body = String(data: responseData, encoding: .utf8) ?? ""
            throw SyncError.serverError((response as? HTTPURLResponse)?.statusCode ?? -1, body)
        }

        UserDefaults.standard.removeObject(forKey: Self.lastSyncedAtKey)
    }

    // MARK: - Private Helpers

    private func freshAccessToken() async throws -> String {
        guard let currentUser = GIDSignIn.sharedInstance.currentUser else {
            throw SyncError.notSignedIn
        }
        return try await withCheckedThrowingContinuation { continuation in
            currentUser.refreshTokensIfNeeded { user, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let token = user?.accessToken.tokenString else {
                    continuation.resume(throwing: SyncError.tokenRefreshFailed)
                    return
                }
                continuation.resume(returning: token)
            }
        }
    }

    /// Returns the Drive file ID of `chur_backup.json` if it exists, otherwise `nil`.
    private func findBackupFileID(token: String) async throws -> String? {
        var components = URLComponents(string: driveFilesURL)!
        components.queryItems = [
            URLQueryItem(name: "spaces", value: "appDataFolder"),
            URLQueryItem(name: "fields",  value: "files(id,name)"),
            URLQueryItem(name: "q",       value: "name = '\(backupFileName)'")
        ]
        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)

        struct FileList: Decodable {
            struct File: Decodable { let id: String }
            let files: [File]
        }
        return try JSONDecoder().decode(FileList.self, from: data).files.first?.id
    }

    /// Creates `chur_backup.json` in the App Data folder using a multipart upload.
    private func createFile(data: Data, token: String) async throws {
        let boundary = UUID().uuidString
        let url = URL(string: "\(driveUploadURL)?uploadType=multipart")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/related; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let metadata = "{\"name\":\"\(backupFileName)\",\"parents\":[\"appDataFolder\"]}"
        var body = Data()
        body.append("--\(boundary)\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n".data(using: .utf8)!)
        body.append(metadata.data(using: .utf8)!)
        body.append("\r\n--\(boundary)\r\nContent-Type: application/json\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n--\(boundary)--".data(using: .utf8)!)
        request.httpBody = body

        let (responseData, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: responseData)
    }

    /// Updates the content of an existing Drive file via a media-only PATCH upload.
    private func patchFile(fileID: String, data: Data, token: String) async throws {
        let url = URL(string: "\(driveUploadURL)/\(fileID)?uploadType=media")!

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = data

        let (responseData, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: responseData)
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            let body = String(data: data, encoding: .utf8) ?? ""
            throw SyncError.serverError(code, body)
        }
    }
}
