import SwiftUI

struct OnboardingView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var store: TeoPateoStore
    @EnvironmentObject private var subscriptionStore: SubscriptionStore

    @State private var step = 0
    @State private var transitionForward = true
    @State private var usingCustomReason = false
    @State private var quitDatePicked = false
    @State private var answered: Set<OnboardingStep> = []

    @State private var nickname = ""
    @State private var age = 32
    @State private var quitStatus: QuitStatus = .readyToQuit
    @State private var primaryReason = ""
    @State private var confidence = 5.0
    @State private var smokingStartMode: SmokingStartMode = .ageStarted
    @State private var ageStartedSmoking = 18
    @State private var yearsSmoking = 10
    @State private var cigarettesPerDay = 10.0
    @State private var firstCigaretteTiming: FirstCigaretteTiming = .withinThirtyMinutes
    @State private var previousQuitAttemptCount: PreviousQuitAttemptCount = .one
    @State private var longestQuitAttempt: LongestQuitAttempt = .fewDays
    @State private var mainChallenge: SmokingChallenge = .cravings
    @State private var selectedCommonSmokingTimes: Set<String> = []
    @State private var selectedEmotionalTriggers: Set<String> = []
    @State private var selectedSituationalTriggers: Set<String> = []
    @State private var quitDatePreference: QuitDatePreference = .chooseDate
    @State private var quitDate = Calendar.current.date(byAdding: .day, value: 10, to: Date()) ?? Date()
    @State private var approachPreference: QuitApproachPreference = .notSure
    @State private var selectedReplacementActions: Set<String> = []
    @State private var costPerPack = 10.0
    @State private var cigarettesPerPack = 20
    @State private var savingsGoalTitle = "Health"
    @State private var customSavingsGoal = ""

    @State private var interlude: OnboardingInterlude?
    @State private var shownInterstitials: Set<Int> = []
    @State private var isSubscriptionOfferPresented = false

    private let replacementActions = [
        "Drink water",
        "Walk",
        "Breathing",
        "Chewing gum",
        "Brush teeth",
        "Message someone",
        "Journal",
        "Short task"
    ]
    private let savingsGoalOptions = [
        "Emergency fund",
        "Trip",
        "Family",
        "Health",
        "Debt",
        "Personal reward",
        "Custom"
    ]

    private let reasonCards: [(label: String, text: String)] = [
        ("My health", "I want my health back."),
        ("My family", "I want to be there for the people I love."),
        ("Save money", "I am done burning money on cigarettes."),
        ("Feel in control", "I want to feel in control again.")
    ]
    private let dailyAmountCards: [(label: String, value: Double)] = [
        ("A few — about 5", 5),
        ("Around 10", 10),
        ("Around 15", 15),
        ("About a pack — 20", 20),
        ("More than a pack", 30)
    ]
    private let confidenceCards: [(label: String, value: Double)] = [
        ("Not yet", 2),
        ("A little", 4),
        ("Somewhat", 6),
        ("Pretty confident", 8),
        ("Very confident", 10)
    ]

    private var steps: [OnboardingStep] { OnboardingStep.allCases }
    private var current: OnboardingStep { OnboardingStep(rawValue: step) ?? .name }

    var body: some View {
        GeometryReader { proxy in
            let metrics = AdaptiveScreenMetrics(
                width: proxy.size.width,
                horizontalSizeClass: horizontalSizeClass,
                dynamicTypeSize: dynamicTypeSize
            )

            ZStack {
                QuitTheme.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    topBar(metrics: metrics)

                    if let interlude {
                        interludeContainer(interlude, metrics: metrics)
                    } else {
                        progress(metrics: metrics)

                        ScrollView {
                            screen(for: current)
                                .id(step)
                                .transition(screenTransition)
                                .padding(.horizontal, metrics.horizontalPadding)
                                .padding(.top, metrics.usesWideLayout ? 24 : 18)
                                .padding(.bottom, 24)
                                .frame(maxWidth: metrics.readingMaxWidth, alignment: .leading)
                                .frame(maxWidth: .infinity)
                        }

                        if showsContinueButton {
                            bottomBar(metrics: metrics)
                        }
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $isSubscriptionOfferPresented) {
            OnboardingSubscriptionOfferView(
                finishOnboarding: finishOnboardingAfterOffer
            )
            .environmentObject(subscriptionStore)
        }
    }

    // MARK: - Chrome

    private func topBar(metrics: AdaptiveScreenMetrics) -> some View {
        HStack {
            Button {
                back()
            } label: {
                Image(systemName: step == 0 ? "xmark" : "chevron.left")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(QuitTheme.cocoa)
                    .frame(width: 42, height: 42)
                    .background(QuitTheme.peach.opacity(0.72))
                    .clipShape(Circle())
            }
            .accessibilityLabel(L10n.string(step == 0 ? "Skip onboarding" : "Back"))

            Spacer()

            Button("Skip for now") {
                store.dismissOnboardingForNow()
            }
            .font(.rounded(.caption, weight: .bold))
            .foregroundColor(QuitTheme.muted)
        }
        .padding(.horizontal, metrics.horizontalPadding)
        .padding(.top, metrics.usesWideLayout ? 18 : 14)
        .frame(maxWidth: metrics.readingMaxWidth)
        .frame(maxWidth: .infinity)
    }

    private func progress(metrics: AdaptiveScreenMetrics) -> some View {
        HStack(spacing: 6) {
            ForEach(steps.indices, id: \.self) { index in
                Capsule()
                    .fill(index <= step ? QuitTheme.cocoa : QuitTheme.line)
                    .frame(height: 5)
            }
        }
        .padding(.horizontal, metrics.horizontalPadding)
        .padding(.top, 14)
        .frame(maxWidth: metrics.readingMaxWidth)
        .frame(maxWidth: .infinity)
    }

    private func bottomBar(metrics: AdaptiveScreenMetrics) -> some View {
        actionBar(
            title: current == .review ? "Create my plan" : "Continue",
            systemImage: current == .review ? "checkmark" : "arrow.right",
            identifier: "onboarding-next-button",
            enabled: canAdvance,
            metrics: metrics,
            action: advance
        )
    }

    private func actionBar(
        title: String,
        systemImage: String,
        identifier: String,
        enabled: Bool,
        metrics: AdaptiveScreenMetrics,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                Text(L10n.key(title))
                Image(systemName: systemImage)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(FilledButtonStyle())
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.45)
        .accessibilityIdentifier(identifier)
        .padding(.horizontal, metrics.horizontalPadding)
        .padding(.top, 12)
        .padding(.bottom, 20)
        .frame(maxWidth: metrics.readingMaxWidth)
        .frame(maxWidth: .infinity)
        .background(QuitTheme.background)
    }

    // MARK: - Interludes (warm fillers between and after questions)

    @ViewBuilder
    private func interludeContainer(_ interlude: OnboardingInterlude, metrics: AdaptiveScreenMetrics) -> some View {
        VStack(spacing: 0) {
            interludeContent(interlude)
                .padding(.horizontal, metrics.horizontalPadding)
                .frame(maxWidth: metrics.readingMaxWidth)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            switch interlude {
            case .message:
                actionBar(
                    title: "Continue",
                    systemImage: "arrow.right",
                    identifier: "onboarding-interlude-continue",
                    enabled: true,
                    metrics: metrics,
                    action: continueFromMessage
                )
            case .building, .pledge:
                EmptyView()
            }
        }
        .transition(.opacity)
    }

    @ViewBuilder
    private func interludeContent(_ interlude: OnboardingInterlude) -> some View {
        switch interlude {
        case let .message(_, text, pose):
            OnboardingMessageScreen(text: text, pose: pose)
        case .building:
            OnboardingBuildingScreen(steps: buildingSteps, reduceMotion: reduceMotion, onFinished: finishBuilding)
        case .pledge:
            OnboardingPledgeScreen(name: displayName, reduceMotion: reduceMotion, onCommitted: completeFromPledge)
        }
    }

    private var buildingSteps: [String] {
        let name = displayName
        return [
            "Reading your reason and triggers",
            "Choosing your first-week goal",
            "Lining up your rescue actions",
            name.isEmpty ? "Personalizing your plan" : "Personalizing everything for \(name)"
        ]
    }

    /// The warm transition shown right before a given question, or `nil`. Each
    /// fires at most once (tracked by `shownInterstitials`).
    private func interstitial(before step: OnboardingStep) -> OnboardingInterlude? {
        let name = displayName
        switch step {
        case .status:
            let text = name.isEmpty
                ? "Thanks for sharing that. Let's get a clear picture of your smoking."
                : "Thanks for sharing that, \(name). Let's get a clear picture of your smoking."
            return .message(id: step.rawValue, text: text, pose: .standing)
        case .quitDate:
            let text = name.isEmpty
                ? "That's the hard part done. Now let's shape your plan."
                : "That's the hard part done, \(name). Now let's shape your plan."
            return .message(id: step.rawValue, text: text, pose: .playful)
        default:
            return nil
        }
    }

    // MARK: - Screens

    @ViewBuilder
    private func screen(for step: OnboardingStep) -> some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            prompt(for: step)
            input(for: step)
        }
    }

    private func prompt(for step: OnboardingStep) -> some View {
        HStack(alignment: .center, spacing: Spacing.xs) {
            TeoMascotView(pose: step.pose, breathing: false, entrance: false)
                .frame(width: mascotPromptSize, height: mascotPromptSize)
                .accessibilityHidden(true)

            speechCloud(eyebrow: eyebrow(for: step), title: step.title)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var mascotPromptSize: CGFloat {
        horizontalSizeClass == .regular ? 184 : 132
    }

    /// Teo's prompt as a chat-style speech bubble, sitting to his right with the
    /// tail pointing back at him. The text types in character by character.
    private func speechCloud(eyebrow: String, title: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            TypewriterText(
                text: eyebrow,
                font: .rounded(.footnote, weight: .semibold),
                color: QuitTheme.muted
            )
            .accessibilityHidden(true)

            TypewriterText(
                text: title,
                font: .rounded(.title2, weight: .bold),
                color: QuitTheme.ink,
                startDelay: Double(eyebrow.count) * 0.028 + 0.15
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 26)
        .padding(.trailing, Spacing.md)
        .padding(.vertical, Spacing.md)
        .background(SpeechBubbleShape().fill(QuitTheme.paper))
        .overlay(SpeechBubbleShape().stroke(QuitTheme.line, lineWidth: 1))
    }

    @ViewBuilder
    private func input(for step: OnboardingStep) -> some View {
        switch step {
        case .name:
            nameInput
        case .reason:
            reasonInput
        case .status:
            statusInput
        case .dailyAmount:
            dailyAmountInput
        case .whenTriggers:
            whenTriggersInput
        case .feelingTriggers:
            feelingTriggersInput
        case .replacements:
            replacementsInput
        case .quitDate:
            quitDateInput
        case .approach:
            approachInput
        case .confidence:
            confidenceInput
        case .review:
            reviewInput
        }
    }

    private var nameInput: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            TextField("Name or nickname", text: $nickname)
                .textFieldStyle(QuietFieldStyle())
                .submitLabel(.next)
                .onSubmit { advance() }
                .accessibilityIdentifier("onboarding-nickname-field")

            MedicalBoundaryNotice()
        }
    }

    private var reasonInput: some View {
        VStack(alignment: .leading, spacing: Spacing.smd) {
            ForEach(reasonCards, id: \.label) { card in
                choiceCard(card.label, isSelected: !usingCustomReason && primaryReason == card.text) {
                    select {
                        usingCustomReason = false
                        primaryReason = card.text
                    }
                }
            }

            choiceCard("Something else", isSelected: usingCustomReason) {
                Haptics.selection()
                withAnimationIfPossible {
                    usingCustomReason = true
                    if reasonCards.contains(where: { $0.text == primaryReason }) {
                        primaryReason = ""
                    }
                }
            }

            if usingCustomReason {
                TextField("In your own words", text: $primaryReason)
                    .textFieldStyle(QuietFieldStyle())
                    .submitLabel(.next)
                    .onSubmit { advance() }
                    .accessibilityIdentifier("onboarding-reason-field")
            }
        }
    }

    private var statusInput: some View {
        VStack(alignment: .leading, spacing: Spacing.smd) {
            ForEach(QuitStatus.allCases) { status in
                choiceCard(status.title, isSelected: answered.contains(.status) && quitStatus == status) {
                    select {
                        quitStatus = status
                        if status == .alreadyQuit {
                            quitDatePreference = .alreadyQuit
                            approachPreference = .coldTurkey
                        } else if quitDatePreference == .alreadyQuit {
                            quitDatePreference = .chooseDate
                        }
                        normalizeQuitDateForPreference()
                    }
                }
            }
        }
    }

    private var dailyAmountInput: some View {
        VStack(alignment: .leading, spacing: Spacing.smd) {
            ForEach(dailyAmountCards, id: \.label) { card in
                choiceCard(card.label, isSelected: answered.contains(.dailyAmount) && cigarettesPerDay == card.value) {
                    select { cigarettesPerDay = card.value }
                }
            }
        }
    }

    private var whenTriggersInput: some View {
        VStack(alignment: .leading, spacing: Spacing.smd) {
            Text("Pick the moments TeoPateo should protect first.")
                .typeBodySecondary()
            FlexibleTags(items: QuitTriggerCatalog.commonSmokingTimes, selected: $selectedCommonSmokingTimes)
            FlexibleTags(items: QuitTriggerCatalog.situationalTriggers, selected: $selectedSituationalTriggers)
        }
    }

    private var feelingTriggersInput: some View {
        VStack(alignment: .leading, spacing: Spacing.smd) {
            Text("Optional — skip if none fit.")
                .typeBodySecondary()
            FlexibleTags(items: QuitTriggerCatalog.emotionalTriggers, selected: $selectedEmotionalTriggers)
        }
    }

    private var replacementsInput: some View {
        VStack(alignment: .leading, spacing: Spacing.smd) {
            Text("We'll line these up for the 10-minute craving timer.")
                .typeBodySecondary()
            FlexibleTags(items: replacementActions, selected: $selectedReplacementActions)
        }
    }

    private var quitDateInput: some View {
        VStack(alignment: .leading, spacing: Spacing.smd) {
            ForEach(QuitDatePreference.allCases) { preference in
                choiceCard(preference.title, isSelected: quitDatePicked && quitDatePreference == preference) {
                    Haptics.selection()
                    quitDatePicked = true
                    withAnimationIfPossible {
                        quitDatePreference = preference
                        normalizeQuitDateForPreference()
                    }
                }
            }

            if quitDatePicked && quitDatePreference != .helpMeChoose {
                DatePicker(
                    quitDatePreference == .alreadyQuit ? "Quit date" : "Target date",
                    selection: $quitDate,
                    in: quitDateRange,
                    displayedComponents: .date
                )
                .font(.rounded(.body, weight: .semibold))
                .tint(QuitTheme.cocoa)
                .padding(.top, Spacing.xs)
            }
        }
    }

    private var approachInput: some View {
        VStack(alignment: .leading, spacing: Spacing.smd) {
            ForEach(QuitApproachPreference.allCases) { approach in
                choiceCard(approach.title, isSelected: answered.contains(.approach) && approachPreference == approach) {
                    select { approachPreference = approach }
                }
            }
        }
    }

    private var confidenceInput: some View {
        VStack(alignment: .leading, spacing: Spacing.smd) {
            ForEach(confidenceCards, id: \.label) { card in
                choiceCard(card.label, isSelected: confidence == card.value) {
                    select { confidence = card.value }
                }
            }
        }
    }

    private var reviewInput: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: Spacing.smd) {
                Text(generatedPlanPreview.planSummary.summary)
                    .typeBody()
                    .fixedSize(horizontal: false, vertical: true)
                OnboardingReviewRow(label: "First-week goal", value: generatedPlanPreview.firstWeekGoal)
                OnboardingReviewRow(label: "Next best action", value: generatedPlanPreview.nextBestAction)
            }
            .quietCard()

            VStack(alignment: .leading, spacing: Spacing.md) {
                OnboardingReviewRow(label: "You", value: nickname.trimmingCharacters(in: .whitespacesAndNewlines))
                OnboardingReviewRow(label: "Approach", value: resolvedApproachTitle)
                OnboardingReviewRow(label: "Quit date", value: resolvedQuitDate.formatted(date: .abbreviated, time: .omitted))
                OnboardingReviewRow(label: "Top triggers", value: selectedTriggerList.prefix(4).joined(separator: ", "))
                OnboardingReviewRow(label: "Daily focus", value: generatedDailyFocusPreview)
                OnboardingReviewRow(label: "Reason", value: primaryReason.trimmingCharacters(in: .whitespacesAndNewlines))
                if let savingsSummary {
                    OnboardingReviewRow(label: "Savings", value: savingsSummary)
                }
            }
            .quietCard()
        }
    }

    // MARK: - Choice card

    private func choiceCard(
        _ title: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: Spacing.smd) {
                Text(L10n.key(title))
                    .font(.rounded(.body, weight: .semibold))
                    .foregroundColor(isSelected ? QuitTheme.onCocoa : QuitTheme.ink)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: Spacing.sm)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(isSelected ? QuitTheme.onCocoa : QuitTheme.faint)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, 17)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? QuitTheme.cocoa : QuitTheme.paper)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(isSelected ? Color.clear : QuitTheme.line, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(L10n.string(title))
        .accessibilityValue(L10n.selectedState(isSelected))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("onboarding-choice-\(title)")
    }

    // MARK: - Conversational copy

    private var displayName: String {
        let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "" : trimmed
    }

    private func eyebrow(for step: OnboardingStep) -> String {
        switch step {
        case .name: return "Hi, I'm Teo."
        case .reason: return displayName.isEmpty ? "Nice to meet you." : "Nice to meet you, \(displayName)."
        case .status: return "No judgment here."
        case .dailyAmount: return "Just so I get the full picture."
        case .whenTriggers: return "Let's map your danger zones."
        case .feelingTriggers: return "Cravings often ride on a feeling."
        case .replacements: return "We'll have a backup ready."
        case .quitDate: return "Your timeline, your call."
        case .approach: return "However you want to do this."
        case .confidence: return "However you feel is okay."
        case .review: return displayName.isEmpty ? "All set." : "All set, \(displayName)."
        }
    }

    // MARK: - Navigation

    private var screenTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .asymmetric(
            insertion: .move(edge: transitionForward ? .trailing : .leading).combined(with: .opacity),
            removal: .move(edge: transitionForward ? .leading : .trailing).combined(with: .opacity)
        )
    }

    private var showsContinueButton: Bool {
        switch current {
        case .name, .whenTriggers, .feelingTriggers, .replacements, .review:
            return true
        case .reason:
            return usingCustomReason || !primaryReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .status, .dailyAmount, .approach, .confidence:
            return answered.contains(current)
        case .quitDate:
            return quitDatePicked
        }
    }

    private var canAdvance: Bool {
        switch current {
        case .name:
            return !nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .reason:
            return !primaryReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .whenTriggers:
            return selectedTriggerCount > 0
        case .replacements:
            return !selectedReplacementActions.isEmpty
        case .review:
            return !nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                !primaryReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                selectedTriggerCount > 0
        default:
            return true
        }
    }

    private func advance() {
        guard canAdvance else { return }

        // Final question → commitment pledge, which finalizes onboarding.
        if current == .review {
            presentInterlude(.pledge)
            return
        }

        // Last setup question → "building your plan" beat, then the review.
        if current == .confidence {
            presentInterlude(.building)
            return
        }

        // A warm transition before entering certain sections (once each).
        if let target = OnboardingStep(rawValue: step + 1),
           !shownInterstitials.contains(target.rawValue),
           let transition = interstitial(before: target) {
            shownInterstitials.insert(target.rawValue)
            presentInterlude(transition)
            return
        }

        Haptics.impact(.light)
        goTo(step + 1, forward: true)
    }

    private func back() {
        if interlude != nil {
            dismissInterlude()
            return
        }
        if step == 0 {
            store.dismissOnboardingForNow()
        } else {
            goTo(step - 1, forward: false)
        }
    }

    private func presentInterlude(_ value: OnboardingInterlude) {
        if reduceMotion {
            interlude = value
        } else {
            withAnimation(.easeInOut(duration: 0.3)) { interlude = value }
        }
    }

    private func dismissInterlude() {
        if reduceMotion {
            interlude = nil
        } else {
            withAnimation(.easeInOut(duration: 0.25)) { interlude = nil }
        }
    }

    /// Continue out of a transition message into the question it precedes.
    /// Advances and clears the interlude together so the next question slides in
    /// directly, without a flash of the question we just left.
    private func continueFromMessage() {
        transitionForward = true
        let target = min(step + 1, steps.count - 1)
        Haptics.impact(.light)
        if reduceMotion {
            step = target
            interlude = nil
        } else {
            withAnimation(.easeInOut(duration: 0.3)) {
                step = target
                interlude = nil
            }
        }
    }

    /// The "building your plan" beat finished — reveal the review.
    private func finishBuilding() {
        transitionForward = true
        if reduceMotion {
            interlude = nil
            step = OnboardingStep.review.rawValue
        } else {
            withAnimation(.easeInOut(duration: 0.35)) {
                interlude = nil
                step = OnboardingStep.review.rawValue
            }
        }
    }

    private func completeFromPledge() {
        guard store.completeOnboarding(
            currentPlanInput,
            keepsOnboardingPresented: true
        ) else {
            return
        }
        isSubscriptionOfferPresented = true
    }

    private func finishOnboardingAfterOffer() {
        isSubscriptionOfferPresented = false
        store.dismissOnboardingForNow()
    }

    private func goTo(_ newStep: Int, forward: Bool) {
        transitionForward = forward
        let clamped = min(max(newStep, 0), steps.count - 1)
        if reduceMotion {
            step = clamped
        } else {
            withAnimation(.easeInOut(duration: 0.28)) {
                step = clamped
            }
        }
    }

    /// Used by single-choice cards: register the choice with a selection haptic
    /// and reveal the Continue button. Moving on is always an explicit Continue tap.
    private func select(_ apply: @escaping () -> Void) {
        Haptics.selection()
        withAnimationIfPossible {
            apply()
            answered.insert(current)
        }
    }

    private func withAnimationIfPossible(_ body: () -> Void) {
        if reduceMotion {
            body()
        } else {
            withAnimation(.easeInOut(duration: 0.2), body)
        }
    }

    // MARK: - Preserved plan logic

    private var selectedTriggerCount: Int {
        selectedCommonSmokingTimes.count + selectedEmotionalTriggers.count + selectedSituationalTriggers.count
    }

    private var selectedTriggerList: [String] {
        orderedSelection(QuitTriggerCatalog.commonSmokingTimes, selected: selectedCommonSmokingTimes) +
            orderedSelection(QuitTriggerCatalog.emotionalTriggers, selected: selectedEmotionalTriggers) +
            orderedSelection(QuitTriggerCatalog.situationalTriggers, selected: selectedSituationalTriggers)
    }

    private var selectedReplacementActionList: [String] {
        orderedSelection(replacementActions, selected: selectedReplacementActions)
    }

    private var resolvedApproachTitle: String {
        switch approachPreference {
        case .taper:
            return quitStatus == .alreadyQuit ? "Cold turkey" : "Taper"
        case .coldTurkey:
            return "Cold turkey"
        case .notSure:
            if quitStatus == .alreadyQuit || (quitStatus == .readyToQuit && confidence >= 7 && cigarettesPerDay <= 10) {
                return "Cold turkey"
            }
            return "Taper"
        }
    }

    private var generatedDailyFocusPreview: String {
        let trigger = selectedTriggerList.first ?? mainChallenge.triggerLabel
        switch quitStatus {
        case .alreadyQuit:
            return "Protect \(trigger.lowercased()) with a 10-minute rescue before the urge peaks."
        case .readyToQuit:
            return "Rehearse the \(trigger.lowercased()) rule once before the quit date."
        case .cuttingDown:
            return "Delay one \(trigger.lowercased()) cigarette and use a replacement first."
        case .thinkingAboutIt:
            return "Notice the next \(trigger.lowercased()) cue and try one replacement without pressure."
        case .unsure:
            return "Log one smoking moment and what the \(mainChallenge.title.lowercased()) was asking for."
        }
    }

    private var quitDateRange: ClosedRange<Date> {
        let today = Calendar.current.startOfDay(for: Date())
        let early = Calendar.current.date(byAdding: .year, value: -60, to: today) ?? today
        let future = Calendar.current.date(byAdding: .year, value: 3, to: today) ?? today
        if quitDatePreference == .alreadyQuit {
            return early...today
        }
        return today...future
    }

    private var suggestedQuitDate: Date {
        let today = Calendar.current.startOfDay(for: Date())
        let days: Int
        switch quitStatus {
        case .alreadyQuit:
            days = 0
        case .readyToQuit:
            days = confidence >= 7 ? 7 : 10
        case .cuttingDown:
            days = confidence >= 7 ? 14 : 21
        case .thinkingAboutIt, .unsure:
            days = 21
        }
        return Calendar.current.date(byAdding: .day, value: days, to: today) ?? today
    }

    private var resolvedQuitDate: Date {
        switch quitDatePreference {
        case .helpMeChoose:
            return suggestedQuitDate
        case .alreadyQuit:
            return min(Calendar.current.startOfDay(for: quitDate), Calendar.current.startOfDay(for: Date()))
        case .chooseDate:
            return max(Calendar.current.startOfDay(for: quitDate), Calendar.current.startOfDay(for: Date()))
        }
    }

    private var savingsSummary: String? {
        let title = savingsGoalTitle == "Custom"
            ? customSavingsGoal.trimmingCharacters(in: .whitespacesAndNewlines)
            : savingsGoalTitle
        guard !title.isEmpty else { return nil }
        let weekly = cigarettesPerDay * 7 * (costPerPack / Double(max(cigarettesPerPack, 1)))
        return "\(currency(weekly)) per smoke-free week toward \(title.lowercased())."
    }

    private var generatedPlanPreview: QuitPlan {
        QuitPlanGenerator.generate(
            from: currentPlanInput,
            existingPlan: store.currentQuitPlan,
            now: Date(),
            calendar: Calendar.current
        ).quitPlan
    }

    private var currentPlanInput: OnboardingPlanInput {
        OnboardingPlanInput(
            nickname: nickname,
            age: age,
            quitStatus: quitStatus,
            confidence: confidence,
            openedAppReason: "",
            ageStartedSmoking: smokingStartMode == .ageStarted ? ageStartedSmoking : nil,
            yearsSmoking: smokingStartMode == .yearsSmoking ? yearsSmoking : nil,
            cigarettesPerDay: cigarettesPerDay,
            firstCigaretteTiming: firstCigaretteTiming,
            previousQuitAttemptCount: previousQuitAttemptCount,
            longestQuitAttempt: longestQuitAttempt,
            mainChallenge: mainChallenge,
            commonSmokingTimes: orderedSelection(QuitTriggerCatalog.commonSmokingTimes, selected: selectedCommonSmokingTimes),
            emotionalTriggers: orderedSelection(QuitTriggerCatalog.emotionalTriggers, selected: selectedEmotionalTriggers),
            situationalTriggers: orderedSelection(QuitTriggerCatalog.situationalTriggers, selected: selectedSituationalTriggers),
            quitDatePreference: quitDatePreference,
            costPerPack: costPerPack,
            cigarettesPerPack: cigarettesPerPack,
            quitDate: quitDate,
            approachPreference: approachPreference,
            replacementActions: selectedReplacementActionList,
            primaryReason: primaryReason,
            savingsGoalTitle: savingsGoalTitle,
            customSavingsGoal: customSavingsGoal
        )
    }

    private func normalizeQuitDateForPreference() {
        if quitDatePreference == .alreadyQuit {
            quitDate = min(quitDate, Date())
        } else {
            quitDate = max(quitDate, Date())
        }
    }

    private func orderedSelection(_ source: [String], selected: Set<String>) -> [String] {
        source.filter { selected.contains($0) }
    }

    private func currency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_US")
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = value.rounded() == value ? 0 : 2
        return formatter.string(from: NSNumber(value: value)) ?? "$0"
    }
}

