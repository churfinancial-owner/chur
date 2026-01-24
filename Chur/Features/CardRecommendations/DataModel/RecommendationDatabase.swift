//
//  RecommendationDatabase.swift
//  Chur
//
//  Loads card recommendation templates from bundle JSON files.
//  Folder structure: recommendations/{region}/{issuer}/rec_{cardTemplateID}.json
//

import Foundation

struct RecommendationDatabase {
    
    // MARK: - Public API
    
    /// All loaded recommendation templates, cached on first access
    static func getAllRecommendations() -> [RecommendationTemplate] {
        return cachedTemplates
    }
    
    /// Recommendations filtered by region (matches CardTemplate.country via CardDatabase)
    static func getRecommendations(for country: String) -> [RecommendationTemplate] {
        cachedTemplates.filter { template in
            guard let card = CardDatabase.getCard(id: template.cardTemplateID) else { return false }
            return card.country == country
        }
    }
    
    /// Lookup a single recommendation by cardTemplateID
    static func getRecommendation(for cardTemplateID: String) -> RecommendationTemplate? {
        templatesByID[cardTemplateID]
    }
    
    /// Force reload from bundle (e.g. after test data changes)
    static func reloadFromBundle() {
        cachedTemplates = loadAllTemplates()
        templatesByID = Dictionary(cachedTemplates.map { ($0.cardTemplateID, $0) },
                                   uniquingKeysWith: { _, last in last })
    }
    
    // MARK: - Private Cache
    
    private static var cachedTemplates: [RecommendationTemplate] = loadAllTemplates()
    private static var templatesByID: [String: RecommendationTemplate] = Dictionary(
        cachedTemplates.map { ($0.cardTemplateID, $0) },
        uniquingKeysWith: { _, last in last }
    )
    
    // MARK: - Loader
    
    private static func loadAllTemplates() -> [RecommendationTemplate] {
        let fileManager = FileManager.default
        var templates: [RecommendationTemplate] = []
        
        // Try to find recommendations folder in bundle
        let possiblePaths: [String?] = [nil, "SeedData", "recommendations"]
        
        var recommendationsURL: URL?
        for subdirectory in possiblePaths {
            let url: URL?
            if let subdir = subdirectory {
                url = Bundle.main.url(forResource: "recommendations", withExtension: nil, subdirectory: subdir)
            } else {
                url = Bundle.main.url(forResource: "recommendations", withExtension: nil)
            }
            if let url = url {
                recommendationsURL = url
                break
            }
        }
        
        // Enumerate the recommendations folder recursively
        if let recommendationsURL = recommendationsURL,
           let enumerator = fileManager.enumerator(at: recommendationsURL, includingPropertiesForKeys: [.isRegularFileKey]) {
            for case let fileURL as URL in enumerator {
                guard fileURL.pathExtension == "json",
                      fileURL.lastPathComponent.hasPrefix("rec_") else { continue }
                
                do {
                    let data = try Data(contentsOf: fileURL)
                    let template = try JSONDecoder().decode(RecommendationTemplate.self, from: data)
                    templates.append(template)
                } catch {
                    #if DEBUG
                    print("⚠️ RecommendationDatabase: Failed to load \(fileURL.lastPathComponent): \(error)")
                    #endif
                }
            }
        }
        
        // Fallback: scan bundle root for rec_*.json files
        if templates.isEmpty {
            guard let bundleURL = Bundle.main.resourceURL,
                  let allFiles = try? fileManager.contentsOfDirectory(
                    at: bundleURL,
                    includingPropertiesForKeys: [.isRegularFileKey],
                    options: .skipsHiddenFiles
                  ) else {
                return []
            }
            
            let recFiles = allFiles.filter {
                $0.pathExtension == "json" && $0.lastPathComponent.hasPrefix("rec_")
            }
            
            for fileURL in recFiles {
                do {
                    let data = try Data(contentsOf: fileURL)
                    let template = try JSONDecoder().decode(RecommendationTemplate.self, from: data)
                    templates.append(template)
                } catch {
                    #if DEBUG
                    print("⚠️ RecommendationDatabase: Failed to load \(fileURL.lastPathComponent): \(error)")
                    #endif
                }
            }
        }
        
        #if DEBUG
        print("✅ RecommendationDatabase: Loaded \(templates.count) recommendation templates")
        #endif
        
        return templates.sorted { $0.priority < $1.priority }
    }
}
