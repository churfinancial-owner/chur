//
//  CardStatusSheet.swift
//  Chur
//
//  Single entry point for the Status row in Card Information — replaces the old
//  confirmationDialog + alert/sheet cascade with one sheet, matching how every other
//  row (Network, Card Type, Approved Date) behaves: tap the row, one sheet opens.
//  Product Change is a pushed sub-screen within the same NavigationStack rather than
//  a sheet-on-a-sheet.
//

import SwiftUI
import SwiftData

struct CardStatusSheet: View {
    @Bindable var card: CreditCard
    @Environment(\.dismiss) private var dismiss
    @State private var showingCancelConfirm = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Text("Status")
                            .foregroundStyle(Color.churDarkGray)
                        Spacer()
                        Text(card.status == "cancelled" ? "Cancelled" : "Active")
                            .foregroundStyle(Color.churMediumGray)
                    }
                }

                if card.status == "cancelled" {
                    Section {
                        Button {
                            CardProductChangeService.reactivate(card: card)
                            dismiss()
                        } label: {
                            Label("Reactivate Card", systemImage: "arrow.uturn.backward.circle")
                        }
                    }
                } else {
                    Section {
                        NavigationLink {
                            ProductChangeCardListView(card: card, onComplete: { dismiss() })
                        } label: {
                            Label("Product Change", systemImage: "arrow.triangle.2.circlepath")
                        }
                    }

                    Section {
                        Button(role: .destructive) {
                            showingCancelConfirm = true
                        } label: {
                            Label("Cancel Card", systemImage: "xmark.circle")
                        }
                    }
                }
            }
            .navigationTitle("Card Status")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color.churOffWhite)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
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
