//
//  NewsFeedSection.swift
//  Chur
//
//  Created by Pak Ho on 5/3/26.
//

import SwiftUI

struct NewsFeedSection: View {
    @EnvironmentObject private var newsService: NewsService
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
                    ProgressView().scaleEffect(0.8)
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
        .task { await newsService.fetchNewsIfNeeded() }
        .onAppear { startAutoScroll() }
        .onDisappear { stopAutoScroll() }
        .sheet(isPresented: $showNewsList) {
            NewsView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }
    
    private func startAutoScroll() {
        timer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { _ in
            Task { @MainActor in
                guard !newsService.posts.isEmpty else { return }
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
