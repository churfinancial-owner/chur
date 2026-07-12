//
//  CardSyncService.swift
//  Chur
//
//  Syncs persisted wallet cards with the latest JSON templates.
//  Updates card metadata, adds/removes benefits, and replaces
//  non-custom reward plans — while preserving user data
//  (usage history, activation state, custom plans, etc.).

import Foundation
import SwiftData

struct CardSyncService {

    /// Syncs every wallet card that has a `templateID` against the latest
    /// in-memory `CardDatabase` / `BenefitDatabase` catalogs.
    /// Call after `reloadFromBundle()` or on app launch.
    @discardableResult
    static func syncWalletCards(modelContext: ModelContext) -> SyncResult {
        let cards: [CreditCard]
        do {
            cards = try modelContext.fetch(FetchDescriptor<CreditCard>())
        } catch {
            #if DEBUG
            print("❌ CardSync: Failed to fetch cards: \(error)")
            #endif
            return SyncResult()
        }

        var result = SyncResult()

        for card in cards {
            guard let templateID = card.templateID,
                  let template = CardDatabase.getCard(id: templateID) else { continue }

            // 1. Sync card-level metadata
            if syncCardMetadata(card: card, template: template) {
                result.cardsUpdated += 1
            }

            // 2. Sync benefits (add missing, remove stale, update changed)
            let benefitDelta = syncBenefits(card: card, template: template, modelContext: modelContext)
            result.benefitsAdded += benefitDelta.added
            result.benefitsRemoved += benefitDelta.removed
            result.benefitsUpdated += benefitDelta.updated

            // 3. Migrate legacy slot selections before plan sync may rebuild rewards
            migrateSlotSelectionsIfNeeded(card: card)

            // 4. Sync non-custom reward plans
            let planDelta = syncRewardPlans(card: card, template: template, modelContext: modelContext)
            result.plansRebuilt += planDelta.plansRebuilt
            result.rewardsPatched += planDelta.rewardsPatched

            // 5. Re-derive reward.categories from slotSelections (the canonical source of truth)
            card.applySlotSelections()
        }

        if result.hasChanges {
            do {
                try modelContext.save()
            } catch {
                #if DEBUG
                print("❌ CardSync: Failed to save: \(error)")
                #endif
            }
        }

        #if DEBUG
        if result.hasChanges {
            print("✅ CardSync: \(result)")
        } else {
            print("✅ CardSync: Everything up to date")
        }
        #endif

        return result
    }

    // MARK: - Card Metadata

    /// Updates mutable card-level fields from the template.
    /// Returns `true` if any field changed.
    private static func syncCardMetadata(card: CreditCard, template: CardTemplate) -> Bool {
        var changed = false

        if card.name != template.name { card.name = template.name; changed = true }
        if card.issuer != template.issuer { card.issuer = template.issuer; changed = true }
        if card.network != template.network { card.network = template.network; changed = true }
        if card.imageName != template.imageName && !card.hasCustomImage {
            card.imageName = template.imageName; changed = true
        }
        if !card.hasCustomAnnualFee && card.annualFee != template.annualFee { card.annualFee = template.annualFee; changed = true }
        if card.country != template.country { card.country = template.country; changed = true }
        if !card.hasCustomForeignFee {
            if card.hasForeignTransactionFee != template.hasForeignTransactionFee {
                card.hasForeignTransactionFee = template.hasForeignTransactionFee; changed = true
            }
            if card.foreignTransactionFeeRate != template.foreignTransactionFeeRate {
                card.foreignTransactionFeeRate = template.foreignTransactionFeeRate; changed = true
            }
        }

        return changed
    }

    // MARK: - Benefits

    private struct BenefitDelta {
        var added = 0
        var removed = 0
        var updated = 0
    }

