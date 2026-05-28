import SwiftUI

struct CravingModeView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: TeoPateoStore
    @State private var secondsRemaining = 600
    @State private var isRunning = false
    @State private var timer: Timer?
    @State private var startedAt = Date()
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
            startedAt = Date()
            store.startCravingSession()
            reasonIndex = 0
        }
        .onDisappear {
            timer?.invalidate()
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
                    .trim(from: 0, to: CGFloat(600 - secondsRemaining) / 600)
                    .stroke(QuitTheme.cocoa, style: StrokeStyle(lineWidth: 18, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 4) {
                    Text(formattedTime)
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .foregroundColor(QuitTheme.ink)
                        .accessibilityIdentifier("craving-timer-label")
                    Text(isRunning ? "Running" : "Ready")
                        .font(.rounded(.caption, weight: .bold))
                        .foregroundColor(QuitTheme.muted)
                }
            }
            .frame(width: 168, height: 168)

            HStack(spacing: 10) {
                Button(isRunning ? "Pause" : "Start timer") {
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
        let minutes = secondsRemaining / 60
        let seconds = secondsRemaining % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func toggleTimer() {
        isRunning.toggle()
        timer?.invalidate()

        guard isRunning else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if secondsRemaining > 0 {
                secondsRemaining -= 1
            } else {
                isRunning = false
                timer?.invalidate()
            }
        }
    }

    private func resetTimer() {
        timer?.invalidate()
        isRunning = false
        secondsRemaining = 600
        startedAt = Date()
        step = .rescue
    }

    private func stopTimerForOutcome() {
        timer?.invalidate()
        isRunning = false
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
        store.completeCravingWithoutSmoking(
            startedAt: startedAt,
            durationSeconds: max(0, 600 - secondsRemaining),
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
        store.completeCravingWithSlip(
            startedAt: startedAt,
            durationSeconds: max(0, 600 - secondsRemaining),
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
        store.dismissCravingSession(
            startedAt: startedAt,
            durationSeconds: max(0, 600 - secondsRemaining),
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
