import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var store: TeoPateoStore
    @State private var isNotificationsPresented = false

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
                    nextActionCard
                    pendingSuggestionCard
                    mascot
                    planWeekCard
                    rescueButton
                    riskCard
                    facts
                }
                .padding(.horizontal, 24)
                .padding(.top, 18)
                .padding(.bottom, 24)
            }
        }
        .sheet(isPresented: $isNotificationsPresented) {
            NotificationSettingsView()
                .environmentObject(store)
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
            .accessibilityIdentifier("continue-setup-button")
        }
        .quietCard()
        .padding(.top, 14)
    }

    @ViewBuilder
    private var nextActionCard: some View {
        let action = store.currentQuitPlan.nextBestAction.trimmingCharacters(in: .whitespacesAndNewlines)
        if store.isOnboardingCompleted && !action.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Next best action")
                    .font(.rounded(.headline, weight: .bold))
                Text(action)
                    .font(.rounded(.subheadline))
                    .foregroundColor(QuitTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                if let focus = store.todaysFocusPlan {
                    Divider()
                    Text(focus.title)
                        .font(.rounded(.caption, weight: .bold))
                        .foregroundColor(QuitTheme.cocoa)
                    Text(focus.action)
                        .font(.rounded(.caption))
                        .foregroundColor(QuitTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .quietCard()
            .padding(.top, 14)
        }
    }

    @ViewBuilder
    private var pendingSuggestionCard: some View {
        if let suggestion = store.highestPriorityPendingPlanSuggestion {
            VStack(alignment: .leading, spacing: 10) {
                Text("Plan suggestion")
                    .font(.rounded(.headline, weight: .bold))
                Text(suggestion.title)
                    .font(.rounded(.subheadline, weight: .bold))
                    .foregroundColor(QuitTheme.ink)
                Text(suggestion.evidenceSummary)
                    .font(.rounded(.caption))
                    .foregroundColor(QuitTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 10) {
                    Button("Accept") {
                        store.acceptPlanSuggestion(suggestion.id)
                    }
                    .buttonStyle(QuietButtonStyle())
                    Button("Review") {
                        store.selectedTab = .plan
                    }
                    .buttonStyle(QuietButtonStyle())
                }
            }
            .quietCard()
            .padding(.top, 14)
        }
    }

    private var header: some View {
        HStack {
            Text("TeoPateo")
                .font(.rounded(.caption, weight: .bold))
                .foregroundColor(QuitTheme.muted)

            Spacer()

            Button {
                isNotificationsPresented = true
            } label: {
                Image(systemName: store.notificationSettings.hasEnabledReminders ? "bell.fill" : "bell")
                    .font(.system(size: 23, weight: .regular, design: .rounded))
                    .foregroundColor(store.notificationSettings.hasEnabledReminders ? QuitTheme.cocoa : QuitTheme.faint)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Notifications")
            .accessibilityIdentifier("notifications-button")
        }
    }

    private var mascot: some View {
        MascotRoomView()
            .frame(height: 278)
    }

    private var planWeekCard: some View {
        PlanWeekCard(days: store.currentWeekPlanAdherence)
            .padding(.top, 2)
    }

    private var rescueButton: some View {
        Button {
            store.isCravingModePresented = true
        } label: {
            Text("I want to smoke")
                .font(.rounded(.title3, weight: .bold))
                .foregroundColor(QuitTheme.onCocoa)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
                .padding(.vertical, 17)
                .background(QuitTheme.cocoa)
                .clipShape(Capsule())
        }
        .padding(.top, 28)
        .frame(maxWidth: .infinity)
        .accessibilityLabel("Start craving rescue")
        .accessibilityHint("Opens the 10-minute craving mode.")
        .accessibilityIdentifier("start-rescue-button")
    }

    private var riskCard: some View {
        let risk = store.calculatedInsights.todayRisk

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Today risk")
                    .font(.rounded(.headline, weight: .bold))
                Spacer()
                Text(risk.level.title)
                    .font(.rounded(.caption, weight: .bold))
                    .foregroundColor(risk.level == .high ? QuitTheme.onCocoa : QuitTheme.onSage)
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

            if risk.actionTitle == "Review plan" {
                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    Text("Reason to protect")
                        .font(.rounded(.caption, weight: .bold))
                        .foregroundColor(QuitTheme.ink)
                    Text(store.reasonForCravingMode())
                        .font(.rounded(.caption))
                        .foregroundColor(QuitTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
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
        .frame(minHeight: 56)
        .padding(.vertical, 4)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(QuitTheme.line)
                .frame(height: 1)
        }
    }
}

private struct PlanWeekCard: View {
    @ScaledMetric(relativeTo: .headline) private var dayDiameter: CGFloat = 40

    let days: [DailyPlanAdherenceDay]

    private var titleDate: Date? {
        days.first(where: \.isToday)?.date ?? days.first?.date
    }

    var body: some View {
        VStack(spacing: 18) {
            HStack {
                Spacer()
                Text(titleDate?.formatted(.dateTime.month(.wide).year()) ?? "")
                    .font(.rounded(.title3, weight: .bold))
                    .foregroundColor(QuitTheme.ink)
                    .accessibilityIdentifier("plan-week-card")
                Spacer()
            }

            HStack(spacing: 0) {
                ForEach(days) { day in
                    VStack(spacing: 10) {
                        Text(weekdayLetter(for: day.date))
                            .font(.rounded(.subheadline, weight: .bold))
                            .foregroundColor(QuitTheme.faint)

                            Text(day.date.formatted(.dateTime.day()))
                                .font(.rounded(.headline, weight: .bold))
                                .foregroundColor(dayTextColor(for: day.status))
                                .minimumScaleFactor(0.75)
                                .frame(width: dayDiameter, height: dayDiameter)
                                .background(dayColor(for: day.status))
                                .clipShape(Circle())
                            .overlay {
                                Circle()
                                    .stroke(day.isToday ? QuitTheme.cocoa.opacity(0.34) : Color.clear, lineWidth: 2)
                            }
                            .accessibilityLabel(accessibilityLabel(for: day))
                            .accessibilityIdentifier("plan-week-day-\(statusIdentifier(for: day.status))")
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 18)
        .background(QuitTheme.paper)
        .cornerRadius(24)
    }

    private func weekdayLetter(for date: Date) -> String {
        String(date.formatted(.dateTime.weekday(.abbreviated)).prefix(1))
    }

    private func dayColor(for status: DailyPlanAdherenceStatus?) -> Color {
        switch status {
        case .achieved:
            return QuitTheme.sage
        case .slightMiss:
            return QuitTheme.peach
        case .missed:
            return QuitTheme.danger
        case nil:
            return QuitTheme.background.opacity(0.72)
        }
    }

    private func dayTextColor(for status: DailyPlanAdherenceStatus?) -> Color {
        switch status {
        case .achieved:
            return QuitTheme.onSage
        case .missed:
            return .white
        case .slightMiss:
            return QuitTheme.cocoa
        case nil:
            return QuitTheme.faint
        }
    }

    private func statusIdentifier(for status: DailyPlanAdherenceStatus?) -> String {
        switch status {
        case .achieved:
            return "achieved"
        case .slightMiss:
            return "slight-miss"
        case .missed:
            return "missed"
        case nil:
            return "not-logged"
        }
    }

    private func accessibilityLabel(for day: DailyPlanAdherenceDay) -> String {
        let date = day.date.formatted(.dateTime.weekday(.wide).month(.wide).day())
        let status: String
        switch day.status {
        case .achieved:
            status = "plan achieved"
        case .slightMiss:
            status = "slightly missed plan"
        case .missed:
            status = "missed plan"
        case nil:
            status = "not logged"
        }

        return "\(date), \(status)"
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

                AnimatedMascotView(size: 164)
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
