//
//  NewsView.swift
//  Chur
//
//  NewsView.swift contains:
//  - NewsFeedSection: Home screen carousel with auto-scroll, pagination, and state handling
//  - NewsCarouselView: Horizontal scroll container with page indicators
//  - NewsCarouselCard: Compact card (330×160) with image, title, body preview, date, chevron
//  - NewsItemCard: Alternative card layout (unused legacy code)
//  - NewsView: Full-screen news list with NavigationStack, pull-to-refresh, loading/error states
//  - NewsRowView: List item card with title, date, body preview
//  - NewsDetailView: Detail view with images, rich text, external links, category/region tags
//  - FlowLayout: Custom layout for wrapping tags horizontally
//  - ExternalLinkButton: Link button with icon and external indicator
//  - PortableTextView, PortableTextBlockView, FormattedTextView: Sanity CMS portable text rendering with headings, lists, formatting support
//
//  Created by Pak Ho on 2/22/26.
//

import SwiftUI

// MARK: - News Feed Section for Home View
struct NewsFeedSection: View {
    @StateObject private var newsService = NewsService()
    @State private var currentIndex = 0
    @State private var timer: Timer?
    @State private var showNewsList = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("📰 CHUR NEWS")
                    .font(.churHeadline())
                    .foregroundStyle(Color.churOlive)
                    .tracking(0.5)
                
                Spacer()
                
                if newsService.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else if !newsService.posts.isEmpty {
                    Button {
                        showNewsList = true
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.churOliveLight)
                                .frame(width: 32, height: 32)
                            
                            Image(systemName: "newspaper")
                                .font(.churImageMedium())
                                .foregroundStyle(.churDarkOlive)
                        }
                    }
                }
            }
            
            if let errorMessage = newsService.errorMessage {
                Text(errorMessage)
                    .font(.churSubheadline())
                    .foregroundStyle(Color.churMediumGray)
                    .padding()
            } else if newsService.posts.isEmpty && !newsService.isLoading {
                Text("No news available")
                    .font(.churSubheadline())
                    .foregroundStyle(Color.churMediumGray)
                    .padding()
            } else {
                NewsCarouselView(
                    posts: Array(newsService.posts.prefix(5)),
                    currentIndex: $currentIndex
                )
            }
        }
        .task {
            await newsService.fetchNews()
        }
        .onAppear {
            startAutoScroll()
        }
        .onDisappear {
            stopAutoScroll()
        }
        .sheet(isPresented: $showNewsList) {
            NewsListPopup(posts: newsService.posts)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }
    
    private func startAutoScroll() {
        timer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { _ in
            Task { @MainActor [weak newsService] in
                guard let newsService = newsService, !newsService.posts.isEmpty else { return }
                withAnimation(.easeInOut) {
                    currentIndex = (currentIndex + 1) % min(5, newsService.posts.count)
                }
            }
        }
    }
    
    private func stopAutoScroll() {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - News List Popup
private struct NewsListPopup: View {
    let posts: [SanityPost]
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPost: SanityPost?

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(posts) { post in
                        Button {
                            selectedPost = post
                        } label: {
                            NewsRowView(post: post)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color.churOffWhite)
            .navigationTitle("Chur News")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.churBigTitle4())
                            .foregroundStyle(Color.churMediumGray)
                    }
                }
            }
            .sheet(item: $selectedPost) { post in
                NewsDetailPopup(post: post)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
    }
}

// MARK: - News Carousel View
struct NewsCarouselView: View {
    let posts: [SanityPost]
    @Binding var currentIndex: Int
    @State private var selectedPost: SanityPost?
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(posts.indices, id: \.self) { index in
                    Button {
                        selectedPost = posts[index]
                    } label: {
                        NewsCarouselCard(post: posts[index])
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 0) // Align with other HomeView sections
            .padding(.vertical, 10)
        }
        .sheet(item: $selectedPost) { post in
            NewsDetailPopup(post: post)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - News Carousel Card
struct NewsCarouselCard: View {
    let post: SanityPost
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Top row: title (3 lines)
            Text(post.title)
                .font(.churSectionHeader())
                .foregroundStyle(Color.churDarkGray)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            // Bottom row split into left and right
            HStack(alignment: .top, spacing: 12) {
                // Left: body preview + date
                VStack(alignment: .leading, spacing: 8) {
                    if let body = post.body?.first?.plainText, !body.isEmpty {
                        Text(body)
                            .font(.churFootnote())
                            .foregroundStyle(Color.churMediumGray)
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                    }

                    Text(post.formattedDate)
                        .font(.churSmall())
                        .foregroundStyle(Color.churMediumGray)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Right: image block (60x60)
                Group {
                    if let imageURL = post.postImage?.imageURL ?? post.mainImage?.imageURL {
                        AsyncImage(url: imageURL) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 60, height: 60)
                            case .failure(_):
                                Rectangle()
                                    .fill(Color.churLightGray)
                                    .frame(width: 60, height: 60)
                                    .overlay {
                                        Image(systemName: "photo")
                                            .font(.caption2)
                                            .foregroundStyle(Color.churMediumGray)
                                    }
                            case .empty:
                                Rectangle()
                                    .fill(Color.churLightGray)
                                    .frame(width: 60, height: 60)
                                    .overlay {
                                        ProgressView()
                                            .scaleEffect(0.6)
                                    }
                            @unknown default:
                                Rectangle()
                                    .fill(Color.churLightGray)
                                    .frame(width: 60, height: 60)
                            }
                        }
                    } else {
                        Rectangle()
                            .fill(Color.churLightGray)
                            .frame(width: 60, height: 60)
                            .overlay {
                                Image(systemName: "photo")
                                    .font(.caption2)
                                    .foregroundStyle(Color.churMediumGray)
                            }
                    }
                }
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(16)
        .frame(width: 300, height: 160)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
        )
    }
}

