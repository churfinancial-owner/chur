//
//  OnboardingSignInStep.swift
//  Chur
//
//  Step 2: Sign in with Apple.
//

import SwiftUI
import AuthenticationServices
import GoogleSignIn

struct OnboardingSignInStep: View {
    let onSignedIn: (String, String, String) -> Void  // (appleUserID, firstName, email)
    let onGoogleSignedIn: (String, String, String) -> Void  // (googleUserID, firstName, email)
    let onSkip: () -> Void

    @State private var signInError: String?

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "person.crop.circle.badge.checkmark")
                    .font(.churBigTitle())
                    .foregroundStyle(Color.churOlive)

                Text("Sign In")
                    .font(.churTitle())
                    .foregroundStyle(Color.churDarkGray)

                Text("Sign in to sync your data across devices and keep your cards safe.")
                    .font(.churRowTextRegular())
                    .foregroundStyle(Color.churMediumGray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()
                .frame(height: 48)

            // Sign in with Apple button
            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                handleSignInResult(result)
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 24)

            // Sign in with Google button
            GoogleSignInButtonWrapper {
                performGoogleSignIn()
            }
            .frame(height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 24)
            .padding(.top, 12)

            if let error = signInError {
                Text(error)
                    .font(.churFootnote())
                    .foregroundStyle(Color.churError)
                    .padding(.top, 8)
            }

            Spacer()

            // Skip link
            Button {
                onSkip()
            } label: {
                Text("Continue without signing in")
                    .font(.churRowTextMedium())
                    .foregroundStyle(Color.churMediumGray)
            }
            .padding(.bottom, 16)
        }
    }

    private func handleSignInResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                signInError = "Unexpected credential type"
                return
            }

            let userID = credential.user
            let firstName = credential.fullName?.givenName ?? ""
            let email = credential.email ?? ""

            signInError = nil
            onSignedIn(userID, firstName, email)

        case .failure(let error):
            // ASAuthorizationError.canceled means user dismissed — don't show error
            if (error as? ASAuthorizationError)?.code == .canceled {
                return
            }
            signInError = "Sign in failed. Please try again."
            #if DEBUG
            print("Sign in with Apple error: \(error)")
            #endif
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

            guard let user = result?.user,
                  let profile = user.profile else {
                signInError = "Unable to get user profile"
                return
            }

            let googleUserID = user.userID ?? ""
            let firstName = profile.givenName ?? ""
            let email = profile.email

            signInError = nil
            onGoogleSignedIn(googleUserID, firstName, email)
        }
    }
}
