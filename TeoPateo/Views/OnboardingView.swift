import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var store: TeoPateoStore

    @State private var step = 0
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
    @State private var selectedCommonSmokingTimes: Set<String> = ["After coffee", "After meals", "Work breaks"]
    @State private var selectedEmotionalTriggers: Set<String> = ["Stress"]
    @State private var selectedSituationalTriggers: Set<String> = []
    @State private var quitDatePreference: QuitDatePreference = .chooseDate
    @State private var quitDate = Calendar.current.date(byAdding: .day, value: 10, to: Date()) ?? Date()
    @State private var approachPreference: QuitApproachPreference = .notSure
    @State private var selectedReplacementActions: Set<String> = ["Drink water", "Walk", "Breathing"]
    @State private var costPerPack = 10.0
    @State private var cigarettesPerPack = 20
    @State private var savingsGoalTitle = "Health"
    @State private var customSavingsGoal = ""

    private let finalStep = 6
    private let choiceColumns = [
        GridItem(.adaptive(minimum: 138), spacing: 8)
    ]
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

    var body: some View {
        ZStack {
            QuitTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                progress

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        stepContent
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 22)
                    .padding(.bottom, 22)
                }

                bottomBar
            }
        }
    }

    private var topBar: some View {
        HStack {
            Button {
                if step == 0 {
                    store.dismissOnboardingForNow()
                } else {
                    withAnimation(.easeInOut) {
                        step -= 1
                    }
                }
            } label: {
                Image(systemName: step == 0 ? "xmark" : "chevron.left")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(QuitTheme.cocoa)
                    .frame(width: 42, height: 42)
                    .background(QuitTheme.peach.opacity(0.72))
                    .clipShape(Circle())
            }
            .accessibilityLabel(step == 0 ? "Skip onboarding" : "Back")

            Spacer()

            Button("Skip for now") {
                store.dismissOnboardingForNow()
            }
            .font(.rounded(.caption, weight: .bold))
            .foregroundColor(QuitTheme.muted)
        }
        .padding(.horizontal, 24)
        .padding(.top, 14)
    }

    private var progress: some View {
        HStack(spacing: 7) {
            ForEach(0...finalStep, id: \.self) { index in
                Capsule()
                    .fill(index <= step ? QuitTheme.cocoa : QuitTheme.line)
                    .frame(height: 5)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 14)
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case 0:
            profileStep
        case 1:
            intentStep
        case 2:
            backgroundStep
        case 3:
            triggerStep
        case 4:
            strategyStep
        case 5:
            savingsStep
        default:
            reviewStep
        }
    }

    private var profileStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            AnimatedMascotView(size: 168)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)

            OnboardingHeader(
                eyebrow: "Profile",
                title: "What should TeoPateo call you?"
            )

            VStack(alignment: .leading, spacing: 14) {
                TextField("Name or nickname", text: $nickname)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("onboarding-nickname-field")

                Stepper("Age \(age)", value: $age, in: 13...100)
                    .font(.rounded(.headline, weight: .bold))

                Text("Your profile stays focused on your quit plan.")
                    .font(.rounded(.caption))
                    .foregroundColor(QuitTheme.muted)
            }
            .quietCard()
        }
    }

    private var intentStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            OnboardingHeader(
                eyebrow: "Quit intent",
                title: "Where are you in the quit journey?"
            )

            LazyVGrid(columns: choiceColumns, alignment: .leading, spacing: 8) {
                ForEach(QuitStatus.allCases) { status in
                    choiceButton(title: status.title, isSelected: quitStatus == status) {
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

            VStack(alignment: .leading, spacing: 14) {
                TextField("Main reason for quitting", text: $primaryReason)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("onboarding-reason-field")

                slider("Confidence", value: $confidence)
            }
            .quietCard()
        }
    }

    private var backgroundStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            OnboardingHeader(
                eyebrow: "Smoking background",
                title: "Set the baseline your plan should respect."
            )

            VStack(alignment: .leading, spacing: 14) {
                Picker("Smoking start", selection: $smokingStartMode) {
                    Text("Age started").tag(SmokingStartMode.ageStarted)
                    Text("Years smoking").tag(SmokingStartMode.yearsSmoking)
                }
                .pickerStyle(.segmented)

                if smokingStartMode == .ageStarted {
                    Stepper("Started around age \(ageStartedSmoking)", value: $ageStartedSmoking, in: 5...100)
                } else {
                    Stepper("\(yearsSmoking) years smoking", value: $yearsSmoking, in: 0...80)
                }

                Stepper(
                    "\(Int(cigarettesPerDay)) cigarettes per day",
                    value: $cigarettesPerDay,
                    in: 0...80,
                    step: 1
                )
            }
            .font(.rounded(.headline, weight: .bold))
            .quietCard()

            optionSection(title: "First cigarette", options: FirstCigaretteTiming.allCases.map(\.title), selected: firstCigaretteTiming.title) { title in
                firstCigaretteTiming = FirstCigaretteTiming.allCases.first { $0.title == title } ?? firstCigaretteTiming
            }

            optionSection(title: "Previous quit attempts", options: PreviousQuitAttemptCount.allCases.map(\.title), selected: previousQuitAttemptCount.title) { title in
                previousQuitAttemptCount = PreviousQuitAttemptCount.allCases.first { $0.title == title } ?? previousQuitAttemptCount
            }

            optionSection(title: "Longest quit attempt", options: LongestQuitAttempt.allCases.map(\.title), selected: longestQuitAttempt.title) { title in
                longestQuitAttempt = LongestQuitAttempt.allCases.first { $0.title == title } ?? longestQuitAttempt
            }

            optionSection(title: "Main challenge", options: SmokingChallenge.allCases.map(\.title), selected: mainChallenge.title) { title in
                mainChallenge = SmokingChallenge.allCases.first { $0.title == title } ?? mainChallenge
            }
        }
    }

    private var triggerStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            OnboardingHeader(
                eyebrow: "Trigger map",
                title: "Pick the moments TeoPateo should protect first."
            )

            tagSection(
                title: "Common smoking times",
                items: QuitTriggerCatalog.commonSmokingTimes,
                selected: $selectedCommonSmokingTimes
            )

            tagSection(
                title: "Emotional triggers",
                items: QuitTriggerCatalog.emotionalTriggers,
                selected: $selectedEmotionalTriggers
            )

            tagSection(
                title: "Situational triggers",
                items: QuitTriggerCatalog.situationalTriggers,
                selected: $selectedSituationalTriggers
            )

            Text(triggerCountSummary)
                .font(.rounded(.caption, weight: .bold))
                .foregroundColor(selectedTriggerCount == 0 ? QuitTheme.cocoa : QuitTheme.muted)
        }
    }

    private var strategyStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            OnboardingHeader(
                eyebrow: "Quit strategy",
                title: "Turn intent into the first plan."
            )

            optionSection(title: "Quit date", options: QuitDatePreference.allCases.map(\.title), selected: quitDatePreference.title) { title in
                quitDatePreference = QuitDatePreference.allCases.first { $0.title == title } ?? quitDatePreference
                normalizeQuitDateForPreference()
            }

            if quitDatePreference != .helpMeChoose {
                VStack(alignment: .leading, spacing: 10) {
                    DatePicker(
                        quitDatePreference == .alreadyQuit ? "Quit date" : "Target date",
                        selection: $quitDate,
                        in: quitDateRange,
                        displayedComponents: .date
                    )
                    .font(.rounded(.headline, weight: .bold))
                    Text(quitDatePreference == .alreadyQuit
                        ? "TeoPateo will focus on relapse prevention and risky windows."
                        : "You can adjust this later from the plan screen.")
                    .font(.rounded(.caption))
                    .foregroundColor(QuitTheme.muted)
                }
                .quietCard()
            } else {
                Text("Suggested date: \(suggestedQuitDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.rounded(.headline, weight: .bold))
                    .foregroundColor(QuitTheme.ink)
                    .quietCard()
            }

            optionSection(title: "Approach", options: QuitApproachPreference.allCases.map(\.title), selected: approachPreference.title) { title in
                approachPreference = QuitApproachPreference.allCases.first { $0.title == title } ?? approachPreference
            }

            tagSection(
                title: "Replacement actions",
                items: replacementActions,
                selected: $selectedReplacementActions
            )

            Text(strategyPreview)
                .font(.rounded(.caption, weight: .bold))
                .foregroundColor(QuitTheme.muted)
        }
    }

    private var savingsStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            OnboardingHeader(
                eyebrow: "Cost savings",
                title: "Make progress accurate and concrete."
            )

            VStack(alignment: .leading, spacing: 14) {
                Stepper(
                    "\(currency(costPerPack)) per pack",
                    value: $costPerPack,
                    in: 0...100,
                    step: 0.5
                )

                Stepper(
                    "\(cigarettesPerPack) cigarettes per pack",
                    value: $cigarettesPerPack,
                    in: 1...50
                )

                Text("This drives money saved and cigarettes avoided on the dashboard.")
                    .font(.rounded(.caption))
                    .foregroundColor(QuitTheme.muted)
            }
            .font(.rounded(.headline, weight: .bold))
            .quietCard()

            optionSection(title: "Savings goal", options: savingsGoalOptions, selected: savingsGoalTitle) { title in
                savingsGoalTitle = title
            }

            if savingsGoalTitle == "Custom" {
                TextField("Savings goal", text: $customSavingsGoal)
                    .textFieldStyle(.roundedBorder)
                    .quietCard()
                    .accessibilityIdentifier("onboarding-custom-savings-field")
            }
        }
    }

    private var reviewStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            OnboardingHeader(
                eyebrow: "First plan",
                title: "TeoPateo will start with this rescue setup."
            )

            VStack(alignment: .leading, spacing: 12) {
                Text(generatedPlanPreview.planSummary.summary)
                    .font(.rounded(.subheadline))
                    .foregroundColor(QuitTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                OnboardingReviewRow(label: "First-week goal", value: generatedPlanPreview.firstWeekGoal)
                OnboardingReviewRow(label: "Next best action", value: generatedPlanPreview.nextBestAction)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .quietCard()

            VStack(alignment: .leading, spacing: 14) {
                OnboardingReviewRow(label: "Profile", value: "\(nickname.trimmingCharacters(in: .whitespacesAndNewlines)), age \(age)")
                OnboardingReviewRow(label: "Status", value: quitStatus.title)
                OnboardingReviewRow(label: "Approach", value: resolvedApproachTitle)
                OnboardingReviewRow(label: "Quit date", value: resolvedQuitDate.formatted(date: .abbreviated, time: .omitted))
                OnboardingReviewRow(label: "Baseline", value: "\(Int(cigarettesPerDay)) cigarettes/day")
                OnboardingReviewRow(label: "Top triggers", value: selectedTriggerList.prefix(4).joined(separator: ", "))
                OnboardingReviewRow(label: "Daily focus", value: generatedDailyFocusPreview)
                OnboardingReviewRow(label: "Reason", value: primaryReason.trimmingCharacters(in: .whitespacesAndNewlines))
                if let savingsSummary {
                    OnboardingReviewRow(label: "Savings", value: savingsSummary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .quietCard()

            Text("Craving mode will use these answers to order activities and trigger rules before the first logged craving.")
                .font(.rounded(.caption))
                .foregroundColor(QuitTheme.muted)
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 10) {
            Button {
                advance()
            } label: {
                HStack {
                    Text(step == finalStep ? "Create my plan" : "Continue")
                    Image(systemName: step == finalStep ? "checkmark" : "arrow.right")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(FilledButtonStyle())
            .disabled(!canAdvance)
            .opacity(canAdvance ? 1 : 0.45)
            .accessibilityIdentifier("onboarding-next-button")
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 20)
        .background(QuitTheme.background)
    }

    private func tagSection(
        title: String,
        items: [String],
        selected: Binding<Set<String>>
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.rounded(.headline, weight: .bold))
            FlexibleTags(items: items, selected: selected)
        }
        .quietCard()
    }

    private func optionSection(
        title: String,
        options: [String],
        selected: String,
        select: @escaping (String) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.rounded(.headline, weight: .bold))
            LazyVGrid(columns: choiceColumns, alignment: .leading, spacing: 8) {
                ForEach(options, id: \.self) { option in
                    choiceButton(title: option, isSelected: selected == option) {
                        select(option)
                    }
                }
            }
        }
        .quietCard()
    }

    private func choiceButton(
        title: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.rounded(.caption, weight: .bold))
                .foregroundColor(isSelected ? .white : QuitTheme.cocoa)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
                .frame(maxWidth: .infinity, minHeight: 44)
                .padding(.horizontal, 10)
                .background(isSelected ? QuitTheme.cocoa : QuitTheme.peach.opacity(0.62))
                .cornerRadius(14)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityIdentifier("onboarding-choice-\(title)")
    }

    private func slider(_ title: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.rounded(.subheadline, weight: .bold))
                Spacer()
                Text("\(Int(value.wrappedValue))")
                    .font(.rounded(.subheadline, weight: .bold))
                    .foregroundColor(QuitTheme.cocoa)
            }
            Slider(value: value, in: 1...10, step: 1)
                .accentColor(QuitTheme.cocoa)
        }
    }

    private var canAdvance: Bool {
        switch step {
        case 0:
            return !nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case 1:
            return !primaryReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case 2:
            return cigarettesPerDay > 0
        case 3:
            return selectedTriggerCount > 0
        case 4:
            return !selectedReplacementActions.isEmpty
        case 5:
            return costPerPack > 0 &&
                cigarettesPerPack > 0 &&
                (savingsGoalTitle != "Custom" || !customSavingsGoal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        default:
            return !primaryReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                selectedTriggerCount > 0
        }
    }

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

    private var triggerCountSummary: String {
        if selectedTriggerCount == 0 {
            return "Choose at least one trigger."
        }
        if selectedTriggerCount == 1 {
            return "1 trigger selected."
        }
        return "\(selectedTriggerCount) triggers selected."
    }

    private var strategyPreview: String {
        let mode = resolvedApproachTitle
        if mode == "Taper" {
            return "First target: \(Int(max(cigarettesPerDay - taperReductionStepPreview, 0))) cigarettes/day."
        }
        return quitStatus == .alreadyQuit
            ? "Craving mode will focus on relapse prevention."
            : "Craving mode will focus on substitutes before the quit date."
    }

    private var taperReductionStepPreview: Double {
        confidence <= 4 || firstCigaretteTiming == .withinFiveMinutes ? 1 : min(max((cigarettesPerDay * 0.2).rounded(), 1), 3)
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

    private func advance() {
        guard canAdvance else { return }

        if step == finalStep {
            store.completeOnboarding(currentPlanInput)
            return
        }

        withAnimation(.easeInOut) {
            step += 1
        }
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

private enum SmokingStartMode {
    case ageStarted
    case yearsSmoking
}

private struct OnboardingHeader: View {
    let eyebrow: String
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(eyebrow)
                .font(.rounded(.caption, weight: .bold))
                .foregroundColor(QuitTheme.muted)
            Text(title)
                .font(.system(size: 31, weight: .heavy, design: .rounded))
                .foregroundColor(QuitTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct OnboardingReviewRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.rounded(.caption, weight: .bold))
                .foregroundColor(QuitTheme.muted)
            Text(value.isEmpty ? "Not set" : value)
                .font(.rounded(.subheadline, weight: .bold))
                .foregroundColor(QuitTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
