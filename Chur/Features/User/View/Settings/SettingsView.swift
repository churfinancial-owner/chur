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
                        LanguageSettingsView(user: user)
                    } label: {
                        Label("Language", systemImage: "character.bubble")
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

                // Metadata, not a control — centered and unselectable so it
                // doesn't read as a tappable row. Diagnostics copying will live
                // on the universal report-an-issue button instead.
                Section {
                    Text(verbatim: AppVersion.footerLabel)
                        .font(.churFootnote())
                        .foregroundStyle(Color.churMediumGray)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .listRowBackground(Color.clear)
                        .accessibilityLabel(Text(verbatim: AppVersion.footerLabel))
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.churOffWhite)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    ChurDoneButton { dismiss() }
                }
                .churBareToolbarBackground()
            }
        }
    }
}
