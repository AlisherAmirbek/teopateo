import SwiftUI

struct InsightsView: View {
    @EnvironmentObject private var store: TeoPateoStore

    private var insights: CalculatedInsights {
        store.calculatedInsights
    }

    var body: some View {
        RootScreen {
            ScreenHeader(eyebrow: "Pattern insights", title: "Your risk is predictable.")

            progressSummary
            riskWindows
            triggerContribution
            heatMap
            planAdjustment
        }
    }

    private var progressSummary: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Progress from history")
                .font(.rounded(.headline, weight: .bold))

            metricRow("Smoke-free streak", insights.smokeFreeSummary)
            metricRow("Cravings handled", "\(insights.cravingsHandled) of \(insights.cravingsLogged)")
            metricRow("Cigarettes avoided", "\(insights.cigarettesAvoided)")
            metricRow("Estimated saved", insights.moneySavedSummary)
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
        VStack(alignment: .leading, spacing: 14) {
            Text("Trigger contribution")
                .font(.rounded(.headline, weight: .bold))

            if insights.topTriggers.isEmpty {
                Text("Select triggers when you finish a craving rescue. Trigger percentages will appear after the first logged craving.")
                    .font(.rounded(.subheadline))
                    .foregroundColor(QuitTheme.muted)
            } else {
                ForEach(insights.topTriggers) { trigger in
                    contributionRow(trigger.name, CGFloat(trigger.share), trigger.shareSummary)
                }
            }
        }
        .quietCard()
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
            Button(insights.planAdjustment.actionTitle) {
                store.selectedTab = .plan
            }
                .buttonStyle(QuietButtonStyle())
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
