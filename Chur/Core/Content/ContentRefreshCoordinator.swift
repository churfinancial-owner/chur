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
        let didUpdate = await RemoteContentService.shared.refreshIfNeeded()
        return apply(didUpdate: didUpdate, modelContext: modelContext)
    }

    /// User-initiated path: skips the interval gate, because someone pulling to
    /// refresh is explicitly saying "check now". The version gate still applies,
    /// so this is cheap when nothing has changed.
    @discardableResult
    static func refreshNow(modelContext: ModelContext) async -> Result {
        let didUpdate = await RemoteContentService.shared.refresh()
        return apply(didUpdate: didUpdate, modelContext: modelContext)
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

        CardDatabase.reloadFromBundle()
        BenefitDatabase.reloadFromBundle()
        OnlineMerchantDatabase.reloadFromBundle()
        MerchantCategoryMapper.reloadFromBundle()

        // Merchants carry brandCategory blocks that synthesize SpendingCategory
        // templates, and those are persisted models.
        CategorySyncService.syncCategories(modelContext: modelContext)
        _ = CardSyncService.syncWalletCards(modelContext: modelContext)

        prefetchWalletArt(modelContext: modelContext)
        return .updated
    }

    private static func prefetchWalletArt(modelContext: ModelContext) {
        guard let cards = try? modelContext.fetch(FetchDescriptor<CreditCard>()) else { return }
        CardArtLoader.shared.prefetch(cards.map { $0.imageName })
    }
}
