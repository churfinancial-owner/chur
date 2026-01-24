//
//  Chur_newsfeed.swift
//  Chur
//
//  Chur_newsfeed.swift contains:
//  - SanityPost: Main news post model with title, body, images, categories, regions, external links, date formatting
//  - Slug: URL slug for posts
//  - CategoryObject: Reusable model for categories, subcategories, and regions with flexible display name handling
//  - SanityReference: Reference type for Sanity CMS relationships
//  - LinkItem: External link with label and URL
//  - SanityImage: Image model with CDN URL construction from asset reference
//  - SanityAssetReference, SanityImageCrop, SanityImageHotspot: Image metadata structures
//  - RawPortableText: Portable text block with formatting support (headings, lists, marks)
//  - TextChild: Individual text span within portable text blocks
//  - MarkDef: Text formatting marks (links, bold, italic, etc.)
//
//  Created by Pak Ho on 2/22/26.
//

import Foundation

struct SanityPost: Codable, Identifiable {
    let _id: String
    let title: String
    let _createdAt: String
    let slug: Slug?
    let body: [RawPortableText]?
    let categories: [CategoryObject]?
    let subcategories: [CategoryObject]?
    let externalLink1: [LinkItem]?
    let externalLink2: [LinkItem]?
    let externalLink3: [LinkItem]?
    let mainImage: SanityImage?
    let postImage: SanityImage?
    let region: [CategoryObject]?
    
    var id: String { _id }
    
    // Formatting the date string to look nice
    var formattedDate: String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: _createdAt) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            return displayFormatter.string(from: date)
        }
        return _createdAt
    }
    
    // Custom decoding to handle both reference and expanded object formats
    enum CodingKeys: String, CodingKey {
        case _id, title, _createdAt, slug, body
        case categories, subcategories, region
        case externalLink1, externalLink2, externalLink3
        case mainImage, postImage
    }
}

struct Slug: Codable {
    let current: String
}

// Category/Subcategory/Region object with full details
struct CategoryObject: Codable, Identifiable {
    let _id: String
    let title: String?
    let name: String?
    let label: String?
    let regionName: String?
    let region: String?
    
    var id: String { _id }
    
    // Display name - try multiple field names in order of preference
    var displayName: String {
        // Try each possible field name
        if let title = title, !title.isEmpty {
            return title
        }
        if let name = name, !name.isEmpty {
            return name
        }
        if let label = label, !label.isEmpty {
            return label
        }
        if let region = region, !region.isEmpty {
            return region
        }
        if let regionName = regionName, !regionName.isEmpty {
            return regionName
        }
        // Fallback to ID
        return _id
    }
}

struct SanityReference: Codable {
    let _ref: String
    let _type: String
    let _key: String?
}

struct LinkItem: Codable {
    let _key: String?
    let _type: String
    let label: String
    let url: String
}

struct SanityImage: Codable {
    let _type: String
    let asset: SanityAssetReference
    let crop: SanityImageCrop?
    let hotspot: SanityImageHotspot?
    
    // Helper to construct the image URL
    var imageURL: URL? {
        // Extract the image ID from the reference
        // Format: "image-{id}-{width}x{height}-{format}"
        let ref = asset._ref
        
        // Parse the reference to extract components
        guard ref.starts(with: "image-") else { return nil }
        let components = ref.dropFirst(6).split(separator: "-")
        guard components.count >= 3 else { return nil }
        
        let imageId = components[0]
        let dimensions = components[1]
        let format = components[2]
        
        // Construct Sanity CDN URL using your project ID
        let projectId = "0fcg3g46"
        let dataset = "production"
        
        return URL(string: "https://cdn.sanity.io/images/\(projectId)/\(dataset)/\(imageId)-\(dimensions).\(format)")
    }
}

struct SanityAssetReference: Codable {
    let _ref: String
    let _type: String
}

struct SanityImageCrop: Codable {
    let _type: String
    let top: Double
    let bottom: Double
    let left: Double
    let right: Double
}

struct SanityImageHotspot: Codable {
    let _type: String
    let x: Double
    let y: Double
    let height: Double
    let width: Double
}

// A structure to hold the raw block data with full formatting support
struct RawPortableText: Codable {
    let _type: String
    let _key: String
    let children: [TextChild]?
    let style: String?
    let listItem: String?
    let level: Int?
    let markDefs: [MarkDef]?
    
    // Helper to extract plain text from this block
    var plainText: String {
        children?.compactMap { $0.text }.joined(separator: " ") ?? ""
    }
}

struct TextChild: Codable {
    let text: String?
    let _type: String
    let _key: String
    let marks: [String]?
}

struct MarkDef: Codable {
    let _key: String
    let _type: String
    let href: String?
}