struct NewsView: View {
    @StateObject private var newsService = NewsService()
    @State private var selectedPost: SanityPost?
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.churOffWhite
                    .ignoresSafeArea()
                
                if newsService.isLoading {
                    ProgressView("Loading news...")
                        .tint(.churOlive)
                } else if let errorMessage = newsService.errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.churBigTitle1())
                            .foregroundStyle(Color.churMediumGray)
                        
                        Text(errorMessage)
                            .foregroundStyle(Color.churMediumGray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button("Try Again") {
                            Task {
                                await newsService.fetchNews()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.churOlive)
                    }
                } else if newsService.posts.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "newspaper")
                            .font(.churBigTitle1())
                            .foregroundStyle(Color.churMediumGray)
                        
                        Text("No news articles yet")
                            .font(.headline)
                            .foregroundStyle(Color.churMediumGray)
                        
                        Button("Refresh") {
                            Task {
                                await newsService.fetchNews()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.churOlive)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(newsService.posts) { post in
                                Button {
                                    selectedPost = post
                                } label: {
                                    NewsRowView(post: post)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16) // Consistent alignment
                        .padding(.vertical, 16)
                    }
                }
            }
            .navigationTitle("News")
            .navigationBarTitleDisplayMode(.large)
            .task {
                // Only fetch if we don't have posts already
                if newsService.posts.isEmpty {
                    await newsService.fetchNews()
                }
            }
            .refreshable {
                await newsService.fetchNews()
            }
            .sheet(item: $selectedPost) { post in
                NewsDetailPopup(post: post)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
    }
}

private struct NewsDetailPopup: View {
    let post: SanityPost
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            NewsDetailView(post: post)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.churBigTitle4())
                                .foregroundStyle(Color.churMediumGray)
                        }
                    }
                }
        }
    }
}

// MARK: - News Row Component
struct NewsRowView: View {
    let post: SanityPost
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(post.title)
                .font(.headline)
                .foregroundStyle(.primary)
                .lineLimit(2)
            
            Text(post.formattedDate)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            if let body = post.body, !body.isEmpty {
                Text(body.first?.plainText ?? "")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.white)
        }
    }
}

