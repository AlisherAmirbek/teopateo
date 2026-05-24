import Foundation

struct ProgressMetric: Identifiable, Equatable {
    let id: UUID
    let label: String
    let value: String

    init(id: UUID = UUID(), label: String, value: String) {
        self.id = id
        self.label = label
        self.value = value
    }
}

enum SaveStatus: Equatable {
    case idle
    case saved(String)
    case failed(String)

    var message: String? {
        switch self {
        case .idle:
            return nil
        case .saved(let message), .failed(let message):
            return message
        }
    }

    var isFailure: Bool {
        if case .failed = self {
            return true
        }
        return false
    }
}

enum CravingOutcome: String, Codable, Equatable {
    case completedWithoutSmoking = "completed_without_smoking"
    case smokedAfterCraving = "smoked_after_craving"
    case dismissedWithoutOutcome = "dismissed_without_outcome"
}

enum SupportRole: String, Codable, Equatable {
    case cravingAlert = "craving_alert"
    case eveningCheckIn = "evening_check_in"
    case quitline = "quitline"
    case backup = "backup"

    var title: String {
        switch self {
        case .cravingAlert:
            return "Craving alert"
        case .eveningCheckIn:
            return "Evening check-in"
        case .quitline:
            return "Quitline"
        case .backup:
            return "Backup"
        }
    }
}

enum NotificationPermissionStatus: String, Equatable {
    case unknown
    case notDetermined
    case denied
    case authorized
    case provisional
    case ephemeral

    var canScheduleNotifications: Bool {
        switch self {
        case .authorized, .provisional, .ephemeral:
            return true
        case .unknown, .notDetermined, .denied:
            return false
        }
    }

    var title: String {
        switch self {
        case .unknown:
            return "Checking permission"
        case .notDetermined:
            return "Permission needed"
        case .denied:
            return "Notifications blocked"
        case .authorized, .provisional, .ephemeral:
            return "Notifications allowed"
        }
    }
}

enum NotificationKind: String, CaseIterable, Codable, Equatable {
    case morningPlan = "morning_plan"
    case riskyWindow = "risky_window"
    case postMeal = "post_meal"
    case eveningCheckIn = "evening_check_in"

    static let userVisibleCases: [NotificationKind] = [
        .morningPlan,
        .riskyWindow,
        .postMeal,
        .eveningCheckIn
    ]

    var title: String {
        switch self {
        case .morningPlan:
            return "Morning plan"
        case .riskyWindow:
            return "Risk-window warning"
        case .postMeal:
            return "Post-meal reminder"
        case .eveningCheckIn:
            return "Evening check-in"
        }
    }

    var detail: String {
        switch self {
        case .morningPlan:
            return "Review the day's target and one substitute before the first routine cue."
        case .riskyWindow:
            return "Warn before your highest-risk craving windows once history reveals them."
        case .postMeal:
            return "Prompt the after-meal replacement action before autopilot starts."
        case .eveningCheckIn:
            return "Close the day with a short check-in and recovery note if needed."
        }
    }

    var supportsFixedTime: Bool {
        self != .riskyWindow
    }
}

struct ReminderTime: Codable, Equatable {
    var hour: Int
    var minute: Int

    init(hour: Int, minute: Int) {
        self.hour = min(max(hour, 0), 23)
        self.minute = min(max(minute, 0), 59)
    }

    var minuteOfDay: Int {
        hour * 60 + minute
    }

    var displayLabel: String {
        let displayHour = hour % 12 == 0 ? 12 : hour % 12
        let suffix = hour < 12 ? "AM" : "PM"
        return String(format: "%d:%02d %@", displayHour, minute, suffix)
    }
}

struct NotificationSettings: Codable, Equatable {
    var morningPlanEnabled: Bool
    var riskyWindowEnabled: Bool
    var postMealEnabled: Bool
    var eveningCheckInEnabled: Bool
    var medicationEnabled: Bool
    var morningPlanTime: ReminderTime
    var postMealTime: ReminderTime
    var eveningCheckInTime: ReminderTime
    var medicationTime: ReminderTime
    var updatedAt: Date

