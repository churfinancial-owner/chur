//
//  SettingsView.swift
//  Chur
//
//  Created by Pak Ho on 1/22/26.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var user: User

    var body: some View {
        NavigationStack {
            List {
                // MARK: - Navigation Links
                Section {
                    NavigationLink {
                        AccountSettingsView(user: user)
                    } label: {
                        Label("Account", systemImage: "person.circle")
                    }

                    NavigationLink {
                        RegionSettingsView(user: user)
                    } label: {
                        Label("Region & Currency", systemImage: "globe")
                    }

                    NavigationLink {
                        NotificationSettingsView()
                    } label: {
                        Label("Notifications", systemImage: "bell")
                    }

                    NavigationLink {
                        DisplaySettingsView(user: user)
                    } label: {
                        Label("Display", systemImage: "eye")
                    }
                }

                // MARK: - Footer
                Section {
                    Button("Feedback") { /* TODO: open feedback URL */ }
                        .foregroundStyle(Color.churMediumGray)
                    Button("Privacy Policy") { /* TODO: open privacy policy URL */ }
                        .foregroundStyle(Color.churMediumGray)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.churOffWhite)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .font(.churRowText())
                        .fontWeight(.bold)
                        .foregroundStyle(Color.churOlive)
                }
            }
        }
    }
}