/// A non-question beat layered over the onboarding flow: a warm transition
/// message, the "building your plan" screen, or the commitment pledge. These do
/// not appear in the progress bar and never replace a question.
private enum OnboardingInterlude: Equatable {
    case message(id: Int, text: String, pose: MascotPose)
    case building
    case pledge
}

private enum OnboardingStep: Int, CaseIterable {
    case name
    case reason
    case status
    case dailyAmount
    case whenTriggers
    case feelingTriggers
    case replacements
    case quitDate
    case approach
    case confidence
    case review

    var title: String {
        switch self {
        case .name: return "What should I call you?"
        case .reason: return "What's pulling you to quit?"
        case .status: return "Where are you with quitting?"
        case .dailyAmount: return "How much do you smoke?"
        case .whenTriggers: return "When do cravings hit hardest?"
        case .feelingTriggers: return "What feelings set them off?"
        case .replacements: return "What could you do instead?"
        case .quitDate: return "When's your quit day?"
        case .approach: return "How do you want to quit?"
        case .confidence: return "How confident do you feel?"
        case .review: return "Here's your starter plan."
        }
    }

    var pose: MascotPose {
        switch self {
        case .name: return .standing
        case .reason: return .waiting
        case .status: return .standing
        case .dailyAmount: return .waiting
        case .whenTriggers: return .walking
        case .feelingTriggers: return .waiting
        case .replacements: return .playful
        case .quitDate: return .walking
        case .approach: return .standing
        case .confidence: return .playing
        case .review: return .playing
        }
    }
}

