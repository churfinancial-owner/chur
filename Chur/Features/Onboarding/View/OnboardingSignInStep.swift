//
//  OnboardingSignInStep.swift
//  Chur
//
//  Step 2: Sign in with Apple or Google.
//  Updated with theme-consistent UI and "Welcome back" restoration state.
//

import SwiftUI
import AuthenticationServices
import GoogleSignIn

struct OnboardingSignInStep: View {
    let onSignedIn: (String, String, String) -> Void  // (appleUserID, firstName, email)
    let onGoogleSignedIn: (String, String, String) -> Void  // (googleUserID, firstName, email)
    let onBack: () -> Void
    let onSkip: () -> Void
    
    @Binding var isRestoring: Bool // Track if a backup is currently being pulled

    @State private var signInError: String?
    @State private var showBackupTooltip = false
    private let impactFeedback = UIImpactFeedbackGenerator(style: .medium)

    var body: some View {
        ZStack {
            // Consistent background texture from Welcome step
            Color.churOffWhite.ignoresSafeArea()
            DotGridBackground().ignoresSafeArea().opacity(0.05)
            
            VStack(spacing: 0) {
                Spacer()
                    .frame(minHeight: 24, maxHeight: 80)

                // Hero Section
                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(Color.churOlive.opacity(0.1))
                            .frame(width: 100, height: 100)
                        
                        Image(systemName: isRestoring ? "arrow.down.circle.fill" : "person.crop.circle.badge.checkmark")
                            .font(.churBigTitle())
                            .foregroundStyle(Color.churOlive)
                            .symbolEffect(.bounce, value: isRestoring || signInError != nil)
                    }

                    VStack(spacing: 8) {
                        if isRestoring {
                            Text("Welcome back!")
                                .font(.churTitle())
                                .foregroundStyle(Color.churDarkGray)
                                .transition(.scale.combined(with: .opacity))

                            Text("We’ve found your latest backup and are\nrestoring your wallet now...")
                                .font(.churRowTextRegular())
                                .foregroundStyle(Color.churMediumGray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        } else {
                            Text("Secure Your Wallet")
                                .font(.churTitle())
                                .foregroundStyle(Color.churDarkGray)

                            Text("Back up your wallet privately to your account\n — only you can access it.")
                                .font(.churRowTextRegular())
                                .foregroundStyle(Color.churMediumGray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                    }
                    .animation(.spring(), value: isRestoring)
                }

                Spacer()
                    .frame(height: 48)

                if isRestoring {
                    // Visual indicator that restoration is in progress
                    ProgressView()
                        .tint(Color.churOlive)
                        .scaleEffect(1.2)
                        .frame(height: 118)
                } else {
                    // Auth Providers
                    VStack(spacing: 14) {
                        SignInWithAppleButton(.signIn) { request in
                            request.requestedScopes = [.fullName, .email]
                        } onCompletion: { result in
                            handleSignInResult(result)
                        }
                        .signInWithAppleButtonStyle(.black)
                        .frame(height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: Color.black.opacity(0.1), radius: 4, y: 2)

                        GoogleSignInButtonWrapper {
                            impactFeedback.impactOccurred()
                            performGoogleSignIn()
                        }
                        .frame(height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: Color.black.opacity(0.05), radius: 4, y: 2)
                    }
                    .padding(.horizontal, 30)
                }

                if let error = signInError {
                    Text(error)
                        .font(.churFootnote())
                        .foregroundStyle(Color.churError)
                        .padding(.top, 16)
                        .transition(.opacity)
                }

                // Backup disclosure
                Button {
                    showBackupTooltip = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "lock.fill")
                            .font(.churMicro())
                        Text("We never store or see your data.")
                            .font(.churFootnote())
                        Text("What's backed up?")
                            .font(.churFootnote())
                            .underline()
                    }
                    .foregroundStyle(Color.churMediumGray)
                }
                .padding(.top, 20)
                .popover(isPresented: $showBackupTooltip, arrowEdge: .bottom) {
                    BackupTooltipContent()
                        .presentationCompactAdaptation(.popover)
                }

                Spacer()

                // Footer Actions
                if !isRestoring {
                    VStack(spacing: 12) {
                        Button {
                            onSkip()
                        } label: {
                            Text("Continue without signing in")
                                .font(.churRowTextMedium())
                                .foregroundStyle(Color.churMediumGray)
                        }

                        HStack(spacing: 4) {
                            Button("Privacy Policy") { /* TODO: open privacy policy URL */ }
                            Text("·")
                            Button("Terms of Service") { /* TODO: open terms of service URL */ }
                        }
                        .font(.churMicro())
                        .foregroundStyle(Color.churMediumGray.opacity(0.6))
                    }
                    .padding(.bottom, 20)
                }
            }
        }
    }

    // MARK: - Handlers

    private func handleSignInResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                signInError = "Unexpected credential type"
                return
            }
            
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            onSignedIn(credential.user, credential.fullName?.givenName ?? "", credential.email ?? "")

        case .failure(let error):
            if (error as? ASAuthorizationError)?.code == .canceled { return }
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            signInError = "Sign in failed. Please try again."
        }
    }

    private func performGoogleSignIn() {
        if GIDSignIn.sharedInstance.configuration == nil {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(
                clientID: Config.googleClientID
            )
        }

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else {
            signInError = "Unable to present sign in"
            return
        }

        var presentingVC = rootVC
        while let presented = presentingVC.presentedViewController {
            presentingVC = presented
        }

        GIDSignIn.sharedInstance.signIn(
            withPresenting: presentingVC,
            hint: nil,
            additionalScopes: ["https://www.googleapis.com/auth/drive.appdata"]
        ) { result, error in
            if let error = error {
                if (error as NSError).code == GIDSignInError.canceled.rawValue { return }
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                signInError = "Google sign in failed."
                return
            }

            guard let user = result?.user, let profile = user.profile else {
                signInError = "Unable to get user profile"
                return
            }

            UINotificationFeedbackGenerator().notificationOccurred(.success)
            onGoogleSignedIn(user.userID ?? "", profile.givenName ?? "", profile.email)
        }
    }
}

// (Tooltip and Background components remain unchanged)
// MARK: - Backup Tooltip

private struct BackupTooltipContent: View {
    private let items: [(String, String)] = [
        ("creditcard.fill",      "Cards, approved dates & notes"),
        ("checkmark.seal.fill",  "Benefit history & usage"),
        ("slider.horizontal.3",  "Preferences & settings"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("What gets backed up")
                .font(.churRowTextMedium())
                .foregroundStyle(Color.churDarkGray)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(items, id: \.0) { icon, label in
                    HStack(spacing: 10) {
                        Image(systemName: icon)
                            .font(.churFootnote())
                            .foregroundStyle(Color.churOlive)
                            .frame(width: 18)
                        Text(label)
                            .font(.churFootnote())
                            .foregroundStyle(Color.churDarkGray.opacity(0.7))
                    }
                }
            }

            Divider()

            Text("Backups are stored privately in your own account. Chur has no access to this data.")
                .font(.churMicro())
                .foregroundStyle(Color.churDarkGray.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(width: 280)
    }
}