// MARK: - News Detail View
struct NewsDetailView: View {
    let post: SanityPost
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 16) {
                        // Post Image as Header (right top, 90x90) + Title (left)
                        HStack(alignment: .top, spacing: 12) {
                            // Title (left side)
                            Text(post.title)
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(Color.churDarkGray)
                                .lineLimit(nil)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            // Post Image (right top, 90x90)
                            if let postImage = post.postImage?.imageURL {
                                AsyncImage(url: postImage) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 90, height: 90)
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                    case .failure(_):
                                        Rectangle()
                                            .fill(Color.churLightGray)
                                            .frame(width: 90, height: 90)
                                            .overlay {
                                                Image(systemName: "photo")
                                                    .foregroundStyle(Color.churMediumGray)
                                                    .font(.caption)
                                            }
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                    case .empty:
                                        Rectangle()
                                            .fill(Color.churLightGray)
                                            .frame(width: 90, height: 90)
                                            .overlay {
                                                ProgressView()
                                                    .scaleEffect(0.7)
                                            }
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                    @unknown default:
                                        EmptyView()
                                    }
                                }
                            }
                        }
                        .padding(.top, 20)
                        
                        // Date
                        HStack {
                            Image(systemName: "calendar")
                                .font(.caption)
                                .foregroundStyle(Color.churMediumGray)
                            Text(post.formattedDate)
                                .font(.subheadline)
                                .foregroundStyle(Color.churMediumGray)
                        }
                        
                        Divider()
                            .padding(.vertical, 8)
                        
                        // Body Content (News Details)
                        if let body = post.body, !body.isEmpty {
                            PortableTextView(blocks: body)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            Text("No content available")
                                .font(.body)
                                .foregroundStyle(Color.churMediumGray)
                                .italic()
                                .padding(.vertical, 20)
                        }
                        
                        Divider()
                            .padding(.vertical, 8)
                        
                        // External Links Section
                        if hasExternalLinks {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Related Links")
                                    .font(.headline)
                                    .foregroundStyle(Color.churOlive)
                                
                                VStack(spacing: 10) {
                                    if let links1 = post.externalLink1 {
                                        ForEach(links1, id: \._key) { link in
                                            ExternalLinkButton(link: link)
                                        }
                                    }
                                    
                                    if let links2 = post.externalLink2 {
                                        ForEach(links2, id: \._key) { link in
                                            ExternalLinkButton(link: link)
                                        }
                                    }
                                    
                                    if let links3 = post.externalLink3 {
                                        ForEach(links3, id: \._key) { link in
                                            ExternalLinkButton(link: link)
                                        }
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            
                            Divider()
                                .padding(.vertical, 8)
                        }
                        
                        // Main Image (smaller)
                        if let mainImage = post.mainImage?.imageURL {
                            AsyncImage(url: mainImage) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFit()
                                        .frame(maxWidth: geometry.size.width - 40)
                                        .frame(maxHeight: 200)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                case .failure(_):
                                    Rectangle()
                                        .fill(Color.churLightGray)
                                        .frame(height: 150)
                                        .frame(maxWidth: geometry.size.width - 40)
                                        .overlay {
                                            Image(systemName: "photo")
                                                .foregroundStyle(Color.churMediumGray)
                                        }
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                case .empty:
                                    Rectangle()
                                        .fill(Color.churLightGray)
                                        .frame(height: 150)
                                        .frame(maxWidth: geometry.size.width - 40)
                                        .overlay {
                                            ProgressView()
                                        }
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                @unknown default:
                                    EmptyView()
                                }
                            }
                            
                            Divider()
                                .padding(.vertical, 8)
                        }
                        
                        // Metadata Section (Categories, Subcategories, Region) at bottom
                        VStack(alignment: .leading, spacing: 12) {
                            // Categories
                            if let categories = post.categories, !categories.isEmpty {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Categories")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundStyle(Color.churOlive)
                                        .textCase(.uppercase)
                                    
                                    FlowLayout(spacing: 8) {
                                        ForEach(categories) { category in
                                            Text(category.displayName)
                                                .font(.caption)
                                                .lineLimit(1)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 5)
                                                .background(Color.churOliveLight)
                                                .clipShape(Capsule())
                                        }
                                    }
                                }
                            }
                            
                            // Subcategories
                            if let subcategories = post.subcategories, !subcategories.isEmpty {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Subcategories")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundStyle(Color.churOlive)
                                        .textCase(.uppercase)
                                    
                                    FlowLayout(spacing: 8) {
                                        ForEach(subcategories) { subcategory in
                                            Text(subcategory.displayName)
                                                .font(.caption)
                                                .lineLimit(1)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 5)
                                                .background(Color.churOliveLight)
                                                .clipShape(Capsule())
                                        }
                                    }
                                }
                            }
                            
                            // Region
                            if let regions = post.region, !regions.isEmpty {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Region")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundStyle(Color.churOlive)
                                        .textCase(.uppercase)
                                    
                                    FlowLayout(spacing: 8) {
                                        ForEach(regions) { region in
                                            HStack(spacing: 4) {
                                                Image(systemName: "location.fill")
                                                    .font(.churBadge())
                                                Text(region.displayName)
                                                    .font(.caption)
                                                    .lineLimit(1)
                                            }
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                            .background(Color.churInfo.opacity(0.2))
                                            .clipShape(Capsule())
                                        }
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity)
        }
        .background(Color.churOffWhite)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var hasExternalLinks: Bool {
        return !(post.externalLink1?.isEmpty ?? true) ||
               !(post.externalLink2?.isEmpty ?? true) ||
               !(post.externalLink3?.isEmpty ?? true)
    }
}

// MARK: - Flow Layout for Tags
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.frames[index].minX,
                                     y: bounds.minY + result.frames[index].minY),
                         proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize
        var frames: [CGRect]
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var frames: [CGRect] = []
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if currentX + size.width > maxWidth && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }
                
                frames.append(CGRect(x: currentX, y: currentY, width: size.width, height: size.height))
                lineHeight = max(lineHeight, size.height)
                currentX += size.width + spacing
            }
            
            self.frames = frames
            self.size = CGSize(width: maxWidth, height: currentY + lineHeight)
        }
    }
}

