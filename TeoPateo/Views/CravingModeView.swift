import SwiftUI

struct CravingModeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject private var store: TeoPateoStore
    @ScaledMetric(relativeTo: .largeTitle) private var timerDiameter: CGFloat = 168
    @ScaledMetric(relativeTo: .largeTitle) private var timerStroke: CGFloat = 18
    @State private var secondsRemaining = CravingCountdownClock.totalSeconds
    @State private var isRunning = false
    @State private var timer: Timer?
    @State private var startedAt = Date()
    @State private var hasTimerStarted = false
    @State private var accumulatedPausedSeconds = 0
    @State private var pausedAt: Date?
    @State private var initialIntensity = 7.0
    @State private var finalIntensity = 3.0
    @State private var selectedActivityID: UUID?
    @State private var reflectionNote = ""
    @State private var slipNote = ""
    @State private var step: CravingStep = .rescue
    @State private var reasonIndex = 0
    @State private var selectedTriggers: Set<String> = []

    var body: some View {
        GeometryReader { proxy in
            let metrics = AdaptiveScreenMetrics(
                width: proxy.size.width,
                horizontalSizeClass: horizontalSizeClass,
                dynamicTypeSize: dynamicTypeSize
            )

            ZStack {
                QuitTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: metrics.cardSpacing) {
                        header
                        StatusBanner(status: store.lastSaveStatus, persistenceError: store.persistenceError)
                        stepContent(metrics: metrics)
                    }
                    .padding(.horizontal, metrics.horizontalPadding)
                    .padding(.top, metrics.verticalPadding)
                    .padding(.bottom, step == .rescue ? (metrics.usesWideLayout ? 104 : 126) : metrics.verticalPadding)
                    .frame(maxWidth: metrics.contentMaxWidth, alignment: .leading)
                    .frame(maxWidth: .infinity)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if step == .rescue {
                    rescueOutcomeBar(isWide: metrics.usesWideLayout)
                }
            }
        }
        .onAppear {
            resetTimerState()
            selectedTriggers = []
            store.startCravingSession()
            reasonIndex = 0
        }
        .onChange(of: scenePhase) { newPhase in
            handleScenePhaseChange(newPhase)
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }

    @ViewBuilder
    private func stepContent(metrics: AdaptiveScreenMetrics) -> some View {
        switch step {
        case .rescue:
            rescueContent(metrics: metrics)
        case .recovered:
            recoveredContent(metrics: metrics)
        case .slipped:
            slippedContent(metrics: metrics)
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 7) {
                Text("Craving mode")
                    .typeLabel()
                Text(L10n.key(headerTitle))
                    .typeDisplay()
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Button {
                saveForLaterAndDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(QuitTheme.ink)
                    .frame(width: 44, height: 44)
                    .background(QuitTheme.paper)
                    .clipShape(Circle())
            }
            .accessibilityLabel("Close craving mode")
        }
    }

    private var headerTitle: String {
        switch step {
        case .rescue:
            return "Ride out the next 10 minutes."
        case .recovered:
            return "Log what helped."
        case .slipped:
            return "Log it and reset."
        }
    }

    // In-the-moment view: only the timer, one action, and one reason. Intensity,
    // triggers, and notes move to the after-the-fact log step.
    @ViewBuilder
    private func rescueContent(metrics: AdaptiveScreenMetrics) -> some View {
        if metrics.usesWideLayout {
            HStack(alignment: .top, spacing: metrics.columnSpacing) {
                timerPanel(metrics: metrics)
                    .frame(maxWidth: 420, alignment: .top)

                VStack(alignment: .leading, spacing: metrics.cardSpacing) {
                    rescueScriptPanel
                    motivationPanel
                }
                .frame(maxWidth: .infinity, alignment: .top)
            }
        } else {
            VStack(alignment: .leading, spacing: metrics.cardSpacing) {
                timerPanel(metrics: metrics)
                rescueScriptPanel
                motivationPanel
            }
        }
    }

    // Log step: the quiet win acknowledgement first, then the logging that used
    // to crowd the in-the-moment screen.
    @ViewBuilder
    private func recoveredContent(metrics: AdaptiveScreenMetrics) -> some View {
        if metrics.usesWideLayout {
            HStack(alignment: .top, spacing: metrics.columnSpacing) {
                VStack(alignment: .leading, spacing: metrics.cardSpacing) {
                    winAcknowledgement
                    sliderPanel(title: "Craving now", value: $finalIntensity)
                    notePanel(title: "Short note", placeholder: "What helped this pass?", text: $reflectionNote)
                    outcomeSaveButtons(
                        primaryTitle: "Save rescue",
                        primaryAction: saveRecoveredCraving
                    )
                }
                .frame(maxWidth: 420, alignment: .top)

                VStack(alignment: .leading, spacing: metrics.cardSpacing) {
                    sliderPanel(title: "How strong did it get?", value: $initialIntensity)
                    activityPanel(title: "What helped?", subtitle: "Pick the action that worked best, if any.")
                    triggerPanel(title: "What set it off?")
                }
                .frame(maxWidth: .infinity, alignment: .top)
            }
        } else {
            VStack(alignment: .leading, spacing: metrics.cardSpacing) {
                winAcknowledgement
                sliderPanel(title: "Craving now", value: $finalIntensity)
                notePanel(title: "Short note", placeholder: "What helped this pass?", text: $reflectionNote)
                sliderPanel(title: "How strong did it get?", value: $initialIntensity)
                activityPanel(title: "What helped?", subtitle: "Pick the action that worked best, if any.")
                triggerPanel(title: "What set it off?")
                outcomeSaveButtons(
                    primaryTitle: "Save rescue",
                    primaryAction: saveRecoveredCraving
                )
            }
        }
    }

    // A calm, earned acknowledgement when a craving is beaten — a mascot pose and
    // a soft entrance, not confetti. The success haptic fires in `moveToRecovered`.
    private var winAcknowledgement: some View {
        VStack(spacing: Spacing.smd) {
            TeoMascotView(pose: .playful, breathing: true, entrance: true)
                .frame(height: 140)
                .accessibilityHidden(true)
            Text("You made it through")
                .typeSection()
                .multilineTextAlignment(.center)
            Text("That urge passed without a cigarette. Teo is proud of you.")
                .typeBodySecondary()
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Spacing.sm)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("You made it through. That urge passed without a cigarette.")
    }

    @ViewBuilder
    private func slippedContent(metrics: AdaptiveScreenMetrics) -> some View {
        if metrics.usesWideLayout {
            HStack(alignment: .top, spacing: metrics.columnSpacing) {
                VStack(alignment: .leading, spacing: metrics.cardSpacing) {
                    outcomeIntro(
                        title: "No reset needed",
                        message: store.currentQuitPlan.slipRecoveryPlan.message
                    )
                    sliderPanel(title: "Craving after smoking", value: $finalIntensity)
                    notePanel(title: "What happened?", placeholder: "A quick note for tomorrow's pattern", text: $slipNote)
                    outcomeSaveButtons(
                        primaryTitle: "Save slip",
                        primaryAction: saveSlippedCraving
                    )
                }
                .frame(maxWidth: 420, alignment: .top)

                triggerPanel(title: "What set it off?")
                    .frame(maxWidth: .infinity, alignment: .top)
            }
        } else {
            VStack(alignment: .leading, spacing: metrics.cardSpacing) {
                outcomeIntro(
                    title: "No reset needed",
                    message: store.currentQuitPlan.slipRecoveryPlan.message
                )
                sliderPanel(title: "Craving after smoking", value: $finalIntensity)
                triggerPanel(title: "What set it off?")
                notePanel(title: "What happened?", placeholder: "A quick note for tomorrow's pattern", text: $slipNote)
                outcomeSaveButtons(
                    primaryTitle: "Save slip",
                    primaryAction: saveSlippedCraving
                )
            }
        }
    }

    private func timerPanel(metrics: AdaptiveScreenMetrics) -> some View {
        let diameter = metrics.usesWideLayout ? max(timerDiameter, 220) : timerDiameter
        let stroke = metrics.usesWideLayout ? max(timerStroke, 20) : timerStroke

        return VStack(spacing: 18) {
            ZStack {
                Circle()
                    .stroke(QuitTheme.peach, lineWidth: stroke)
                Circle()
                    .trim(from: 0, to: timerProgress)
                    .stroke(QuitTheme.cocoa, style: StrokeStyle(lineWidth: stroke, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 4) {
                    Text(formattedTime)
                        .font(.rounded(.largeTitle, weight: .heavy))
                        .monospacedDigit()
                        .foregroundColor(QuitTheme.ink)
                        .accessibilityIdentifier("craving-timer-label")
                    Text(L10n.key(timerStatusText))
                        .font(.rounded(.caption, weight: .bold))
                        .foregroundColor(QuitTheme.muted)
                }
            }
            .frame(width: diameter, height: diameter)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(L10n.string("Craving timer"))
            .accessibilityValue(timerAccessibilityValue)
            .accessibilityAddTraits(.updatesFrequently)

            HStack(spacing: 10) {
                Button {
                    toggleTimer()
                } label: {
                    Text(L10n.key(timerActionTitle))
                }
                .buttonStyle(FilledButtonStyle())
                .accessibilityLabel(L10n.string(timerActionTitle))
                .accessibilityIdentifier("craving-start-pause-button")

                Button("Reset") {
                    resetTimer()
                }
                .buttonStyle(QuietButtonStyle())
                .accessibilityIdentifier("craving-reset-button")
            }
        }
        .quietCard()
    }

    private var rescueScriptPanel: some View {
        let rescue = store.currentQuitPlan.cravingRescuePlan
        return VStack(alignment: .leading, spacing: Spacing.smd) {
            Text("Rescue script")
                .typeSection()
            Text(rescue.primaryScript)
                .typeBody()
                .fixedSize(horizontal: false, vertical: true)
            Text(rescue.backupAction)
                .font(.rounded(.footnote, weight: .bold))
                .foregroundColor(QuitTheme.cocoa)
                .fixedSize(horizontal: false, vertical: true)
        }
        .quietCard()
    }

    private var motivationPanel: some View {
        let reasons = store.reasonsForCravingMode()
        let text = reasons.isEmpty
            ? store.reasonForCravingMode()
            : reasons[safeReasonIndex(count: reasons.count)].text

        return VStack(alignment: .leading, spacing: Spacing.smd) {
            Text("Reason to wait")
                .typeSection()
            Text(text)
                .typeBody()
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                if reasons.count > 1 {
                    Button("Show another reason") {
                        reasonIndex = (safeReasonIndex(count: reasons.count) + 1) % reasons.count
                    }
                    .buttonStyle(QuietButtonStyle())
                }
            }
        }
        .quietCard()
    }

    private func sliderPanel(title: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            slider(title, value: value)
        }
        .quietCard()
    }

    private func outcomeIntro(title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(title)
                .typeSection()
            Text(message)
                .typeBodySecondary()
        }
        .quietCard()
    }

    private func activityPanel(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(title)
                    .typeSection()
                Text(subtitle)
                    .typeBodySecondary()
            }

            ForEach(store.activitiesForCurrentCraving(triggers: selectedTriggers)) { activity in
                let isSelected = selectedActivityID == activity.id
                Button {
                    selectedActivityID = activity.id
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(QuitTheme.cocoa)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(activity.title)
                                .font(.rounded(.subheadline, weight: .bold))
                                .foregroundColor(QuitTheme.ink)
                            Text(activity.instruction)
                                .font(.rounded(.caption))
                                .foregroundColor(QuitTheme.muted)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(activity.title). \(activity.instruction)")
                .accessibilityValue(L10n.selectedState(isSelected))
                .accessibilityHint(isSelected ? L10n.string("Selected replacement activity.") : L10n.string("Double-tap to choose this replacement activity."))
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .quietCard()
    }

    private func triggerPanel(title: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.smd) {
            Text(title)
                .typeSection()

            FlexibleTags(items: store.cravingTriggerOptions, selected: $selectedTriggers)
        }
        .quietCard()
    }

    private func notePanel(title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: Spacing.smd) {
            Text(title)
                .typeSection()
            TextField(placeholder, text: text)
                .textFieldStyle(QuietFieldStyle())
                .accessibilityIdentifier("craving-note-field")
        }
        .quietCard()
    }

    @ViewBuilder
    private func rescueOutcomeBar(isWide: Bool) -> some View {
        if isWide {
            HStack(spacing: 12) {
                recoveredButton
                smokedButton
                saveForLaterButton
            }
            .padding(.horizontal, 24)
            .padding(.top, 14)
            .padding(.bottom, 12)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
            .background(QuitTheme.background)
        } else {
            VStack(spacing: 10) {
                rescueOutcomeChoices
                saveForLaterButton
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 10)
            .background(QuitTheme.background)
        }
    }

    @ViewBuilder
    private var rescueOutcomeChoices: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: 10) {
                recoveredButton
                smokedButton
            }
        } else {
            HStack(spacing: 10) {
                recoveredButton
                smokedButton
            }
        }
    }

    private var recoveredButton: some View {
        Button("I got through it") {
            moveToRecovered()
        }
        .buttonStyle(FilledButtonStyle())
        .accessibilityIdentifier("craving-recovered-button")
    }

    private var smokedButton: some View {
        Button("I smoked") {
            moveToSlipped()
        }
        .buttonStyle(QuietButtonStyle())
        .accessibilityIdentifier("craving-smoked-button")
    }

    private var saveForLaterButton: some View {
        Button("Save for later") {
            saveForLaterAndDismiss()
        }
        .font(.rounded(.caption, weight: .bold))
        .foregroundColor(QuitTheme.muted)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .accessibilityIdentifier("craving-save-later-button")
    }

    private func outcomeSaveButtons(primaryTitle: String, primaryAction: @escaping () -> Void) -> some View {
        VStack(spacing: 10) {
            Button(primaryTitle) {
                primaryAction()
            }
            .buttonStyle(FilledButtonStyle())
            .accessibilityIdentifier("craving-outcome-save-button")

            Button("Back to rescue") {
                step = .rescue
            }
            .buttonStyle(QuietButtonStyle())
        }
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
                .accessibilityLabel(title)
                .accessibilityValue(L10n.scoreValue(Int(value.wrappedValue)))
        }
    }

    private var formattedTime: String {
        let secondsRemaining = max(secondsRemaining, 0)
        let minutes = secondsRemaining / 60
        let seconds = secondsRemaining % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private var timerProgress: CGFloat {
        CGFloat(CravingCountdownClock.totalSeconds - secondsRemaining) / CGFloat(CravingCountdownClock.totalSeconds)
    }

    private var timerStatusText: String {
        if isRunning {
            return "Running"
        }

        if secondsRemaining <= 0 {
            return "Complete"
        }

        return hasTimerStarted ? "Paused" : "Ready"
    }

    private var timerAccessibilityValue: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .spellOut
        formatter.zeroFormattingBehavior = [.dropLeading]

        let remaining = formatter.string(from: TimeInterval(max(secondsRemaining, 0))) ?? formattedTime
        return String(
            format: L10n.string("%@ remaining, %@"),
            remaining,
            L10n.string(timerStatusText)
        )
    }

    private var timerActionTitle: String {
        if isRunning {
            return "Pause"
        }

        if hasTimerStarted && secondsRemaining > 0 {
            return "Resume"
        }

        return "Start timer"
    }

    private func toggleTimer() {
        if isRunning {
            pauseTimer()
        } else {
            startTimer()
        }
    }

    private func resetTimer() {
        resetTimerState()
        step = .rescue
    }

    private func resetTimerState(at date: Date = Date()) {
        timer?.invalidate()
        timer = nil
        isRunning = false
        secondsRemaining = CravingCountdownClock.totalSeconds
        startedAt = date
        hasTimerStarted = false
        accumulatedPausedSeconds = 0
        pausedAt = nil
    }

    private func startTimer(at date: Date = Date()) {
        Haptics.impact(.medium)

        if secondsRemaining <= 0 {
            resetTimerState(at: date)
        }

        if !hasTimerStarted {
            startedAt = date
            accumulatedPausedSeconds = 0
            pausedAt = nil
            hasTimerStarted = true
        } else if let pausedAt {
            accumulatedPausedSeconds += max(0, Int(date.timeIntervalSince(pausedAt)))
            self.pausedAt = nil
        }

        isRunning = true
        reconcileTimer(at: date)
        scheduleTimer()
    }

    private func pauseTimer(at date: Date = Date()) {
        reconcileTimer(at: date)
        timer?.invalidate()
        timer = nil
        isRunning = false

        if hasTimerStarted {
            pausedAt = date
        }
    }

    private func stopTimerForOutcome(at date: Date = Date()) {
        reconcileTimer(at: date)
        timer?.invalidate()
        timer = nil
        isRunning = false

        if hasTimerStarted && pausedAt == nil {
            pausedAt = date
        }
    }

    private func scheduleTimer() {
        timer?.invalidate()

        guard isRunning else {
            timer = nil
            return
        }

        let scheduledTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            reconcileTimer()
        }
        scheduledTimer.tolerance = 0.1
        timer = scheduledTimer
    }

    private func reconcileTimer(at date: Date = Date()) {
        secondsRemaining = CravingCountdownClock.remainingSeconds(
            startedAt: startedAt,
            now: date,
            hasStarted: hasTimerStarted,
            accumulatedPausedSeconds: accumulatedPausedSeconds,
            pausedAt: pausedAt
        )

        if secondsRemaining <= 0 {
            timer?.invalidate()
            timer = nil
            isRunning = false
            if hasTimerStarted && pausedAt == nil {
                pausedAt = date
            }
        }
    }

    private func handleScenePhaseChange(_ newPhase: ScenePhase) {
        switch newPhase {
        case .active:
            reconcileTimer()
            if isRunning {
                scheduleTimer()
            }
        default:
            timer?.invalidate()
            timer = nil
        }
    }

    private func elapsedDurationSeconds(at date: Date = Date()) -> Int {
        CravingCountdownClock.elapsedSeconds(
            startedAt: startedAt,
            now: date,
            hasStarted: hasTimerStarted,
            accumulatedPausedSeconds: accumulatedPausedSeconds,
            pausedAt: pausedAt
        )
    }

    private func moveToRecovered() {
        Haptics.success()
        stopTimerForOutcome()
        finalIntensity = min(initialIntensity, max(1.0, initialIntensity - 3.0))
        step = .recovered
    }

    private func moveToSlipped() {
        Haptics.impact(.soft)
        stopTimerForOutcome()
        finalIntensity = initialIntensity
        step = .slipped
    }

    private func saveRecoveredCraving() {
        let completedAt = Date()
        store.completeCravingWithoutSmoking(
            startedAt: startedAt,
            completedAt: completedAt,
            durationSeconds: elapsedDurationSeconds(at: completedAt),
            initialIntensity: initialIntensity,
            finalIntensity: finalIntensity,
            helpedActivityID: selectedActivityID,
            supportContactID: nil,
            reflectionNote: reflectionNote,
            selectedTriggers: selectedTriggers
        )
        Haptics.success()
        resetTimer()
        dismiss()
    }

    private func saveSlippedCraving() {
        let completedAt = Date()
        store.completeCravingWithSlip(
            startedAt: startedAt,
            completedAt: completedAt,
            durationSeconds: elapsedDurationSeconds(at: completedAt),
            initialIntensity: initialIntensity,
            finalIntensity: finalIntensity,
            helpedActivityID: selectedActivityID,
            supportContactID: nil,
            cigarettesSmoked: 1,
            slipNote: slipNote.isEmpty ? "Smoked during a craving." : slipNote,
            recoveryAction: store.currentQuitPlan.slipRecoveryPlan.defaultRecoveryAction,
            selectedTriggers: selectedTriggers
        )
        Haptics.selection()
        resetTimer()
        dismiss()
    }

    private func saveForLaterAndDismiss() {
        let dismissedAt = Date()
        store.dismissCravingSession(
            startedAt: startedAt,
            dismissedAt: dismissedAt,
            durationSeconds: elapsedDurationSeconds(at: dismissedAt),
            initialIntensity: initialIntensity,
            selectedTriggers: selectedTriggers
        )
        resetTimer()
        dismiss()
    }

    private func safeReasonIndex(count: Int) -> Int {
        guard count > 0 else {
            return 0
        }
        return min(reasonIndex, count - 1)
    }
}

