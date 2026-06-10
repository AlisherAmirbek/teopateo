import SwiftUI

struct TodayView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject private var store: TeoPateoStore
    @State private var isNotificationsPresented = false
    @State private var tutorialTarget: TutorialTarget?

    var body: some View {
        GeometryReader { proxy in
            let metrics = AdaptiveScreenMetrics(
                width: proxy.size.width,
                horizontalSizeClass: horizontalSizeClass,
                dynamicTypeSize: dynamicTypeSize
            )

            ZStack {
                QuitTheme.background.ignoresSafeArea()

                ScrollViewReader { scrollProxy in
                    ScrollView {
                        content(metrics: metrics)
                            .padding(.horizontal, metrics.horizontalPadding)
                            .padding(.top, metrics.usesWideLayout ? 22 : 18)
                            .padding(.bottom, metrics.verticalPadding)
                            .frame(maxWidth: metrics.contentMaxWidth, alignment: .leading)
                            .frame(maxWidth: .infinity)
                    }
                    .onChange(of: tutorialTarget) { newTarget in
                        scrollToTutorialTarget(newTarget, using: scrollProxy)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                rescueBar(metrics: metrics)
            }
        }
        .sheet(isPresented: $isNotificationsPresented) {
            NotificationSettingsView()
                .environmentObject(store)
        }
        .overlayPreferenceValue(TutorialAnchorKey.self) { anchors in
            tutorialOverlay(anchors: anchors)
        }
    }

    @ViewBuilder
    private func tutorialOverlay(anchors: [String: Anchor<CGRect>]) -> some View {
        if store.isTutorialActive {
            // Outer reader keeps the real safe-area insets (for card placement);
            // the inner reader spans the full screen so the dim covers everything,
            // including the pinned rescue bar, with the cut-outs in the same space.
            GeometryReader { outer in
                let safeInsets = outer.safeAreaInsets
                GeometryReader { full in
                    TutorialCoachMarks(
                        rects: anchors.reduce(into: [String: CGRect]()) { result, entry in
                            result[entry.key] = full[entry.value]
                        },
                        size: full.size,
                        safeInsets: safeInsets,
                        onDone: { store.completeTutorial() },
                        onActiveTargetChange: { tutorialTarget = $0 }
                    )
                }
                .ignoresSafeArea()
            }
            .transition(.opacity)
            .zIndex(10)
        }
    }

    /// Brings the spotlighted element into view before the cut-out lands on it.
    /// The rescue bar and tabs are fixed, so they need no scrolling.
    private func scrollToTutorialTarget(_ target: TutorialTarget?, using proxy: ScrollViewProxy) {
        guard let target, target != .rescue else { return }
        withAnimation(.easeInOut(duration: 0.35)) {
            proxy.scrollTo(target.rawValue, anchor: .center)
        }
    }

    @ViewBuilder
    private func content(metrics: AdaptiveScreenMetrics) -> some View {
        if metrics.usesWideLayout {
            wideContent(metrics: metrics)
        } else {
            compactContent
        }
    }

    private var compactContent: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            header
            StatusBanner(status: store.lastSaveStatus, persistenceError: store.persistenceError)
            if !store.isOnboardingCompleted {
                onboardingPrompt
            }
            mascotHero(height: 278)
            planWeekCard
            nextActionCard
            pendingSuggestionCard
            facts
            safetyResources
        }
    }

    private func wideContent(metrics: AdaptiveScreenMetrics) -> some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            header
            StatusBanner(status: store.lastSaveStatus, persistenceError: store.persistenceError)

            if !store.isOnboardingCompleted {
                onboardingPrompt
            }

            HStack(alignment: .top, spacing: metrics.columnSpacing) {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    mascotHero(height: 332)
                    planWeekCard
                    nextActionCard
                    pendingSuggestionCard
                }
                .frame(maxWidth: .infinity, alignment: .top)

                VStack(alignment: .leading, spacing: Spacing.lg) {
                    facts
                    safetyResources
                }
                .frame(maxWidth: .infinity, alignment: .top)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("TeoPateo")
                    .typeLabel()
                Text(greetingTitle)
                    .typeDisplay()
                    .fixedSize(horizontal: false, vertical: true)
            }

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

    private var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default: return "Good night"
        }
    }

    private var greetingTitle: String {
        let name = store.displayName
        return name == "you" ? greeting : "\(greeting), \(name)"
    }

    // MARK: - Mascot hero (kept on the home screen, now reactive)

    private func mascotHero(height: CGFloat) -> some View {
        VStack(spacing: Spacing.smd) {
            MascotRoomView()
                .frame(height: height)
                .tutorialAnchor(.teo)
            Text(streakCaption)
                .typeBodySecondary()
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("today-mascot-caption")
        }
        .frame(maxWidth: .infinity)
    }

    private var streakCaption: String {
        if !store.isOnboardingCompleted {
            return "Finish setup and Teo will build your plan."
        }
        let progress = store.progressSummary
        if progress.smokeFreeDays >= 1 {
            let unit = progress.smokeFreeDays == 1 ? "day" : "days"
            return "\(progress.smokeFreeDays) \(unit) smoke-free. Teo is proud of you."
        }
        if progress.cravingsHandled >= 1 {
            let unit = progress.cravingsHandled == 1 ? "craving" : "cravings"
            return "\(progress.cravingsHandled) \(unit) handled. Teo has your back."
        }
        return "Teo is right here with you."
    }

    // MARK: - Cards

    private var onboardingPrompt: some View {
        VStack(alignment: .leading, spacing: Spacing.smd) {
            HStack(alignment: .top, spacing: Spacing.smd) {
                Image(systemName: "list.clipboard")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(QuitTheme.cocoa)
                    .frame(width: 34, height: 34)
                    .background(QuitTheme.peach.opacity(0.74))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Finish your quit plan")
                        .typeSection()
                    Text("Set your triggers, reason, and first rescue actions.")
                        .typeBodySecondary()
                }
            }

            Button("Continue setup") {
                store.presentOnboarding()
            }
            .buttonStyle(QuietButtonStyle())
            .accessibilityIdentifier("continue-setup-button")
        }
        .quietCard()
    }

    @ViewBuilder
    private var nextActionCard: some View {
        let action = store.currentQuitPlan.nextBestAction.trimmingCharacters(in: .whitespacesAndNewlines)
        if store.isOnboardingCompleted && !action.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.smd) {
                Text("Next best action")
                    .typeSection()
                Text(action)
                    .typeBody()
                    .fixedSize(horizontal: false, vertical: true)
                if let focus = store.todaysFocusPlan {
                    Divider().overlay(QuitTheme.line)
                    Text(focus.title)
                        .font(.rounded(.footnote, weight: .bold))
                        .foregroundColor(QuitTheme.cocoa)
                    Text(focus.action)
                        .typeBodySecondary()
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .quietCard()
            .tutorialAnchor(.nextAction)
        }
    }

    @ViewBuilder
    private var pendingSuggestionCard: some View {
        if let suggestion = store.highestPriorityPendingPlanSuggestion {
            VStack(alignment: .leading, spacing: Spacing.smd) {
                Text("Plan suggestion")
                    .typeSection()
                Text(suggestion.title)
                    .font(.rounded(.callout, weight: .bold))
                    .foregroundColor(QuitTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(suggestion.evidenceSummary)
                    .typeBodySecondary()
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: Spacing.smd) {
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
        }
    }

    private var planWeekCard: some View {
        PlanWeekCard(days: store.currentWeekPlanAdherence)
            .tutorialAnchor(.calendar)
    }

    private var safetyResources: some View {
        SafetyResourcesView()
    }

    private var facts: some View {
        let insights = store.calculatedInsights

        return VStack(spacing: 0) {
            factRow("Smoke-free", insights.smokeFreeSummary)
            factRow("Cravings handled", "\(insights.cravingsHandled)")
            factRow("Saved", insights.moneySavedSummary)
            factRow("Next risk", insights.nextRiskSummary)
        }
    }

    private func factRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .typeBodySecondary()
            Spacer()
            Text(value)
                .font(.rounded(.headline, weight: .bold))
                .foregroundColor(QuitTheme.ink)
        }
        .frame(minHeight: 56)
        .padding(.vertical, Spacing.xs)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(QuitTheme.line)
                .frame(height: 1)
        }
    }

    // MARK: - Pinned rescue (the only rescue entry on this screen)

    private func rescueBar(metrics: AdaptiveScreenMetrics) -> some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(QuitTheme.line)
                .frame(height: 1)

            Button {
                Haptics.impact(.medium)
                store.isCravingModePresented = true
            } label: {
                Text("I want to smoke")
                    .font(.rounded(.title3, weight: .bold))
                    .foregroundColor(QuitTheme.onCocoa)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 30)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 16)
                    .background(QuitTheme.cocoa)
                    .clipShape(Capsule())
            }
            .accessibilityLabel("Start craving rescue")
            .accessibilityHint("Opens the 10-minute craving mode.")
            .accessibilityIdentifier("start-rescue-button")
            .tutorialAnchor(.rescue)
            .padding(.horizontal, metrics.horizontalPadding)
            .padding(.top, Spacing.smd)
            .padding(.bottom, Spacing.sm)
            .frame(maxWidth: metrics.contentMaxWidth)
            .frame(maxWidth: .infinity)
        }
        .background(QuitTheme.background)
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
        .background(QuitSurface(cornerRadius: 24))
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

