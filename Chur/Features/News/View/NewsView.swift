import SwiftUI
import SwiftData

struct NewsView: View {
    @EnvironmentObject private var newsService: NewsService
    @Environment(\.dismiss) private var dismiss
    @Query private var ownedCards: [CreditCard]

    @State private var selectedPost: SanityPost?
    @State private var selectedTagSlug: String? = nil
    @State private var selectedIssuerID: String? = nil
    @State private var selectedPartnerName: String? = nil
    @State private var walletOnly = false
    @State private var searchText = ""

    private var ownedTemplateIDs: Set<String> {
        Set(ownedCards.compactMap { $0.templateID })
    }

    private var hasActiveFilters: Bool {
        walletOnly || selectedTagSlug != nil || selectedIssuerID != nil || selectedPartnerName != nil
    }

    private var filteredPosts: [SanityPost] {
        newsService.posts
            .filtered(walletOnly: walletOnly, ownedTemplateIDs: ownedTemplateIDs)
            .filtered(byTag: selectedTagSlug)
            .filtered(byIssuer: selectedIssuerID)
            .filtered(byPartner: selectedPartnerName)
            .filtered(bySearch: searchText)
    }

    private var availableIssuers: [Issuer] {
        var seen = Set<String>()
        return newsService.posts
            .compactMap { $0.issuerId }
            .compactMap { id in
                guard seen.insert(id).inserted else { return nil }
                return IssuerDatabase.byID[id]
            }
    }

    private var availablePartners: [(name: String, partner: Partner)] {
        var seen = Set<String>()
        return newsService.posts.compactMap { post -> (String, Partner)? in
            guard let pName = post.partner?.name else { return nil }
            let key = pName.lowercased()
            guard seen.insert(key).inserted else { return nil }
            guard let partner = PartnerDatabase.byID[pName]
                ?? PartnerDatabase.allPartners.first(where: { $0.name.lowercased() == key })
            else { return nil }
            return (pName, partner)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                newsHeader
                Divider()

                if newsService.isLoading && newsService.posts.isEmpty {
                    Spacer()
                    ProgressView("Loading news...").tint(Color.churOlive)
                    Spacer()
                } else if let error = newsService.errorMessage, newsService.posts.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.churHero())
                            .foregroundStyle(Color.churMediumGray)
                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(Color.churMediumGray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        Button("Try Again") { Task { await newsService.fetchNews() } }
                            .buttonStyle(.borderedProminent)
                            .tint(Color.churOlive)
                    }
                    Spacer()
                } else if filteredPosts.isEmpty {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.churBigTitle3())
                            .foregroundStyle(Color.churLightGray)
                        Text("No results")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.churMediumGray)
                        if hasActiveFilters || !searchText.isEmpty {
                            Button("Clear filters") { clearAllFilters() }
                                .font(.subheadline)
                                .foregroundStyle(Color.churOlive)
                                .padding(.top, 4)
                        }
                    }
                    Spacer()
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredPosts) { post in
                                Button { selectedPost = post } label: {
                                    NewsRowView(post: post)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 24)
                    }
                }
            }
            .background(Color.churOffWhite.ignoresSafeArea())
            .navigationBarHidden(true)
            .task { await newsService.fetchNewsIfNeeded() }
            .sheet(item: $selectedPost) { post in
                NewsDetailPopup(post: post, allPosts: newsService.posts)
            }
        }
    }

    private func clearAllFilters() {
        searchText = ""
        selectedTagSlug = nil
        selectedIssuerID = nil
        selectedPartnerName = nil
        walletOnly = false
    }
}

// MARK: - Header

private extension NewsView {

