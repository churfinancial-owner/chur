import SwiftUI
import SwiftData

struct PointTransferView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var cards: [CreditCard]
    
    // MARK: - State Management
    @State private var searchText: String = ""
    @State private var selectedItem: String? = nil
    @State private var isBankSelected: Bool = false
    
    @State private var filteredBanks: [String] = []
    @State private var filteredAirlines: [String] = []
    @State private var filteredHotels: [String] = []

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView {
                LazyVStack(spacing: 0) {
                    PatternHeaderBanner(imageName: "HeaderPattern5")

                    VStack(alignment: .leading, spacing: 28) {
                        heroHeader
                        searchBar
                        
                        if !filteredBanks.isEmpty {
                            partnerSection(title: "POINT SOURCES", icon: "building.columns.fill", items: filteredBanks, color: .blue, isBank: true)
                        }
                        
                        if !filteredAirlines.isEmpty {
                            partnerSection(title: "AIRLINES", icon: "airplane", items: filteredAirlines, color: .purple, isBank: false)
                        }
                        
                        if !filteredHotels.isEmpty {
                            partnerSection(title: "HOTELS", icon: "bed.double.fill", items: filteredHotels, color: .orange, isBank: false)
                        }
                        
                        if !searchText.isEmpty && filteredBanks.isEmpty && filteredAirlines.isEmpty && filteredHotels.isEmpty {
                            emptySearchState
                        }
                        
                        Spacer(minLength: 60)
                    }
                    .padding(.horizontal, 22)
                }
            }
            .background(Color.churOffWhite)
            .ignoresSafeArea(edges: .top)

            dismissButton
        }
        .onAppear { runSearch() }
        // Updated to the non-deprecated onChange syntax
        .onChange(of: searchText) { _, _ in runSearch() }
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Logic
    private func runSearch() {
        // Use a standard Task. 'detached' is often overkill unless
        // the filtering takes seconds.
        Task {
            let query = searchText.lowercased()
            
            let b = TransferPartnerDatabase.displayNames.filter { query.isEmpty || $0.localizedCaseInsensitiveContains(query) }
            let a = TransferPartnerDatabase.airlines.filter { query.isEmpty || $0.localizedCaseInsensitiveContains(query) }
            let h = TransferPartnerDatabase.hotels.filter { query.isEmpty || $0.localizedCaseInsensitiveContains(query) }
            
            // UI updates must happen on the MainActor
            await MainActor.run {
                withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.8)) {
                    self.filteredBanks = b
                    self.filteredAirlines = a
                    self.filteredHotels = h
                }
            }
        }
    }

    // MARK: - Subviews
    private var heroHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TRAVEL")
                .font(.churBadgeBold())
                .foregroundStyle(.black)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Color.churPillColor1Orange).clipShape(Capsule())

            Text("Transfer Partners")
                .font(.churTitle())
                .foregroundStyle(Color.churDarkGray)
            
            headerDescription
                .font(.churFootnoteMedium())
                .foregroundStyle(Color.churMediumGray)
                .lineSpacing(3)
        }
        .padding(.top, 16)
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.churMediumGray)
            
            TextField("Search partners...", text: $searchText)
                .font(.churCaptionMedium())
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
            
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.churMediumGray)
                }
            }
        }
        .padding(12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
        .padding(.top, 4)
    }

    private var headerDescription: Text {
        Text("Tap to see paths. Blue ") +
        Text(Image(systemName: "creditcard.fill")).foregroundColor(.blue) +
        Text(" means active; yellow ") +
        Text(Image(systemName: "lock.fill")).foregroundColor(.yellow) +
        Text(" is locked.")
    }

    private var dismissButton: some View {
        SheetDismissButton { dismiss() }
    }

    @ViewBuilder
    private func partnerSection(title: String, icon: String, items: [String], color: Color, isBank: Bool) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: icon)
                .font(.churMicroBold())
                .foregroundStyle(Color.churMediumGray)
                .tracking(1.1)

            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(items, id: \.self) { item in
                    let logo = getLogoName(for: item, isBank: isBank)
                    
                    PartnerTile(
                        name: item,
                        logoName: logo,
                        color: color,
                        isSelected: selectedItem == item,
                        isHighlighted: isNodeHighlighted(nodeName: item, isBankNode: isBank),
                        walletStatus: isBank ? userHasProgram(item) : nil,
                        allianceLogo: TransferPartnerDatabase.allianceImage(for: item)
                    ) {
                        handleTap(name: item, isBank: isBank)
                    }
                }
            }
        }
    }

    private func getLogoName(for item: String, isBank: Bool) -> String? {
        if isBank { return IssuerDatabase.byName[item]?.logoImageName }
        return TransferPartnerDatabase.partnerIcons[item]
    }

    private func userHasProgram(_ displayName: String) -> Bool {
        guard let name = TransferPartnerDatabase.programName(for: displayName) else { return false }
        let userProgramNames = Set(cards.flatMap { $0.activeRewards.map { $0.rewardProgramName } })
        return userProgramNames.contains(name)
    }

    private func handleTap(name: String, isBank: Bool) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            selectedItem = (selectedItem == name) ? nil : name
            isBankSelected = isBank
        }
    }

    private func isNodeHighlighted(nodeName: String, isBankNode: Bool) -> Bool {
        guard let selected = selectedItem else { return false }
        if isBankSelected {
            return !isBankNode && (TransferPartnerDatabase.mappings[selected]?.contains(nodeName) ?? false)
        } else {
            return isBankNode && (TransferPartnerDatabase.mappings[nodeName]?.contains(selected) ?? false)
        }
    }

    private var emptySearchState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass").font(.churHero()).foregroundColor(.churMediumGray.opacity(0.5))
            Text("No partners found for '\(searchText)'").font(.churCaption()).foregroundColor(.churMediumGray)
        }
        .frame(maxWidth: .infinity).padding(.top, 40)
    }
}

// MARK: - Partner Tile Component
struct PartnerTile: View {
    let name: String
    let logoName: String?
    let color: Color
    let isSelected: Bool
    let isHighlighted: Bool
    var walletStatus: Bool? = nil
    var allianceLogo: String? = nil
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(isSelected ? .white.opacity(0.25) : color.opacity(0.08))
                        .frame(width: 32, height: 32)
                    
                    if let logoName {
                        Image(logoName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                            .clipShape(Circle())
                    } else {
                        Image(systemName: fallbackIcon)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(isSelected ? .white : color)
                    }
                }
                
                Text(name)
                    .font(.churMicroBold())
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .foregroundColor(isSelected ? .white : Color.churDarkGray)
                
                Spacer(minLength: 0)
                
                VStack(alignment: .trailing, spacing: 4) {
                    if let allianceLogo {
                        Image(allianceLogo).resizable().scaledToFit().frame(width: 14, height: 14)
                    }
                    if let hasCard = walletStatus {
                        Image(systemName: hasCard ? "creditcard.fill" : "lock.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(hasCard ? (isSelected ? .white : .blue) : .yellow)
                    }
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 64)
            .background(isSelected ? color : (isHighlighted ? color.opacity(0.12) : Color.white))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected || isHighlighted ? color : Color.black.opacity(0.04), lineWidth: 1.5)
            )
            .shadow(color: isSelected ? color.opacity(0.25) : .clear, radius: 6, y: 3)
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.04 : 1.0)
    }

    private var fallbackIcon: String {
        if color == .purple { return "airplane" }
        if color == .orange { return "bed.double.fill" }
        return "sparkles"
    }
}
