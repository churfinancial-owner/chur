//
//  ContentDomain.swift
//  Chur
//
//  Domains of seed content that can be published remotely.
//  See ROADMAP.md §P1 and Scripts/ChurContentPublish.
//

import Foundation

enum ContentDomain: String, CaseIterable {
    case cards
    case rewards
    case benefits

    /// Merchants ship as two domains, not one. The per-merchant files and
    /// SeedDataGenericMappings.json have different shapes and different blast
    /// radii: a broken mappings payload should cost map name-matching, not the
    /// whole merchant list that online search and brand categories depend on.
    case merchants
    case merchantMappings

    /// Index only — `imageName` → URL + sha256. The PNGs themselves are fetched
    /// individually by CardArtLoader, not staged with the JSON bundles: 15 MB
    /// cannot be part of an all-or-nothing content commit.
    case cardArt

    /// The same index shape as `cardArt`, for badge, bank and partner icons
    /// (P1d). A second domain rather than more entries in the first one so a
    /// broken icon index costs icons and not card art — and so either can be
    /// republished without touching the other.
    ///
    /// Both are read by `CardArtLoader`, which merges them: the two name spaces
    /// are disjoint (`icon_*`/`badge_*` against card `imageName`s) and the
    /// on-disk cache is content-addressed, so one loader and one directory serve
    /// both without collision.
    case iconArt

    // MARK: - P1d domains
    //
    // Read-only catalogs. None of these write to SwiftData — the exception in
    // the pipeline stays `merchants`, whose brandCategory synthesizes a
    // persisted SpendingCategory.

    /// `rec_*.json` — sign-up bonuses and offer copy, the fastest-staling
    /// content in the app. `isActive: false` throughout today, so publishing
    /// this changes nothing user-visible until the flag flips.
    case recommendations

    /// The badge catalog. `detectionRules` reference benefit ids, so this and
    /// `benefits` have to agree — the same cross-domain coupling cards and
    /// benefits acquired in P1b.
    case badges

    /// Airline/hotel partner directory. Referenced by `transferPartners` by id,
    /// so the two travel together in practice even though they fall back
    /// independently.
    case partners
    case transferPartners

    /// Two standalone tool sheets. Separate domains because they are separate
    /// shapes: a rule that accepts both would accept neither properly.
    case autoRentalCoverage
    case cellPhoneProtection

    /// Issuer metadata — names, logos, which countries they appear in.
    case issuers

    /// Reward program point values. Money math: `CardDatabase` resolves
    /// `pointCashValue` from here for every card, remote ones included, which is
    /// why leaving it bundle-only was already a latent bug (P1d note 1).
    case programs
    case programUpgrades

    /// Bank relationship tiers → `CreditCard.boostMultiplier` → the pricing
    /// engine. A rates domain: changes here move numbers, not labels.
    case boostPrograms

    /// Hand-authored categories. The last and most dangerous domain: `cardFilter`,
    /// `excludeFromParent` and `categoryLinks` feed `CardRateCalculator`'s match
    /// resolution, so a bad publish changes prices rather than labels.
    case categories

    /// Stable on-disk cache name. Remote bundles are version-stamped
    /// (`cards-42.json`) but the cache is not, so reads never need the version.
    var cacheFilename: String { "\(rawValue).json" }
}