enum CravingCountdownClock {
    static let totalSeconds = 600

    static func elapsedSeconds(
        startedAt: Date,
        now: Date,
        hasStarted: Bool,
        accumulatedPausedSeconds: Int = 0,
        pausedAt: Date? = nil
    ) -> Int {
        guard hasStarted else {
            return 0
        }

        let rawElapsedSeconds = Int(now.timeIntervalSince(startedAt))
        let pausedSeconds = max(0, accumulatedPausedSeconds) + currentPauseSeconds(pausedAt: pausedAt, now: now)
        let activeElapsedSeconds = rawElapsedSeconds - pausedSeconds

        return min(totalSeconds, max(0, activeElapsedSeconds))
    }

    static func remainingSeconds(
        startedAt: Date,
        now: Date,
        hasStarted: Bool,
        accumulatedPausedSeconds: Int = 0,
        pausedAt: Date? = nil
    ) -> Int {
        totalSeconds - elapsedSeconds(
            startedAt: startedAt,
            now: now,
            hasStarted: hasStarted,
            accumulatedPausedSeconds: accumulatedPausedSeconds,
            pausedAt: pausedAt
        )
    }

    private static func currentPauseSeconds(pausedAt: Date?, now: Date) -> Int {
        guard let pausedAt else {
            return 0
        }

        return max(0, Int(now.timeIntervalSince(pausedAt)))
    }
}

private enum CravingStep: Equatable {
    case rescue
    case recovered
    case slipped
}

struct FilledButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.rounded(.headline, weight: .bold))
            .foregroundColor(QuitTheme.onCocoa)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 52)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 12)
            .padding(.vertical, 14)
            .background(QuitTheme.cocoa.opacity(configuration.isPressed ? 0.82 : 1))
            .cornerRadius(12)
    }
}

struct QuietButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.rounded(.headline, weight: .bold))
            .foregroundColor(QuitTheme.cocoa)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 52)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 12)
            .padding(.vertical, 14)
            .background(QuitTheme.peach.opacity(configuration.isPressed ? 0.55 : 0.85))
            .cornerRadius(12)
    }
}
