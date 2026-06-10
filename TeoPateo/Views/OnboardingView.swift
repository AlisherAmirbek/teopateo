import SwiftUI

struct OnboardingView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var store: TeoPateoStore

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
        Button {
            advance()
        } label: {
            HStack {
                Text(L10n.key(current == .review ? "Create my plan" : "Continue"))
                Image(systemName: current == .review ? "checkmark" : "arrow.right")
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(FilledButtonStyle())
        .disabled(!canAdvance)
        .opacity(canAdvance ? 1 : 0.45)
        .accessibilityIdentifier("onboarding-next-button")
        .padding(.horizontal, metrics.horizontalPadding)
        .padding(.top, 12)
        .padding(.bottom, 20)
        .frame(maxWidth: metrics.readingMaxWidth)
        .frame(maxWidth: .infinity)
        .background(QuitTheme.background)
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
        VStack(alignment: .leading, spacing: 0) {
            TeoMascotView(pose: step.pose, breathing: false, entrance: false)
                .frame(height: 88)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 4)
                .accessibilityHidden(true)

            speechCloud(eyebrow: eyebrow(for: step), title: step.title)
        }
    }

    /// Teo's prompt as a chat-style speech bubble whose text types in.
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
        .padding(.horizontal, Spacing.md)
        .padding(.top, 24)
        .padding(.bottom, Spacing.md)
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
                    selectAndAdvance {
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
                    selectAndAdvance {
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
                    selectAndAdvance { cigarettesPerDay = card.value }
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
                    quitDatePicked = true
                    if preference == .helpMeChoose {
                        selectAndAdvance { quitDatePreference = preference }
                    } else {
                        Haptics.selection()
                        withAnimationIfPossible {
                            quitDatePreference = preference
                            normalizeQuitDateForPreference()
                        }
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
                    selectAndAdvance { approachPreference = approach }
                }
            }
        }
    }

    private var confidenceInput: some View {
        VStack(alignment: .leading, spacing: Spacing.smd) {
            ForEach(confidenceCards, id: \.label) { card in
                choiceCard(card.label, isSelected: confidence == card.value) {
                    selectAndAdvance { confidence = card.value }
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
            return usingCustomReason
        case .quitDate:
            return quitDatePicked && quitDatePreference != .helpMeChoose
        default:
            return false
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

        if current == .review {
            Haptics.success()
            store.completeOnboarding(currentPlanInput)
            return
        }

        Haptics.impact(.light)
        goTo(step + 1, forward: true)
    }

    private func back() {
        if step == 0 {
            store.dismissOnboardingForNow()
        } else {
            goTo(step - 1, forward: false)
        }
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

    /// Used by single-choice cards: register the choice with a selection haptic,
    /// then glide to the next screen so the flow feels tap-forward.
    private func selectAndAdvance(_ apply: @escaping () -> Void) {
        Haptics.selection()
        withAnimationIfPossible {
            apply()
            answered.insert(current)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            goTo(step + 1, forward: true)
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

/// A rounded message bubble with a small tail at the top, pointing up toward Teo.
private struct SpeechBubbleShape: Shape {
    var cornerRadius: CGFloat = 18
    var tailHeight: CGFloat = 11
    var tailWidth: CGFloat = 18
    var tailInset: CGFloat = 42

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let r = min(cornerRadius, (rect.height - tailHeight) / 2)
        let bodyTop = rect.minY + tailHeight

        path.move(to: CGPoint(x: rect.minX + r, y: bodyTop))
        path.addLine(to: CGPoint(x: tailInset - tailWidth / 2, y: bodyTop))
        path.addLine(to: CGPoint(x: tailInset, y: rect.minY))
        path.addLine(to: CGPoint(x: tailInset + tailWidth / 2, y: bodyTop))
        path.addLine(to: CGPoint(x: rect.maxX - r, y: bodyTop))
        path.addArc(
            center: CGPoint(x: rect.maxX - r, y: bodyTop + r),
            radius: r, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        path.addArc(
            center: CGPoint(x: rect.maxX - r, y: rect.maxY - r),
            radius: r, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        path.addArc(
            center: CGPoint(x: rect.minX + r, y: rect.maxY - r),
            radius: r, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.minX, y: bodyTop + r))
        path.addArc(
            center: CGPoint(x: rect.minX + r, y: bodyTop + r),
            radius: r, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false
        )
        path.closeSubpath()
        return path
    }
}
