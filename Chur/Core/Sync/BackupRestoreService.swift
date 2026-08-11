//
//  BackupRestoreService.swift
//  Chur
//
//  Applies a downloaded ChurBackup to the local SwiftData store.
//
//  Strategy:
//  1. Apply user preferences from the backup onto the existing User object.
//  2. For each CreditCardBackup, insert a CreditCard skeleton with the SAME id
//     as the backup — this preserves benefit IDs ({cardID}_{templateBenefitID})
//     so usage history can be matched exactly.
//  3. Call CardSyncService to seed benefits and reward plans from templates.
//  4. Apply user-specific overrides (configurable reward labels, custom point
//     values, benefit activation state, usage history).
//  5. Reinsert Card History (CardProductChangeEvent) independently — those rows
//     reference cards by plain string ID, not by relationship.
//

import Foundation
import SwiftData

struct BackupRestoreService {

    // MARK: - Public Entry Point

    enum RestoreResult {
        case restored(cardCount: Int)
        case noBackupFound
        case failed(Error)
    }

    /// Downloads the backup and applies it if the user has no existing local cards.
    /// Safe to call after sign-in — silently returns `.noBackupFound` if nothing exists.
    static func checkAndRestore(
        user: User,
        existingCards: [CreditCard],
        modelContext: ModelContext
    ) async -> RestoreResult {
        guard existingCards.isEmpty else {
            // Local cards already exist — user signed in on the same device.
            // Skip restore to avoid overwriting newer local data.
            return .noBackupFound
        }

        do {
            let backup = try await CloudSyncManager.shared.downloadBackup()
            await MainActor.run {
                restore(backup: backup, user: user, modelContext: modelContext)
            }
            return .restored(cardCount: backup.cards.count)
        } catch CloudSyncManager.SyncError.noBackupFound {
            return .noBackupFound
        } catch {
            return .failed(error)
        }
    }

    // MARK: - Core Restore Logic

    /// Applies a `ChurBackup` to the local SwiftData store.
    /// Must be called on the `@MainActor` (SwiftData model objects are main-actor-bound).
    @MainActor
    static func restore(backup: ChurBackup, user: User, modelContext: ModelContext) {
        // 1. Restore user preferences (skip auth fields — already set from sign-in)
        applyUserPreferences(backup.user, to: user)

        // 2. Fetch existing card IDs so we don't double-insert
        let existingIDs = Set(
            (try? modelContext.fetch(FetchDescriptor<CreditCard>()))?.map { $0.id } ?? []
        )

        // 3. Insert card skeletons, preserving the original ID from the backup
        for cardBackup in backup.cards {
            guard !existingIDs.contains(cardBackup.id) else { continue }

            let card = CreditCard(
                id: cardBackup.id,
                templateID: cardBackup.templateID,
                name: cardBackup.name,
                issuer: cardBackup.issuer,
                network: cardBackup.network,
                imageName: cardBackup.imageName,
                hasCustomImage: cardBackup.hasCustomImage ?? false,
                cardType: cardBackup.cardType,
                isAuthorizedUser: cardBackup.isAuthorizedUser,
                annualFee: cardBackup.annualFee,
                approvedMonth: cardBackup.approvedMonth,
                approvedDay: cardBackup.approvedDay,
                approvedYear: cardBackup.approvedYear,
                currency: cardBackup.currency,
                country: cardBackup.country,
                hasForeignTransactionFee: cardBackup.hasForeignTransactionFee,
                foreignTransactionFeeRate: cardBackup.foreignTransactionFeeRate,
                note: cardBackup.note,
                noteIsVisible: cardBackup.noteIsVisible ?? true,
                // v2 backups have no colours — fall back to the init defaults
                // rather than writing nil, so an old backup restores exactly as
                // it did before.
                noteTextColor: cardBackup.noteTextColor ?? "#FFFFFF",
                noteBgColor: cardBackup.noteBgColor ?? "#000000"
            )
            // Fields not in CreditCard.init
            // `init` stamps dateAdded with Date(); overwrite it so the wallet
            // keeps the card's real age instead of the restore time.
            if let dateAdded = cardBackup.dateAdded { card.dateAdded = dateAdded }
            card.status = cardBackup.status
            card.cancelledDate = cardBackup.cancelledDate
            card.hasCustomAnnualFee = cardBackup.hasCustomAnnualFee
            card.hasCustomForeignFee = cardBackup.hasCustomForeignFee
            card.selectedPlanID = cardBackup.selectedPlanID
            card.rewardProgramOverride = cardBackup.rewardProgramOverride

            modelContext.insert(card)
        }

        // 4. Seed benefits + reward plans from templates via CardSyncService.
        //    Because we preserved the card IDs, seeded benefit IDs will be
        //    "{cardBackup.id}_{templateBenefitID}" — matching the backup exactly.
        CardSyncService.syncWalletCards(modelContext: modelContext)

        // 5. Apply user-specific overrides on top of the seeded template data
        let allCards = (try? modelContext.fetch(FetchDescriptor<CreditCard>())) ?? []
        for cardBackup in backup.cards {
            guard let card = allCards.first(where: { $0.id == cardBackup.id }) else { continue }
            card.slotSelections = cardBackup.slotSelections ?? [:]
            card.applySlotSelections()
            applyRewardUserData(cardBackup.rewardUserData, to: card)
            applyBenefitUserData(cardBackup.benefitUserData, to: card, modelContext: modelContext)
        }

        // 6. Restore card display order
        user.cardDisplayOrder = backup.user.cardDisplayOrder

        // 7. Restore the Card History timeline
        applyProductChangeEvents(backup.productChangeEvents, modelContext: modelContext)

        try? modelContext.save()
    }

