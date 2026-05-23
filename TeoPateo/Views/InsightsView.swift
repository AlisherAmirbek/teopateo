import SwiftUI

struct InsightsView: View {
    @EnvironmentObject private var store: TeoPateoStore

    private var insights: CalculatedInsights {
        store.calculatedInsights
    }

    var body: some View {
        RootScreen {
            ScreenHeader(eyebrow: "Pattern insights", title: "Your risk is predictable.")
            StatusBanner(status: store.lastSaveStatus, persistenceError: store.persistenceError)

            todayRisk
            progressSummary
            riskWindows
            triggerContribution
            slipContribution
            heatMap
            planAdjustment
            historyPreview
        }
    }

    private var todayRisk: some View {
        let risk = insights.todayRisk
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Today's risk")
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
            Text(insights.dataConfidenceSummary)
                .font(.rounded(.caption, weight: .bold))
                .foregroundColor(QuitTheme.muted)
        }
        .quietCard()
    }

    private var progressSummary: some View {
        let progress = store.progressSummary
        return VStack(alignment: .leading, spacing: 14) {
            Text("Progress from history")
                .font(.rounded(.headline, weight: .bold))

            metricRow("Smoke-free streak", insights.smokeFreeSummary)
            metricRow("Cravings handled", "\(insights.cravingsHandled) of \(insights.cravingsLogged)")
            metricRow("Cravings ending in smoking", "\(insights.slippedCravings)")
            metricRow("Cigarettes avoided", "\(insights.cigarettesAvoided)")
            metricRow("Estimated saved", insights.moneySavedSummary)

            if !progress.milestones.isEmpty {
                Divider()
                ForEach(progress.milestones, id: \.self) { milestone in
                    Text(milestone)
                        .font(.rounded(.caption, weight: .bold))
                        .foregroundColor(QuitTheme.cocoa)
                }
            }
        }
        .quietCard()
    }

    private var riskWindows: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Highest-risk windows")
                .font(.rounded(.headline, weight: .bold))

            if insights.riskWindows.isEmpty {
                Text("Log cravings from rescue mode to reveal the times that need extra protection.")
                    .font(.rounded(.subheadline))
                    .foregroundColor(QuitTheme.muted)
            } else {
                ForEach(insights.riskWindows) { window in
                    HStack {
                        Text(window.title)
                            .font(.rounded(.subheadline, weight: .bold))
                            .foregroundColor(QuitTheme.ink)
                        Spacer()
                        Text("\(window.shareSummary) of cravings")
                            .font(.rounded(.caption, weight: .bold))
                            .foregroundColor(QuitTheme.muted)
                    }
                    .padding(.top, 4)
                }
            }
        }
        .quietCard()
    }

    private var triggerContribution: some View {
        contributionSection(
            title: "Craving triggers",
            empty: "Select triggers when you finish a craving rescue. Trigger percentages will appear after the first logged craving.",
            triggers: insights.topTriggers
        )
    }

    private var slipContribution: some View {
        contributionSection(
            title: "Slip triggers",
            empty: "Record a slip recovery to separate smoking triggers from handled-craving triggers.",
            triggers: insights.topSlipTriggers
        )
    }

    private var heatMap: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Craving heat")
                .font(.rounded(.headline, weight: .bold))
            Text("Last 28 days")
                .font(.rounded(.caption, weight: .bold))
                .foregroundColor(QuitTheme.muted)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                ForEach(insights.heatMapDays) { day in
                    RoundedRectangle(cornerRadius: 5)
                        .fill(color(for: day.level))
                        .frame(height: 34)
                        .accessibilityLabel("\(day.count) logged cravings")
                }
            }
        }
        .quietCard()
    }

    private var planAdjustment: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(insights.planAdjustment.title)
                .font(.rounded(.headline, weight: .bold))
            Text(insights.planAdjustment.detail)
                .font(.rounded(.subheadline))
                .foregroundColor(QuitTheme.muted)
            if store.canApplyPlanAdjustmentSuggestion {
                Button("Apply suggestion") {
                    if store.applyPlanAdjustmentSuggestion() {
                        store.selectedTab = .plan
                    }
                }
                .buttonStyle(FilledButtonStyle())
            }
            Button(insights.planAdjustment.actionTitle) {
                store.selectedTab = .plan
            }
            .buttonStyle(QuietButtonStyle())
        }
        .quietCard()
    }

    private var historyPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent history")
                .font(.rounded(.headline, weight: .bold))

            let entries = store.historyEntries().prefix(5)
            if entries.isEmpty {
                Text("Cravings, check-ins, and slips will appear here after you save them.")
                    .font(.rounded(.subheadline))
                    .foregroundColor(QuitTheme.muted)
            } else {
                ForEach(Array(entries)) { entry in
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(entry.kind.rawValue): \(entry.title)")
                            .font(.rounded(.subheadline, weight: .bold))
                        Text(entry.detail)
                            .font(.rounded(.caption))
                            .foregroundColor(QuitTheme.muted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .quietCard()
    }

    private func contributionSection(
        title: String,
        empty: String,
        triggers: [TriggerInsight]
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.rounded(.headline, weight: .bold))

            if triggers.isEmpty {
                Text(empty)
                    .font(.rounded(.subheadline))
                    .foregroundColor(QuitTheme.muted)
            } else {
                ForEach(triggers) { trigger in
                    contributionRow(trigger.name, CGFloat(trigger.share), trigger.shareSummary)
                }
            }
        }
        .quietCard()
    }

    private func metricRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.rounded(.subheadline))
                .foregroundColor(QuitTheme.muted)
            Spacer(minLength: 12)
            Text(value)
                .font(.rounded(.headline, weight: .bold))
                .foregroundColor(QuitTheme.ink)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 2)
    }

    private func contributionRow(_ label: String, _ progress: CGFloat, _ value: String) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.rounded(.caption, weight: .bold))
                .lineLimit(2)
                .minimumScaleFactor(0.82)
                .frame(width: 88, alignment: .leading)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(QuitTheme.peach.opacity(0.42))
                    Capsule()
                        .fill(QuitTheme.cocoa)
                        .frame(width: proxy.size.width * min(max(progress, 0), 1))
                }
            }
            .frame(height: 9)
            Text(value)
                .font(.rounded(.caption, weight: .bold))
                .frame(width: 38, alignment: .trailing)
        }
    }

    private func color(for level: Int) -> Color {
        switch level {
        case 0:
            return QuitTheme.faint.opacity(0.14)
        case 1:
            return QuitTheme.peach.opacity(0.36)
        case 2:
            return QuitTheme.peach.opacity(0.72)
        case 3:
            return QuitTheme.sage
        default:
            return QuitTheme.cocoa
        }
    }
}