    /// Diffs the card's persisted benefits against the template's benefit ID list.
    private static func syncBenefits(
        card: CreditCard,
        template: CardTemplate,
        modelContext: ModelContext
    ) -> BenefitDelta {
        var delta = BenefitDelta()
        let cardInstanceID = card.id

        let prefix = "\(cardInstanceID)_"
        var existingByTemplateID: [String: Benefit] = [:]
        for benefit in card.benefits {
            if benefit.id.hasPrefix(prefix) {
                let templateBenefitID = String(benefit.id.dropFirst(prefix.count))
                existingByTemplateID[templateBenefitID] = benefit
            }
        }

        let desiredBenefitIDs = Set(template.benefitIDs)
        let existingBenefitIDs = Set(existingByTemplateID.keys)

        // ADD missing benefits
        let toAdd = desiredBenefitIDs.subtracting(existingBenefitIDs)
        for benefitID in toAdd {
            if let benefitTemplate = BenefitDatabase.getBenefit(id: benefitID) {
                let newBenefit = benefitTemplate.toBenefit(cardInstanceID: cardInstanceID, modelContext: modelContext)
                card.benefits.append(newBenefit)
                delta.added += 1
            }
        }

        // REMOVE stale benefits
        let toRemove = existingBenefitIDs.subtracting(desiredBenefitIDs)
        for benefitID in toRemove {
            if let benefit = existingByTemplateID[benefitID] {
                // Force-resolve the localized fault while the context is still live.
                // SwiftData stores [String: LocalizedStrings] as a transformable (lazy)
                // attribute. If any view holds a reference after deletion+save, accessing
                // this un-resolved fault crashes with "detached from context". Loading it
                // here ensures the value is in-memory before the context detaches.
                _ = benefit.localized
                card.benefits.removeAll { $0.id == benefit.id }
                modelContext.delete(benefit)
                delta.removed += 1
            }
        }

        // UPDATE existing benefits
        let toUpdate = existingBenefitIDs.intersection(desiredBenefitIDs)
        for benefitID in toUpdate {
            guard let benefit = existingByTemplateID[benefitID],
                  let benefitTemplate = BenefitDatabase.getBenefit(id: benefitID) else { continue }
            if updateBenefitFields(benefit: benefit, template: benefitTemplate) {
                delta.updated += 1
            }
        }

        return delta
    }

    /// Patches mutable template-sourced fields on a persisted Benefit.
    private static func updateBenefitFields(benefit: Benefit, template: BenefitTemplate) -> Bool {
        var changed = false

        var localizedDict: [String: LocalizedStrings] = [:]
        localizedDict["en"] = LocalizedStrings(name: template.nameEN, description: template.descriptionEN ?? "")
        if let name = template.nameZH_Hans, let desc = template.descriptionZH_Hans {
            localizedDict["zh-Hans"] = LocalizedStrings(name: name, description: desc)
        }
        if let name = template.nameZH_HK, let desc = template.descriptionZH_HK {
            localizedDict["zh-Hant-HK"] = LocalizedStrings(name: name, description: desc)
        }
        if let name = template.nameZH_TW, let desc = template.descriptionZH_TW {
            localizedDict["zh-Hant-TW"] = LocalizedStrings(name: name, description: desc)
        }

        if benefit.benefitType != template.benefitType { benefit.benefitType = template.benefitType; changed = true }
        if benefit.displayGroup != template.displayGroup { benefit.displayGroup = template.displayGroup; changed = true }
        if benefit.localized != localizedDict { benefit.localized = localizedDict; changed = true }
        if benefit.value != template.value { benefit.value = template.value; changed = true }
        if benefit.valueCurrency != template.valueCurrency { benefit.valueCurrency = template.valueCurrency; changed = true }
        if benefit.calendarMonthOverrides != template.calendarMonthOverrides { benefit.calendarMonthOverrides = template.calendarMonthOverrides; changed = true }
        if benefit.frequency != template.frequency { benefit.frequency = template.frequency; changed = true }
        if benefit.isRecurring != template.isRecurring { benefit.isRecurring = template.isRecurring; changed = true }
        if benefit.resetType != template.resetType { benefit.resetType = template.resetType; changed = true }
        if benefit.usageLimit != template.usageLimit { benefit.usageLimit = template.usageLimit; changed = true }
        if benefit.validCountries != template.validCountries { benefit.validCountries = template.validCountries; changed = true }
        if benefit.excludedCountries != template.excludedCountries { benefit.excludedCountries = template.excludedCountries; changed = true }
        if benefit.trackingMode != template.trackingMode { benefit.trackingMode = template.trackingMode; changed = true }
        if benefit.activationMode != template.activationMode { benefit.activationMode = template.activationMode; changed = true }
        if benefit.activationInstructions != template.activationInstructions { benefit.activationInstructions = template.activationInstructions; changed = true }
        if benefit.isActive != template.isActive { benefit.isActive = template.isActive; changed = true }
        if benefit.activeFromDate != template.activeFromDate { benefit.activeFromDate = template.activeFromDate; changed = true }
        if benefit.activeToDate != template.activeToDate { benefit.activeToDate = template.activeToDate; changed = true }
        if benefit.activationDelayPeriods != template.activationDelayPeriods { benefit.activationDelayPeriods = template.activationDelayPeriods; changed = true }
        if benefit.partnerName != template.partnerName { benefit.partnerName = template.partnerName; changed = true }
        if benefit.partnerID != template.partnerID { benefit.partnerID = template.partnerID; changed = true }
        if benefit.redemptionMethod != template.redemptionMethod { benefit.redemptionMethod = template.redemptionMethod; changed = true }
        if benefit.limitDescription != template.limitDescription { benefit.limitDescription = template.limitDescription; changed = true }
        if benefit.referenceLink != template.referenceLink { benefit.referenceLink = template.referenceLink; changed = true }
        if benefit.benefitNotes != template.benefitNotes { benefit.benefitNotes = template.benefitNotes; changed = true }
        if benefit.displayOrder != template.displayOrder { benefit.displayOrder = template.displayOrder; changed = true }
        if benefit.iconName != template.iconName { benefit.iconName = template.iconName; changed = true }

        return changed
    }

