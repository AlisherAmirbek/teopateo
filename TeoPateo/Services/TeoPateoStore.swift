import Foundation

final class TeoPateoStore: ObservableObject {
    @Published var selectedTab: AppTab = .today
    @Published var isCravingModePresented = false
    @Published var quitMode = "Taper"
    @Published var mood = 6.0
    @Published var stress = 7.0
    @Published var confidence = 5.0
    @Published var smokedToday: Bool?
    @Published var selectedTriggers: Set<String> = ["Coffee", "Work stress"]
    @Published var coachMessages: [CoachMessage] = [
        CoachMessage(
            text: "After work is your highest-risk pattern. Want to plan the first 10 minutes after you leave?",
            isUser: false
        )
    ]

    let metrics = [
        ProgressMetric(label: "Smoke-free", value: "4 days"),
        ProgressMetric(label: "Cravings handled", value: "18"),
        ProgressMetric(label: "Saved", value: "$42")
    ]

    let triggerRules = [
        TriggerRule(trigger: "After coffee", action: "Drink water first, wait 10 minutes, log the urge."),
        TriggerRule(trigger: "Leaving work", action: "Walk one block before checking messages."),
        TriggerRule(trigger: "Alcohol", action: "Text support before the first drink."),
        TriggerRule(trigger: "After meals", action: "Brush teeth or chew gum immediately.")
    ]

    func sendCoachMessage(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        coachMessages.append(CoachMessage(text: trimmed, isUser: true))
        coachMessages.append(
            CoachMessage(
                text: "Name the trigger, choose one 10-minute substitute, then decide who gets the alert if the urge spikes.",
                isUser: false
            )
        )
    }
}

enum AppTab: String, CaseIterable {
    case today = "Today"
    case plan = "Plan"
    case checkIn = "Check-in"
    case insights = "Insights"
    case coach = "Coach"
}