    init(
        morningPlanEnabled: Bool = false,
        riskyWindowEnabled: Bool = false,
        postMealEnabled: Bool = false,
        eveningCheckInEnabled: Bool = false,
        medicationEnabled: Bool = false,
        morningPlanTime: ReminderTime = ReminderTime(hour: 8, minute: 30),
        postMealTime: ReminderTime = ReminderTime(hour: 13, minute: 30),
        eveningCheckInTime: ReminderTime = ReminderTime(hour: 20, minute: 30),
        medicationTime: ReminderTime = ReminderTime(hour: 9, minute: 0),
        updatedAt: Date = Date()
    ) {
        self.morningPlanEnabled = morningPlanEnabled
        self.riskyWindowEnabled = riskyWindowEnabled
        self.postMealEnabled = postMealEnabled
        self.eveningCheckInEnabled = eveningCheckInEnabled
        self.medicationEnabled = medicationEnabled
        self.morningPlanTime = morningPlanTime
        self.postMealTime = postMealTime
        self.eveningCheckInTime = eveningCheckInTime
        self.medicationTime = medicationTime
        self.updatedAt = updatedAt
    }

    var hasEnabledReminders: Bool {
        morningPlanEnabled ||
            riskyWindowEnabled ||
            postMealEnabled ||
            eveningCheckInEnabled
    }

    func isEnabled(_ kind: NotificationKind) -> Bool {
        switch kind {
        case .morningPlan:
            return morningPlanEnabled
        case .riskyWindow:
            return riskyWindowEnabled
        case .postMeal:
            return postMealEnabled
        case .eveningCheckIn:
            return eveningCheckInEnabled
        }
    }

    func time(for kind: NotificationKind) -> ReminderTime? {
        switch kind {
        case .morningPlan:
            return morningPlanTime
        case .postMeal:
            return postMealTime
        case .eveningCheckIn:
            return eveningCheckInTime
        case .riskyWindow:
            return nil
        }
    }

    mutating func setEnabled(_ isEnabled: Bool, for kind: NotificationKind) {
        switch kind {
        case .morningPlan:
            morningPlanEnabled = isEnabled
        case .riskyWindow:
            riskyWindowEnabled = isEnabled
        case .postMeal:
            postMealEnabled = isEnabled
        case .eveningCheckIn:
            eveningCheckInEnabled = isEnabled
        }
    }

    mutating func setTime(_ time: ReminderTime, for kind: NotificationKind) {
        switch kind {
        case .morningPlan:
            morningPlanTime = time
        case .postMeal:
            postMealTime = time
        case .eveningCheckIn:
            eveningCheckInTime = time
        case .riskyWindow:
            return
        }
    }
}

struct NotificationScheduleItem: Equatable {
    let identifier: String
    let kind: NotificationKind
    let title: String
    let body: String
    let time: ReminderTime
}

enum NotificationPlanner {
    static let identifierPrefix = "teopateo.notification."

    static var allManagedIdentifiers: [String] {
        [
            identifier(for: .morningPlan),
            identifier(for: .postMeal),
            identifier(for: .eveningCheckIn),
            identifierPrefix + "medication"
        ] + (0..<24).map { riskyWindowIdentifier(startHour: $0) }
    }

    static func scheduleItems(
        settings: NotificationSettings,
        quitPlan: QuitPlan,
        riskWindows: [RiskWindowInsight],
        topTriggers: [TriggerInsight]
    ) -> [NotificationScheduleItem] {
        var items: [NotificationScheduleItem] = []

        if settings.morningPlanEnabled {
            items.append(
                NotificationScheduleItem(
                    identifier: identifier(for: .morningPlan),
                    kind: .morningPlan,
                    title: "Review today's quit plan",
                    body: "Choose the first trigger you will protect and keep one 10-minute substitute ready.",
                    time: settings.morningPlanTime
                )
            )
        }

        if settings.riskyWindowEnabled {
            items.append(contentsOf: riskWindowItems(
                quitPlan: quitPlan,
                riskWindows: riskWindows,
                topTriggers: topTriggers
            ))
        }

        if settings.postMealEnabled {
            items.append(
                NotificationScheduleItem(
                    identifier: identifier(for: .postMeal),
                    kind: .postMeal,
                    title: "Protect the after-meal window",
                    body: "Start the replacement action before smoking becomes automatic.",
                    time: settings.postMealTime
                )
            )
        }

        if settings.eveningCheckInEnabled {
            items.append(
                NotificationScheduleItem(
                    identifier: identifier(for: .eveningCheckIn),
                    kind: .eveningCheckIn,
                    title: "Check in without judgment",
                    body: "Record what happened today and reset for tomorrow.",
                    time: settings.eveningCheckInTime
                )
            )
        }

        return items.sorted {
            if $0.time.minuteOfDay != $1.time.minuteOfDay {
                return $0.time.minuteOfDay < $1.time.minuteOfDay
            }
            return $0.identifier < $1.identifier
        }
    }

