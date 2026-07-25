//
//  CardHistorySheet.swift
//  Chur
//
//  Timeline of every card the user has ever added: active cards, plain cancels, and
//  Product Change chains (e.g. Citi Costco Visa → Citi Custom Cash). A Product Change
//  cancels the old CreditCard row and adds a new one (CardProductChangeService), linked
//  by a CardProductChangeEvent — this view walks those links to reconstruct each lineage.
//

import SwiftUI
import SwiftData

struct CardHistorySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var allCards: [CreditCard]
    @Query private var events: [CardProductChangeEvent]

    private enum EndReason {
        case ongoing
        case cancelled
        case productChanged(toName: String)
    }

    private struct LineageNode: Identifiable {
        let card: CreditCard
        let startDate: Date
        let endDate: Date?
        let endReason: EndReason
        var id: String { card.id }
    }

    /// One array per lineage (oldest card first), newest lineage first.
    private var lineages: [[LineageNode]] {
        let cardsByID = Dictionary(uniqueKeysWithValues: allCards.map { ($0.id, $0) })
        let eventByFromID = Dictionary(uniqueKeysWithValues: events.map { ($0.fromCardID, $0) })
        let toCardIDs = Set(events.map { $0.toCardID })

        // A lineage starts at any card that wasn't itself created by a Product Change.
        let roots = allCards.filter { !toCardIDs.contains($0.id) }

        let chains: [[LineageNode]] = roots.map { root in
            var chain: [LineageNode] = []
            var current = root
            var start = current.dateAdded
            while true {
                if let event = eventByFromID[current.id], let next = cardsByID[event.toCardID] {
                    chain.append(LineageNode(card: current, startDate: start, endDate: event.changeDate, endReason: .productChanged(toName: next.name)))
                    current = next
                    start = event.changeDate
                } else if current.status == "cancelled" {
                    chain.append(LineageNode(card: current, startDate: start, endDate: current.cancelledDate, endReason: .cancelled))
                    break
                } else {
                    chain.append(LineageNode(card: current, startDate: start, endDate: nil, endReason: .ongoing))
                    break
                }
            }
            return chain
        }

        return chains.sorted { ($0.last?.startDate ?? .distantPast) > ($1.last?.startDate ?? .distantPast) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if lineages.isEmpty {
                    EmptyStatePlaceholder(
                        icon: "clock.arrow.circlepath",
                        title: "No Card History",
                        subtitle: "As you add, cancel, or product-change cards, their timeline shows up here."
                    )
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            ForEach(Array(lineages.enumerated()), id: \.offset) { _, lineage in
                                lineageCard(lineage)
                            }
                        }
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

    private func lineageCard(_ lineage: [LineageNode]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(lineage.enumerated()), id: \.element.id) { index, node in
                timelineRow(node, isLast: index == lineage.count - 1)
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private func timelineRow(_ node: LineageNode, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                Image(systemName: icon(for: node.endReason))
                    .font(.churRowTextMedium())
                    .foregroundStyle(iconColor(for: node.endReason))
                if !isLast {
                    Rectangle()
                        .fill(Color.churMediumGray.opacity(0.3))
                        .frame(width: 2)
                        .frame(minHeight: 24)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(node.card.name)
                    .font(.churRowTextMedium())
                    .foregroundStyle(Color.churDarkGray)
                Text(node.card.issuer)
                    .font(.churSmall())
                    .foregroundStyle(Color.churMediumGray)
                Text(dateRangeText(node))
                    .font(.churSmall())
                    .foregroundStyle(Color.churMediumGray)

                if case .cancelled = node.endReason {
                    Button("Reactivate") {
                        CardProductChangeService.reactivate(card: node.card)
                    }
                    .font(.churSmallBold())
                    .foregroundStyle(Color.churOlive)
                    .padding(.top, 2)
                }
            }
            .padding(.bottom, isLast ? 0 : 16)

            Spacer()
        }
    }

    private func icon(for reason: EndReason) -> String {
        switch reason {
        case .ongoing: return "checkmark.circle.fill"
        case .cancelled: return "xmark.circle.fill"
        case .productChanged: return "arrow.triangle.2.circlepath.circle.fill"
        }
    }

    private func iconColor(for reason: EndReason) -> Color {
        switch reason {
        case .ongoing: return .churOlive
        case .cancelled: return Color.churMediumGray
        case .productChanged: return .blue
        }
    }

    private func dateRangeText(_ node: LineageNode) -> String {
        let start = node.startDate.formatted(.dateTime.month(.abbreviated).day().year())
        switch node.endReason {
        case .ongoing:
            return "\(start) – Present"
        case .cancelled:
            let end = (node.endDate ?? node.startDate).formatted(.dateTime.month(.abbreviated).day().year())
            return "\(start) – \(end) (Cancelled)"
        case .productChanged(let toName):
            let end = (node.endDate ?? node.startDate).formatted(.dateTime.month(.abbreviated).day().year())
            return "\(start) – \(end) (Changed to \(toName))"
        }
    }
}