private enum SmokingStartMode {
    case ageStarted
    case yearsSmoking
}

private struct OnboardingReviewRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(L10n.key(label))
                .typeLabel()
            Text(value.isEmpty ? "Not set" : value)
                .font(.rounded(.callout, weight: .semibold))
                .foregroundColor(QuitTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Reveals text one character at a time, like Teo typing a message. The full
/// string is reserved (invisible) so the bubble never reflows, and is exposed as
/// the accessibility label so VoiceOver and UI tests see the whole message.
/// Honors Reduce Motion by showing the text immediately.
private struct TypewriterText: View {
    let text: String
    let font: Font
    let color: Color
    var interval: Double = 0.028
    var startDelay: Double = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var count = 0

    var body: some View {
        ZStack(alignment: .topLeading) {
            Text(text)
                .font(font)
                .foregroundColor(.clear)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityHidden(true)
            Text(String(text.prefix(count)))
                .font(font)
                .foregroundColor(color)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(text)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .task(id: text) {
            await typeOut()
        }
    }

    private func typeOut() async {
        if reduceMotion {
            count = text.count
            return
        }
        count = 0
        if startDelay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(startDelay * 1_000_000_000))
        }
        guard !text.isEmpty else { return }
        for index in 1...text.count {
            try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            if Task.isCancelled { return }
            count = index
        }
    }
}

