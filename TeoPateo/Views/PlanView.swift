import SwiftUI

struct PlanView: View {
    @EnvironmentObject private var store: TeoPateoStore

    var body: some View {
        RootScreen {
            ScreenHeader(eyebrow: "Quit plan", title: "Your plan stays specific.")

            quitDate
            approach
            rules
            support
            medicationNote
        }
    }

    private var quitDate: some View {
        HStack(spacing: 14) {
            VStack(spacing: 2) {
                Text("JUN")
                    .font(.rounded(.caption, weight: .bold))
                Text("01")
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
            }
            .foregroundColor(.white)
            .frame(width: 70, height: 70)
            .background(QuitTheme.cocoa)
            .cornerRadius(16)

            VStack(alignment: .leading, spacing: 4) {
                Text("Quit date")
                    .font(.rounded(.headline, weight: .bold))
                Text("11 days away. Reminders increase during your highest-risk windows.")
                    .font(.rounded(.subheadline))
                    .foregroundColor(QuitTheme.muted)
            }
        }
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
            Text(store.quitMode == "Taper" ? "Reduce by two cigarettes every three days until quit date." : "Prepare substitutes and support alerts before quit date.")
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
        }
        .quietCard()
    }

    private var support: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Support circle")
                .font(.rounded(.headline, weight: .bold))
            supportRow("Maya", "Craving alert and evening check-in")
            supportRow("1-800-QUIT-NOW", "US quitline support")
        }
        .quietCard()
    }

    private var medicationNote: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Medication note")
                .font(.rounded(.headline, weight: .bold))
            Text("Nicotine replacement therapy and prescription quit medicines can help some people. Talk with a doctor, pharmacist, or quitline counselor before making medication decisions.")
                .font(.rounded(.subheadline))
                .foregroundColor(QuitTheme.muted)
        }
        .quietCard()
    }

    private func supportRow(_ name: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(name)
                .font(.rounded(.subheadline, weight: .bold))
            Text(detail)
                .font(.rounded(.caption))
                .foregroundColor(QuitTheme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
