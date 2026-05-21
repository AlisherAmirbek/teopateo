import SwiftUI

struct CravingModeView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: TeoPateoStore
    @State private var secondsRemaining = 600
    @State private var isRunning = false
    @State private var timer: Timer?
    @State private var startedAt = Date()

    private let triggers = ["Coffee", "Work stress", "After meal", "Boredom", "Alcohol", "Social"]

    var body: some View {
        ZStack {
            QuitTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    timerPanel
                    reasonPanel
                    activityPanel
                    triggerPanel
                    survivedButton
                }
                .padding(24)
            }
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
                Text("Ride out the next 10 minutes.")
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundColor(QuitTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Button {
                dismiss()
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

                Button("Reset") {
                    resetTimer()
                }
                .buttonStyle(QuietButtonStyle())
            }
        }
        .quietCard()
    }

    private var reasonPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your reason")
                .font(.rounded(.headline, weight: .bold))
            Text("I want mornings without chest tightness, and I want to keep promises I made when I was calm.")
                .font(.rounded(.subheadline))
                .foregroundColor(QuitTheme.muted)
        }
        .quietCard()
    }

    private var activityPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Do one instead")
                .font(.rounded(.headline, weight: .bold))

            replacementRow("Drink cold water", "Finish one full glass before deciding anything.")
            replacementRow("Walk outside", "Move until the timer drops below 6:00.")
            replacementRow("Text Maya", "Send the preset craving alert.")
        }
        .quietCard()
    }

    private var triggerPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Log the trigger")
                .font(.rounded(.headline, weight: .bold))

            FlexibleTags(items: triggers, selected: $store.selectedTriggers)
        }
        .quietCard()
    }

    private var survivedButton: some View {
        Button("I got through it") {
            store.completeCraving(
                startedAt: startedAt,
                durationSeconds: max(0, 600 - secondsRemaining),
                completedWithoutSmoking: true
            )
            resetTimer()
            dismiss()
        }
        .buttonStyle(FilledButtonStyle())
    }

    private func replacementRow(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.rounded(.subheadline, weight: .bold))
                .foregroundColor(QuitTheme.ink)
            Text(subtitle)
                .font(.rounded(.caption))
                .foregroundColor(QuitTheme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
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
    }
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
