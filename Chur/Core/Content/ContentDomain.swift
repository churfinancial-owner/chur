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

    /// Stable on-disk cache name. Remote bundles are version-stamped
    /// (`cards-42.json`) but the cache is not, so reads never need the version.
    var cacheFilename: String { "\(rawValue).json" }
}
