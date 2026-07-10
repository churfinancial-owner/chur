//
//  OnboardingContainerView.swift
//  Chur
//
//  Root container for the 5-step onboarding flow.
//  Steps: Welcome → Sign In → Profile → Region → Add Cards
//

import SwiftUI
import SwiftData

enum OnboardingStep: Int, CaseIterable {
    case welcome = 0
    case signIn = 1
    case profile = 2
    case region = 3
    case addCards = 4
}

struct OnboardingContainerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var users: [User]
    @Query private var categories: [SpendingCategory]

    @State private var currentStep: OnboardingStep = .welcome
    @State private var isRestoring = false // NEW: Track restoration to show message

    // Collected data across steps
    @State private var appleUserID = ""
    @State private var googleUserID = ""
    @State private var firstName = ""
    @State private var email = ""
    @State private var authProvider = "anonymous"
    @State private var selectedCountry: String = User.detectUserCountry()
    @State private var profileEmoji = "😊"
    @State private var profilePhotoData: Data?
    
    @State private var pendingTemplates: [CardTemplate] = []
    @State private var pendingTemplateCounts: [String: Int] = [:]

    var body: some View {
        VStack(spacing: 0) {
            if currentStep != .welcome {
                topBar
            }

            ZStack {
                switch currentStep {
                case .welcome:
                    OnboardingWelcomeStep {
                        advanceToNextStep()
                    }
                    .transition(stepTransition)

                case .signIn:
                    OnboardingSignInStep(
                        onSignedIn: { userID, name, userEmail in
                            appleUserID = userID
                            if !name.isEmpty { firstName = name }
                            if !userEmail.isEmpty { email = userEmail }
                            authProvider = "apple"
                            advanceToNextStep()
                        },
                        onGoogleSignedIn: { userID, name, userEmail in
                            googleUserID = userID
                            if !name.isEmpty { firstName = name }
                            if !userEmail.isEmpty { email = userEmail }
                            authProvider = "google"
                            
                            // Check for existing backup — but skip if user just deleted their account.
                            // The skip flag guards against Drive propagation delay causing a false
                            // "Welcome back" immediately after a delete-account action.
                            Task {
                                let skipRestore = UserDefaults.standard.bool(forKey: "chur.skipNextRestore")
                                if skipRestore {
                                    // Don't consume the flag here — finishOnboarding() owns it
                                    // so the fallback restore there is also blocked.
                                    await MainActor.run { advanceToNextStep() }
                                    return
                                }

                                let user = ensureUserExists()
                                let result = await BackupRestoreService.checkAndRestore(
                                    user: user,
                                    existingCards: [],
                                    modelContext: modelContext
                                )

                                await MainActor.run {
                                    switch result {
                                    case .restored:
                                        // Trigger the "Welcome back" UI state
                                        withAnimation { isRestoring = true }

                                        // Brief delay so they can read the message before Home loads
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                            finishOnboarding()
                                        }
                                    default:
                                        // No backup, continue manual flow
                                        advanceToNextStep()
                                    }
                                }
                            }
                        },
                        onBack: {
                            regressToPreviousStep()
                        },
                        onSkip: {
                            advanceToNextStep()
                        },
                        isRestoring: $isRestoring // Pass the binding for the message
                    )
                    .transition(stepTransition)

                case .profile:
                    OnboardingProfileStep(
                        firstName: $firstName,
                        profilePhotoData: $profilePhotoData
                    ) {
                        advanceToNextStep()
                    }
                    .transition(stepTransition)

                case .region:
                    OnboardingRegionStep(
                        selectedCountry: $selectedCountry
                    ) {
                        advanceToNextStep()
                    }
                    .transition(stepTransition)

                case .addCards:
                    OnboardingAddCardsStep(
                        selectedCountry: selectedCountry,
                        pendingTemplates: $pendingTemplates,
                        pendingTemplateCounts: $pendingTemplateCounts,
                        onContinue: { templates in
                            commitCards(templates)
                            finishOnboarding()
                        }
                    )
                    .transition(stepTransition)
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: currentStep)
        }
        .background(Color.churOffWhite)
        .onAppear {
            if let incompleteUser = users.first, !incompleteUser.onboardingCompleted {
                modelContext.delete(incompleteUser)
                
                appleUserID = ""
                googleUserID = ""
                firstName = ""
                email = ""
                pendingTemplates = []
                pendingTemplateCounts = [:]
                
                try? modelContext.save()
            }
        }
    }

    // MARK: - Navigation Logic

    private func advanceToNextStep() {
        guard let nextStep = OnboardingStep(rawValue: currentStep.rawValue + 1) else {
            return
        }
        currentStep = nextStep
    }

    private func regressToPreviousStep() {
        if let prevStep = OnboardingStep(rawValue: currentStep.rawValue - 1) {
            currentStep = prevStep
        }
    }

    private func finishOnboarding() {
        let user = ensureUserExists()
        
        if !firstName.isEmpty { user.firstName = firstName }
        user.profileEmoji = profileEmoji
        user.profilePhotoData = profilePhotoData
        user.onboardingCompleted = true
        
        loadCategoriesIfNeeded()
        try? modelContext.save()

        // Fallback check if user completed manual empty flow with Google.
        // Also guards the delete-account path: the skip flag may still be set if
        // the primary restore in onGoogleSignedIn was bypassed.
        if authProvider == "google" && pendingTemplates.isEmpty {
            let skip = UserDefaults.standard.bool(forKey: "chur.skipNextRestore")
            UserDefaults.standard.removeObject(forKey: "chur.skipNextRestore")
            if !skip {
                let ctx = modelContext
                Task {
                    let existing = (try? ctx.fetch(FetchDescriptor<CreditCard>())) ?? []
                    await BackupRestoreService.checkAndRestore(
                        user: user,
                        existingCards: existing,
                        modelContext: ctx
                    )
                }
            }
        }
    }

    private func skipOnboarding() {
        finishOnboarding()
    }

    // MARK: - Top Bar and Transitions
    
    private var topBar: some View {
        HStack {
            Button {
                regressToPreviousStep()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.churHeadline())
                    .foregroundStyle(Color.churMediumGray)
            }
            .opacity(currentStep == .welcome || isRestoring ? 0 : 1) // Hide if restoring

            Spacer()

            OnboardingProgressIndicator(
                totalSteps: OnboardingStep.allCases.count,
                currentStep: currentStep.rawValue
            )
            .opacity(isRestoring ? 0 : 1)

            Spacer()

            Button {
                skipOnboarding()
            } label: {
                Text("Skip")
                    .font(.churRowTextMedium())
                    .foregroundStyle(Color.churMediumGray)
            }
            .opacity(isRestoring ? 0 : 1)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private var stepTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }

    // MARK: - Data Management

    private func commitCards(_ templates: [CardTemplate]) {
        let user = ensureUserExists()
        guard !templates.isEmpty else { return }

        for template in templates {
            let newCard = template.toCreditCard(modelContext: modelContext)
            if !user.cardDisplayOrder.contains(newCard.id) {
                user.cardDisplayOrder.append(newCard.id)
            }
            let cardCategories = newCard.activeRewards.compactMap { $0.categories }.joined()
            for categoryID in cardCategories where categoryID != "merchants" {
                if !user.selectedCategories.contains(categoryID) {
                    user.selectedCategories.append(categoryID)
                }
            }
        }
        
        let allCards = (try? modelContext.fetch(FetchDescriptor<CreditCard>())) ?? []
        let proposals = ProgramUpgradeDatabase.detectPendingChanges(cards: allCards)
        ProgramUpgradeDatabase.applyAll(proposals)
        
        try? modelContext.save()
    }

    @discardableResult
    private func ensureUserExists() -> User {
        if let existing = users.first {
            if !appleUserID.isEmpty { existing.appleUserID = appleUserID }
            if !googleUserID.isEmpty { existing.googleUserID = googleUserID }
            if !email.isEmpty { existing.email = email }
            existing.authProvider = authProvider
            existing.country = selectedCountry
            return existing
        }

        let user = User(firstName: firstName, email: email, appleUserID: appleUserID)
        user.googleUserID = googleUserID
        user.authProvider = authProvider
        user.country = selectedCountry
        modelContext.insert(user)
        return user
    }

    private func loadCategoriesIfNeeded() {
        if TestDataConfiguration.loadSeedCategories && categories.isEmpty {
            SeedDataLoader.loadCategories(into: modelContext)
        }
    }
}
