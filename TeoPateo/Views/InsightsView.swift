import SwiftUI

struct InsightsView: View {
    private let heatLevels = [1, 1, 2, 2, 1, 2, 3, 1, 2, 2, 3, 4, 3, 2, 1, 1, 2, 4, 4, 3, 2, 1, 2, 3, 4, 3, 2, 1]

    var body: some View {
        RootScreen {
            ScreenHeader(eyebrow: "Pattern insights", title: "Your risk is predictable.")

            topPattern
            triggerContribution
            heatMap
            planAdjustment
        }
    }

    private var topPattern: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Top pattern")
                .font(.rounded(.headline, weight: .bold))
            Text("Your highest-risk window is 9:00-10:30 PM. It accounts for 38% of logged cravings.")
                .font(.rounded(.subheadline))
                .foregroundColor(QuitTheme.muted)
        }
        .quietCard()
    }

    private var triggerContribution: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Trigger contribution")
                .font(.rounded(.headline, weight: .bold))
            contributionRow("Coffee", 0.42, "42%")
            contributionRow("Stress", 0.36, "36%")
            contributionRow("Meals", 0.24, "24%")
            contributionRow("Social", 0.18, "18%")
        }
        .quietCard()
    }

    private var heatMap: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Craving heat")
                .font(.rounded(.headline, weight: .bold))
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                ForEach(Array(heatLevels.enumerated()), id: \.offset) { _, level in
                    RoundedRectangle(cornerRadius: 5)
                        .fill(color(for: level))
                        .frame(height: 34)
                }
            }
        }
        .quietCard()
    }

    private var planAdjustment: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Plan adjustment")
                .font(.rounded(.headline, weight: .bold))
            Text("Add a leaving-work rule: walk one block before entering a store or opening delivery apps.")
                .font(.rounded(.subheadline))
                .foregroundColor(QuitTheme.muted)
            Button("Add to plan") {}
                .buttonStyle(QuietButtonStyle())
        }
        .quietCard()
    }

    private func contributionRow(_ label: String, _ progress: CGFloat, _ value: String) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.rounded(.caption, weight: .bold))
                .frame(width: 54, alignment: .leading)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(QuitTheme.peach.opacity(0.42))
                    Capsule()
                        .fill(QuitTheme.cocoa)
                        .frame(width: proxy.size.width * progress)
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
