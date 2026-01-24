//
//  SettingsView.swift
//  Chur
//
//  Created by Pak Ho on 1/22/26.
//

import SwiftUI
import AuthenticationServices
import GoogleSignIn

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var user: User
    @AppStorage("expiryWarningDays") private var expiryWarningDays: Int = 3
    @State private var signInError: String?
    @State private var showSignOutConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                // MARK: - Profile Photo
                Section {
                    VStack(spacing: 6) {
                        ProfilePhotoPicker(profilePhotoData: $user.profilePhotoData, diameter: 90)
                        Text(user.profilePhotoData == nil ? "Tap to add a photo" : "Tap to change photo")
                            .font(.churMicro())
                            .foregroundStyle(Color.churMediumGray)
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }

                Section("Account") {
                    HStack {
                        Text("Name")
                        Spacer()
                        Text(user.firstName.isEmpty ? "Not set" : user.firstName)
                            .foregroundStyle(Color.churMediumGray)
                    }

                    HStack {
                        Text("Email")
                        Spacer()
                        Text(user.email.isEmpty ? "Not set" : user.email)
                            .foregroundStyle(Color.churMediumGray)
                    }

                    if user.authProvider == "anonymous" {
                        SignInWithAppleButton(.signIn) { request in
                            request.requestedScopes = [.fullName, .email]
                        } onCompletion: { result in
                            handleSignInResult(result)
                        }
                        .signInWithAppleButtonStyle(.black)
                        .frame(height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

                        GoogleSignInButtonWrapper {
                            performGoogleSignIn()
                        }
                        .frame(height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 8, trailing: 16))

                        if let error = signInError {
                            Text(error)
                                .font(.system(size: 12, design: .rounded))
                                .foregroundStyle(Color.churError)
                        }
                    }
                }

                Section("Preferences") {
                    Toggle("Notifications", isOn: .constant(true))
                        .tint(Color.churOlive)
                    Toggle("Location Services", isOn: .constant(true))
                        .tint(Color.churOlive)
                    Stepper(
                        "Expiry warning: \(expiryWarningDays) day\(expiryWarningDays == 1 ? "" : "s") before",
                        value: $expiryWarningDays,
                        in: 1...30
                    )
                    
                    // Country/Region Picker
                    VStack(alignment: .leading, spacing: 2) {
                        Picker("Region", selection: $user.country) {
                            ForEach(RegionDatabase.activeRegions) { region in
                                HStack {
                                    Text(region.flag)
                                    Text(region.name)
                                }
                                .tag(region.id)
                            }
                        }
                        .onChange(of: user.country) { _, newRegion in
                            TransferPartnerDatabase.loadFromBundle(region: newRegion)
                        }
                        
                        Text("Display currency: \(CurrencyConversion.currencyCode(forCountry: user.country))")
                            .font(.churMicro())
                            .foregroundStyle(Color.churMediumGray)
                    }
                }

                // MARK: - Display
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Reward displayed as")
                            .font(.churSmallBold())
                            .foregroundStyle(Color.churMediumGray)

                        HStack(spacing: 8) {
                            displayModeButton(label: "Multiplier (4x)", isSelected: !user.showEffectiveRate) {
                                user.showEffectiveRate = false
                            }
                            displayModeButton(label: effectiveRateExample, isSelected: user.showEffectiveRate) {
                                user.showEffectiveRate = true
                            }
                        }

                        Text(user.showEffectiveRate
                             ? "Rewards sorted by effective % return per dollar spent"
                             : "Rewards sorted by multiplier")
                            .font(.churMicro())
                            .foregroundStyle(Color.churMediumGray)
                    }
                    .padding(.vertical, 4)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 4, trailing: 0))
                } header: {
                    Text("Display")
                }

                if user.authProvider == "apple" || user.authProvider == "google" {
                    Section {
                        Button("Sign Out") {
                            showSignOutConfirmation = true
                        }
                        .foregroundStyle(Color.churError)
                        .alert("Sign Out", isPresented: $showSignOutConfirmation) {
                            Button("Cancel", role: .cancel) {}
                            Button("Sign Out", role: .destructive) {
                                if user.authProvider == "google" {
                                    GIDSignIn.sharedInstance.signOut()
                                }
                                user.appleUserID = ""
                                user.googleUserID = ""
                                user.authProvider = "anonymous"
                            }
                        } message: {
                            Text("Signing out will stop syncing your data. Your cards and preferences will remain on this device.")
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.churOlive)
                }
            }
        }
    }

    private func handleSignInResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                signInError = "Unexpected credential type"
                return
            }
            user.appleUserID = credential.user
            if let name = credential.fullName?.givenName, !name.isEmpty {
                user.firstName = name
            }
            if let email = credential.email, !email.isEmpty {
                user.email = email
            }
            user.authProvider = "apple"
            signInError = nil

        case .failure(let error):
            if (error as? ASAuthorizationError)?.code == .canceled { return }
            signInError = "Sign in failed. Please try again."
        }
    }

    private func performGoogleSignIn() {
        // Ensure configuration is set (guards against SDK assertion crash)
        if GIDSignIn.sharedInstance.configuration == nil {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(
                clientID: "72421479384-khfht84hnp48i7svdvce61d06511eepu.apps.googleusercontent.com"
            )
        }

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else {
            signInError = "Unable to present sign in"
            return
        }

        // Walk to the topmost presented view controller
        var presentingVC = rootVC
        while let presented = presentingVC.presentedViewController {
            presentingVC = presented
        }

        GIDSignIn.sharedInstance.signIn(withPresenting: presentingVC) { result, error in
            if let error = error {
                if (error as NSError).code == GIDSignInError.canceled.rawValue {
                    return
                }
                signInError = "Google sign in failed. Please try again."
                #if DEBUG
                print("Google Sign-In error: \(error)")
                #endif
                return
            }

            guard let googleUser = result?.user,
                  let profile = googleUser.profile else {
                signInError = "Unable to get user profile"
                return
            }

            user.googleUserID = googleUser.userID ?? ""
            if let name = profile.givenName, !name.isEmpty {
                user.firstName = name
            }
            if !profile.email.isEmpty {
                user.email = profile.email
            }
            user.authProvider = "google"
            signInError = nil
        }
    }

    private var effectiveRateExample: String {
        "Effective Rate (5%)"
    }

    private func displayModeButton(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.churFootnoteBold())
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .foregroundStyle(isSelected ? .white : Color.churOlive)
                .background(isSelected ? Color.churOlive : Color.clear)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.churOlive, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }
}