/// A rounded message bubble with a small tail on its left edge, pointing back
/// toward Teo who sits to the bubble's left.
private struct SpeechBubbleShape: Shape {
    var cornerRadius: CGFloat = 18
    var tailWidth: CGFloat = 12
    var tailSpread: CGFloat = 18

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let r = min(cornerRadius, min(rect.height, rect.width - tailWidth) / 2)
        let bodyLeft = rect.minX + tailWidth

        // Keep the tail on the straight part of the left edge, centered vertically.
        let tipY = max(
            rect.minY + r + tailSpread / 2,
            min(rect.midY, rect.maxY - r - tailSpread / 2)
        )

        path.move(to: CGPoint(x: bodyLeft + r, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
        path.addArc(
            center: CGPoint(x: rect.maxX - r, y: rect.minY + r),
            radius: r, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        path.addArc(
            center: CGPoint(x: rect.maxX - r, y: rect.maxY - r),
            radius: r, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false
        )
        path.addLine(to: CGPoint(x: bodyLeft + r, y: rect.maxY))
        path.addArc(
            center: CGPoint(x: bodyLeft + r, y: rect.maxY - r),
            radius: r, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false
        )
        path.addLine(to: CGPoint(x: bodyLeft, y: tipY + tailSpread / 2))
        path.addLine(to: CGPoint(x: rect.minX, y: tipY))
        path.addLine(to: CGPoint(x: bodyLeft, y: tipY - tailSpread / 2))
        path.addLine(to: CGPoint(x: bodyLeft, y: rect.minY + r))
        path.addArc(
            center: CGPoint(x: bodyLeft + r, y: rect.minY + r),
            radius: r, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false
        )
        path.closeSubpath()
        return path
    }
}

// MARK: - Interlude screens
//
// Warm "filler" beats shown between and after the onboarding questions. They
// never change the questions themselves — they add pacing and encouragement,
// in TeoPateo's minimalist palette with Teo the dog.

/// Teo with a short, encouraging line — the transition between question groups.
private struct OnboardingMessageScreen: View {
    let text: String
    let pose: MascotPose

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Spacer(minLength: Spacing.lg)

            TeoMascotView(pose: pose, breathing: true, entrance: false)
                .frame(width: 200, height: 200)
                .accessibilityHidden(true)

            Text(text)
                .font(.rounded(.title2, weight: .bold))
                .foregroundColor(QuitTheme.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Spacing.sm)
                .accessibilityAddTraits(.isHeader)

            Spacer(minLength: Spacing.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// "Building your plan…" — a short processing beat so the generated plan feels
/// earned. Ticks through a few status lines, then calls `onFinished`.
private struct OnboardingBuildingScreen: View {
    let steps: [String]
    let reduceMotion: Bool
    let onFinished: () -> Void

    @State private var visibleCount = 0

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Spacer(minLength: Spacing.lg)

            TeoMascotView(pose: .playing, breathing: true, entrance: false)
                .frame(width: 184, height: 184)
                .accessibilityHidden(true)

            Text("Building your plan…")
                .font(.rounded(.title2, weight: .bold))
                .foregroundColor(QuitTheme.ink)
                .accessibilityAddTraits(.isHeader)

            VStack(alignment: .leading, spacing: Spacing.smd) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, line in
                    let done = index < visibleCount
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: done ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(done ? QuitTheme.sage : QuitTheme.faint)
                        Text(line)
                            .font(.rounded(.body, weight: .semibold))
                            .foregroundColor(done ? QuitTheme.ink : QuitTheme.faint)
                        Spacer(minLength: 0)
                    }
                    .opacity(done ? 1 : 0.55)
                }
            }
            .frame(maxWidth: 360)

            Spacer(minLength: Spacing.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("onboarding-building")
        .task { await run() }
    }

    private func run() async {
        guard !steps.isEmpty else {
            onFinished()
            return
        }

        if reduceMotion {
            visibleCount = steps.count
            try? await Task.sleep(nanoseconds: 700_000_000)
            if Task.isCancelled { return }
            onFinished()
            return
        }

        for index in 1...steps.count {
            try? await Task.sleep(nanoseconds: 650_000_000)
            if Task.isCancelled { return }
            withAnimation(.easeOut(duration: 0.3)) { visibleCount = index }
            Haptics.selection()
        }

        try? await Task.sleep(nanoseconds: 750_000_000)
        if Task.isCancelled { return }
        onFinished()
    }
}

/// A press-and-hold commitment beat. Holding fills the ring; completing it
/// finalizes onboarding. Honors Reduce Motion with a plain button, and is
/// operable by VoiceOver via an accessibility action.
private struct OnboardingPledgeScreen: View {
    let name: String
    let reduceMotion: Bool
    let onCommitted: () -> Void