    private static func riskWindowItems(
        quitPlan: QuitPlan,
        riskWindows: [RiskWindowInsight],
        topTriggers: [TriggerInsight]
    ) -> [NotificationScheduleItem] {
        let topTrigger = topTriggers.first?.name
        let action = topTrigger.flatMap { matchingRule(for: $0, in: quitPlan.triggerRules)?.action }
        let actionText = action.map { " Start with: \($0)" } ?? " Keep your 10-minute rescue ready."

        return riskWindows.prefix(3).map { window in
            NotificationScheduleItem(
                identifier: riskyWindowIdentifier(startHour: window.startHour),
                kind: .riskyWindow,
                title: "Risk window coming up",
                body: "\(window.startLabel) has shown up in your craving history.\(actionText)",
                time: warningTime(beforeStartHour: window.startHour)
            )
        }
    }

    private static func warningTime(beforeStartHour startHour: Int) -> ReminderTime {
        ReminderTime(hour: (startHour + 23) % 24, minute: 30)
    }

    private static func matchingRule(
        for trigger: String,
        in triggerRules: [TriggerRule]
    ) -> TriggerRule? {
        let triggerText = trigger.lowercased()
        return triggerRules.first { rule in
            guard rule.isEnabled else { return false }
            let ruleText = rule.trigger.lowercased()
            return ruleText.contains(triggerText) || triggerText.contains(ruleText)
        }
    }

    private static func identifier(for kind: NotificationKind) -> String {
        identifierPrefix + kind.rawValue
    }

    private static func riskyWindowIdentifier(startHour: Int) -> String {
        identifierPrefix + "risky_window_\(startHour)"
    }
}

enum ReplacementActivityCategory: String, Codable, CaseIterable, Equatable {
    case movement
    case breathing
    case sensory
    case support
    case journaling
    case distraction

    var title: String {
        switch self {
        case .movement:
            return "Movement"
        case .breathing:
            return "Breathing"
        case .sensory:
            return "Sensory"
        case .support:
            return "Support"
        case .journaling:
            return "Journaling"
        case .distraction:
            return "Distraction"
        }
    }
}

enum QuitTriggerCatalog {
    static let onboardingTriggers = [
        "Coffee",
        "After meals",
        "Work stress",
        "Driving or commute",
        "Alcohol",
        "Boredom",
        "Social smoking",
        "Morning routine",
        "Evening wind-down"
    ]
}

enum RiskLevel: String, Equatable {
    case low = "Low"
    case moderate = "Moderate"
    case high = "High"
}

struct RiskLevelInsight: Equatable {
    let level: RiskLevel
    let summary: String
    let actionTitle: String
}

struct ProgressSummary: Equatable {
    let smokeFreeDays: Int
    let cigarettesAvoided: Int
    let moneySaved: Double
    let cravingsHandled: Int
    let milestones: [String]
}

struct CalculatedInsights: Equatable {
    let smokeFreeDays: Int
    let smokeFreeSummary: String
    let cravingsLogged: Int
    let cravingsHandled: Int
    let slippedCravings: Int
    let cigarettesAvoided: Int
    let moneySaved: Double
    let moneySavedSummary: String
    let riskWindows: [RiskWindowInsight]
    let topTriggers: [TriggerInsight]
    let topSlipTriggers: [TriggerInsight]
    let heatMapDays: [CravingHeatDay]
    let planAdjustment: PlanAdjustmentInsight
    let todayRisk: RiskLevelInsight
    let dataConfidenceSummary: String

    var nextRiskSummary: String {
        riskWindows.first?.startLabel ?? "Log cravings"
    }
}

struct RiskWindowInsight: Identifiable, Equatable {
    let startHour: Int
    let cravingCount: Int
    let share: Double

    var id: Int { startHour }

    var title: String {
        "\(Self.hourLabel(startHour))-\(Self.hourLabel((startHour + 1) % 24))"
    }

