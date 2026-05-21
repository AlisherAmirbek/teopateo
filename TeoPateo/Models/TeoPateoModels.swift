import Foundation

struct ProgressMetric: Identifiable {
    let id = UUID()
    let label: String
    let value: String
}

struct TriggerRule: Identifiable {
    let id = UUID()
    let trigger: String
    let action: String
    var isEnabled: Bool = true
}

struct CoachMessage: Identifiable {
    let id = UUID()
    let text: String
    let isUser: Bool
}