    private let holdDuration: TimeInterval = 1.4

    @State private var progress: CGFloat = 0
    @State private var holding = false
    @State private var committed = false
    @State private var commitWork: DispatchWorkItem?

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer(minLength: Spacing.lg)

            Text(heading)
                .font(.rounded(.title2, weight: .bold))
                .foregroundColor(QuitTheme.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Spacing.sm)
                .accessibilityAddTraits(.isHeader)

            control

            Text(reduceMotion ? "Tap when you're ready." : "Press and hold to start your plan.")
                .font(.rounded(.subheadline, weight: .medium))
                .foregroundColor(QuitTheme.muted)
                .multilineTextAlignment(.center)

            Spacer(minLength: Spacing.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var heading: String {
        name.isEmpty ? "Let's make it official." : "Let's make it official, \(name)."
    }

    @ViewBuilder
    private var control: some View {
        if reduceMotion {
            Button {
                commit()
            } label: {
                Text(L10n.key("Start my plan"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(FilledButtonStyle())
            .padding(.horizontal, Spacing.xl)
            .accessibilityIdentifier("onboarding-pledge-commit")
        } else {
            ZStack {
                Circle()
                    .stroke(QuitTheme.line, lineWidth: 12)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(QuitTheme.cocoa, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                Text(holding ? "Holding…" : "Hold")
                    .font(.rounded(.headline, weight: .bold))
                    .foregroundColor(QuitTheme.cocoa)
            }
            .frame(width: 196, height: 196)
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in if !holding { beginHold() } }
                    .onEnded { _ in cancelHold() }
            )
            .accessibilityElement()
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(L10n.string("Commit to your plan"))
            .accessibilityHint(L10n.string("Press and hold, or double tap, to start your plan."))
            .accessibilityAction { commit() }
            .accessibilityIdentifier("onboarding-pledge-commit")
        }
    }

    private func beginHold() {
        guard !committed else { return }
        holding = true
        Haptics.impact(.light)
        withAnimation(.linear(duration: holdDuration)) { progress = 1 }

        let work = DispatchWorkItem { commit() }
        commitWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + holdDuration, execute: work)
    }

    private func cancelHold() {
        guard !committed else { return }
        holding = false
        commitWork?.cancel()
        commitWork = nil
        withAnimation(.easeOut(duration: 0.3)) { progress = 0 }
    }

    private func commit() {
        guard !committed else { return }
        committed = true
        holding = false
        commitWork?.cancel()
        commitWork = nil
        withAnimation(.easeOut(duration: 0.2)) { progress = 1 }
        Haptics.success()
        onCommitted()
    }
}