    // MARK: - Reward Plans

    private struct PlanDelta {
        var plansRebuilt = 0
        var rewardsPatched = 0
        var hasChanges: Bool { plansRebuilt > 0 || rewardsPatched > 0 }
    }

    /// Syncs non-custom reward plans against the latest template.
    ///
    /// - Same plan IDs: patches reward fields in-place.
    /// - Plan structure changed: rebuilds from template, then `applySlotSelections()` (called
    ///   by the sync loop) re-derives `reward.categories` from `card.slotSelections`.
    ///
    /// `categories` on configurable rewards is a derived cache — never written here.
    private static func syncRewardPlans(
        card: CreditCard,
        template: CardTemplate,
        modelContext: ModelContext
    ) -> PlanDelta {
        guard !template.rewardPlans.isEmpty else { return PlanDelta() }

        let customPlans = card.rewardPlans.filter { $0.isCustomPlan }
        let templatePlans = card.rewardPlans.filter { !$0.isCustomPlan }

        let existingIDs = Set(templatePlans.map { $0.id })
        let newIDs = Set(template.rewardPlans.map { $0.id })

        // CASE 1: Same plan IDs — patch in place, no delete/recreate
        if existingIDs == newIDs {
            var delta = PlanDelta()
            for planTemplate in template.rewardPlans {
                guard let existing = templatePlans.first(where: { $0.id == planTemplate.id }) else { continue }

                // Patch plan-level metadata
                if existing.name != planTemplate.name { existing.name = planTemplate.name; delta.rewardsPatched += 1 }
                if existing.isDefault != planTemplate.isDefault { existing.isDefault = planTemplate.isDefault; delta.rewardsPatched += 1 }
                if existing.isAvailableForNewUsers != planTemplate.isAvailableForNewUsers { existing.isAvailableForNewUsers = planTemplate.isAvailableForNewUsers; delta.rewardsPatched += 1 }
                if existing.planStartDate != planTemplate.planStartDate { existing.planStartDate = planTemplate.planStartDate; delta.rewardsPatched += 1 }
                if existing.planEndDate != planTemplate.planEndDate { existing.planEndDate = planTemplate.planEndDate; delta.rewardsPatched += 1 }
                if existing.isPromo != planTemplate.isPromo { existing.isPromo = planTemplate.isPromo; delta.rewardsPatched += 1 }

                if existing.rewards.count == planTemplate.rewards.count {
                    // Patch each reward's template fields in place — user fields untouched
                    for (reward, r) in zip(existing.rewards, planTemplate.rewards) {
                        if updateRewardFields(reward: reward, template: r, card: card) {
                            delta.rewardsPatched += 1
                        }
                    }
                } else {
                    // Reward count changed — rebuild rewards for this plan, preserving user config
                    rebuildPlanRewards(plan: existing, planTemplate: planTemplate, modelContext: modelContext)
                    delta.rewardsPatched += planTemplate.rewards.count
                }
            }
            return delta
        }

        // CASE 2: Plan structure changed — rebuild from template.
        // slotSelections on the card already has the user's choices; applySlotSelections()
        // called after sync will re-derive reward.categories from it.
        let previousSelectedPlanID = card.selectedPlanID

        for plan in templatePlans {
            card.rewardPlans.removeAll { $0.id == plan.id }
            for reward in plan.rewards { modelContext.delete(reward) }
            modelContext.delete(plan)
        }

        var delta = PlanDelta()
        for planTemplate in template.rewardPlans {
            let plan = RewardPlan(
                id: planTemplate.id,
                name: planTemplate.name,
                isDefault: planTemplate.isDefault,
                isAvailableForNewUsers: planTemplate.isAvailableForNewUsers,
                planStartDate: planTemplate.planStartDate,
                planEndDate: planTemplate.planEndDate,
                isCustomPlan: false,
                isPromo: planTemplate.isPromo
            )
            modelContext.insert(plan)

            for r in planTemplate.rewards {
                let reward = makeReward(from: r)
                modelContext.insert(reward)
                plan.rewards.append(reward)
            }
            card.rewardPlans.append(plan)
            delta.plansRebuilt += 1
        }

        for plan in customPlans {
            if !card.rewardPlans.contains(where: { $0.id == plan.id }) {
                card.rewardPlans.append(plan)
            }
        }

        if let previousID = previousSelectedPlanID,
           card.rewardPlans.contains(where: { $0.id == previousID }) {
            card.selectedPlanID = previousID
        } else {
            card.selectedPlanID = nil
        }

        return delta
    }

