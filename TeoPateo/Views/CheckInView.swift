import SwiftUI

struct CheckInView: View {
    @EnvironmentObject private var store: TeoPateoStore
    @State private var slipNote = ""
    @State private var slipContext = ""
    @State private var recoveryAction = "Pause before the next cigarette and use the rescue plan."

    var body: some View {
        RootScreen {
            ScreenHeader(eyebrow: "Daily check-in", title: "Record today without judging it.")
            StatusBanner(status: store.lastSaveStatus, persistenceError: store.persistenceError)
            dailyFocus

            if let today = store.todayCheckIn {
                existingCheckIn(today)
            }

            sliders
            smokedToday
            taperTarget

            if store.smokedToday == true {
                slipRecovery
            }

            Button("Save check-in") {
                save()
            }
            .buttonStyle(FilledButtonStyle())
            .disabled(store.smokedToday == nil)
            .opacity(store.smokedToday == nil ? 0.45 : 1)
            .accessibilityIdentifier("checkin-save-button")
        }
        .onAppear {
            recoveryAction = store.currentQuitPlan.slipRecoveryPlan.defaultRecoveryAction
        }
    }

    private var dailyFocus: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Today's plan")
                .font(.rounded(.headline, weight: .bold))
            Text(store.dailyFocus)
                .font(.rounded(.subheadline))
                .foregroundColor(QuitTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .quietCard()
    }

    private func existingCheckIn(_ checkIn: DailyCheckIn) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Today already has a check-in")
                .font(.rounded(.headline, weight: .bold))
            Text("Saving again updates today's record instead of creating a duplicate.")
                .font(.rounded(.subheadline))
                .foregroundColor(QuitTheme.muted)
            Text(checkIn.smokedToday == true ? "Recorded smoking today" : "Recorded no smoke today")
                .font(.rounded(.caption, weight: .bold))
                .foregroundColor(QuitTheme.cocoa)
        }
        .quietCard()
    }

    private var sliders: some View {
        VStack(spacing: 18) {
            slider("Mood", value: $store.mood)
            slider("Stress", value: $store.stress)
            slider("Confidence", value: $store.confidence)
        }
        .quietCard()
    }

    private var smokedToday: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Did you smoke today?")
                .font(.rounded(.headline, weight: .bold))
            HStack(spacing: 10) {
                smokeChoice("No smoke", selected: store.smokedToday == false) {
                    store.smokedToday = false
                }
                smokeChoice("I smoked", selected: store.smokedToday == true) {
                    store.smokedToday = true
                }
            }
        }
        .quietCard()
    }

    @ViewBuilder
    private var taperTarget: some View {
        if let target = store.todayTaperTarget {
            VStack(alignment: .leading, spacing: 8) {
                Text("Taper target")
                    .font(.rounded(.headline, weight: .bold))
                Text("Today's target is \(Int(target)) cigarette\(Int(target) == 1 ? "" : "s").")
                    .font(.rounded(.subheadline))
                    .foregroundColor(QuitTheme.muted)

                if let smokedToday = store.smokedToday {
                    let cigarettes = smokedToday ? store.cigarettesSmoked : 0
                    Text(Double(cigarettes) <= target ? "This check-in is within target." : "This check-in is above target. Use it to adjust tomorrow's plan.")
                        .font(.rounded(.caption, weight: .bold))
                        .foregroundColor(Double(cigarettes) <= target ? QuitTheme.sage : QuitTheme.cocoa)
                }
            }
            .quietCard()
        }
    }

    private var slipRecovery: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Slip recovery")
                .font(.rounded(.headline, weight: .bold))
            Text(store.currentQuitPlan.slipRecoveryPlan.message)
                .font(.rounded(.subheadline))
                .foregroundColor(QuitTheme.muted)

            Stepper("Cigarettes smoked: \(store.cigarettesSmoked)", value: $store.cigarettesSmoked, in: 1...80)
                .font(.rounded(.subheadline))

            Text("Trigger")
                .font(.rounded(.subheadline, weight: .bold))
            FlexibleTags(items: store.cravingTriggerOptions, selected: $store.selectedSlipTriggers)

            TextField("Context, such as commute or after dinner", text: $slipContext)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("checkin-slip-context-field")
            TextEditor(text: $slipNote)
                .frame(height: 90)
                .padding(8)
                .background(QuitTheme.background)
                .cornerRadius(12)
                .accessibilityIdentifier("checkin-slip-note-editor")
            TextField("Recovery action", text: $recoveryAction)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("checkin-recovery-action-field")
        }
        .quietCard()
    }

    private func smokeChoice(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.rounded(.headline, weight: .bold))
                .foregroundColor(selected ? .white : QuitTheme.cocoa)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(selected ? QuitTheme.cocoa : QuitTheme.peach.opacity(0.85))
                .cornerRadius(12)
        }
        .accessibilityIdentifier("checkin-choice-\(title)")
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
                .accessibilityValue("\(Int(value.wrappedValue)) out of 10")
        }
    }

    private func save() {
        let saved = store.saveCheckIn(slipNote: slipNote)
        guard saved, store.smokedToday == true else {
            return
        }

        store.saveSlipEvent(
            cigarettesSmoked: store.cigarettesSmoked,
            triggers: store.selectedSlipTriggers,
            mood: store.mood,
            stress: store.stress,
            context: slipContext,
            note: slipNote,
            recoveryAction: recoveryAction
        )
    }
}
