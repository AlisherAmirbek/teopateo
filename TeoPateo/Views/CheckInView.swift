import SwiftUI

struct CheckInView: View {
    @EnvironmentObject private var store: TeoPateoStore
    @State private var note = "Delay the first craving by 10 minutes and text Maya if it hits after work."
    @State private var slipNote = "I left work stressed and bought cigarettes before dinner."

    var body: some View {
        RootScreen {
            ScreenHeader(eyebrow: "Daily check-in", title: "Record today without judging it.")

            sliders
            smokedToday

            if store.smokedToday == true {
                slipRecovery
            }

            focus
            Button("Save check-in") {
                store.saveCheckIn(focusNote: note, slipNote: slipNote)
            }
                .buttonStyle(FilledButtonStyle())
        }
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
                Button("No smoke") {
                    store.smokedToday = false
                }
                .buttonStyle(QuietButtonStyle())
                Button("I smoked") {
                    store.smokedToday = true
                }
                .buttonStyle(QuietButtonStyle())
            }
        }
        .quietCard()
    }

    private var slipRecovery: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Slip recovery")
                .font(.rounded(.headline, weight: .bold))
            Text("This stays part of the same quit attempt. Capture what happened and adjust the plan.")
                .font(.rounded(.subheadline))
                .foregroundColor(QuitTheme.muted)
            TextEditor(text: $slipNote)
                .frame(height: 96)
                .padding(8)
                .background(QuitTheme.background)
                .cornerRadius(12)
        }
        .quietCard()
    }

    private var focus: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Today focus")
                .font(.rounded(.headline, weight: .bold))
            TextEditor(text: $note)
                .frame(height: 104)
                .padding(8)
                .background(QuitTheme.paper)
                .cornerRadius(12)
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
}
