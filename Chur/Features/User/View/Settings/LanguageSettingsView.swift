//
//  LanguageSettingsView.swift
//  Chur
//

import SwiftUI

struct LanguageSettingsView: View {
    @Bindable var user: User
    @AppStorage("appLanguage") private var appLanguageRaw: String = AppLanguage.system.rawValue

    private var selection: Binding<AppLanguage> {
        Binding(
            get: { AppLanguage(rawValue: user.languagePreference) ?? .system },
            set: { newValue in
                user.languagePreference = newValue.rawValue
                appLanguageRaw = newValue.rawValue
            }
        )
    }

    var body: some View {
        List {
            Section {
                Picker("Language", selection: selection) {
                    Text("System Default").tag(AppLanguage.system)
                    Text("English").tag(AppLanguage.english)
                    Text("繁體中文（香港）").tag(AppLanguage.chineseHK)
                }
                .pickerStyle(.inline)
                .tint(Color.churOlive)
            } header: {
                Text("App Language")
            } footer: {
                Text("Changes how card, benefit, and category names are displayed.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.churOffWhite)
        .navigationTitle("Language")
        .navigationBarTitleDisplayMode(.inline)
    }
}
