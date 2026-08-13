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

    /// Stable on-disk cache name. Remote bundles are version-stamped
    /// (`cards-42.json`) but the cache is not, so reads never need the version.
    var cacheFilename: String { "\(rawValue).json" }
}