    var startLabel: String {
        Self.hourLabel(startHour)
    }

    var shareSummary: String {
        Self.percentLabel(share)
    }

    private static func hourLabel(_ hour: Int) -> String {
        let normalizedHour = (hour + 24) % 24
        let displayHour = normalizedHour % 12 == 0 ? 12 : normalizedHour % 12
        let suffix = normalizedHour < 12 ? "AM" : "PM"
        return "\(displayHour):00 \(suffix)"
    }

    private static func percentLabel(_ share: Double) -> String {
        "\(Int((share * 100).rounded()))%"
    }
}

struct TriggerInsight: Identifiable, Equatable {
    let name: String
    let count: Int
    let share: Double

    var id: String { name }

    var shareSummary: String {
        "\(Int((share * 100).rounded()))%"
    }
}

struct CravingHeatDay: Identifiable, Equatable {
    let date: Date
    let count: Int
    let level: Int

    var id: Date { date }
}

struct PlanAdjustmentInsight: Equatable {
    let title: String
    let detail: String
    let actionTitle: String
}

struct WeeklyRecap: Equatable {
    let weekStart: Date
    let weekEnd: Date
    let cravingsLogged: Int
    let cravingsHandled: Int
    let smokeFreeCheckInDays: Int
    let topTrigger: String?
    let planAdjustment: PlanAdjustmentInsight
}

struct TaperScheduleDay: Identifiable, Equatable {
    let date: Date
    let targetCigarettes: Double
    let isToday: Bool

    var id: Date { date }
}

struct TriggerRule: Identifiable, Codable, Equatable {
    let id: UUID
    var trigger: String
    var action: String
    var isEnabled: Bool
    var supportContactID: UUID?

    init(
        id: UUID = UUID(),
        trigger: String,
        action: String,
        isEnabled: Bool = true,
        supportContactID: UUID? = nil
    ) {
        self.id = id
        self.trigger = trigger
        self.action = action
        self.isEnabled = isEnabled
        self.supportContactID = supportContactID
    }
}

struct CoachMessage: Identifiable, Codable, Equatable {
    let id: UUID
    var text: String
    let isUser: Bool
    let createdAt: Date

    init(id: UUID = UUID(), text: String, isUser: Bool, createdAt: Date = Date()) {
        self.id = id
        self.text = text
        self.isUser = isUser
        self.createdAt = createdAt
    }
}

struct CoachChat: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var messages: [CoachMessage]
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        messages: [CoachMessage] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.messages = messages
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "New chat" : trimmed
    }
}

struct QuitPlan: Identifiable, Codable, Equatable {
    let id: UUID
    var quitDate: Date
    var quitMode: String
    var triggerRules: [TriggerRule]
    var medicationNote: String
    var baselineCigarettesPerDay: Double
    var costPerPack: Double
    var cigarettesPerPack: Int
    var taperTargetCigarettesPerDay: Double
    var taperReductionStep: Double
    var taperReductionIntervalDays: Int
    var attemptStartedAt: Date
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        quitDate: Date,
        quitMode: String,
        triggerRules: [TriggerRule],
        medicationNote: String,
        baselineCigarettesPerDay: Double = 10,
        costPerPack: Double = 10,
        cigarettesPerPack: Int = 20,
        taperTargetCigarettesPerDay: Double = 0,
        taperReductionStep: Double = 2,
        taperReductionIntervalDays: Int = 3,
        attemptStartedAt: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.quitDate = quitDate
        self.quitMode = quitMode
        self.triggerRules = triggerRules
        self.medicationNote = medicationNote
        self.baselineCigarettesPerDay = baselineCigarettesPerDay
        self.costPerPack = costPerPack
        self.cigarettesPerPack = cigarettesPerPack
        self.taperTargetCigarettesPerDay = taperTargetCigarettesPerDay
        self.taperReductionStep = taperReductionStep
        self.taperReductionIntervalDays = taperReductionIntervalDays
        self.attemptStartedAt = attemptStartedAt ?? quitDate
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var costPerCigarette: Double {
        guard cigarettesPerPack > 0 else {
            return 0
        }
        return costPerPack / Double(cigarettesPerPack)
    }
}

