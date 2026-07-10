//
//  reset_refresh_tool.swift
//  Chur
//
//  Created by Pak Ho on 3/9/26.
//

import SwiftUI
import SwiftData

@Observable
class UserDashboardViewModel {
    var isResettingData = false
    var showResetSuccessBanner = false
    
    // MARK: - Add All Region Cards (Debug)
    
    /// Adds every card from CardDatabase that matches the user's region,
    /// skipping any already in the wallet.
    func addAllRegionCards(modelContext: ModelContext) {
        guard let user = try? modelContext.fetch(FetchDescriptor<User>()).first else { return }
        let region = user.country
        
        let existingTemplateIDs = Set(
            (try? modelContext.fetch(FetchDescriptor<CreditCard>()))?.compactMap { $0.templateID } ?? []
        )
        
        let allTemplates = CardDatabase.getAllCards()
        let regionTemplates = allTemplates.filter { $0.country == region && !existingTemplateIDs.contains($0.id) }
        
        guard !regionTemplates.isEmpty else {
            #if DEBUG
            print("⚠️ No new cards to add for region \(region)")
            #endif
            triggerSuccessBanner()
            return
        }
        
        var existingCategorySet = Set(user.selectedCategories)
        var newCategories: [String] = []
        
        for template in regionTemplates {
            let newCard = template.toCreditCard(modelContext: modelContext)
            
            if !user.cardDisplayOrder.contains(newCard.id) {
                user.cardDisplayOrder.append(newCard.id)
            }
            
            let cardCategories = newCard.activeRewards.compactMap { $0.categories }.joined()
            for categoryID in cardCategories where categoryID != "merchants" {
                if !existingCategorySet.contains(categoryID) {
                    existingCategorySet.insert(categoryID)
                    newCategories.append(categoryID)
                }
            }
        }
        
        if !newCategories.isEmpty {
            user.selectedCategories.append(contentsOf: newCategories)
        }
        
        #if DEBUG
        print("✅ Added \(regionTemplates.count) cards for region \(region)")
        #endif
        
        triggerSuccessBanner()
    }
    
    // MARK: - Reload Logic
    func reloadAllJSONs(region: String = "US", modelContext: ModelContext) {
        // Core data catalogs
        BenefitDatabase.reloadFromBundle()
        CardDatabase.reloadFromBundle()
        TransferPartnerDatabase.loadFromBundle(region: region)
        
        // Reference data
        IssuerDatabase.reloadFromBundle()
        OnlineMerchantDatabase.reloadFromBundle()
        RegionDatabase.reloadFromBundle()
        BadgeDatabase.reloadFromBundle()
        
        // Merchant mapping cache
        MerchantCategoryMapper.reloadFromBundle()
        
        // SwiftData-persisted categories (delete + re-insert)
        SeedDataLoader.reloadCategories(into: modelContext)
        
        // Sync categories with latest bundle templates
        CategorySyncService.syncCategories(modelContext: modelContext)
        
        // Sync persisted wallet cards with the freshly-reloaded templates
        CardSyncService.syncWalletCards(modelContext: modelContext)
        
        #if DEBUG
        print("✅ All JSONs reloaded from bundle (benefits, cards, transfer partners, issuers, merchants, regions, badges, merchant mappings, categories)")
        #endif
        
        triggerSuccessBanner()
    }
    
    // MARK: - Data Reset Logic
    
    /// Wipes ALL persisted data (SwiftData + UserDefaults), refreshes JSON caches,
    /// and returns the app to the onboarding screen as if freshly installed.
    func resetAllData(modelContext: ModelContext) {
        guard !isResettingData else { return }
        isResettingData = true
        
        #if DEBUG
        TestDataConfiguration.resetToRealTime()
        #endif
        
        // 1. Nuke all SwiftData in one shot — no cascade ordering issues.
        do {
            try modelContext.container.erase()
            #if DEBUG
            print("✅ ModelContainer erased — all persisted data removed")
            #endif
        } catch {
            #if DEBUG
            print("❌ ModelContainer erase failed: \(error)")
            #endif
        }
        
        // 2. Clear all UserDefaults for this app
        clearAllUserDefaults()
        
        // 3. Refresh in-memory JSON caches so they're ready for the next session
        BenefitDatabase.reloadFromBundle()
        CardDatabase.reloadFromBundle()
        TransferPartnerDatabase.loadFromBundle()
        IssuerDatabase.reloadFromBundle()
        OnlineMerchantDatabase.reloadFromBundle()
        RegionDatabase.reloadFromBundle()
        BadgeDatabase.reloadFromBundle()
        MerchantCategoryMapper.reloadFromBundle()
        
        // 4. Notify the rest of the app
        NotificationCenter.default.post(name: .appDataDidReset, object: nil)
        
        isResettingData = false
        
        #if DEBUG
        print("✅ Full reset complete — app will return to onboarding")
        #endif
    }

    private func triggerSuccessBanner() {
        withAnimation {
            showResetSuccessBanner = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation {
                self.showResetSuccessBanner = false
            }
        }
    }

    private func clearAllUserDefaults() {
        guard let bundleID = Bundle.main.bundleIdentifier else { return }
        UserDefaults.standard.removePersistentDomain(forName: bundleID)
        UserDefaults.standard.synchronize()
    }
}

extension NSNotification.Name {
    static let appDataDidReset = NSNotification.Name("appDataDidReset")
}

struct DeveloperToolsSection: View {
    // These bindings allow this sub-view to trigger the sheets and alerts
    // that live in your main UserDashboardView
    @Binding var showingTimeTravel: Bool
    @Binding var showResetAlert: Bool
    
    // These closures let us call functions from the main view
    let onReloadJSONs: () -> Void
    let onAddAllRegionCards: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            Text("DEVELOPER TOOLS")
                .font(.churSmallBold())
                .foregroundStyle(Color.churMediumGray)
                .tracking(1)
            
            // 1. Time Travel
            Button {
                showingTimeTravel = true
            } label: {
                devButtonLabel(text: "Time Travel", icon: "clock.arrow.circlepath", color: .orange)
            }
            
            // 2. Add All Region Cards
            Button {
                onAddAllRegionCards()
            } label: {
                devButtonLabel(text: "Add All Region Cards", icon: "plus.rectangle.on.rectangle", color: .purple)
            }
            
            // 3. Reload JSONs
            Button {
                onReloadJSONs()
            } label: {
                devButtonLabel(text: "Reload All JSONs", icon: "arrow.triangle.2.circlepath", color: .blue)
            }
            
            // 4. Delete All Data
            Button {
                showResetAlert = true
            } label: {
                devButtonLabel(text: "Delete All Data", icon: "trash", color: .red)
            }
        }
        .padding(.top, 20)
    }
    
    // Helper function to keep the button code clean
    private func devButtonLabel(text: String, icon: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
            Text(text)
        }
        .font(.churCaption())
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
