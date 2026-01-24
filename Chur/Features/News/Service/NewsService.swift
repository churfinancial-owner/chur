//
//  NewsService.swift
//  Chur
//
//  NewsService.swift contains:
//  - NewsService: ObservableObject for fetching news from Sanity CMS
//    - Published properties: posts array, loading state, error messages
//    - fetchNews(): Async method that queries Sanity API with GROQ, fetches posts with dereferenced categories/subcategories/regions
//  - SanityResponse: Codable model for API response decoding
//
//  Created by Pak Ho on 2/22/26.
//

import Foundation
import Combine

@MainActor
class NewsService: ObservableObject {
    @Published var posts: [SanityPost] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let projectId = "0fcg3g46"
    
    func fetchNews() async {
        isLoading = true
        errorMessage = nil
        
        // Updated query with explicit dereferencing
        let query = """
        *[_type == "post"] | order(_createdAt desc) {
          _id,
          title,
          _createdAt,
          slug,
          body,
          externalLink1,
          externalLink2,
          externalLink3,
          mainImage,
          postImage,
          "categories": categories[]->{
            _id,
            title,
            name,
            label
          },
          "subcategories": subcategories[]->{
            _id,
            title,
            name,
            label
          },
          "region": region[]->{
            _id,
            title,
            name,
            label,
            region,
            regionName
          }
        }
        """
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        let urlString = "https://\(projectId).api.sanity.io/v2021-10-21/data/query/production?query=\(encodedQuery)"
                
        guard let url = URL(string: urlString) else {
            errorMessage = "Invalid URL"
            isLoading = false
            return
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decodedResponse = try JSONDecoder().decode(SanityResponse.self, from: data)
            posts = decodedResponse.result
            isLoading = false
        } catch {
            errorMessage = "Failed to fetch news: \(error.localizedDescription)"
            isLoading = false
        }
    }
}

// MARK: - Models for Decoding
struct SanityResponse: Codable {
    let result: [SanityPost]
}
