import Foundation
import Combine

@MainActor
class NewsService: ObservableObject {
    @Published var posts: [SanityPost] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let projectId = Config.sanityProjectID
    private var lastFetchedAt: Date?

    func fetchNewsIfNeeded() async {
        if !posts.isEmpty, let last = lastFetchedAt, Date().timeIntervalSince(last) < 1800 {
            return
        }
        await fetchNews()
    }

    func fetchNews() async {
        isLoading = true
        errorMessage = nil
        
        let query = """
        *[_type == "post"] | order(coalesce(publishedAt, _createdAt) desc) {
          _id,
          title,
          _createdAt,
          slug,
          postImage,

          // Dereference single document links
          "issuer": issuer->{ _id, issuer_id },
          "partner": partner->{ _id, name },
          "language": language->{ _id, name, code },
          "posttype": posttype->{ _id, posttype }, 
          
          // Dereference arrays of document links
          "linkedCards": linkedCards[]->{ _id, cardId },
          "tags": tags[]->{ _id, "slug": slug.current, label },
          "region": region[]->{ _id, region },
          
          offerHistory[] {
            _key,
            recordDate,
            signupBonus,
            spendingReq,
            annualFee,
            isCurrent,
            isAllTimeHigh
          },
          publishedAt,
          header_body1,
          body,
          isCollapsed1,
          header_body2,
          body2,
          isCollapsed2,
          header_body3,
          body3,
          isCollapsed3,
          applyLink
        }
        """
        
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "https://\(projectId).api.sanity.io/v2021-10-21/data/query/\(Config.sanityDataset)?query=\(encodedQuery)"
                
        guard let url = URL(string: urlString) else {
            errorMessage = "Invalid URL"
            isLoading = false
            return
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decodedResponse = try JSONDecoder().decode(SanityResponse.self, from: data)
            posts = decodedResponse.result
            lastFetchedAt = Date()
            isLoading = false
        } catch {
            print("Decoding Error: \(error)")
            errorMessage = "Failed to fetch news: \(error.localizedDescription)"
            isLoading = false
        }
    }
}

struct SanityResponse: Codable {
    let result: [SanityPost]
}
