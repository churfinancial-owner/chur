//
//  CardStatusSheet.swift
//  Chur
//
//  Single entry point for the Status row in Card Information — Product Change is a
//  pushed sub-screen (ProductChangeCardListView) within the same NavigationStack rather
//  than a sheet-on-a-sheet, and Cancel/Reactivate are plain rows with one inline
//  confirmation, matching the sibling sheets in this folder (NetworkPickerSheet,
//  CardTypePickerSheet, ApprovedDatePickerSheet).
//

import SwiftUI
import SwiftData

struct CardStatusSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var card: CreditCard
    @State private var showingCancelConfirm = false

    private var isCancelled: Bool { card.status == "cancelled" }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerView
                    statusSection
                    actionsSection
                    Spacer(minLength: 32)
                }
                .padding()
            }
            .background(Color.churOffWhite)
            .navigationTitle("Card Status")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .font(.churRowText())
                        .fontWeight(.bold)
                        .foregroundStyle(Color.churOlive)
                }
            }
            .alert("Cancel \(card.name)?", isPresented: $showingCancelConfirm) {
                Button("Cancel Card", role: .destructive) {
                    CardProductChangeService.cancel(card: card)
                    dismiss()
                }
                Button("Keep Card", role: .cancel) {}
            } message: {
                Text("This removes the card from your wallet and reward calculations. Its history is kept — you can reactivate it later from Card History.")
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var headerView: some View {
        VStack(spacing: 8) {
            Text("🔄").font(.churBigTitle1())
            Text("Manage whether this card is active, cancelled, or switched to a different product.")
                .font(.churCaptionRegular())
                .foregroundStyle(Color.churMediumGray)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CURRENT STATUS")
                .font(.churSmallBold())
                .foregroundStyle(Color.churOlive)
                .tracking(0.5)

            HStack(spacing: 10) {
                Circle()
                    .fill(isCancelled ? Color.churMediumGray : Color.churOlive)
                    .frame(width: 8, height: 8)
                Text(isCancelled ? "Cancelled" : "Active")
                    .font(.churRowText())
                    .foregroundStyle(Color.churDarkGray)
                Spacer()
            }
            .padding(16)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
        }
    }

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ACTIONS")
                .font(.churSmallBold())
                .foregroundStyle(Color.churOlive)
                .tracking(0.5)

            VStack(spacing: 0) {
                if isCancelled {
                    Button {
                        CardProductChangeService.reactivate(card: card)
                        dismiss()
                    } label: {
                        HStack(spacing: 10) {
                            Text("Reactivate Card")
                                .font(.churRowText())
                                .foregroundStyle(Color.churDarkGray)
                            Spacer()
                            Image(systemName: "arrow.uturn.backward.circle.fill")
                                .foregroundStyle(Color.churOlive)
                                .font(.churBigTitle4())
                        }
                        .padding(16)
                    }
                    .buttonStyle(.plain)
                } else {
                    NavigationLink {
                        ProductChangeCardListView(card: card, onComplete: { dismiss() })
                    } label: {
                        HStack(spacing: 10) {
                            Text("Product Change")
                                .font(.churRowText())
                                .foregroundStyle(Color.churDarkGray)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.churSmallBold())
                                .foregroundStyle(Color.churMediumGray)
                        }
                        .padding(16)
                    }
                    .buttonStyle(.plain)

                    Divider().padding(.horizontal, 16).opacity(0.5)

                    Button {
                        showingCancelConfirm = true
                    } label: {
                        HStack(spacing: 10) {
                            Text("Cancel Card")
                                .font(.churRowText())
                                .foregroundStyle(.red)
                            Spacer()
                        }
                        .padding(16)
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
        }
    }
}

/// Same-issuer card picker for Product Change, pushed within CardStatusSheet's
/// NavigationStack. Calls `onComplete` (dismisses the whole Status sheet) once the
/// switch is made — the old card is now cancelled, so there's nothing left to do here.
struct ProductChangeCardListView: View {
    let card: CreditCard
    let onComplete: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var pendingTemplate: CardTemplate?

    private var candidates: [CardTemplate] {
        CardDatabase.getAllCards()
            .filter { $0.issuer == card.issuer && $0.id != card.templateID }
            .sorted { $0.name < $1.name }
    }

    var body: some View {
        Group {
            if candidates.isEmpty {
                EmptyStatePlaceholder(
                    icon: "creditcard",
                    title: "No Other \(card.issuer) Cards",
                    subtitle: "There are no other \(card.issuer) cards to switch to yet."
                )
            } else {
                List(candidates, id: \.id) { template in
                    CardDatabaseRow(template: template, addedCount: 0, onAdd: {
                        pendingTemplate = template
                    })
                    .contentShape(Rectangle())
                    .onTapGesture { pendingTemplate = template }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Switch \(card.name) To")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color.churOffWhite)
        .alert("Switch to \(pendingTemplate?.name ?? "")?", isPresented: Binding(
            get: { pendingTemplate != nil },
            set: { if !$0 { pendingTemplate = nil } }
        )) {
            Button("Switch", role: .destructive) {
                if let template = pendingTemplate {
                    CardProductChangeService.productChange(fromCard: card, toTemplateID: template.id, modelContext: modelContext)
                }
                onComplete()
            }
            Button("Cancel", role: .cancel) { pendingTemplate = nil }
        } message: {
            Text("\(card.name) will be cancelled and \(pendingTemplate?.name ?? "the new card") added in its place, keeping the same approved date. \(card.name)'s history stays viewable in Card History.")
        }
    }
}