// MARK: - External Link Button
struct ExternalLinkButton: View {
    let link: LinkItem
    @State private var isReady = false
    
    var body: some View {
        Link(destination: URL(string: link.url)!) {
            HStack {
                Image(systemName: "link")
                    .font(.caption)
                    .foregroundStyle(Color.churOlive)
                
                Text(link.label)
                    .font(.subheadline)
                    .foregroundStyle(Color.churDarkGray)
                
                Spacer()
                
                if isReady {
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundStyle(Color.churMediumGray)
                        .transition(.opacity.combined(with: .scale))
                } else {
                    ProgressView()
                        .scaleEffect(0.7)
                        .tint(Color.churMediumGray)
                }
            }
            .padding()
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
        .onAppear {
            // Simulate validation or loading - adjust delay as needed
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeIn(duration: 0.2)) {
                    isReady = true
                }
            }
        }
    }
}

// MARK: - Portable Text Renderer
struct PortableTextView: View {
    let blocks: [RawPortableText]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(blocks.indices, id: \.self) { index in
                let block = blocks[index]
                if block._type == "block" {
                    PortableTextBlockView(block: block, blocks: blocks)
                }
            }
        }
    }
}

struct PortableTextBlockView: View {
    let block: RawPortableText
    let blocks: [RawPortableText]
    
    var body: some View {
        let style = block.style ?? "normal"
        let listItem = block.listItem
        let level = block.level ?? 1
        
        HStack(alignment: .top, spacing: 8) {
            // List item bullet/number
            if let listItem = listItem {
                let indent = CGFloat(level - 1) * 20
                Spacer()
                    .frame(width: indent)
                
                if listItem == "bullet" {
                    Text("•")
                        .font(.body)
                        .foregroundStyle(Color.churDarkGray)
                        .frame(width: 20, alignment: .leading)
                } else if listItem == "number" {
                    Text("\(getListNumber()).")
                        .font(.body)
                        .foregroundStyle(Color.churDarkGray)
                        .frame(width: 20, alignment: .leading)
                }
            }
            
            // Block content with formatting
            FormattedTextView(children: block.children ?? [], markDefs: block.markDefs ?? [], style: style)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    private func getListNumber() -> Int {
        guard let currentIndex = blocks.firstIndex(where: { $0._key == block._key }) else {
            return 1
        }
        
        var number = 1
        for i in 0..<currentIndex {
            if blocks[i].listItem == "number" && blocks[i].level == block.level {
                number += 1
            }
        }
        return number
    }
}

struct FormattedTextView: View {
    let children: [TextChild]
    let markDefs: [MarkDef]
    let style: String
    
    var body: some View {
        let attributedString = buildAttributedString()
        
        Group {
            switch style {
            case "h1":
                Text(attributedString)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(Color.churDarkGray)
            case "h2":
                Text(attributedString)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Color.churDarkGray)
            case "h3":
                Text(attributedString)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Color.churDarkGray)
            case "h4":
                Text(attributedString)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color.churDarkGray)
            case "h5":
                Text(attributedString)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.churDarkGray)
            case "h6":
                Text(attributedString)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.churDarkGray)
            case "blockquote":
                HStack(alignment: .top, spacing: 12) {
                    Rectangle()
                        .fill(Color.churOlive)
                        .frame(width: 4)
                    Text(attributedString)
                        .font(.body)
                        .italic()
                        .foregroundStyle(Color.churMediumGray)
                }
            default:
                Text(attributedString)
                    .font(.body)
                    .foregroundStyle(Color.churDarkGray)
                    .lineSpacing(4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func buildAttributedString() -> AttributedString {
        var result = AttributedString()
        
        for child in children {
            guard let text = child.text, !text.isEmpty else { continue }
            var attributedText = AttributedString(text)
            
            // Apply marks (bold, italic, etc.)
            if let marks = child.marks {
                for mark in marks {
                    switch mark {
                    case "strong":
                        attributedText.font = .body.bold()
                    case "em":
                        attributedText.font = .body.italic()
                    case "code":
                        attributedText.font = .system(.body, design: .rounded)
                        attributedText.backgroundColor = Color.churLightGray.opacity(0.3)
                    case "underline":
                        attributedText.underlineStyle = .single
                    case "strike-through":
                        attributedText.strikethroughStyle = .single
                    default:
                        // Check if it's a link mark
                        if let markDef = markDefs.first(where: { $0._key == mark }),
                           let href = markDef.href,
                           let url = URL(string: href) {
                            attributedText.link = url
                            attributedText.foregroundColor = Color.churOlive
                            attributedText.underlineStyle = .single
                        }
                    }
                }
            }
            
            result.append(attributedText)
        }
        
        return result
    }
}
