//
//  ContentRefreshCoordinator.swift
//  Chur
//
//  The one place that turns "new content arrived" into "the app reflects it".
//
//  Applying a publish is more than downloading it: template caches have to be
//  rebuilt, persisted categories and wallet cards reconciled against them, and
//  wallet art fetched. Missing a step is invisible — the download succeeds and
//  the screen just doesn't change — so the sequence lives here rather than being
//  repeated at each call site.
//

import Foundation
import SwiftData

@MainActor
enum ContentRefreshCoordinator {

    enum Result {
        case updated
        case alreadyCurrent
        case failed
    }

    /// Launch and foreground path: respects the 30-minute interval.
    @discardableResult
    static func refreshIfNeeded(modelContext: ModelContext) async -> Result {
        let didUpdate = await detached { await RemoteContentService.shared.refreshIfNeeded() }
        return apply(didUpdate: didUpdate, modelContext: modelContext)
    }

    /// User-initiated path: skips the interval gate, because someone pulling to
    /// refresh is explicitly saying "check now". The version gate still applies,
    /// so this is cheap when nothing has changed.
    @discardableResult
    static func refreshNow(modelContext: ModelContext) async -> Result {
        let didUpdate = await detached { await RemoteContentService.shared.refresh() }
        return apply(didUpdate: didUpdate, modelContext: modelContext)
    }

    /// Onboarding path: there is no `ModelContext` worth writing to yet.
    ///
    /// The refresh used to live only in ContentView, which RootView shows *instead
    /// of* onboarding — so a fresh install ran no refresh at all until onboarding
    /// finished. "Add your cards" then listed bundled cards with no art, because
    /// the cardArt index had never been fetched.
    ///
    /// Reloads the in-memory databases but deliberately skips the two sync
    /// services: they write persisted models, the user does not exist yet, and
    /// ContentView.initializeAppDataIfNeeded() runs both on every launch anyway.
    @discardableResult
    static func refreshForOnboarding() async -> Result {
        let didUpdate = await detached { await RemoteContentService.shared.refreshIfNeeded() }

        guard didUpdate else {
            if ContentRefreshLog.latest?.outcome == ContentRefreshLog.Outcome.failed.rawValue {
                return .failed
            }
            return .alreadyCurrent
        }

        reloadDatabases()
        CardArtLoader.shared.contentDidChange()
        return .updated
    }

    /// Runs the network work in an unstructured task, which does *not* inherit
    /// cancellation from its caller.
    ///
    /// The launch refresh is started from ContentView's `.task`, and SwiftUI
    /// cancels a `.task` when the view disappears or changes identity — which
    /// cancelled the manifest download mid-flight and surfaced as
    /// NSURLErrorCancelled (-999). A download worth starting is worth finishing:
    /// the result is written to the shared cache, not to the view.
    private static func detached(_ work: @escaping @MainActor () async -> Bool) async -> Bool {
        await Task { await work() }.value
    }

    private static func apply(didUpdate: Bool, modelContext: ModelContext) -> Result {
        guard didUpdate else {
            // A refresh that changed nothing and a refresh that failed look
            // identical to the caller, so the log is what separates them.
            if ContentRefreshLog.latest?.outcome == ContentRefreshLog.Outcome.failed.rawValue {
                return .failed
            }
            // Still worth topping up art: a card may have been added while
            // offline, or a previous fetch may have failed.
            prefetchWalletArt(modelContext: modelContext)
            return .alreadyCurrent
        }

        reloadDatabases()

        // A new version can change which art an imageName points at, and rows
        // already showing a placeholder have no other reason to look again.
        CardArtLoader.shared.contentDidChange()

        // Merchants carry brandCategory blocks that synthesize SpendingCategory
        // templates, and those are persisted models.
        CategorySyncService.syncCategories(modelContext: modelContext)
        _ = CardSyncService.syncWalletCards(modelContext: modelContext)

        prefetchWalletArt(modelContext: modelContext)
        return .updated
    }

    /// In-memory template caches only — nothing here touches persisted models,
    /// which is what lets onboarding call it before a user exists.
    ///
    /// **Every remote domain needs a line here.** A domain that publishes but is
    /// never reloaded is the pipeline's quietest failure: the download succeeds,
    /// the version moves, the log says `applied`, and the screen shows the old
    /// data until the app is relaunched. Nothing reports it.
    private static func reloadDatabases() {
        CardDatabase.reloadFromBundle()
        BenefitDatabase.reloadFromBundle()
        OnlineMerchantDatabase.reloadFromBundle()
        MerchantCategoryMapper.reloadFromBundle()

        // P1d domains.
        //
        // Order matters in one place: PartnerDatabase before
        // TransferPartnerDatabase, which resolves partner refs through
        // `PartnerDatabase.byID` as it builds its programs. Reloading it second
        // would resolve the new payload against the old partner table.
        IssuerDatabase.reloadFromBundle()
        BadgeDatabase.reloadFromBundle()
        PartnerDatabase.reloadFromBundle()
        TransferPartnerDatabase.loadFromBundle(region: RegionDatabase.detectUserRegion())
        AutoRentalCoverageView.reloadFromBundle()
        CellPhoneProtectionView.reloadFromBundle()
        RecommendationDatabase.reloadFromBundle()
        BoostProgramDatabase.reloadFromBundle()
        ProgramUpgradeDatabase.reloadFromBundle()
        RewardProgramDefaults.reloadFromBundle()

        // Last, and that is load-bearing: it indexes issuers, partners,
        // merchants and category templates, so rebuilding it any earlier would
        // index the payload that was just replaced. Same hazard as the
        // PartnerDatabase ordering note above.
        PartnerIconResolver.reloadFromBundle()

        // Categories have no database of their own — they are read fresh by
        // SeedDataLoader.loadCategoryTemplates() and reconciled into persisted
        // SpendingCategory rows by CategorySyncService, which apply() already
        // calls. Nothing to reload here, which is worth stating so the next
        // person doesn't go looking for the missing line.
    }

    private static func prefetchWalletArt(modelContext: ModelContext) {
        guard let cards = try? modelContext.fetch(FetchDescriptor<CreditCard>()) else { return }
        CardArtLoader.shared.prefetch(cards.map { $0.imageName })
    }
}
