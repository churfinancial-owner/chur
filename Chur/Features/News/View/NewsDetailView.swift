import SwiftUI
import SwiftData

struct NewsDetailView: View {
    let post: SanityPost
    var allPosts: [SanityPost] = []

    @Query var categories: [SpendingCategory]

    @State var showOfferHistory = false
    @State var showBody1: Bool
    @State var showBody2: Bool
    @State var showBody3: Bool
    @State var showRewards = false
    @State var linkedNewsPost: SanityPost?

    let brandAccent: Color = .churOliveDark
    let surfaceColor: Color = .white
    let backgroundColor: Color = Color.churOffWhite

    init(post: SanityPost, allPosts: [SanityPost] = []) {
        self.post = post
        self.allPosts = allPosts
        _showBody1 = State(initialValue: !(post.isCollapsed1 ?? false))
        _showBody2 = State(initialValue: !(post.isCollapsed2 ?? true))
        _showBody3 = State(initialValue: !(post.isCollapsed3 ?? true))
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    headerSection

                    VStack(alignment: .leading, spacing: 32) {
                        titleSection

                        if !linkedCardsList.isEmpty && !post.isCardPost {
                            cardChipsCarousel
                        }

                        if let currentOffer = post.currentOffer, currentOffer.hasContent {
                            offerBentoBox(currentOffer: currentOffer)
                                .padding(.horizontal, 20)
                        }

                        VStack(spacing: 16) {
                            if let body = post.body, !body.isEmpty {
                                collapsibleBodySection(
                                    header: post.header_body1 ?? "Overview",
                                    blocks: body,
                                    isExpanded: $showBody1
                                )
                            }
                            if let body2 = post.body2, !body2.isEmpty {
                                collapsibleBodySection(
                                    header: post.header_body2 ?? "More Details",
                                    blocks: body2,
                                    isExpanded: $showBody2
                                )
                            }
                            if let body3 = post.body3, !body3.isEmpty {
                                collapsibleBodySection(
                                    header: post.header_body3 ?? "Additional Details",
                                    blocks: body3,
                                    isExpanded: $showBody3
                                )
                            }
                            if post.isCardPost {
                                cardRewardRatesSection
                            }
                        }

                        footerTagsSection

                        Spacer(minLength: post.applyLink != nil ? 100 : 40)
                    }
                }
            }
            .ignoresSafeArea(edges: .top)

            stickyApplyBar
        }
        .background(backgroundColor)
        .navigationBarHidden(true)
        .sheet(item: $linkedNewsPost) { linked in
            NewsDetailPopup(post: linked, allPosts: allPosts)
        }
    }

    var linkedCardsList: [(cardId: String, template: CardTemplate)] {
        (post.linkedCards ?? []).compactMap { ref in
            guard let id = ref.cardId, let template = CardDatabase.getCard(id: id) else { return nil }
            return (cardId: id, template: template)
        }
    }
}
