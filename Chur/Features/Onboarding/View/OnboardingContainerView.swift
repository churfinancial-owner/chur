//
//  OnboardingContainerView.swift
//  Chur
//
//  Root container for the 5-step onboarding flow.
//  Steps: Welcome → Sign In → Region → Add Cards → Profile
//

import SwiftUI
import SwiftData

enum OnboardingStep: Int, CaseIterable {
    case welcome = 0
    case signIn = 1
    case region = 2
    case addCards = 3
    case profile = 4
}

struct OnboardingContainerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var users: [User]
    @Query private var categories: [SpendingCategory]

    @State private var currentStep: OnboardingStep = .welcome

    // Collected data across steps
    @State private var appleUserID = ""
    @State private var googleUserID = ""
    @State private var firstName = ""
    @State private var email = ""
    @State private var authProvider = "anonymous"
    @State private var selectedCountry: String = User.detectUserCountry()
    @State private var profileEmoji = "😊"
    @State private var profilePhotoData: Data?

    // Program upgrade state (no longer used for alerts)
    @State private var upgradeProposals: [ProgramUpgradeProposal] = []

    var body: some View {
        VStack(spacing: 0) {
            // Top bar: progress + skip
            if currentStep != .welcome {
                topBar
            }

            // Step content
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
                            advanceToNextStep()
                        },
                        onSkip: {
                            advanceToNextStep()
                        }
                    )
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
                        onContinue: { templates in
                            commitCards(templates)
                        },
                        onSkip: {
                            advanceToNextStep()
                        }
                    )
                    .transition(stepTransition)

                case .profile:
                    OnboardingProfileStep(
                        firstName: $firstName,
                        profilePhotoData: $profilePhotoData
                    ) {
                        finishOnboarding()
                    }
                    .transition(stepTransition)
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: currentStep)
        }
        .background(Color.churOffWhite)
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Spacer()

            OnboardingProgressIndicator(
                totalSteps: OnboardingStep.allCases.count,
                currentStep: currentStep.rawValue
            )

            Spacer()

            Button {
                skipOnboarding()
            } label: {
                Text("Skip")
                    .font(.churRowTextMedium())
                    .foregroundStyle(Color.churMediumGray)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - Transitions

    private var stepTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }

    // MARK: - Navigation

    private func advanceToNextStep() {
        guard let nextStep = OnboardingStep(rawValue: currentStep.rawValue + 1) else {
            finishOnboarding()
            return
        }
        currentStep = nextStep
    }

    // MARK: - Skip

    private func skipOnboarding() {
        let user = ensureUserExists()
        user.onboardingCompleted = true
        loadCategoriesIfNeeded()
        try? modelContext.save()
    }

    // MARK: - Finish

    private func finishOnboarding() {
        let user = ensureUserExists()
        user.firstName = firstName
        user.profileEmoji = profileEmoji
        user.profilePhotoData = profilePhotoData
        user.onboardingCompleted = true
        loadCategoriesIfNeeded()
        try? modelContext.save()
    }

    // MARK: - Card Commit

    private func commitCards(_ templates: [CardTemplate]) {
        guard !templates.isEmpty else {
            advanceToNextStep()
            return
        }

        let user = ensureUserExists()
        for template in templates {
            let newCard = template.toCreditCard(modelContext: modelContext)
            if !user.cardDisplayOrder.contains(newCard.id) {
                user.cardDisplayOrder.append(newCard.id)
            }
            // Auto-add spending categories from the card's rewards
            let cardCategories = newCard.activeRewards.compactMap { $0.categories }.joined()
            for categoryID in cardCategories where categoryID != "merchants" {
                if !user.selectedCategories.contains(categoryID) {
                    user.selectedCategories.append(categoryID)
                }
            }
        }
        try? modelContext.save()

        // Automatically apply program upgrades after cards are committed
        let allCards = (try? modelContext.fetch(FetchDescriptor<CreditCard>())) ?? []
        let proposals = ProgramUpgradeDatabase.detectPendingChanges(cards: allCards)
        ProgramUpgradeDatabase.applyAll(proposals)
        try? modelContext.save()
        advanceToNextStep()
    }

    // MARK: - User Management

    @discardableResult
    private func ensureUserExists() -> User {
        if let existing = users.first {
            // Update with collected data
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