    // MARK: - Reward Field Helpers

    /// Patches all template-owned fields on an existing RewardRate in place.
    /// Never touches `categories` on configurable rewards — those are derived by `applySlotSelections()`.
    /// Returns true if any field changed.
    @discardableResult
    private static func updateRewardFields(reward: RewardRate, template: RewardTemplate, card: CreditCard) -> Bool {
        var changed = false
        if reward.rate != template.rate { reward.rate = template.rate; changed = true }
        // rewardProgramName: skip if user has manually switched the program for this card,
        // or if the current name is the auto-upgrade target of the template program
        // (set by ProgramUpgradeDatabase — reverting it here would undo the upgrade every launch)
        let isAutoUpgraded = ProgramUpgradeDatabase.isUpgradedProgram(
            reward.rewardProgramName,
            sourceProgram: template.rewardProgramName,
            templateID: card.templateID
        )
        if card.rewardProgramOverride == nil && !isAutoUpgraded && reward.rewardProgramName != template.rewardProgramName { reward.rewardProgramName = template.rewardProgramName; changed = true }
        // pointCashValue: skip if user has set a custom valuation, or if the reward was
        // auto-upgraded (the template value belongs to the source program, not the current one)
        if !reward.hasCustomPointValue && !isAutoUpgraded && reward.pointCashValue != template.pointCashValue { reward.pointCashValue = template.pointCashValue; changed = true }
        if reward.pointCashValueCurrency != template.pointCashValueCurrency { reward.pointCashValueCurrency = template.pointCashValueCurrency; changed = true }
        // categories: user-owned for configurable rewards; template-owned otherwise
        if !reward.isUserConfigurable && reward.categories != template.categories { reward.categories = template.categories; changed = true }
        if reward.merchantIdentifier != template.merchantIdentifier { reward.merchantIdentifier = template.merchantIdentifier; changed = true }
        if reward.merchantName != template.merchantName { reward.merchantName = template.merchantName; changed = true }
        if reward.countries != template.countries { reward.countries = template.countries; changed = true }
        if reward.channels != template.channels { reward.channels = template.channels; changed = true }
        if reward.rewardStartDate != template.rewardStartDate { reward.rewardStartDate = template.rewardStartDate; changed = true }
        if reward.rewardEndDate != template.rewardEndDate { reward.rewardEndDate = template.rewardEndDate; changed = true }
        if reward.isRotating != template.isRotating { reward.isRotating = template.isRotating; changed = true }
        if reward.rewardNotes != template.rewardNotes { reward.rewardNotes = template.rewardNotes; changed = true }
        if reward.groupLabel != template.groupLabel { reward.groupLabel = template.groupLabel; changed = true }
        if reward.isUserConfigurable != template.isUserConfigurable { reward.isUserConfigurable = template.isUserConfigurable; changed = true }
        if reward.configurableSlot != template.configurableSlot { reward.configurableSlot = template.configurableSlot; changed = true }
        if reward.configurableOptions != template.configurableOptions { reward.configurableOptions = template.configurableOptions; changed = true }
        // configurableIncludes ([String: [String]]?) intentionally not compared — SwiftData cannot
        // reliably roundtrip nested collection types. It is written only during a full rebuild.
        return changed
    }

