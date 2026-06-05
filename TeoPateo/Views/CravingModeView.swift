import SwiftUI

struct CravingModeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var store: TeoPateoStore
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

    var body: some View {
        ZStack {
            QuitTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    StatusBanner(status: store.lastSaveStatus, persistenceError: store.persistenceError)

                    switch step {
                    case .rescue:
                        rescueContent
                    case .recovered:
                        recoveredContent
                    case .slipped:
                        slippedContent
                    }
                }
                .padding(24)
                .padding(.bottom, step == .rescue ? 126 : 24)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if step == .rescue {
                rescueOutcomeBar
            }
        }
        .onAppear {
            resetTimerState()
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

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 7) {
                Text("Craving mode")
                    .font(.rounded(.caption, weight: .bold))
                    .foregroundColor(QuitTheme.muted)
                Text(headerTitle)
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundColor(QuitTheme.ink)
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

    private var rescueContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            timerPanel
            rescueScriptPanel
            motivationPanel
            intensityNowPanel
            activityPanel(title: "Pick one action now", subtitle: "Do one small replacement while the timer runs.")
            triggerPanel(title: "Optional trigger")
        }
    }

    private var recoveredContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            outcomeIntro(
                title: "Craving handled",
                message: "Save the parts that made this easier so the next rescue can be sharper."
            )
            sliderPanel(title: "Craving after rescue", value: $finalIntensity)
            activityPanel(title: "What helped?", subtitle: "Pick the action that worked best, if any.")
            triggerPanel(title: "What set it off?")
            notePanel(title: "Short note", placeholder: "What helped this pass?", text: $reflectionNote)
            outcomeSaveButtons(
                primaryTitle: "Save rescue",
                primaryAction: saveRecoveredCraving
            )
        }
    }

    private var slippedContent: some View {
        VStack(alignment: .leading, spacing: 18) {
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

    private var timerPanel: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .stroke(QuitTheme.peach, lineWidth: 18)
                Circle()
                    .trim(from: 0, to: timerProgress)
                    .stroke(QuitTheme.cocoa, style: StrokeStyle(lineWidth: 18, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 4) {
                    Text(formattedTime)
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .foregroundColor(QuitTheme.ink)
                        .accessibilityIdentifier("craving-timer-label")
                    Text(timerStatusText)
                        .font(.rounded(.caption, weight: .bold))
                        .foregroundColor(QuitTheme.muted)
                }
            }
            .frame(width: 168, height: 168)

            HStack(spacing: 10) {
                Button(timerActionTitle) {
                    toggleTimer()
                }
                .buttonStyle(FilledButtonStyle())
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
        return VStack(alignment: .leading, spacing: 10) {
            Text("Rescue script")
                .font(.rounded(.headline, weight: .bold))
            Text(rescue.primaryScript)
                .font(.rounded(.subheadline))
                .foregroundColor(QuitTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
            Text(rescue.backupAction)
                .font(.rounded(.caption, weight: .bold))
                .foregroundColor(QuitTheme.cocoa)
                .fixedSize(horizontal: false, vertical: true)
        }
        .quietCard()
    }

    private var intensityNowPanel: some View {
        sliderPanel(title: "Craving now", value: $initialIntensity)
    }

    private var motivationPanel: some View {
        let reasons = store.reasonsForCravingMode()
        let text = reasons.isEmpty
            ? store.reasonForCravingMode()
            : reasons[safeReasonIndex(count: reasons.count)].text

        return VStack(alignment: .leading, spacing: 10) {
            Text("Reason to wait")
                .font(.rounded(.headline, weight: .bold))
            Text(text)
                .font(.rounded(.subheadline))
                .foregroundColor(QuitTheme.ink)
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
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.rounded(.headline, weight: .bold))
            Text(message)
                .font(.rounded(.subheadline))
                .foregroundColor(QuitTheme.muted)
        }
        .quietCard()
    }

    private func activityPanel(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.rounded(.headline, weight: .bold))
                Text(subtitle)
                    .font(.rounded(.caption))
                    .foregroundColor(QuitTheme.muted)
            }

            ForEach(store.activitiesForCurrentCraving(triggers: store.selectedTriggers)) { activity in
                Button {
                    selectedActivityID = activity.id
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: selectedActivityID == activity.id ? "checkmark.circle.fill" : "circle")
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
            }
        }
        .quietCard()
    }

    private func triggerPanel(title: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.rounded(.headline, weight: .bold))

            FlexibleTags(items: store.cravingTriggerOptions, selected: $store.selectedTriggers)
        }
        .quietCard()
    }

    private func notePanel(title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.rounded(.headline, weight: .bold))
            TextField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("craving-note-field")
        }
        .quietCard()
    }

    private var rescueOutcomeBar: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Button("I got through it") {
                    moveToRecovered()
                }
                .buttonStyle(FilledButtonStyle())
                .accessibilityIdentifier("craving-recovered-button")

                Button("I smoked") {
                    moveToSlipped()
                }
                .buttonStyle(QuietButtonStyle())
                .accessibilityIdentifier("craving-smoked-button")
            }

            Button("Save for later") {
                saveForLaterAndDismiss()
            }
            .font(.rounded(.caption, weight: .bold))
            .foregroundColor(QuitTheme.muted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .accessibilityIdentifier("craving-save-later-button")
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .background(QuitTheme.background)
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
        stopTimerForOutcome()
        finalIntensity = min(initialIntensity, max(1.0, initialIntensity - 3.0))
        step = .recovered
    }

    private func moveToSlipped() {
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
            reflectionNote: reflectionNote
        )
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
            recoveryAction: store.currentQuitPlan.slipRecoveryPlan.defaultRecoveryAction
        )
        resetTimer()
        dismiss()
    }

    private func saveForLaterAndDismiss() {
        let dismissedAt = Date()
        store.dismissCravingSession(
            startedAt: startedAt,
            dismissedAt: dismissedAt,
            durationSeconds: elapsedDurationSeconds(at: dismissedAt),
            initialIntensity: initialIntensity
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
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(QuitTheme.cocoa.opacity(configuration.isPressed ? 0.82 : 1))
            .cornerRadius(12)
    }
}

struct QuietButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.rounded(.headline, weight: .bold))
            .foregroundColor(QuitTheme.cocoa)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(QuitTheme.peach.opacity(configuration.isPressed ? 0.55 : 0.85))
            .cornerRadius(12)
    }
}
