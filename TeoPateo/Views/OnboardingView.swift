import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var store: TeoPateoStore
    @State private var step = 0
    @State private var cigarettesPerDay = 10.0
    @State private var costPerPack = 10.0
    @State private var quitDate = Calendar.current.date(byAdding: .day, value: 11, to: Date()) ?? Date()
    @State private var quitMode = "Taper"
    @State private var selectedTriggers: Set<String> = ["Coffee", "After meals", "Work stress"]
    @State private var primaryReason = ""
    @State private var isInterestedInMedicationSupport = false

    private let finalStep = 5

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
            welcomeStep
        case 1:
            baselineStep
        case 2:
            quitDateStep
        case 3:
            triggerStep
        case 4:
            reasonStep
        default:
            reviewStep
        }
    }

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            Image("Mascot")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .frame(height: 190)
                .padding(.vertical, 8)

            VStack(alignment: .leading, spacing: 10) {
                Text("Build the plan for your hardest 10 minutes.")
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundColor(QuitTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Text("TeoPateo will turn your smoking patterns into a first rescue plan before the next craving hits.")
                    .font(.rounded(.subheadline))
                    .foregroundColor(QuitTheme.muted)
                    .lineSpacing(2)
            }

            VStack(spacing: 10) {
                OnboardingSignalRow(icon: "target", title: "Name the risky moments")
                OnboardingSignalRow(icon: "figure.walk", title: "Choose what you will do instead")
                OnboardingSignalRow(icon: "heart.text.square", title: "Keep your reason close")
            }
        }
    }

    private var baselineStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            OnboardingHeader(
                eyebrow: "Baseline",
                title: "Start with the numbers your progress depends on."
            )

            VStack(alignment: .leading, spacing: 18) {
                Stepper(
                    "\(Int(cigarettesPerDay)) cigarettes per day",
                    value: $cigarettesPerDay,
                    in: 0...80,
                    step: 1
                )

                Stepper(
                    "\(currency(costPerPack)) per pack",
                    value: $costPerPack,
                    in: 0...50,
                    step: 0.5
                )
            }
            .font(.rounded(.headline, weight: .bold))
            .quietCard()

            Text("These drive cigarettes avoided and money saved. You can adjust them later.")
                .font(.rounded(.caption))
                .foregroundColor(QuitTheme.muted)
        }
    }

    private var quitDateStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            OnboardingHeader(
                eyebrow: "Quit plan",
                title: "Choose the date and approach."
            )

            VStack(alignment: .leading, spacing: 16) {
                DatePicker(
                    "Quit date",
                    selection: $quitDate,
                    in: Date()...,
                    displayedComponents: .date
                )
                .font(.rounded(.headline, weight: .bold))

                Picker("Approach", selection: $quitMode) {
                    Text("Taper").tag("Taper")
                    Text("Cold turkey").tag("Cold turkey")
                }
                .pickerStyle(.segmented)

                Text(quitMode == "Taper"
                    ? "Taper means gradually reducing cigarettes before fully quitting."
                    : "Cold turkey means stopping completely on your quit date.")
                    .font(.rounded(.caption))
                    .foregroundColor(QuitTheme.muted)

                Text(quitMode == "Taper"
                    ? "Your first taper target will be \(Int(max(cigarettesPerDay - 2, 0))) cigarettes per day."
                    : "Craving mode will focus on substitutes and support before the quit date.")
                    .font(.rounded(.subheadline))
                    .foregroundColor(QuitTheme.muted)
            }
            .quietCard()
        }
    }

    private var triggerStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            OnboardingHeader(
                eyebrow: "Trigger map",
                title: "Pick the moments most likely to pull you toward smoking."
            )

            FlexibleTags(
                items: QuitTriggerCatalog.onboardingTriggers,
                selected: $selectedTriggers
            )

            Text(triggerCountSummary)
                .font(.rounded(.caption, weight: .bold))
                .foregroundColor(selectedTriggers.isEmpty ? QuitTheme.cocoa : QuitTheme.muted)
        }
    }

    private var reasonStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            OnboardingHeader(
                eyebrow: "Rescue anchor",
                title: "Add the reason that should interrupt a craving."
            )

            VStack(alignment: .leading, spacing: 14) {
                TextField("Reason for quitting", text: $primaryReason)
                    .textFieldStyle(.roundedBorder)

                Divider()

                Toggle("I want to discuss quit medicines or nicotine replacement", isOn: $isInterestedInMedicationSupport)
                    .font(.rounded(.subheadline))
                    .toggleStyle(SwitchToggleStyle(tint: QuitTheme.cocoa))
            }
            .quietCard()

            Text(reasonSummary)
                .font(.rounded(.caption, weight: .bold))
                .foregroundColor(primaryReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? QuitTheme.cocoa : QuitTheme.muted)
        }
    }

    private var reviewStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            OnboardingHeader(
                eyebrow: "First plan",
                title: "TeoPateo will start with this rescue setup."
            )

            VStack(alignment: .leading, spacing: 14) {
                OnboardingReviewRow(label: "Quit date", value: quitDate.formatted(date: .abbreviated, time: .omitted))
                OnboardingReviewRow(label: "Approach", value: quitMode)
                OnboardingReviewRow(label: "Baseline", value: "\(Int(cigarettesPerDay)) cigarettes/day")
                OnboardingReviewRow(label: "Top triggers", value: selectedTriggerList.joined(separator: ", "))
                OnboardingReviewRow(label: "Reason", value: primaryReason.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .quietCard()

            Text("Craving mode will use these triggers to suggest the first 10-minute substitute.")
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
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 20)
        .background(QuitTheme.background)
    }

    private var selectedTriggerList: [String] {
        QuitTriggerCatalog.onboardingTriggers.filter { selectedTriggers.contains($0) }
    }

    private var canAdvance: Bool {
        switch step {
        case 3:
            return !selectedTriggers.isEmpty
        case 4, 5:
            return !primaryReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !selectedTriggers.isEmpty
        default:
            return true
        }
    }

    private var triggerCountSummary: String {
        if selectedTriggers.isEmpty {
            return "Choose at least one trigger."
        }
        if selectedTriggers.count == 1 {
            return "1 trigger selected."
        }
        return "\(selectedTriggers.count) triggers selected."
    }

    private var reasonSummary: String {
        primaryReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Add one reason before creating the plan."
            : "This will appear inside craving mode."
    }

    private func advance() {
        guard canAdvance else { return }

        if step == finalStep {
            store.completeOnboarding(
                OnboardingPlanInput(
                    cigarettesPerDay: cigarettesPerDay,
                    costPerPack: costPerPack,
                    quitDate: quitDate,
                    quitMode: quitMode,
                    selectedTriggers: selectedTriggerList,
                    primaryReason: primaryReason,
                    isInterestedInMedicationSupport: isInterestedInMedicationSupport
                )
            )
            return
        }

        withAnimation(.easeInOut) {
            step += 1
        }
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

private struct OnboardingSignalRow: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(QuitTheme.cocoa)
                .frame(width: 34, height: 34)
                .background(QuitTheme.peach.opacity(0.74))
                .clipShape(Circle())

            Text(title)
                .font(.rounded(.subheadline, weight: .bold))
                .foregroundColor(QuitTheme.ink)

            Spacer()
        }
        .padding(14)
        .background(QuitTheme.paper)
        .cornerRadius(18)
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
            Text(value)
                .font(.rounded(.subheadline, weight: .bold))
                .foregroundColor(QuitTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
