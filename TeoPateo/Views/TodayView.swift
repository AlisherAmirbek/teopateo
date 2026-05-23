import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var store: TeoPateoStore

    var body: some View {
        ZStack {
            QuitTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    header
                    StatusBanner(status: store.lastSaveStatus, persistenceError: store.persistenceError)
                        .padding(.top, 8)
                    if !store.isOnboardingCompleted {
                        onboardingPrompt
                    }
                    mascot
                    copy
                    rescueButton
                    riskCard
                    facts
                }
                .padding(.horizontal, 24)
                .padding(.top, 18)
                .padding(.bottom, 24)
            }
        }
    }

    private var onboardingPrompt: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "list.clipboard")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(QuitTheme.cocoa)
                    .frame(width: 34, height: 34)
                    .background(QuitTheme.peach.opacity(0.74))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text("Finish your quit plan")
                        .font(.rounded(.headline, weight: .bold))
                        .foregroundColor(QuitTheme.ink)
                    Text("Set your triggers, reason, and first rescue actions.")
                        .font(.rounded(.caption))
                        .foregroundColor(QuitTheme.muted)
                }
            }

            Button("Continue setup") {
                store.presentOnboarding()
            }
            .buttonStyle(QuietButtonStyle())
        }
        .quietCard()
        .padding(.top, 14)
    }

    private var header: some View {
        HStack {
            Text("TeoPateo")
                .font(.rounded(.caption, weight: .bold))
                .foregroundColor(QuitTheme.muted)

            Spacer()

            Button {} label: {
                Image(systemName: "bell")
                    .font(.system(size: 23, weight: .regular, design: .rounded))
                    .foregroundColor(QuitTheme.faint)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Notifications")
        }
    }

    private var mascot: some View {
        MascotRoomView()
            .frame(height: 278)
    }

    private var copy: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("Pause before the cigarette.")
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .foregroundColor(QuitTheme.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text("Your 10-minute rescue plan is ready when the urge shows up.")
                .font(.rounded(.subheadline))
                .foregroundColor(QuitTheme.muted)
                .lineSpacing(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var rescueButton: some View {
        Button {
            store.isCravingModePresented = true
        } label: {
            HStack {
                Text("I want to smoke")
                    .font(.rounded(.caption, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.72))

                Spacer()

                Text("Start rescue")
                    .font(.rounded(.headline, weight: .bold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 18)
            .frame(height: 72)
            .background(QuitTheme.cocoa)
            .clipShape(Capsule())
        }
        .padding(.top, 28)
    }

    private var riskCard: some View {
        let risk = store.calculatedInsights.todayRisk

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Today risk")
                    .font(.rounded(.headline, weight: .bold))
                Spacer()
                Text(risk.level.rawValue)
                    .font(.rounded(.caption, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(risk.level == .high ? QuitTheme.cocoa : QuitTheme.sage)
                    .cornerRadius(12)
            }

            Text(risk.summary)
                .font(.rounded(.subheadline))
                .foregroundColor(QuitTheme.muted)

            Button(risk.actionTitle) {
                if risk.actionTitle == "Start rescue" {
                    store.isCravingModePresented = true
                } else {
                    store.selectedTab = .plan
                }
            }
            .buttonStyle(QuietButtonStyle())
        }
        .quietCard()
        .padding(.top, 18)
    }

    private var facts: some View {
        let insights = store.calculatedInsights

        return VStack(spacing: 0) {
            factRow("Smoke-free", insights.smokeFreeSummary)
            factRow("Cravings handled", "\(insights.cravingsHandled)")
            factRow("Saved", insights.moneySavedSummary)
            factRow("Next risk", insights.nextRiskSummary)
        }
        .padding(.top, 22)
    }

    private func factRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.rounded(.subheadline))
                .foregroundColor(QuitTheme.muted)
            Spacer()
            Text(value)
                .font(.rounded(.headline, weight: .bold))
                .foregroundColor(QuitTheme.ink)
        }
        .frame(height: 56)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(QuitTheme.line)
                .frame(height: 1)
        }
    }
}

private struct MascotRoomView: View {
    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let cornerX = width * 0.5
            let floorY = height * 0.66

            ZStack {
                roomLines(width: width, cornerX: cornerX, floorY: floorY)
                    .stroke(
                        QuitTheme.ink.opacity(0.18),
                        style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round)
                    )

                Ellipse()
                    .fill(QuitTheme.ink.opacity(0.06))
                    .frame(width: 112, height: 12)
                    .position(x: cornerX, y: floorY + 26)

                Image("Mascot")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 164, height: 164)
                    .opacity(0.98)
                    .position(x: cornerX, y: floorY - 27)
            }
            .frame(width: width, height: height)
        }
    }

    private func roomLines(width: CGFloat, cornerX: CGFloat, floorY: CGFloat) -> Path {
        Path { path in
            path.move(to: CGPoint(x: cornerX, y: 16))
            path.addLine(to: CGPoint(x: cornerX, y: floorY))

            path.move(to: CGPoint(x: cornerX, y: floorY))
            path.addLine(to: CGPoint(x: 8, y: floorY + 52))

            path.move(to: CGPoint(x: cornerX, y: floorY))
            path.addLine(to: CGPoint(x: width - 8, y: floorY + 52))
        }
    }
}