// MARK: - First-run tutorial (one-time coach marks)

/// Elements on Today that the tutorial can spotlight.
private enum TutorialTarget: String {
    case teo, calendar, nextAction, rescue
}

private struct TutorialAnchorKey: PreferenceKey {
    static var defaultValue: [String: Anchor<CGRect>] = [:]
    static func reduce(value: inout [String: Anchor<CGRect>], nextValue: () -> [String: Anchor<CGRect>]) {
        value.merge(nextValue()) { _, new in new }
    }
}

private extension View {
    /// Reports this view's frame so the tutorial overlay can spotlight it, and
    /// tags it with a scroll id so the tour can bring it into view.
    func tutorialAnchor(_ target: TutorialTarget) -> some View {
        self
            .id(target.rawValue)
            .anchorPreference(key: TutorialAnchorKey.self, value: .bounds) { anchor in
                [target.rawValue: anchor]
            }
    }
}

/// A small downward triangle used as the tab-bar tip's tail.
private struct DownCaret: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct TutorialTip {
    /// `nil` means there's no Today element to spotlight (e.g. a tab-bar tip).
    let target: TutorialTarget?
    let title: String
    let text: String
    /// Anchors the card to the bottom with a caret aimed at the tab bar.
    var pointsAtTabBar = false
}

