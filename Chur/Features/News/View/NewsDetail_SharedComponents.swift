import SwiftUI

// MARK: - Shared view helpers used by all news detail posts

extension NewsDetailView {

    var headerSection: some View {
        Group {
            if post.isCardPost {
                cardHeroSection(card: linkedCardsList.first)
            } else {
                ZStack(alignment: .bottom) {
                    LinearGradient(colors: [brandAccent.opacity(0.8), brandAccent.opacity(0.4), .clear],
                                   startPoint: .top, endPoint: .bottom)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    heroBadge.offset(y: 20)
                }
                .frame(height: 100)
                .padding(.bottom, 20)
            }
        }
    }

    var heroBadge: some View {
        Group {
            if let heroURL = post.postImage?.imageURL {
                AsyncImage(url: heroURL) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())
                    } else {
                        Image(systemName: "storefront.fill")
                            .foregroundStyle(Color.churLightGray)
                            .frame(width: 80, height: 80)
                    }
                }
            }
        }
        .frame(width: 80, height: 80)
        .padding(4)
        .background(Circle().fill(.white))
        .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 5)
    }

    var titleSection: some View {
        Text(post.title)
            .font(.churTitle2())
            .multilineTextAlignment(.center)
            .foregroundStyle(Color.churDarkGray)
            .padding(.horizontal, 32)
            .frame(maxWidth: .infinity)
    }

    func collapsibleBodySection(header: String, blocks: [RawPortableText], isExpanded: Binding<Bool>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { isExpanded.wrappedValue.toggle() }
            } label: {
                HStack {
                    Text(header).font(.churHeadline())
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.churCaption())
                        .rotationEffect(.degrees(isExpanded.wrappedValue ? 90 : 0))
                        .foregroundStyle(Color.churMediumGray)
                }
                .padding(.vertical, 16).padding(.horizontal, 20)
                .background(surfaceColor).clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            if isExpanded.wrappedValue {
                PortableTextView(blocks: blocks).padding(.horizontal, 8).padding(.bottom, 8).transition(.opacity)
            }
        }
        .padding(.horizontal, 20)
    }

    func offerBentoBox(currentOffer: OfferRecord) -> some View {
        let pastOffers = (post.offerHistory ?? []).filter { $0.isCurrent != true && $0.hasContent }
        return VStack(spacing: 0) {
            if currentOffer.isAllTimeHigh == true {
                HStack {
                    Image(systemName: "sparkles")
                    Text("ALL-TIME HIGH OFFER").font(.churMicroBold()).tracking(1.5)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 10).background(Color.churWarning).foregroundStyle(.white)
            }
            VStack(spacing: 0) {
                HStack {
                    Text("Current Offer").font(.churSmallBold()).foregroundStyle(brandAccent)
                    Spacer()
                    if !pastOffers.isEmpty {
                        Button { withAnimation(.spring()) { showOfferHistory.toggle() } } label: {
                            Text(showOfferHistory ? "Hide History" : "View History")
                                .font(.churMicroBold()).foregroundStyle(Color.churInfo)
                        }
                    }
                }.padding([.horizontal, .top], 20)
                HStack(spacing: 0) {
                    bentoItem(value: currentOffer.signupBonus ?? "—", label: "Bonus")
                    bentoItem(value: currentOffer.spendingReq ?? "—", label: "Spend")
                    bentoItem(value: currentOffer.annualFee == 0 ? "No Fee" : "$\(Int(currentOffer.annualFee ?? 0))", label: "Fee")
                }.padding(.vertical, 24)
                if showOfferHistory {
                    VStack(alignment: .leading, spacing: 0) {
                        Divider().padding(.horizontal, 20)
                        ForEach(pastOffers) { record in historyRow(record: record) }
                    }.transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .background(surfaceColor)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.04), radius: 20, x: 0, y: 10)
    }

    private func historyRow(record: OfferRecord) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 0) {
                Text(record.formattedDate ?? "—")
                    .font(.churMicroBold()).foregroundStyle(Color.churDarkGray)
                    .frame(width: 75, alignment: .leading)
                VStack(alignment: .leading, spacing: 2) {
                    Text(record.signupBonus ?? "—")
                        .font(.churMicroBold()).foregroundStyle(Color.churDarkGray)
                    Text("Spend \(record.spendingReq ?? "—") • Fee \(record.annualFee == 0 ? "None" : "$\(Int(record.annualFee ?? 0))")")
                        .font(.churBadge()).foregroundStyle(Color.churMediumGray)
                }
                Spacer()
                if record.isAllTimeHigh == true {
                    Image(systemName: "trophy.fill").font(.churBadge()).foregroundStyle(Color.churWarning).padding(.leading, 8)
                }
            }.padding(.horizontal, 20).padding(.vertical, 12)
            Divider().padding(.leading, 20)
        }.background(Color.churOffWhite.opacity(0.2))
    }

    private func bentoItem(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.churHeadline()).foregroundStyle(Color.churDarkGray)
            Text(label).font(.churBadgeBold()).foregroundStyle(Color.churMediumGray).textCase(.uppercase)
        }.frame(maxWidth: .infinity)
    }

    var footerTagsSection: some View {
        let issuer = IssuerDatabase.byID[post.issuerId ?? ""]
            ?? IssuerDatabase.allIssuers.first { $0.name.lowercased() == (post.issuerId ?? "").lowercased() }
        let partnerKey = post.partner?.name ?? ""
        let partner = PartnerDatabase.byID[partnerKey]
            ?? PartnerDatabase.allPartners.first { $0.name.lowercased() == partnerKey.lowercased() }

        return VStack(alignment: .leading, spacing: 16) {
            Divider().padding(.bottom, 4)

            FlowLayout(spacing: 8) {
                if let issuer {
                    entityChip(name: issuer.shortName, imageName: issuer.logoImageName)
                }
                if let partner {
                    entityChip(name: partner.shortName, imageName: partner.logoImageName)
                }
                if let langName = post.language?.name {
                    tagPill(text: langName, color: Color.churOliveLight2.opacity(0.2), icon: "globe")
                }
                ForEach(post.region ?? []) { reg in
                    if let regionName = reg.region {
                        tagPill(text: regionName, color: Color.churInfo.opacity(0.1), icon: "location.fill")
                    }
                }
                ForEach(post.tags ?? []) { tag in
                    if let label = tag.label {
                        tagPill(text: label, color: Color.churOlive.opacity(0.1), icon: "tag.fill")
                    }
                }
            }

            Text("Updated \(post.formattedDate)")
                .font(.churMicroBold())
                .foregroundStyle(Color.churMediumGray)
                .textCase(.uppercase)
                .tracking(1.0)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 8)
        }
        .padding(.horizontal, 24)
        .padding(.top, 32)
    }

    private func entityChip(name: String, imageName: String?) -> some View {
        HStack(spacing: 6) {
            if let imageName {
                Image(imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            }
            Text(name)
                .font(.churSmallBold())
                .foregroundStyle(Color.churDarkGray)
        }
        .frame(height: 32)
        .padding(.horizontal, 12)
        .background(Color.white)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    private func tagPill(text: String, color: Color, icon: String? = nil) -> some View {
        HStack(spacing: 5) {
            if let icon { Image(systemName: icon).font(.churBadge()) }
            Text(text).font(.churSmallBold())
        }
        .frame(height: 32)
        .padding(.horizontal, 12)
        .background(color)
        .foregroundStyle(Color.churDarkGray)
        .clipShape(Capsule())
    }

    var stickyApplyBar: some View {
        Group {
            if let link = post.applyLink, let url = URL(string: link) {
                Link(destination: url) {
                    HStack(spacing: 6) {
                        Text("Apply")
                            .font(.churCaption())
                        Image(systemName: "arrow.up.right")
                            .font(.churSmallBold())
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 11)
                    .background(brandAccent)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                    .shadow(color: brandAccent.opacity(0.35), radius: 10, x: 0, y: 5)
                }
                .padding(.trailing, 24)
                .padding(.bottom, 40)
            }
        }
    }
}