    /// Rebuilds a plan's rewards when the reward count changes.
    /// slotSelections on the card preserves user choices; applySlotSelections() called
    /// after sync re-derives reward.categories.
    private static func rebuildPlanRewards(plan: RewardPlan, planTemplate: PlanTemplate, modelContext: ModelContext) {
        for reward in plan.rewards { modelContext.delete(reward) }
        plan.rewards.removeAll()
        for r in planTemplate.rewards {
            let reward = makeReward(from: r)
            modelContext.insert(reward)
            plan.rewards.append(reward)
        }
    }

    /// Creates a new RewardRate from a RewardTemplate with all template fields set.
    /// User-owned fields (categories for configurable, selectedConfigurableLabel) are left at defaults.
    private static func makeReward(from r: RewardTemplate) -> RewardRate {
        RewardRate(
            rate: r.rate,
            rewardProgramName: r.rewardProgramName,
            pointCashValue: r.pointCashValue,
            pointCashValueCurrency: r.pointCashValueCurrency,
            categories: r.categories,
            merchantIdentifier: r.merchantIdentifier,
            merchantName: r.merchantName,
            countries: r.countries,
            channels: r.channels,
            rewardStartDate: r.rewardStartDate,
            rewardEndDate: r.rewardEndDate,
            isRotating: r.isRotating,
            rewardNotes: r.rewardNotes,
            groupLabel: r.groupLabel,
            isUserConfigurable: r.isUserConfigurable,
            configurableSlot: r.configurableSlot,
            configurableOptions: r.configurableOptions,
            configurableIncludes: r.configurableIncludes
        )
    }

    // MARK: - Slot Selection Migration

    /// One-time migration: if a card has no `slotSelections` yet, reads legacy
    /// `selectedConfigurableLabel` values from persisted rewards and promotes them
    /// to the canonical `slotSelections` dict. Runs only when `slotSelections` is empty
    /// so it is safe to call on every sync.
    private static func migrateSlotSelectionsIfNeeded(card: CreditCard) {
        guard card.slotSelections.isEmpty else { return }
        for plan in card.rewardPlans {
            for reward in plan.rewards where reward.isUserConfigurable {
                if let slot = reward.configurableSlot,
                   let label = reward.selectedConfigurableLabel, !label.isEmpty {
                    card.slotSelections[slot] = label
                }
            }
        }
    }

    struct SyncResult: CustomStringConvertible {
        var cardsUpdated = 0
        var benefitsAdded = 0
        var benefitsRemoved = 0
        var benefitsUpdated = 0
        var plansRebuilt = 0    // full delete+recreate (plan structure changed)
        var rewardsPatched = 0  // in-place field updates (plan structure unchanged)

        var hasChanges: Bool {
            cardsUpdated > 0 || benefitsAdded > 0 || benefitsRemoved > 0 || benefitsUpdated > 0 || plansRebuilt > 0 || rewardsPatched > 0
        }

        var description: String {
            "\(cardsUpdated) cards updated, benefits: +\(benefitsAdded) -\(benefitsRemoved) ~\(benefitsUpdated), \(plansRebuilt) plans rebuilt, \(rewardsPatched) rewards patched"
        }
    }
}