/// A dimmed overlay that spotlights one Today element at a time with a short
/// instruction and a "Got it!" button. Warm, minimalist, and dismissible.
private struct TutorialCoachMarks: View {
    let rects: [String: CGRect]
    let size: CGSize
    let safeInsets: EdgeInsets
    let onDone: () -> Void
    let onActiveTargetChange: (TutorialTarget?) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var index = 0

    private static let allTips: [TutorialTip] = [
        TutorialTip(
            target: .teo,
            title: "Meet Teo",
            text: "Your companion through this. Tap Teo any time for a little lift."
        ),
        TutorialTip(
            target: .calendar,
            title: "Your week at a glance",
            text: "Each day fills in as you check in, so your streak is easy to see."
        ),
        TutorialTip(
            target: .nextAction,
            title: "Start here",
            text: "Teo's next best action — the one small step to focus on today."
        ),
        TutorialTip(
            target: .rescue,
            title: "When a craving hits",
            text: "Tap “I want to smoke” for a 10-minute rescue. Teo stays with you until it passes."
        ),
        TutorialTip(
            target: nil,
            title: "Check in daily",
            text: "Tap Check-in to tell Teo how your day went. Plan, Insights, and Coach are here too.",
            pointsAtTabBar: true
        )
    ]

    /// Only show tips whose target is actually on screen (plus the centered one).
    private var tips: [TutorialTip] {
        Self.allTips.filter { tip in
            guard let target = tip.target else { return true }
            return rects[target.rawValue] != nil
        }
    }

