//
//  NewsCarouselComponents.swift
//  Chur
//
//  Created by Pak Ho on 5/3/26.
//

import SwiftUI
import SwiftData

struct NewsCarouselView: View {
    let posts: [SanityPost]
    @Binding var currentIndex: Int
    @State private var selectedPost: SanityPost?
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(posts.indices, id: \.self) { index in
                    Button { selectedPost = posts[index] } label: {
                        NewsCarouselCard(post: posts[index])
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 10)
        }
        .sheet(item: $selectedPost) { post in
            NewsDetailPopup(post: post, allPosts: posts)
        }
    }
}

struct NewsCarouselCard: View {
    let post: SanityPost
    @Query private var ownedCards: [CreditCard]

    private var isWalletRelevant: Bool {
        let ownedIDs = Set(ownedCards.compactMap { $0.templateID })
        return post.linkedCards?.contains { ownedIDs.contains($0.cardId ?? "") } ?? false
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 10) {
                Text(post.title).font(.churSectionHeader()).foregroundStyle(Color.churDarkGray).lineLimit(3).multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)

                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        if let body = post.body?.first?.plainText {
                            Text(body).font(.churFootnote()).foregroundStyle(Color.churMediumGray).lineLimit(3).multilineTextAlignment(.leading)
                        }
                        Text(post.formattedDate).font(.churSmall()).foregroundStyle(Color.churMediumGray)
                    }.frame(maxWidth: .infinity, alignment: .leading)

                    if let imageURL = post.postImage?.imageURL {
                        AsyncImage(url: imageURL) { phase in
                            if let image = phase.image { image.resizable().scaledToFit().frame(width: 60, height: 60) }
                            else { Color.churLightGray.frame(width: 60, height: 60) }
                        }.clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
            .padding(16).frame(width: 300, height: 160)
            .background(RoundedRectangle(cornerRadius: 16).fill(.white).shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2))

            if isWalletRelevant {
                HStack(spacing: 4) {
                    Image(systemName: "creditcard.fill")
                        .font(.system(size: 8, weight: .bold))
                    Text("IN YOUR WALLET")
                        .font(.churNanoBold())
                        .tracking(0.4)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.churGoldGradient)
                .clipShape(Capsule())
                .padding(10)
            }
        }
    }
}