struct DailyCheckIn: Identifiable, Codable, Equatable {
    let id: UUID
    let date: Date
    let mood: Double
    let stress: Double
    let confidence: Double
    let smokedToday: Bool?
    let cigarettesSmoked: Int
    let taperTargetCigarettes: Double?
    let stayedWithinTaperTarget: Bool?
    let slipNote: String
    let createdAt: Date
    let updatedAt: Date

    init(
        id: UUID = UUID(),
        date: Date,
        mood: Double,
        stress: Double,
        confidence: Double,
        smokedToday: Bool?,
        cigarettesSmoked: Int = 0,
        taperTargetCigarettes: Double? = nil,
        stayedWithinTaperTarget: Bool? = nil,
        slipNote: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.date = date
        self.mood = mood
        self.stress = stress
        self.confidence = confidence
        self.smokedToday = smokedToday
        self.cigarettesSmoked = cigarettesSmoked
        self.taperTargetCigarettes = taperTargetCigarettes
        self.stayedWithinTaperTarget = stayedWithinTaperTarget
        self.slipNote = slipNote
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct CravingEvent: Identifiable, Codable, Equatable {
    let id: UUID
    let startedAt: Date
    let completedAt: Date?
    let durationSeconds: Int
    let selectedTriggers: [String]
    let outcome: CravingOutcome
    let initialIntensity: Double?
    let finalIntensity: Double?
    let helpedActivityID: UUID?
    let supportContactID: UUID?
    let reflectionNote: String
    let dismissedAt: Date?
    let createdAt: Date
    let updatedAt: Date

    var completedWithoutSmoking: Bool {
        outcome == .completedWithoutSmoking
    }

    init(
        id: UUID = UUID(),
        startedAt: Date,
        completedAt: Date?,
        durationSeconds: Int,
        selectedTriggers: [String],
        completedWithoutSmoking: Bool,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.init(
            id: id,
            startedAt: startedAt,
            completedAt: completedAt,
            durationSeconds: durationSeconds,
            selectedTriggers: selectedTriggers,
            outcome: completedWithoutSmoking ? .completedWithoutSmoking : .smokedAfterCraving,
            initialIntensity: nil,
            finalIntensity: nil,
            helpedActivityID: nil,
            supportContactID: nil,
            reflectionNote: "",
            dismissedAt: nil,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    init(
        id: UUID = UUID(),
        startedAt: Date,
        completedAt: Date?,
        durationSeconds: Int,
        selectedTriggers: [String],
        outcome: CravingOutcome,
        initialIntensity: Double? = nil,
        finalIntensity: Double? = nil,
        helpedActivityID: UUID? = nil,
        supportContactID: UUID? = nil,
        reflectionNote: String = "",
        dismissedAt: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.durationSeconds = durationSeconds
        self.selectedTriggers = selectedTriggers
        self.outcome = outcome
        self.initialIntensity = initialIntensity
        self.finalIntensity = finalIntensity
        self.helpedActivityID = helpedActivityID
        self.supportContactID = supportContactID
        self.reflectionNote = reflectionNote
        self.dismissedAt = dismissedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct SlipEvent: Identifiable, Codable, Equatable {
    let id: UUID
    let occurredAt: Date
    let cigarettesSmoked: Int
    let selectedTriggers: [String]
    let mood: Double?
    let stress: Double?
    let context: String
    let note: String
    let recoveryAction: String
    let createdAt: Date
    let updatedAt: Date

    init(
        id: UUID = UUID(),
        occurredAt: Date,
        cigarettesSmoked: Int,
        selectedTriggers: [String],
        mood: Double? = nil,
        stress: Double? = nil,
        context: String = "",
        note: String,
        recoveryAction: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.occurredAt = occurredAt
        self.cigarettesSmoked = cigarettesSmoked
        self.selectedTriggers = selectedTriggers
        self.mood = mood
        self.stress = stress
        self.context = context
        self.note = note
        self.recoveryAction = recoveryAction
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct ReplacementActivity: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var instruction: String
    var category: ReplacementActivityCategory
    var durationSeconds: Int
    var linkedTrigger: String
    var isEnabled: Bool
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        instruction: String,
        category: ReplacementActivityCategory,
        durationSeconds: Int = 600,
        linkedTrigger: String = "",
        isEnabled: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.instruction = instruction
        self.category = category
        self.durationSeconds = durationSeconds
        self.linkedTrigger = linkedTrigger
        self.isEnabled = isEnabled
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct RiskySituation: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var expectedContext: String
    var preventionPlan: String
    var backupAction: String
    var isEnabled: Bool
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        expectedContext: String,
        preventionPlan: String,
        backupAction: String,
        isEnabled: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.expectedContext = expectedContext
        self.preventionPlan = preventionPlan
        self.backupAction = backupAction
        self.isEnabled = isEnabled
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct SupportContact: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var detail: String
    var phoneNumber: String
    var preferredRole: SupportRole
    var defaultMessage: String
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        detail: String,
        phoneNumber: String = "",
        preferredRole: SupportRole = .cravingAlert,
        defaultMessage: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.detail = detail
        self.phoneNumber = phoneNumber
        self.preferredRole = preferredRole
        self.defaultMessage = defaultMessage
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct UserReason: Identifiable, Codable, Equatable {
    let id: UUID
    var text: String
    var sortOrder: Int
    var isPrimary: Bool
    var category: String
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        text: String,
        sortOrder: Int = 0,
        isPrimary: Bool = false,
        category: String = "personal",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.text = text
        self.sortOrder = sortOrder
        self.isPrimary = isPrimary
        self.category = category
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct AppSettings: Codable, Equatable {
    var onboardingCompleted: Bool
    var updatedAt: Date

    init(
        onboardingCompleted: Bool = false,
        updatedAt: Date = Date()
    ) {
        self.onboardingCompleted = onboardingCompleted
        self.updatedAt = updatedAt
    }
}

struct OnboardingPlanInput: Equatable {
    var cigarettesPerDay: Double
    var costPerPack: Double
    var quitDate: Date
    var quitMode: String
    var selectedTriggers: [String]
    var primaryReason: String

    init(
        cigarettesPerDay: Double,
        costPerPack: Double,
        quitDate: Date,
        quitMode: String,
        selectedTriggers: [String],
        primaryReason: String
    ) {
        self.cigarettesPerDay = cigarettesPerDay
        self.costPerPack = costPerPack
        self.quitDate = quitDate
        self.quitMode = quitMode
        self.selectedTriggers = selectedTriggers
        self.primaryReason = primaryReason
    }
}

struct HistoryEntry: Identifiable, Equatable {
    enum Kind: String, Equatable {
        case craving = "Craving"
        case checkIn = "Check-in"
        case slip = "Slip"
    }

    let id: UUID
    let kind: Kind
    let date: Date
    let title: String
    let detail: String
}

struct HistoryDayGroup: Identifiable, Equatable {
    let day: Date
    let entries: [HistoryEntry]

    var id: Date { day }
}

struct PersistedTeoPateoSnapshot: Equatable {
    var appSettings: AppSettings?
    var notificationSettings: NotificationSettings?
    var quitPlan: QuitPlan?
    var dailyCheckIns: [DailyCheckIn]
    var cravingEvents: [CravingEvent]
    var slipEvents: [SlipEvent]
    var replacementActivities: [ReplacementActivity]
    var riskySituations: [RiskySituation]
    var supportContacts: [SupportContact]
    var userReasons: [UserReason]
    var coachChats: [CoachChat]
    var selectedCoachChatID: UUID?

    init(
        appSettings: AppSettings? = nil,
        notificationSettings: NotificationSettings? = nil,
        quitPlan: QuitPlan? = nil,
        dailyCheckIns: [DailyCheckIn] = [],
        cravingEvents: [CravingEvent] = [],
        slipEvents: [SlipEvent] = [],
        replacementActivities: [ReplacementActivity] = [],
        riskySituations: [RiskySituation] = [],
        supportContacts: [SupportContact] = [],
        userReasons: [UserReason] = [],
        coachChats: [CoachChat] = [],
        selectedCoachChatID: UUID? = nil
    ) {
        self.appSettings = appSettings
        self.notificationSettings = notificationSettings
        self.quitPlan = quitPlan
        self.dailyCheckIns = dailyCheckIns
        self.cravingEvents = cravingEvents
        self.slipEvents = slipEvents
        self.replacementActivities = replacementActivities
        self.riskySituations = riskySituations
        self.supportContacts = supportContacts
        self.userReasons = userReasons
        self.coachChats = coachChats
        self.selectedCoachChatID = selectedCoachChatID
    }
}
