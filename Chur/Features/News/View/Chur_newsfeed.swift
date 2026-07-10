import Foundation

// MARK: - Main Post Model
struct SanityPost: Codable, Identifiable {
    let _id: String
    let title: String
    let _createdAt: String
    let slug: Slug?
    let postImage: SanityImage?

    // Reference objects resolved via GROQ dereferencing
    let issuer: IssuerReference?
    let partner: PartnerReference?
    let language: LanguageReference?
    let posttype: PostTypeReference?
    let linkedCards: [CardReference]?

    // Offer history
    let offerHistory: [OfferRecord]?

    // Content sections
    let publishedAt: String?
    let header_body1: String?
    let body: [RawPortableText]?
    let isCollapsed1: Bool?
    let header_body2: String?
    let body2: [RawPortableText]?
    let isCollapsed2: Bool?
    let header_body3: String?
    let body3: [RawPortableText]?
    let isCollapsed3: Bool?
    let applyLink: String?
    
    // Categorization
    let region: [RegionObject]?
    let tags: [TagReference]?

    var id: String { _id }

    var isCardPost: Bool { posttype?.slug?.lowercased() == "card" }

    // Helper to resolve Issuer ID for local database lookups
    var issuerId: String? { issuer?.issuer_id }

    var currentOffer: OfferRecord? {
        offerHistory?.first(where: { $0.isCurrent == true }) ?? offerHistory?.first
    }

    var formattedDate: String {
        let dateStr = publishedAt ?? _createdAt
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = iso.date(from: dateStr)
        
        if date == nil {
            iso.formatOptions = [.withInternetDateTime]
            date = iso.date(from: dateStr)
        }
        
        guard let date else { return String(dateStr.prefix(10)) }
        let display = DateFormatter()
        display.dateFormat = "yyyy-MM-dd"
        return display.string(from: date)
    }

    enum CodingKeys: String, CodingKey {
        case _id, title, _createdAt, slug, postImage
        case issuer, partner, language, posttype, linkedCards
        case offerHistory, publishedAt
        case header_body1, body, isCollapsed1
        case header_body2, body2, isCollapsed2
        case header_body3, body3, isCollapsed3
        case applyLink, region, tags
    }
}

// MARK: - Reference & Categorization Models

struct TagReference: Codable, Identifiable {
    let _id: String
    let slug: String?
    let label: String?
    var id: String { _id }
}

struct IssuerReference: Codable {
    let _id: String
    let issuer_id: String?
}

struct PartnerReference: Codable {
    let _id: String
    let name: String?
}

struct LanguageReference: Codable {
    let _id: String
    let name: String?
    let code: String?
}

struct CardReference: Codable {
    let _id: String
    let cardId: String?
}

struct PostTypeReference: Codable {
    let _id: String
    let slug: String?

    enum CodingKeys: String, CodingKey {
        case _id
        case slug = "posttype"
    }
}

struct RegionObject: Codable, Identifiable {
    let _id: String
    let region: String?
    var id: String { _id }
}

// MARK: - Offer History Model

struct OfferRecord: Codable, Identifiable {
    let _key: String?
    let recordDate: String?
    let signupBonus: String?
    let spendingReq: String?
    let annualFee: Double?
    let isCurrent: Bool?
    let isAllTimeHigh: Bool?

    var id: String { _key ?? recordDate ?? UUID().uuidString }

    var hasContent: Bool {
        signupBonus != nil || spendingReq != nil || annualFee != nil
    }

    var formattedDate: String? {
        guard let dateStr = recordDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: dateStr) {
            let display = DateFormatter()
            display.dateFormat = "MMM yyyy"
            return display.string(from: date)
        }
        return dateStr
    }
}

// MARK: - Supporting Sanity Models (Images & Portable Text)

struct Slug: Codable {
    let current: String
}

struct SanityImage: Codable {
    let _type: String
    let asset: SanityAssetReference
    let crop: SanityImageCrop?
    let hotspot: SanityImageHotspot?

    var imageURL: URL? {
        let ref = asset._ref
        guard ref.starts(with: "image-") else { return nil }
        let components = ref.dropFirst(6).split(separator: "-")
        guard components.count >= 3 else { return nil }
        
        let imageId = components[0]
        let dimensions = components[1]
        let format = components[2]
        
        let projectId = Config.sanityProjectID
        let dataset = Config.sanityDataset
        
        return URL(string: "https://cdn.sanity.io/images/\(projectId)/\(dataset)/\(imageId)-\(dimensions).\(format)")
    }
}

struct SanityAssetReference: Codable {
    let _ref: String
    let _type: String
}

struct SanityImageCrop: Codable {
    let _type: String
    let top, bottom, left, right: Double
}

struct SanityImageHotspot: Codable {
    let _type: String
    let x, y, height, width: Double
}

struct RawPortableText: Codable {
    let _type: String
    let _key: String
    let children: [TextChild]?
    let style: String?
    let listItem: String?
    let level: Int?
    let markDefs: [MarkDef]?

    var plainText: String {
        children?.compactMap { $0.text }.joined(separator: "") ?? ""
    }
}

struct TextChild: Codable {
    let _key: String
    let _type: String
    let text: String?
    let marks: [String]?
}

struct MarkDef: Codable {
    let _key: String
    let _type: String
    let href: String?
}

// MARK: - News Filter Extensions

extension Array where Element == SanityPost {
    /// Filters news posts linked to a specific credit card template ID
    func relevant(toCard templateID: String) -> [SanityPost] {
        guard !templateID.isEmpty else { return [] }
        return filter { post in
            post.linkedCards?.contains { $0.cardId == templateID } ?? false
        }
    }

    /// Filters news posts by a specific tag slug
    func filtered(byTag slug: String?) -> [SanityPost] {
        guard let slug else { return self }
        return filter { post in
            post.tags?.contains { $0.slug == slug } ?? false
        }
    }

    func filtered(byIssuer issuerID: String?) -> [SanityPost] {
        guard let issuerID else { return self }
        return filter { $0.issuerId == issuerID }
    }

    func filtered(byPartner partnerName: String?) -> [SanityPost] {
        guard let partnerName else { return self }
        return filter { $0.partner?.name?.lowercased() == partnerName.lowercased() }
    }

    func filtered(walletOnly: Bool, ownedTemplateIDs: Set<String>) -> [SanityPost] {
        guard walletOnly else { return self }
        return filter { post in
            post.linkedCards?.contains { card in
                guard let id = card.cardId else { return false }
                return ownedTemplateIDs.contains(id)
            } ?? false
        }
    }

    /// Searches through title and all three body sections for a keyword
    func filtered(bySearch text: String) -> [SanityPost] {
        let query = text.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return self }
        return filter { post in
            let titleMatch = post.title.lowercased().contains(query)
            
            // Comprehensive body search across all 3 content blocks
            let body1Match = post.body?.contains { $0.plainText.lowercased().contains(query) } == true
            let body2Match = post.header_body2?.lowercased().contains(query) == true ||
                             post.body2?.contains { $0.plainText.lowercased().contains(query) } == true
            let body3Match = post.header_body3?.lowercased().contains(query) == true ||
                             post.body3?.contains { $0.plainText.lowercased().contains(query) } == true
            
            return titleMatch || body1Match || body2Match || body3Match
        }
    }

    /// Aggregates all unique tags available across the current set of posts
    var availableTags: [TagReference] {
        var seen = Set<String>()
        return flatMap { $0.tags ?? [] }.filter { tag in
            guard let slug = tag.slug else { return false }
            return seen.insert(slug).inserted
        }
    }
}
