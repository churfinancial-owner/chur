//
//  EditCardSheet.swift
//  Chur
//
//  Created by Pak Ho on 1/26/26.
//
import SwiftUI
import SwiftData

struct EditCardSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var users: [User]
    
    let card: CreditCard
    
    @State private var showDeleteConfirmation = false
    
    var currentUser: User? {
        users.first
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "pencil.circle")
                    .font(.churBigTitle())
                    .foregroundStyle(Color.churOlive)
                
                Text("Edit Card")
                    .font(.churTitle())
                    .foregroundStyle(Color.churDarkGray)
                
                Text("Editing: \(card.name)")
                    .font(.churSubheadline())
                    .foregroundStyle(Color.churMediumGray)
                
                Text("Coming soon...")
                    .font(.churBody())
                    .foregroundStyle(Color.churMediumGray)
                    .padding(.top)
                
                Spacer()
                
                // Delete button at bottom
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text("Delete Card")
                    }
                    .font(.churSubheadline())
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.churError)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.churOffWhite)
            .navigationTitle("Edit Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(Color.churOlive)
                }
            }
            .alert("Delete Card?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteCard()
                }
            } message: {
                Text("Are you sure you want to delete \(card.name)? This will remove all tracked benefits and rewards data.")
            }
        }
    }
    
    private func deleteCard() {
        // Remove from user's display order
        if let user = currentUser {
            user.cardDisplayOrder.removeAll { $0 == card.id }
        }
        
        // Delete the card (cascade will delete rewards and benefits)
        modelContext.delete(card)
        
        // Dismiss the sheet
        dismiss()
    }
}