    var body: some View {
        let safeIndex = min(index, max(tips.count - 1, 0))
        let tip = tips[safeIndex]
        let hole = tip.target.flatMap { rects[$0.rawValue] }

        ZStack {
            spotlight(hole: hole)
                .frame(width: size.width, height: size.height)
                .contentShape(Rectangle())
                .onTapGesture { }

            cardLayer(tip: tip, hole: hole, index: safeIndex)
        }
        .accessibilityAddTraits(.isModal)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: index)
        .onAppear { onActiveTargetChange(tip.target) }
        .onChange(of: index) { newIndex in
            let safe = min(newIndex, max(tips.count - 1, 0))
            onActiveTargetChange(tips[safe].target)
        }
    }

    private func spotlight(hole: CGRect?) -> some View {
        Path { path in
            path.addRect(CGRect(origin: .zero, size: size))
            if let hole {
                let padded = hole.insetBy(dx: -10, dy: -10)
                path.addRoundedRect(in: padded, cornerSize: CGSize(width: 18, height: 18))
            }
        }
        .fill(Color.black.opacity(0.58), style: FillStyle(eoFill: true))
    }

    @ViewBuilder
    private func cardLayer(tip: TutorialTip, hole: CGRect?, index: Int) -> some View {
        // Keep the card clear of the highlight: top-half targets (and the tab-bar
        // tip) push the card to the bottom, lower targets push it to the top.
        let placeAtBottom = tip.pointsAtTabBar
            || (hole?.midY ?? size.height / 2) < size.height / 2

        VStack(spacing: 0) {
            if placeAtBottom {
                Spacer(minLength: 0)
                cardWithCaret(tip: tip, index: index)
            } else {
                cardWithCaret(tip: tip, index: index)
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, safeInsets.top + Spacing.md)
        .padding(.bottom, safeInsets.bottom + (tip.pointsAtTabBar ? Spacing.xs : Spacing.md))
        .frame(width: size.width, height: size.height)
    }

    /// The card, plus a downward tail aimed at the centered Check-in tab for
    /// tab-bar tips. The tail sits flush against the card so it reads as one piece.
    private func cardWithCaret(tip: TutorialTip, index: Int) -> some View {
        VStack(spacing: 0) {
            card(tip: tip, index: index)
            if tip.pointsAtTabBar {
                DownCaret()
                    .fill(QuitTheme.paper)
                    .frame(width: 28, height: 13)
                    .padding(.top, -1)
                    .accessibilityHidden(true)
            }
        }
    }

    private func card(tip: TutorialTip, index: Int) -> some View {
        VStack(alignment: .leading, spacing: Spacing.smd) {
            Text(verbatim: String(format: L10n.string("%d of %d"), index + 1, tips.count))
                .typeLabel()
            Text(L10n.key(tip.title))
                .typeSection()
            Text(L10n.key(tip.text))
                .typeBodySecondary()
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Button(action: onDone) {
                    Text(L10n.key("Skip"))
                        .font(.rounded(.subheadline, weight: .semibold))
                        .foregroundColor(QuitTheme.muted)
                }
                .accessibilityIdentifier("tutorial-skip")

                Spacer()

                Button(action: advance) {
                    Text(L10n.key("Got it!"))
                        .font(.rounded(.subheadline, weight: .bold))
                        .foregroundColor(QuitTheme.onCocoa)
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.sm)
                        .background(QuitTheme.cocoa)
                        .clipShape(Capsule())
                }
                .accessibilityIdentifier("tutorial-got-it")
            }
            .padding(.top, Spacing.xs)
        }
        .quietCard()
        .frame(maxWidth: 360)
        .shadow(color: Color.black.opacity(0.18), radius: 18, x: 0, y: 8)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
    }

    private func advance() {
        Haptics.selection()
        if index >= tips.count - 1 {
            onDone()
        } else {
            index += 1
        }
    }
}
