//
//  ContentManifest.swift
//  Chur
//
//  Shape of manifest.json as emitted by Scripts/ChurContentPublish.
//  This is the cross-platform contract — a future Android client decodes
//  the same document, so changes here are breaking changes for both.
//

import Foundation

struct ContentManifest: Codable {
    let contentVersion: Int
    let minAppVersion: String
    let generatedAt: String
    let bundles: [ContentBundleRef]

    func bundle(for domain: ContentDomain) -> ContentBundleRef? {
        bundles.first { $0.domain == domain.rawValue }
    }
}

struct ContentBundleRef: Codable {
    let domain: String
    let url: String
    let sha256: String
    let bytes: Int
}

enum ContentError: Error, CustomStringConvertible {
    case noContainer
    case badResponse(String)
    case checksumMismatch(String)
    case validationFailed(String)

    var description: String {
        switch self {
        case .noContainer:
            return "No writable container for content cache"
        case .badResponse(let detail):
            return "Bad response: \(detail)"
        case .checksumMismatch(let domain):
            return "Checksum mismatch for '\(domain)'"
        case .validationFailed(let detail):
            return "Validation failed: \(detail)"
        }
    }
}