    // MARK: - Product Change History

    /// Reinserts Product Change events (backup v3+).
    ///
    /// These are not cascade-linked to `CreditCard` — `fromCardID` / `toCardID`
    /// are plain strings — so they are restored independently of which cards
    /// made it back, exactly as they survive a card deletion locally. Events are
    /// never mutated after creation, so matching on `id` alone is enough to keep
    /// this idempotent across repeated restores.
    private static func applyProductChangeEvents(
        _ events: [CardProductChangeEventBackup]?,
        modelContext: ModelContext
    ) {
        guard let events, !events.isEmpty else { return }

        let existingIDs = Set(
            (try? modelContext.fetch(FetchDescriptor<CardProductChangeEvent>()))?.map { $0.id } ?? []
        )

        for entry in events where !existingIDs.contains(entry.id) {
            modelContext.insert(
                CardProductChangeEvent(
                    id: entry.id,
                    fromCardID: entry.fromCardID,
                    toCardID: entry.toCardID,
                    fromTemplateID: entry.fromTemplateID,
                    toTemplateID: entry.toTemplateID,
                    changeDate: entry.changeDate
                )
            )
        }
    }

    // MARK: - User Preferences

    private static func applyUserPreferences(_ src: UserBackup, to user: User) {
        if !src.firstName.isEmpty        { user.firstName = src.firstName }
        if !src.email.isEmpty            { user.email = src.email }
        user.profileEmoji                = src.profileEmoji
        user.country                     = src.country
        user.languagePreference          = src.languagePreference ?? AppLanguage.system.rawValue
        user.selectedCategories          = src.selectedCategories
        user.deselectedCategories        = src.deselectedCategories
        user.explicitlySelectedParentCategories = src.explicitlySelectedParentCategories
        user.showEffectiveRate           = src.showEffectiveRate
        user.boostEnrollments            = src.boostEnrollments
        user.strategyPreferences         = src.strategyPreferences
        user.earningPowerTravelModeEnabled = src.earningPowerTravelModeEnabled
        // Both added in backup v3. Guarded rather than assigned straight through:
        // a v2 backup decodes these as nil, and nil there means "this backup
        // predates the field", not "the user cleared it".
        if let photo = src.profilePhotoData { user.profilePhotoData = photo }
        if let dateAdded = src.dateAdded    { user.dateAdded = dateAdded }
        // cardDisplayOrder is applied after cards are inserted (step 6 in restore)
    }

    // MARK: - Reward User Data

    /// Restores custom point values only. Configurable category choices are restored
    /// via card.slotSelections + card.applySlotSelections() before this is called.
    private static func applyRewardUserData(_ data: [RewardUserData], to card: CreditCard) {
        for entry in data {
            guard entry.hasCustomPointValue else { continue }
            guard let plan = card.rewardPlans.first(where: { $0.id == entry.planID }) else { continue }
            let rate: RewardRate?
            if let slot = entry.configurableSlot {
                rate = plan.rewards.first { $0.configurableSlot == slot }
            } else {
                rate = entry.rateIndex < plan.rewards.count ? plan.rewards[entry.rateIndex] : nil
            }
            guard let rate else { continue }
            rate.hasCustomPointValue = true
            rate.pointCashValue = entry.pointCashValue
        }
    }

    // MARK: - Benefit User Data + Usage History

    private static func applyBenefitUserData(
        _ data: [BenefitUserData],
        to card: CreditCard,
        modelContext: ModelContext
    ) {
        for entry in data {
            // Since card.id == cardBackup.id, benefit IDs match exactly
            guard let benefit = card.benefits.first(where: { $0.id == entry.benefitID }) else {
                continue
            }

            benefit.isActivatedByUser = entry.isActivatedByUser
            benefit.activatedAt       = entry.activatedAt
            benefit.autoApplyEnabled  = entry.autoApplyEnabled
            benefit.autoApplyUntil    = entry.autoApplyUntil
            // Both added in backup v3. Assigned unguarded because nil is also the
            // freshly-seeded value for each: a v2 backup lands on the same state
            // it produced before, and `autoApplyAmount = nil` legitimately means
            // "replay the full remaining budget".
            benefit.autoApplyAmount   = entry.autoApplyAmount
            benefit.isMuted           = entry.isMuted ?? false
            // isActive is intentionally not restored — template controls visibility

            // Insert usage records, skipping any that already exist
            let existingIDs = Set(benefit.usageHistory.map { $0.id })
            for usageEntry in entry.usageHistory {
                guard !existingIDs.contains(usageEntry.id) else { continue }
                let record = BenefitUsageRecord(
                    id: usageEntry.id,
                    redeemedAt: usageEntry.redeemedAt,
                    periodKey: usageEntry.periodKey,
                    redeemedAmount: usageEntry.redeemedAmount,
                    isFullyRedeemed: usageEntry.isFullyRedeemed,
                    notes: usageEntry.notes,
                    source: usageEntry.source,
                    externalID: usageEntry.externalID
                )
                modelContext.insert(record)
                benefit.usageHistory.append(record)
            }
        }
    }
}