    var newsHeader: some View {
        VStack(spacing: 0) {
            // Title row
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.churTitle2())
                        .foregroundStyle(Color.churLightGray)
                }
                Spacer()
                Text("Chur News")
                    .font(.churSubheadline())
                    .foregroundStyle(Color.churDarkGray)
                Spacer()
                Button { Task { await newsService.fetchNews() } } label: {
                    if newsService.isLoading {
                        ProgressView().scaleEffect(0.75).tint(Color.churOlive)
                            .frame(width: 22, height: 22)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.churRowTextMedium())
                            .foregroundStyle(Color.churOlive)
                            .frame(width: 22, height: 22)
                    }
                }
                .disabled(newsService.isLoading)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            // Search bar with embedded active-filter chips
            smartSearchBar

            // Unified filter pills row
            filterPillsRow
        }
        .background(Color.churOffWhite)
    }

    // MARK: Smart search bar

    var smartSearchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.churFootnote())
                .foregroundStyle(Color.churMediumGray)

            HStack(spacing: 6) {
                if walletOnly {
                    inlineChip(text: "My Wallet", icon: "creditcard.fill", color: Color.churOlive.opacity(0.15)) {
                        withAnimation(.spring(response: 0.25)) { walletOnly = false }
                    }
                }
                if let id = selectedIssuerID, let issuer = IssuerDatabase.byID[id] {
                    inlineChip(text: issuer.shortName, color: Color.blue.opacity(0.12)) {
                        withAnimation(.spring(response: 0.25)) { selectedIssuerID = nil }
                    }
                }
                if let name = selectedPartnerName {
                    inlineChip(text: name, color: Color.purple.opacity(0.1)) {
                        withAnimation(.spring(response: 0.25)) { selectedPartnerName = nil }
                    }
                }
                if let slug = selectedTagSlug,
                   let tag = newsService.posts.availableTags.first(where: { $0.slug == slug }) {
                    inlineChip(text: "#\(tag.label ?? slug)", color: Color.churOlive.opacity(0.12)) {
                        withAnimation(.spring(response: 0.25)) { selectedTagSlug = nil }
                    }
                }

                TextField(hasActiveFilters ? "" : "Search news...", text: $searchText)
                    .font(.churRowTextRegular())
                    .autocorrectionDisabled()
            }

            if !searchText.isEmpty || hasActiveFilters {
                Button { clearAllFilters() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.churCaptionRegular())
                        .foregroundStyle(Color.churLightGray)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Color.churLightGray.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
        .animation(.spring(response: 0.25), value: hasActiveFilters)
        .animation(.spring(response: 0.25), value: walletOnly)
        .animation(.spring(response: 0.25), value: selectedTagSlug)
        .animation(.spring(response: 0.25), value: selectedIssuerID)
        .animation(.spring(response: 0.25), value: selectedPartnerName)
    }

    func inlineChip(text: String, icon: String? = nil, color: Color, onRemove: @escaping () -> Void) -> some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon)
                    .font(.churBadgeBold())
            }
            Text(text)
                .font(.churSmallBold())
                .lineLimit(1)
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.churNanoBold())
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color)
        .foregroundStyle(Color.churDarkGray)
        .clipShape(Capsule())
    }

    // MARK: Filter pills row

    var filterPillsRow: some View {
        let tags = newsService.posts.availableTags
        let issuers = availableIssuers
        let partners = availablePartners
        let showRow = !ownedCards.isEmpty || !issuers.isEmpty || !partners.isEmpty || !tags.isEmpty

        return Group {
            if showRow {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        // My Wallet toggle
                        if !ownedCards.isEmpty {
                            filterTogglePill(
                                label: "My Wallet",
                                icon: "creditcard.fill",
                                isSelected: walletOnly,
                                selectedColor: Color.churOlive
                            ) {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                    walletOnly.toggle()
                                }
                            }
                        }

                        // Issuers
                        if !issuers.isEmpty {
                            if !ownedCards.isEmpty { pillDivider }
                            ForEach(issuers) { issuer in
                                filterImagePill(
                                    label: issuer.shortName,
                                    imageName: issuer.logoImageName,
                                    isSelected: selectedIssuerID == issuer.id,
                                    selectedColor: Color.blue.opacity(0.75)
                                ) {
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                        selectedIssuerID = selectedIssuerID == issuer.id ? nil : issuer.id
                                    }
                                }
                            }
                        }

                        // Partners
                        if !partners.isEmpty {
                            if !issuers.isEmpty || !ownedCards.isEmpty { pillDivider }
                            ForEach(partners, id: \.name) { item in
                                filterImagePill(
                                    label: item.partner.shortName,
                                    imageName: item.partner.logoImageName,
                                    isSelected: selectedPartnerName == item.name,
                                    selectedColor: Color.purple.opacity(0.75)
                                ) {
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                        selectedPartnerName = selectedPartnerName == item.name ? nil : item.name
                                    }
                                }
                            }
                        }

                        // Tags
                        if !tags.isEmpty {
                            if !partners.isEmpty || !issuers.isEmpty || !ownedCards.isEmpty { pillDivider }
                            ForEach(tags) { tag in
                                filterTagPill(tag)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }
            }
        }
    }

    var pillDivider: some View {
        Rectangle()
            .fill(Color.churLightGray.opacity(0.5))
            .frame(width: 1, height: 18)
    }

    func filterTogglePill(label: String, icon: String, isSelected: Bool, selectedColor: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.churMicroBold())
                Text(label)
                    .font(isSelected ? .churFootnoteBold() : .churFootnoteMedium())
            }
            .foregroundStyle(isSelected ? .white : Color.churDarkGray)
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background(isSelected ? selectedColor : Color.white)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(isSelected ? 0 : 0.05), radius: 4, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }

    func filterImagePill(label: String, imageName: String?, isSelected: Bool, selectedColor: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let imageName {
                    Image(imageName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 14, height: 14)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
                Text(label)
                    .font(isSelected ? .churFootnoteBold() : .churFootnoteMedium())
            }
            .foregroundStyle(isSelected ? .white : Color.churDarkGray)
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background(isSelected ? selectedColor : Color.white)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(isSelected ? 0 : 0.05), radius: 4, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }

    func filterTagPill(_ tag: TagReference) -> some View {
        let isSelected = selectedTagSlug == tag.slug
        return Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                selectedTagSlug = isSelected ? nil : tag.slug
            }
        } label: {
            HStack(spacing: 3) {
                Text("#")
                    .font(.churMicroBold())
                    .opacity(0.55)
                Text(tag.label ?? tag.slug ?? "")
                    .font(isSelected ? .churFootnoteBold() : .churFootnoteMedium())
            }
            .foregroundStyle(isSelected ? .white : Color.churDarkGray)
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background(isSelected ? Color.churOlive : Color.white)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(isSelected ? 0 : 0.05), radius: 4, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }
}
