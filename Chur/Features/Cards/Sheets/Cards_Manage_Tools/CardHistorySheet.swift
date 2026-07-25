//
//  CardHistorySheet.swift
//  Chur
//
//  A single chronological timeline across every card the user has ever added —
//  active, cancelled, and product-changed-away — ordered by each card's real-world
//  approved date (not dateAdded), newest at top, oldest at bottom. Reads like a
//  credit history rather than a per-card list.
//

import SwiftUI
import SwiftData

struct CardHistorySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var allCards: [CreditCard]
    @Query private var events: [CardProductChangeEvent]

    private enum NodeStatus {
        case active
        case cancelled(Date?)
        case productChanged(toName: String, Date)
    }

    private struct HistoryNode: Identifiable {
        let card: CreditCard
        let approvedDate: Date
        let status: NodeStatus
        var id: String { card.id }
    }

    private var nodes: [HistoryNode] {
        let cardsByID = Dictionary(uniqueKeysWithValues: allCards.map { ($0.id, $0) })
        let eventByFromID = Dictionary(uniqueKeysWithValues: events.map { ($0.fromCardID, $0) })

        let built: [HistoryNode] = allCards.map { card in
            let status: NodeStatus
            if let event = eventByFromID[card.id] {
                status = .productChanged(toName: cardsByID[event.toCardID]?.name ?? "another card", event.changeDate)
            } else if card.status == "cancelled" {
                status = .cancelled(card.cancelledDate)
            } else {
                status = .active
            }
            return HistoryNode(card: card, approvedDate: Self.approvedDate(for: card), status: status)
        }

        return built.sorted { a, b in
            if a.approvedDate != b.approvedDate { return a.approvedDate > b.approvedDate }
            return a.card.dateAdded > b.card.dateAdded
        }
    }

    private static func approvedDate(for card: CreditCard) -> Date {
        let components = DateComponents(year: card.approvedYear, month: card.approvedMonth, day: card.approvedDay)
        return Calendar.current.date(from: components) ?? card.dateAdded
    }

    var body: some View {
        NavigationStack {
            Group {
                if nodes.isEmpty {
                    EmptyStatePlaceholder(
                        icon: "clock.arrow.circlepath",
                        title: "No Card History",
                        subtitle: "As you add, cancel, or product-change cards, your timeline shows up here."
                    )
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(nodes.enumerated()), id: \.element.id) { index, node in
                                timelineRow(node, isLast: index == nodes.count - 1)
                            }
                        }
                        .padding(16)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(16)
                    }
                }
            }
            .navigationTitle("Card History")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color.churOffWhite)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func timelineRow(_ node: HistoryNode, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 4) {
                cardIcon(node.card)
                if !isLast {
                    Rectangle()
                        .fill(Color.churMediumGray.opacity(0.3))
                        .frame(width: 2)
                        .frame(minHeight: 28)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(node.card.name)
                    .font(.churRowTextMedium())
                    .foregroundStyle(Color.churDarkGray)
                Text(node.card.issuer)
                    .font(.churSmall())
                    .foregroundStyle(Color.churMediumGray)

                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor(node.status))
                        .frame(width: 6, height: 6)
                    Text(statusText(node.status))
                        .font(.churSmall())
                        .foregroundStyle(Color.churMediumGray)
                }
                .padding(.top, 2)

                if case .cancelled = node.status {
                    Button("Reactivate") {
                        CardProductChangeService.reactivate(card: node.card)
                    }
                    .font(.churSmallBold())
                    .foregroundStyle(Color.churOlive)
                    .padding(.top, 2)
                }
            }
            .padding(.bottom, isLast ? 0 : 20)

            Spacer()
        }
    }

    @ViewBuilder
    private func cardIcon(_ card: CreditCard) -> some View {
        if let uiImage = UIImage(named: card.imageName) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 44, height: 28)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
        } else {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.cardColor(for: card.issuer))
                .frame(width: 44, height: 28)
                .overlay {
                    Text(card.issuer.prefix(1))
                        .font(.churNanoBold())
                        .foregroundStyle(.white)
                }
        }
    }

    private func statusColor(_ status: NodeStatus) -> Color {
        switch status {
        case .active: return .churOlive
        case .cancelled: return Color.churMediumGray
        case .productChanged: return .blue
        }
    }

    private func statusText(_ status: NodeStatus) -> String {
        switch status {
        case .active:
            return "Active"
        case .cancelled(let date):
            guard let date else { return "Cancelled" }
            return "Cancelled \(date.formatted(.dateTime.month(.abbreviated).day().year()))"
        case .productChanged(let toName, let date):
            return "Changed to \(toName) · \(date.formatted(.dateTime.month(.abbreviated).day().year()))"
        }
    }
}
