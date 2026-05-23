import SwiftUI

struct PlanView: View {
    @EnvironmentObject private var store: TeoPateoStore
    @State private var newTrigger = ""
    @State private var newAction = ""
    @State private var newReason = ""
    @State private var newActivityTitle = ""
    @State private var newActivityInstruction = ""
    @State private var newActivityCategory: ReplacementActivityCategory = .distraction

    var body: some View {
        RootScreen {
            ScreenHeader(eyebrow: "Quit plan", title: "Your plan stays specific.")
            StatusBanner(status: store.lastSaveStatus, persistenceError: store.persistenceError)

            quitDate
            progressBaseline
            approach
            rules
            reasons
            replacementActivities
            medicationNote
        }
    }

    private var quitDate: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quit date")
                .font(.rounded(.headline, weight: .bold))

            DatePicker(
                "Target date",
                selection: Binding(
                    get: { store.currentQuitPlan.quitDate },
                    set: { store.updateQuitDate($0) }
                ),
                displayedComponents: .date
            )
            .font(.rounded(.subheadline))

            Text(quitDateSummary)
                .font(.rounded(.subheadline))
                .foregroundColor(QuitTheme.muted)
        }
        .quietCard()
    }

    private var progressBaseline: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Progress baseline")
                .font(.rounded(.headline, weight: .bold))

            Stepper(
                "Baseline \(Int(store.currentQuitPlan.baselineCigarettesPerDay)) cigarettes/day",
                value: Binding(
                    get: { Int(store.currentQuitPlan.baselineCigarettesPerDay) },
                    set: {
                        store.updateProgressBaseline(
                            cigarettesPerDay: Double($0),
                            costPerPack: store.currentQuitPlan.costPerPack,
                            cigarettesPerPack: store.currentQuitPlan.cigarettesPerPack
                        )
                    }
                ),
                in: 0...80
            )

            Stepper(
                "Pack cost \(currency(store.currentQuitPlan.costPerPack))",
                value: Binding(
                    get: { store.currentQuitPlan.costPerPack },
                    set: {
                        store.updateProgressBaseline(
                            cigarettesPerDay: store.currentQuitPlan.baselineCigarettesPerDay,
                            costPerPack: $0,
                            cigarettesPerPack: store.currentQuitPlan.cigarettesPerPack
                        )
                    }
                ),
                in: 0...50,
                step: 0.5
            )
        }
        .font(.rounded(.subheadline))
        .quietCard()
    }

    private var approach: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Approach")
                .font(.rounded(.headline, weight: .bold))
            Picker("Approach", selection: $store.quitMode) {
                Text("Taper").tag("Taper")
                Text("Cold turkey").tag("Cold turkey")
            }
            .pickerStyle(.segmented)
            Text(store.quitMode == "Taper" ? "Today's target is \(Int(store.currentQuitPlan.taperTargetCigarettesPerDay)) cigarettes. Adjust the baseline as your taper gets clearer." : "Prepare substitutes before the quit date.")
                .font(.rounded(.subheadline))
                .foregroundColor(QuitTheme.muted)
        }
        .quietCard()
    }

    private var rules: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("When this happens")
                .font(.rounded(.headline, weight: .bold))
            ForEach(store.triggerRules) { rule in
                VStack(alignment: .leading, spacing: 4) {
                    Text(rule.trigger)
                        .font(.rounded(.subheadline, weight: .bold))
                    Text(rule.action)
                        .font(.rounded(.caption))
                        .foregroundColor(QuitTheme.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
            }

            Divider()
            TextField("Trigger", text: $newTrigger)
                .textFieldStyle(.roundedBorder)
            TextField("What I'll do instead", text: $newAction)
                .textFieldStyle(.roundedBorder)
            Button("Add trigger rule") {
                store.addTriggerRule(trigger: newTrigger, action: newAction)
                newTrigger = ""
                newAction = ""
            }
            .buttonStyle(QuietButtonStyle())
        }
        .quietCard()
    }

    private var reasons: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Reasons")
                .font(.rounded(.headline, weight: .bold))

            ForEach(store.userReasons) { reason in
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(reason.text)
                            .font(.rounded(.subheadline, weight: .bold))
                        if reason.isPrimary {
                            Text("Primary reason")
                                .font(.rounded(.caption, weight: .bold))
                                .foregroundColor(QuitTheme.muted)
                        }
                    }
                    Spacer()
                    if !reason.isPrimary {
                        Button("Use") {
                            store.setPrimaryUserReason(reason.id)
                        }
                        .font(.rounded(.caption, weight: .bold))
                        .foregroundColor(QuitTheme.cocoa)
                    }
                    Button {
                        store.deleteUserReason(reason.id)
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(QuitTheme.muted)
                            .frame(width: 34, height: 34)
                            .background(QuitTheme.peach.opacity(0.55))
                            .clipShape(Circle())
                    }
                    .accessibilityLabel("Remove reason")
                }
            }

            Divider()
            TextField("Reason for quitting", text: $newReason)
                .textFieldStyle(.roundedBorder)
            Button("Add reason") {
                store.addUserReason(newReason, isPrimary: store.userReasons.isEmpty)
                newReason = ""
            }
            .buttonStyle(QuietButtonStyle())
        }
        .quietCard()
    }

    private var replacementActivities: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Replacement activities")
                .font(.rounded(.headline, weight: .bold))

            ForEach(store.replacementActivities.filter(\.isEnabled).prefix(4)) { activity in
                VStack(alignment: .leading, spacing: 3) {
                    Text(activity.title)
                        .font(.rounded(.subheadline, weight: .bold))
                    Text(activity.instruction)
                        .font(.rounded(.caption))
                        .foregroundColor(QuitTheme.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()
            TextField("Activity", text: $newActivityTitle)
                .textFieldStyle(.roundedBorder)
            TextField("Instruction", text: $newActivityInstruction)
                .textFieldStyle(.roundedBorder)
            Picker("Category", selection: $newActivityCategory) {
                ForEach(ReplacementActivityCategory.allCases, id: \.self) { category in
                    Text(category.title).tag(category)
                }
            }
            .pickerStyle(.menu)
            Button("Add activity") {
                store.addReplacementActivity(
                    title: newActivityTitle,
                    instruction: newActivityInstruction,
                    category: newActivityCategory
                )
                newActivityTitle = ""
                newActivityInstruction = ""
            }
            .buttonStyle(QuietButtonStyle())
        }
        .quietCard()
    }

    private var medicationNote: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Medication note")
                .font(.rounded(.headline, weight: .bold))
            Text(store.currentQuitPlan.medicationNote)
                .font(.rounded(.subheadline))
                .foregroundColor(QuitTheme.muted)
        }
        .quietCard()
    }

    private var quitDateSummary: String {
        let today = Calendar.current.startOfDay(for: Date())
        let quitDate = Calendar.current.startOfDay(for: store.currentQuitPlan.quitDate)
        let days = Calendar.current.dateComponents([.day], from: today, to: quitDate).day ?? 0
        if days == 0 {
            return "Quit date is today. Keep the rescue plan close."
        }
        if days > 0 {
            return days == 1 ? "1 day away." : "\(days) days away."
        }
        return "Quit date has passed. Keep the attempt alive or choose a new date."
    }

    private func currency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = value.rounded() == value ? 0 : 2
        return formatter.string(from: NSNumber(value: value)) ?? "$0"
    }
}
