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

    func addingMinutes(_ minutes: Int) -> ReminderTime {
        let minutesPerDay = 24 * 60
        let normalized = (minuteOfDay + minutes) % minutesPerDay
        let wrapped = normalized < 0 ? normalized + minutesPerDay : normalized
        return ReminderTime(hour: wrapped / 60, minute: wrapped % 60)
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
        ReminderTime(hour: startHour, minute: 0).addingMinutes(-30)
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

    static let userVisibleCases: [ReplacementActivityCategory] = [
        .movement,
        .breathing,
        .sensory,
        .journaling,
        .distraction
    ]

    var title: String {
        switch self {
        case .movement:
            return "Movement"
        case .breathing:
            return "Breathing"
        case .sensory:
            return "Sensory"
        case .support:
            return "Distraction"
        case .journaling:
            return "Journaling"
        case .distraction:
            return "Distraction"
        }
    }
}

enum QuitTriggerCatalog {
    static let commonSmokingTimes = [
        "Morning",
        "After coffee",
        "After meals",
        "Work breaks",
        "Driving",
        "Evening",
        "Before bed"
    ]

    static let emotionalTriggers = [
        "Stress",
        "Anger",
        "Anxiety",
        "Loneliness",
        "Boredom",
        "Celebration"
    ]

    static let situationalTriggers = [
        "Alcohol",
        "Friends who smoke",
        "Work pressure",
        "Being outside",
        "Phone scrolling",
        "Waiting"
    ]

    static var onboardingTriggers: [String] {
        (commonSmokingTimes + emotionalTriggers + situationalTriggers).uniqued()
    }
}

enum QuitStatus: String, Codable, CaseIterable, Equatable, Identifiable {
    case alreadyQuit = "already_quit"
    case readyToQuit = "ready_to_quit"
    case cuttingDown = "cutting_down"
    case thinkingAboutIt = "thinking_about_it"
    case unsure

    var id: String { rawValue }

    var title: String {
        switch self {
        case .alreadyQuit:
            return "Already quit"
        case .readyToQuit:
            return "Ready to quit"
        case .cuttingDown:
            return "Cutting down"
        case .thinkingAboutIt:
            return "Thinking about it"
        case .unsure:
            return "Unsure"
        }
    }

    var readinessStage: String {
        switch self {
        case .alreadyQuit:
            return "Relapse prevention"
        case .readyToQuit:
            return "Quit-date preparation"
        case .cuttingDown:
            return "Taper planning"
        case .thinkingAboutIt:
            return "Motivation and preparation"
        case .unsure:
            return "Awareness and motivation"
        }
    }

    var defaultDailyFocus: String {
        switch self {
        case .alreadyQuit:
            return "Protect the riskiest craving window before it starts."
        case .readyToQuit:
            return "Rehearse the 10-minute rescue before the quit date."
        case .cuttingDown:
            return "Protect one cigarette you can delay today."
        case .thinkingAboutIt:
            return "Notice one cue and try one replacement without pressure."
        case .unsure:
            return "Track one smoking moment and what it was trying to solve."
        }
    }
}

enum FirstCigaretteTiming: String, Codable, CaseIterable, Equatable, Identifiable {
    case withinFiveMinutes = "within_5_minutes"
    case withinThirtyMinutes = "within_30_minutes"
    case laterMorning = "later_morning"
    case afternoonOrEvening = "afternoon_or_evening"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .withinFiveMinutes:
            return "Within 5 minutes"
        case .withinThirtyMinutes:
            return "Within 30 minutes"
        case .laterMorning:
            return "Later in the morning"
        case .afternoonOrEvening:
            return "Afternoon or evening"
        }
    }
}

enum PreviousQuitAttemptCount: String, Codable, CaseIterable, Equatable, Identifiable {
    case none
    case one
    case twoToThree = "two_to_three"
    case fourOrMore = "four_or_more"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none:
            return "None"
        case .one:
            return "1"
        case .twoToThree:
            return "2-3"
        case .fourOrMore:
            return "4 or more"
        }
    }
}

enum LongestQuitAttempt: String, Codable, CaseIterable, Equatable, Identifiable {
    case lessThanDay = "less_than_day"
    case fewDays = "few_days"
    case fewWeeks = "few_weeks"
    case fewMonths = "few_months"
    case yearOrMore = "year_or_more"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .lessThanDay:
            return "Less than a day"
        case .fewDays:
            return "A few days"
        case .fewWeeks:
            return "A few weeks"
        case .fewMonths:
            return "A few months"
        case .yearOrMore:
            return "A year or more"
        }
    }
}

enum SmokingChallenge: String, Codable, CaseIterable, Equatable, Identifiable {
    case cravings
    case stress
    case habitRoutine = "habit_routine"
    case alcohol
    case socialPressure = "social_pressure"
    case boredom
    case withdrawal
    case weightGain = "weight_gain"
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cravings:
            return "Cravings"
        case .stress:
            return "Stress"
        case .habitRoutine:
            return "Habit or routine"
        case .alcohol:
            return "Alcohol"
        case .socialPressure:
            return "Social pressure"
        case .boredom:
            return "Boredom"
        case .withdrawal:
            return "Withdrawal"
        case .weightGain:
            return "Weight gain"
        case .other:
            return "Other"
        }
    }

    var triggerLabel: String {
        switch self {
        case .habitRoutine:
            return "Routine"
        case .socialPressure:
            return "Social pressure"
        case .weightGain:
            return "Weight concern"
        default:
            return title
        }
    }
}

enum QuitDatePreference: String, Codable, CaseIterable, Equatable, Identifiable {
    case chooseDate = "choose_date"
    case alreadyQuit = "already_quit"
    case helpMeChoose = "help_me_choose"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .chooseDate:
            return "Choose date"
        case .alreadyQuit:
            return "Already quit"
        case .helpMeChoose:
            return "Help me choose"
        }
    }
}

enum QuitApproachPreference: String, Codable, CaseIterable, Equatable, Identifiable {
    case taper
    case coldTurkey = "cold_turkey"
    case notSure = "not_sure"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .taper:
            return "Taper"
        case .coldTurkey:
            return "Cold turkey"
        case .notSure:
            return "Not sure"
        }
    }
}

struct UserProfile: Codable, Equatable {
    var nickname: String
    var age: Int
    let createdAt: Date
    var updatedAt: Date

    init(
        nickname: String,
        age: Int,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.nickname = nickname
        self.age = age
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct QuitReadiness: Codable, Equatable {
    var status: QuitStatus
    var confidence: Double
    var openedAppReason: String
    let createdAt: Date
    var updatedAt: Date

    init(
        status: QuitStatus,
        confidence: Double,
        openedAppReason: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.status = status
        self.confidence = confidence
        self.openedAppReason = openedAppReason
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct SmokingBackground: Codable, Equatable {
    var ageStartedSmoking: Int?
    var yearsSmoking: Int?
    var firstCigaretteTiming: FirstCigaretteTiming
    var previousQuitAttemptCount: PreviousQuitAttemptCount
    var longestQuitAttempt: LongestQuitAttempt
    var mainChallenge: SmokingChallenge
    let createdAt: Date
    var updatedAt: Date

    init(
        ageStartedSmoking: Int? = nil,
        yearsSmoking: Int? = nil,
        firstCigaretteTiming: FirstCigaretteTiming,
        previousQuitAttemptCount: PreviousQuitAttemptCount,
        longestQuitAttempt: LongestQuitAttempt,
        mainChallenge: SmokingChallenge,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.ageStartedSmoking = ageStartedSmoking
        self.yearsSmoking = yearsSmoking
        self.firstCigaretteTiming = firstCigaretteTiming
        self.previousQuitAttemptCount = previousQuitAttemptCount
        self.longestQuitAttempt = longestQuitAttempt
        self.mainChallenge = mainChallenge
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct SavingsGoal: Codable, Equatable {
    var title: String
    var customText: String
    let createdAt: Date
    var updatedAt: Date

    init(
        title: String,
        customText: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.title = title
        self.customText = customText
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var displayTitle: String {
        let custom = customText.trimmingCharacters(in: .whitespacesAndNewlines)
        if title == "Custom", !custom.isEmpty {
            return custom
        }
        return title
    }
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

enum QuitStrategyType: String, Codable, Equatable {
    case taper
    case coldTurkey = "cold_turkey"
    case relapsePrevention = "relapse_prevention"
    case preparation
    case awareness

    var title: String {
        switch self {
        case .taper:
            return "Taper"
        case .coldTurkey:
            return "Cold turkey"
        case .relapsePrevention:
            return "Relapse prevention"
        case .preparation:
            return "Preparation"
        case .awareness:
            return "Awareness"
        }
    }
}

struct PlanSummary: Codable, Equatable {
    var title: String
    var summary: String
    var planStartDate: Date
    var quitDate: Date
    var quitStatus: QuitStatus
    var readinessStage: String
    var mainReason: String
    var confidenceLevel: Double

    init(
        title: String = "Your quit plan",
        summary: String = "",
        planStartDate: Date = Date(),
        quitDate: Date = Date(),
        quitStatus: QuitStatus = .readyToQuit,
        readinessStage: String = QuitStatus.readyToQuit.readinessStage,
        mainReason: String = "",
        confidenceLevel: Double = 5
    ) {
        self.title = title
        self.summary = summary
        self.planStartDate = planStartDate
        self.quitDate = quitDate
        self.quitStatus = quitStatus
        self.readinessStage = readinessStage
        self.mainReason = mainReason
        self.confidenceLevel = confidenceLevel
    }
}

struct DailyTaperTarget: Identifiable, Codable, Equatable {
    var dayIndex: Int
    var maximumCigarettes: Double

    var id: Int { dayIndex }
}

struct QuitStrategyPlan: Codable, Equatable {
    var strategyType: QuitStrategyType
    var rationale: String
    var quitDate: Date
    var taperTarget: Double
    var taperStep: Double
    var taperIntervalDays: Int
    var firstCigaretteDelayGoal: String
    var protectedCigarettes: [String]
    var nextSevenDayTargets: [DailyTaperTarget]

    init(
        strategyType: QuitStrategyType = .taper,
        rationale: String = "",
        quitDate: Date = Date(),
        taperTarget: Double = 0,
        taperStep: Double = 0,
        taperIntervalDays: Int = 3,
        firstCigaretteDelayGoal: String = "",
        protectedCigarettes: [String] = [],
        nextSevenDayTargets: [DailyTaperTarget] = []
    ) {
        self.strategyType = strategyType
        self.rationale = rationale
        self.quitDate = quitDate
        self.taperTarget = taperTarget
        self.taperStep = taperStep
        self.taperIntervalDays = taperIntervalDays
        self.firstCigaretteDelayGoal = firstCigaretteDelayGoal
        self.protectedCigarettes = protectedCigarettes
        self.nextSevenDayTargets = nextSevenDayTargets
    }
}

struct GeneratedTriggerRule: Identifiable, Codable, Equatable {
    var id: UUID
    var trigger: String
    var warningSign: String
    var replacementAction: String
    var backupAction: String
    var cravingModePrompt: String
    var reminderHint: String?
    var priority: Int

    init(
        id: UUID = UUID(),
        trigger: String,
        warningSign: String,
        replacementAction: String,
        backupAction: String,
        cravingModePrompt: String,
        reminderHint: String? = nil,
        priority: Int
    ) {
        self.id = id
        self.trigger = trigger
        self.warningSign = warningSign
        self.replacementAction = replacementAction
        self.backupAction = backupAction
        self.cravingModePrompt = cravingModePrompt
        self.reminderHint = reminderHint
        self.priority = priority
    }
}

struct CravingRescuePlan: Codable, Equatable {
    var primaryScript: String
    var primaryReasonID: UUID?
    var prioritizedActivityIDs: [UUID]
    var backupAction: String
    var supportFallback: String
    var slipRecoveryPrompt: String

    init(
        primaryScript: String = "Start the 10-minute rescue before deciding.",
        primaryReasonID: UUID? = nil,
        prioritizedActivityIDs: [UUID] = [],
        backupAction: String = "If the urge is still high, change location and keep the timer running.",
        supportFallback: String = "If this feels too big to handle alone, contact a trusted person or 1-800-QUIT-NOW.",
        slipRecoveryPrompt: String = "If you smoke, log the trigger and return to the next planned pause."
    ) {
        self.primaryScript = primaryScript
        self.primaryReasonID = primaryReasonID
        self.prioritizedActivityIDs = prioritizedActivityIDs
        self.backupAction = backupAction
        self.supportFallback = supportFallback
        self.slipRecoveryPrompt = slipRecoveryPrompt
    }
}

struct SlipRecoveryPlan: Codable, Equatable {
    var message: String
    var reflectionQuestions: [String]
    var defaultRecoveryAction: String
    var preserveQuitAttemptByDefault: Bool
    var suggestedSupportAction: String

    init(
        message: String = "No reset needed. Treat this as plan data and make the next choice small.",
        reflectionQuestions: [String] = [
            "What trigger showed up?",
            "What happened right before smoking?",
            "What is the next protected moment?"
        ],
        defaultRecoveryAction: String = "Pause before the next cigarette and use one replacement activity.",
        preserveQuitAttemptByDefault: Bool = true,
        suggestedSupportAction: String = "Use the coach or a quitline if the same trigger keeps repeating."
    ) {
        self.message = message
        self.reflectionQuestions = reflectionQuestions
        self.defaultRecoveryAction = defaultRecoveryAction
        self.preserveQuitAttemptByDefault = preserveQuitAttemptByDefault
        self.suggestedSupportAction = suggestedSupportAction
    }
}

struct DailyFocusPlan: Identifiable, Codable, Equatable {
    var dayIndex: Int
    var title: String
    var action: String
    var relatedTrigger: String?
    var isUserEdited: Bool

    var id: Int { dayIndex }

    init(
        dayIndex: Int,
        title: String,
        action: String,
        relatedTrigger: String? = nil,
        isUserEdited: Bool = false
    ) {
        self.dayIndex = dayIndex
        self.title = title
        self.action = action
        self.relatedTrigger = relatedTrigger
        self.isUserEdited = isUserEdited
    }
}

struct SavingsPlan: Codable, Equatable {
    var costPerPack: Double
    var cigarettesPerPack: Int
    var savingsGoal: String
    var weeklySavingsBaseline: Double
    var cigarettesAvoidedBaseline: Double
    var firstMilestoneAmount: Double
    var savingsGoalMessage: String
    var dashboardMessage: String

    init(
        costPerPack: Double = 0,
        cigarettesPerPack: Int = 20,
        savingsGoal: String = "",
        weeklySavingsBaseline: Double = 0,
        cigarettesAvoidedBaseline: Double = 0,
        firstMilestoneAmount: Double = 0,
        savingsGoalMessage: String = "",
        dashboardMessage: String = ""
    ) {
        self.costPerPack = costPerPack
        self.cigarettesPerPack = cigarettesPerPack
        self.savingsGoal = savingsGoal
        self.weeklySavingsBaseline = weeklySavingsBaseline
        self.cigarettesAvoidedBaseline = cigarettesAvoidedBaseline
        self.firstMilestoneAmount = firstMilestoneAmount
        self.savingsGoalMessage = savingsGoalMessage
        self.dashboardMessage = dashboardMessage
    }
}

enum PlanSuggestionType: String, Codable, Equatable {
    case addTriggerRule = "add_trigger_rule"
    case updateTriggerRule = "update_trigger_rule"
    case reorderTriggerRules = "reorder_trigger_rules"
    case addReplacementActivity = "add_replacement_activity"
    case reorderReplacementActivities = "reorder_replacement_activities"
    case adjustTaperPace = "adjust_taper_pace"
    case addRiskyWindowReminder = "add_risky_window_reminder"
    case changeDailyFocus = "change_daily_focus"
    case updateSlipRecovery = "update_slip_recovery"

    var title: String {
        switch self {
        case .addTriggerRule:
            return "Add trigger rule"
        case .updateTriggerRule:
            return "Update trigger rule"
        case .reorderTriggerRules:
            return "Reorder trigger rules"
        case .addReplacementActivity:
            return "Add replacement activity"
        case .reorderReplacementActivities:
            return "Reorder activities"
        case .adjustTaperPace:
            return "Adjust taper pace"
        case .addRiskyWindowReminder:
            return "Add reminder"
        case .changeDailyFocus:
            return "Change today's focus"
        case .updateSlipRecovery:
            return "Update slip recovery"
        }
    }
}

enum PlanSuggestionStatus: String, Codable, Equatable {
    case pending
    case accepted
    case edited
    case dismissed
}

struct PlanAdjustmentSuggestion: Identifiable, Codable, Equatable {
    var id: UUID
    var planID: UUID
    var type: PlanSuggestionType
    var title: String
    var explanation: String
    var evidenceSummary: String
    var suggestedAction: String
    var affectedPlanArea: String
    var confidence: Double
    var status: PlanSuggestionStatus
    var evidenceKey: String
    var trigger: String?
    var replacementAction: String?
    var backupAction: String?
    var activityID: UUID?
    var activityTitle: String?
    var activityInstruction: String?
    var taperReductionIntervalDays: Int?
    var dailyFocusTitle: String?
    var dailyFocusAction: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        planID: UUID,
        type: PlanSuggestionType,
        title: String,
        explanation: String,
        evidenceSummary: String,
        suggestedAction: String,
        affectedPlanArea: String,
        confidence: Double,
        status: PlanSuggestionStatus = .pending,
        evidenceKey: String,
        trigger: String? = nil,
        replacementAction: String? = nil,
        backupAction: String? = nil,
        activityID: UUID? = nil,
        activityTitle: String? = nil,
        activityInstruction: String? = nil,
        taperReductionIntervalDays: Int? = nil,
        dailyFocusTitle: String? = nil,
        dailyFocusAction: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.planID = planID
        self.type = type
        self.title = title
        self.explanation = explanation
        self.evidenceSummary = evidenceSummary
        self.suggestedAction = suggestedAction
        self.affectedPlanArea = affectedPlanArea
        self.confidence = min(max(confidence, 0), 1)
        self.status = status
        self.evidenceKey = evidenceKey
        self.trigger = trigger
        self.replacementAction = replacementAction
        self.backupAction = backupAction
        self.activityID = activityID
        self.activityTitle = activityTitle
        self.activityInstruction = activityInstruction
        self.taperReductionIntervalDays = taperReductionIntervalDays
        self.dailyFocusTitle = dailyFocusTitle
        self.dailyFocusAction = dailyFocusAction
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
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

enum DailyPlanAdherenceStatus: Equatable {
    case achieved
    case slightMiss
    case missed
}

struct DailyPlanAdherenceDay: Identifiable, Equatable {
    let date: Date
    let targetCigarettes: Double
    let cigarettesSmoked: Int?
    let status: DailyPlanAdherenceStatus?
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
    var quitStatus: QuitStatus
    var readinessStage: String
    var planSummary: PlanSummary
    var firstWeekGoal: String
    var nextBestAction: String
    var generatedDailyFocus: String
    var generatedPlanSummary: String
    var strategyPlan: QuitStrategyPlan
    var generatedTriggerRules: [GeneratedTriggerRule]
    var cravingRescuePlan: CravingRescuePlan
    var slipRecoveryPlan: SlipRecoveryPlan
    var dailyFocusPlan: [DailyFocusPlan]
    var savingsPlan: SavingsPlan
    var pendingPlanSuggestions: [PlanAdjustmentSuggestion]
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
        quitStatus: QuitStatus = .readyToQuit,
        readinessStage: String = QuitStatus.readyToQuit.readinessStage,
        planSummary: PlanSummary? = nil,
        firstWeekGoal: String = "",
        nextBestAction: String = "",
        generatedDailyFocus: String = QuitStatus.readyToQuit.defaultDailyFocus,
        generatedPlanSummary: String = "",
        strategyPlan: QuitStrategyPlan? = nil,
        generatedTriggerRules: [GeneratedTriggerRule] = [],
        cravingRescuePlan: CravingRescuePlan = CravingRescuePlan(),
        slipRecoveryPlan: SlipRecoveryPlan = SlipRecoveryPlan(),
        dailyFocusPlan: [DailyFocusPlan] = [],
        savingsPlan: SavingsPlan = SavingsPlan(),
        pendingPlanSuggestions: [PlanAdjustmentSuggestion] = [],
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
        self.quitStatus = quitStatus
        self.readinessStage = readinessStage
        self.planSummary = planSummary ?? PlanSummary(
            quitDate: quitDate,
            quitStatus: quitStatus,
            readinessStage: readinessStage
        )
        self.firstWeekGoal = firstWeekGoal
        self.nextBestAction = nextBestAction
        self.generatedDailyFocus = generatedDailyFocus
        self.generatedPlanSummary = generatedPlanSummary
        self.strategyPlan = strategyPlan ?? QuitStrategyPlan(
            strategyType: quitMode == "Cold turkey" ? .coldTurkey : .taper,
            quitDate: quitDate,
            taperTarget: taperTargetCigarettesPerDay,
            taperStep: taperReductionStep,
            taperIntervalDays: taperReductionIntervalDays
        )
        self.generatedTriggerRules = generatedTriggerRules
        self.cravingRescuePlan = cravingRescuePlan
        self.slipRecoveryPlan = slipRecoveryPlan
        self.dailyFocusPlan = dailyFocusPlan
        self.savingsPlan = savingsPlan
        self.pendingPlanSuggestions = pendingPlanSuggestions
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

enum CoachDataConsentStatus: String, Codable, Equatable {
    case notDetermined = "not_determined"
    case granted
    case denied

    var isGranted: Bool {
        self == .granted
    }
}

struct PrivacySettings: Codable, Equatable {
    static let currentPolicyVersion = "2026-06-06"

    var coachDataConsentStatus: CoachDataConsentStatus
    var coachDataConsentUpdatedAt: Date?
    var policyVersion: String
    var updatedAt: Date

    init(
        coachDataConsentStatus: CoachDataConsentStatus = .notDetermined,
        coachDataConsentUpdatedAt: Date? = nil,
        policyVersion: String = PrivacySettings.currentPolicyVersion,
        updatedAt: Date = Date()
    ) {
        self.coachDataConsentStatus = coachDataConsentStatus
        self.coachDataConsentUpdatedAt = coachDataConsentUpdatedAt
        self.policyVersion = policyVersion
        self.updatedAt = updatedAt
    }
}

struct OnboardingPlanInput: Equatable {
    var nickname: String
    var age: Int
    var quitStatus: QuitStatus
    var confidence: Double
    var openedAppReason: String
    var ageStartedSmoking: Int?
    var yearsSmoking: Int?
    var cigarettesPerDay: Double
    var firstCigaretteTiming: FirstCigaretteTiming
    var previousQuitAttemptCount: PreviousQuitAttemptCount
    var longestQuitAttempt: LongestQuitAttempt
    var mainChallenge: SmokingChallenge
    var commonSmokingTimes: [String]
    var emotionalTriggers: [String]
    var situationalTriggers: [String]
    var quitDatePreference: QuitDatePreference
    var costPerPack: Double
    var cigarettesPerPack: Int
    var quitDate: Date
    var approachPreference: QuitApproachPreference
    var replacementActions: [String]
    var primaryReason: String
    var savingsGoalTitle: String
    var customSavingsGoal: String

    init(
        nickname: String,
        age: Int,
        quitStatus: QuitStatus,
        confidence: Double,
        openedAppReason: String,
        ageStartedSmoking: Int?,
        yearsSmoking: Int?,
        cigarettesPerDay: Double,
        firstCigaretteTiming: FirstCigaretteTiming,
        previousQuitAttemptCount: PreviousQuitAttemptCount,
        longestQuitAttempt: LongestQuitAttempt,
        mainChallenge: SmokingChallenge,
        commonSmokingTimes: [String],
        emotionalTriggers: [String],
        situationalTriggers: [String],
        quitDatePreference: QuitDatePreference,
        costPerPack: Double,
        cigarettesPerPack: Int,
        quitDate: Date,
        approachPreference: QuitApproachPreference,
        replacementActions: [String],
        primaryReason: String,
        savingsGoalTitle: String,
        customSavingsGoal: String
    ) {
        self.nickname = nickname
        self.age = age
        self.quitStatus = quitStatus
        self.confidence = confidence
        self.openedAppReason = openedAppReason
        self.ageStartedSmoking = ageStartedSmoking
        self.yearsSmoking = yearsSmoking
        self.cigarettesPerDay = cigarettesPerDay
        self.firstCigaretteTiming = firstCigaretteTiming
        self.previousQuitAttemptCount = previousQuitAttemptCount
        self.longestQuitAttempt = longestQuitAttempt
        self.mainChallenge = mainChallenge
        self.commonSmokingTimes = commonSmokingTimes
        self.emotionalTriggers = emotionalTriggers
        self.situationalTriggers = situationalTriggers
        self.quitDatePreference = quitDatePreference
        self.costPerPack = costPerPack
        self.cigarettesPerPack = cigarettesPerPack
        self.quitDate = quitDate
        self.approachPreference = approachPreference
        self.replacementActions = replacementActions
        self.primaryReason = primaryReason
        self.savingsGoalTitle = savingsGoalTitle
        self.customSavingsGoal = customSavingsGoal
    }
}

struct PersonalizedPlanGenerationOutput: Equatable {
    let quitPlan: QuitPlan
    let triggerRules: [TriggerRule]
    let userReasons: [UserReason]
    let replacementActivities: [ReplacementActivity]
    let riskySituations: [RiskySituation]
}

enum QuitPlanGenerator {
    static func generate(
        from input: OnboardingPlanInput,
        existingPlan: QuitPlan,
        now: Date,
        calendar: Calendar
    ) -> PersonalizedPlanGenerationOutput {
        let primaryReason = trimmed(input.primaryReason)
        let selectedTriggers = normalizedTriggers(
            commonSmokingTimes: input.commonSmokingTimes,
            emotionalTriggers: input.emotionalTriggers,
            situationalTriggers: input.situationalTriggers,
            mainChallenge: input.mainChallenge
        )
        let replacementActions = normalizedReplacementActions(input.replacementActions)
        let quitDate = resolvedQuitDate(
            preference: input.quitDatePreference,
            selectedDate: input.quitDate,
            status: input.quitStatus,
            confidence: input.confidence,
            previousAttempts: input.previousQuitAttemptCount,
            longestQuitAttempt: input.longestQuitAttempt,
            now: now,
            calendar: calendar
        )
        let strategyType = resolvedStrategyType(
            preference: input.approachPreference,
            status: input.quitStatus,
            confidence: input.confidence,
            cigarettesPerDay: input.cigarettesPerDay,
            firstCigaretteTiming: input.firstCigaretteTiming
        )
        let quitMode = planQuitMode(for: strategyType)
        let taperSettings = generatedTaperSettings(
            cigarettesPerDay: input.cigarettesPerDay,
            confidence: input.confidence,
            firstCigaretteTiming: input.firstCigaretteTiming,
            previousAttempts: input.previousQuitAttemptCount,
            longestQuitAttempt: input.longestQuitAttempt,
            mainChallenge: input.mainChallenge,
            strategyType: strategyType
        )
        let generatedRules = generatedTriggerRules(
            commonSmokingTimes: input.commonSmokingTimes,
            emotionalTriggers: input.emotionalTriggers,
            situationalTriggers: input.situationalTriggers,
            mainChallenge: input.mainChallenge,
            selectedReplacementActions: replacementActions
        )
        let triggerRules = selectedTriggers.map { trigger in
            TriggerRule(
                trigger: trigger,
                action: onboardingAction(
                    for: trigger,
                    selectedReplacementActions: replacementActions,
                    mainChallenge: input.mainChallenge
                )
            )
        }
        let primaryReasonID = UUID()
        let userReasons = [
            UserReason(
                id: primaryReasonID,
                text: primaryReason,
                sortOrder: 0,
                isPrimary: true,
                createdAt: now,
                updatedAt: now
            )
        ]
        let activities = onboardingReplacementActivities(
            for: selectedTriggers,
            selectedActions: replacementActions,
            now: now
        )
        let activityIDs = prioritizedActivityIDs(
            activities: activities,
            generatedRules: generatedRules,
            selectedActions: replacementActions
        )
        let dailyPlan = firstWeekDailyPlan(
            status: input.quitStatus,
            triggers: selectedTriggers,
            mainChallenge: input.mainChallenge,
            strategyType: strategyType
        )
        let dailyFocus = dailyPlan.first?.action ?? input.quitStatus.defaultDailyFocus
        let firstWeekGoal = generatedFirstWeekGoal(
            status: input.quitStatus,
            strategyType: strategyType,
            triggers: selectedTriggers,
            taperTarget: taperSettings.target
        )
        let nextBestAction = generatedNextBestAction(
            status: input.quitStatus,
            strategyType: strategyType,
            triggers: selectedTriggers,
            replacementActions: replacementActions
        )
        let planSummary = generatedPlanSummary(
            nickname: input.nickname,
            status: input.quitStatus,
            strategyType: strategyType,
            selectedTriggers: selectedTriggers,
            mainChallenge: input.mainChallenge,
            dailyFocus: dailyFocus,
            primaryReason: primaryReason,
            quitDate: quitDate,
            confidence: input.confidence,
            now: now
        )
        let strategyPlan = QuitStrategyPlan(
            strategyType: strategyType,
            rationale: strategyRationale(
                status: input.quitStatus,
                strategyType: strategyType,
                confidence: input.confidence,
                cigarettesPerDay: input.cigarettesPerDay,
                firstCigaretteTiming: input.firstCigaretteTiming,
                previousAttempts: input.previousQuitAttemptCount,
                mainChallenge: input.mainChallenge
            ),
            quitDate: quitDate,
            taperTarget: taperSettings.target,
            taperStep: taperSettings.step,
            taperIntervalDays: taperSettings.intervalDays,
            firstCigaretteDelayGoal: firstCigaretteDelayGoal(for: input.firstCigaretteTiming),
            protectedCigarettes: protectedCigarettes(from: selectedTriggers),
            nextSevenDayTargets: nextSevenDayTargets(
                startTarget: taperSettings.target,
                step: taperSettings.step,
                intervalDays: taperSettings.intervalDays,
                strategyType: strategyType
            )
        )
        let rescuePlan = CravingRescuePlan(
            primaryScript: primaryRescueScript(
                triggers: selectedTriggers,
                replacementActions: replacementActions,
                mainChallenge: input.mainChallenge
            ),
            primaryReasonID: primaryReasonID,
            prioritizedActivityIDs: activityIDs,
            backupAction: backupRescueAction(mainChallenge: input.mainChallenge),
            supportFallback: "If the urge feels bigger than the plan, contact a trusted person or call 1-800-QUIT-NOW.",
            slipRecoveryPrompt: "If you smoke, log the trigger, keep the quit attempt alive, and protect the next planned moment."
        )
        let slipPlan = slipRecoveryPlan(
            previousAttempts: input.previousQuitAttemptCount,
            longestQuitAttempt: input.longestQuitAttempt,
            mainChallenge: input.mainChallenge,
            confidence: input.confidence
        )
        let savingsPlan = generatedSavingsPlan(
            cigarettesPerDay: input.cigarettesPerDay,
            costPerPack: input.costPerPack,
            cigarettesPerPack: input.cigarettesPerPack,
            savingsGoalTitle: input.savingsGoalTitle,
            customSavingsGoal: input.customSavingsGoal
        )
        let riskySituations = onboardingRiskySituations(
            generatedRules: generatedRules,
            mainChallenge: input.mainChallenge,
            now: now
        )

        var plan = existingPlan
        plan.quitDate = quitDate
        plan.quitMode = quitMode
        plan.quitStatus = input.quitStatus
        plan.readinessStage = input.quitStatus.readinessStage
        plan.planSummary = planSummary
        plan.firstWeekGoal = firstWeekGoal
        plan.nextBestAction = nextBestAction
        plan.generatedDailyFocus = dailyFocus
        plan.generatedPlanSummary = planSummary.summary
        plan.strategyPlan = strategyPlan
        plan.generatedTriggerRules = generatedRules
        plan.cravingRescuePlan = rescuePlan
        plan.slipRecoveryPlan = slipPlan
        plan.dailyFocusPlan = dailyPlan
        plan.savingsPlan = savingsPlan
        plan.pendingPlanSuggestions = []
        plan.triggerRules = triggerRules
        plan.medicationNote = ""
        plan.baselineCigarettesPerDay = max(input.cigarettesPerDay, 0)
        plan.costPerPack = max(input.costPerPack, 0)
        plan.cigarettesPerPack = max(input.cigarettesPerPack, 1)
        plan.taperTargetCigarettesPerDay = taperSettings.target
        plan.taperReductionStep = taperSettings.step
        plan.taperReductionIntervalDays = taperSettings.intervalDays
        plan.attemptStartedAt = quitMode == "Taper" && existingPlan.quitMode == "Taper"
            ? existingPlan.attemptStartedAt
            : (quitMode == "Taper" ? now : quitDate)
        plan.updatedAt = now

        return PersonalizedPlanGenerationOutput(
            quitPlan: plan,
            triggerRules: triggerRules,
            userReasons: userReasons,
            replacementActivities: activities,
            riskySituations: riskySituations
        )
    }

    private struct TaperSettings {
        let target: Double
        let step: Double
        let intervalDays: Int
    }

    private static func normalizedTriggers(
        commonSmokingTimes: [String],
        emotionalTriggers: [String],
        situationalTriggers: [String],
        mainChallenge: SmokingChallenge
    ) -> [String] {
        let normalized = commonSmokingTimes + emotionalTriggers + situationalTriggers + [mainChallenge.triggerLabel]
        let unique = uniqueStrings(normalized.map(trimmed).filter { !$0.isEmpty })
        return unique.isEmpty ? [mainChallenge.triggerLabel] : Array(unique.prefix(6))
    }

    private static func normalizedReplacementActions(_ actions: [String]) -> [String] {
        let unique = uniqueStrings(actions.map(trimmed).filter { !$0.isEmpty })
        return unique.isEmpty ? ["Drink water", "Walk", "Breathing"] : unique
    }

    private static func resolvedStrategyType(
        preference: QuitApproachPreference,
        status: QuitStatus,
        confidence: Double,
        cigarettesPerDay: Double,
        firstCigaretteTiming: FirstCigaretteTiming
    ) -> QuitStrategyType {
        switch status {
        case .alreadyQuit:
            return .relapsePrevention
        case .thinkingAboutIt:
            return .preparation
        case .unsure:
            return .awareness
        case .cuttingDown:
            return preference == .coldTurkey ? .coldTurkey : .taper
        case .readyToQuit:
            switch preference {
            case .taper:
                return .taper
            case .coldTurkey:
                return .coldTurkey
            case .notSure:
                if confidence >= 7 && cigarettesPerDay <= 10 && firstCigaretteTiming != .withinFiveMinutes {
                    return .coldTurkey
                }
                return .taper
            }
        }
    }

    private static func planQuitMode(for strategyType: QuitStrategyType) -> String {
        strategyType == .coldTurkey || strategyType == .relapsePrevention ? "Cold turkey" : "Taper"
    }

    private static func resolvedQuitDate(
        preference: QuitDatePreference,
        selectedDate: Date,
        status: QuitStatus,
        confidence: Double,
        previousAttempts: PreviousQuitAttemptCount,
        longestQuitAttempt: LongestQuitAttempt,
        now: Date,
        calendar: Calendar
    ) -> Date {
        let today = calendar.startOfDay(for: now)
        switch preference {
        case .alreadyQuit:
            return min(calendar.startOfDay(for: selectedDate), today)
        case .chooseDate:
            return max(calendar.startOfDay(for: selectedDate), today)
        case .helpMeChoose:
            var days: Int
            switch status {
            case .alreadyQuit:
                days = 0
            case .readyToQuit:
                days = confidence >= 7 ? 7 : 10
            case .cuttingDown:
                days = confidence >= 7 ? 14 : 21
            case .thinkingAboutIt, .unsure:
                days = 21
            }
            if previousAttempts == .fourOrMore || longestQuitAttempt == .lessThanDay {
                days += 4
            }
            return calendar.date(byAdding: .day, value: days, to: today) ?? today
        }
    }

    private static func generatedTaperSettings(
        cigarettesPerDay: Double,
        confidence: Double,
        firstCigaretteTiming: FirstCigaretteTiming,
        previousAttempts: PreviousQuitAttemptCount,
        longestQuitAttempt: LongestQuitAttempt,
        mainChallenge: SmokingChallenge,
        strategyType: QuitStrategyType
    ) -> TaperSettings {
        guard strategyType == .taper || strategyType == .preparation || strategyType == .awareness else {
            return TaperSettings(target: 0, step: 0, intervalDays: 3)
        }

        let baseline = max(cigarettesPerDay, 0)
        let dependenceSignal = firstCigaretteTiming == .withinFiveMinutes || firstCigaretteTiming == .withinThirtyMinutes
        let needsGentleStart = baseline >= 20 ||
            confidence <= 4 ||
            firstCigaretteTiming == .withinFiveMinutes ||
            previousAttempts == .fourOrMore ||
            longestQuitAttempt == .lessThanDay ||
            mainChallenge == .withdrawal ||
            mainChallenge == .stress
        let fastStart = baseline <= 8 &&
            confidence >= 7 &&
            !dependenceSignal &&
            previousAttempts != .fourOrMore

        let step: Double
        let intervalDays: Int
        if needsGentleStart {
            step = 1
            intervalDays = baseline >= 20 || confidence <= 3 ? 5 : 4
        } else if fastStart {
            step = min(max((baseline * 0.25).rounded(), 1), 3)
            intervalDays = 2
        } else {
            step = min(max((baseline * 0.2).rounded(), 1), 3)
            intervalDays = confidence >= 8 ? 2 : 3
        }

        return TaperSettings(target: baseline, step: step, intervalDays: intervalDays)
    }

    private static func generatedTriggerRules(
        commonSmokingTimes: [String],
        emotionalTriggers: [String],
        situationalTriggers: [String],
        mainChallenge: SmokingChallenge,
        selectedReplacementActions: [String]
    ) -> [GeneratedTriggerRule] {
        let candidates = rankedTriggers(
            commonSmokingTimes: commonSmokingTimes,
            emotionalTriggers: emotionalTriggers,
            situationalTriggers: situationalTriggers,
            mainChallenge: mainChallenge
        )
        let topTriggers = candidates.isEmpty ? [mainChallenge.triggerLabel] : candidates

        return topTriggers.prefix(3).enumerated().map { index, trigger in
            GeneratedTriggerRule(
                trigger: trigger,
                warningSign: warningSign(for: trigger, mainChallenge: mainChallenge),
                replacementAction: onboardingAction(
                    for: trigger,
                    selectedReplacementActions: selectedReplacementActions,
                    mainChallenge: mainChallenge
                ),
                backupAction: "Start the 10-minute rescue before leaving the current place.",
                cravingModePrompt: cravingPrompt(for: trigger),
                reminderHint: reminderHint(for: trigger),
                priority: index + 1
            )
        }
    }

    private static func rankedTriggers(
        commonSmokingTimes: [String],
        emotionalTriggers: [String],
        situationalTriggers: [String],
        mainChallenge: SmokingChallenge
    ) -> [String] {
        var scores: [String: Int] = [:]
        var order: [String] = []

        func add(_ trigger: String, score: Int) {
            let value = trimmed(trigger)
            guard !value.isEmpty else { return }
            let existingKey = scores.keys.first { $0.caseInsensitiveCompare(value) == .orderedSame }
            let key = existingKey ?? value
            if existingKey == nil {
                order.append(value)
            }
            scores[key, default: 0] += score
        }

        commonSmokingTimes.forEach { add($0, score: 4) }
        emotionalTriggers.forEach { add($0, score: 3) }
        situationalTriggers.forEach { add($0, score: 3) }
        add(mainChallenge.triggerLabel, score: 5)

        return order.sorted { lhs, rhs in
            let lhsScore = scores.first { $0.key.caseInsensitiveCompare(lhs) == .orderedSame }?.value ?? 0
            let rhsScore = scores.first { $0.key.caseInsensitiveCompare(rhs) == .orderedSame }?.value ?? 0
            if lhsScore != rhsScore {
                return lhsScore > rhsScore
            }
            return (order.firstIndex(of: lhs) ?? 0) < (order.firstIndex(of: rhs) ?? 0)
        }
    }

    private static func generatedPlanSummary(
        nickname: String,
        status: QuitStatus,
        strategyType: QuitStrategyType,
        selectedTriggers: [String],
        mainChallenge: SmokingChallenge,
        dailyFocus: String,
        primaryReason: String,
        quitDate: Date,
        confidence: Double,
        now: Date
    ) -> PlanSummary {
        let triggerText = selectedTriggers.prefix(2).joined(separator: " and ")
        let protectedMoments = triggerText.isEmpty ? mainChallenge.triggerLabel.lowercased() : triggerText.lowercased()
        let name = trimmed(nickname)
        let title = name.isEmpty ? "Your relapse-prevention plan" : "\(name)'s relapse-prevention plan"
        let summary = "You are in \(status.readinessStage.lowercased()). Your first strategy is \(strategyType.title.lowercased()), with special protection for \(protectedMoments). \(dailyFocus) If you smoke, log what happened and keep the quit attempt alive."

        return PlanSummary(
            title: title,
            summary: summary,
            planStartDate: now,
            quitDate: quitDate,
            quitStatus: status,
            readinessStage: status.readinessStage,
            mainReason: primaryReason,
            confidenceLevel: min(max(confidence, 1), 10)
        )
    }

    private static func strategyRationale(
        status: QuitStatus,
        strategyType: QuitStrategyType,
        confidence: Double,
        cigarettesPerDay: Double,
        firstCigaretteTiming: FirstCigaretteTiming,
        previousAttempts: PreviousQuitAttemptCount,
        mainChallenge: SmokingChallenge
    ) -> String {
        switch strategyType {
        case .relapsePrevention:
            return "You already quit, so the plan protects risky moments instead of resetting progress."
        case .preparation:
            return "You are still deciding, so the plan starts with low-pressure rehearsal and trigger mapping."
        case .awareness:
            return "You are unsure, so the first job is to notice cues, motivation, and cost without forcing a quit date."
        case .coldTurkey:
            return confidence >= 7
                ? "Your confidence is high enough to prepare for a direct quit attempt with rescue actions ready."
                : "You chose cold turkey, so the plan adds extra rescue preparation before the quit date."
        case .taper:
            let dependenceText = firstCigaretteTiming == .withinFiveMinutes || firstCigaretteTiming == .withinThirtyMinutes
                ? " and an early first cigarette"
                : ""
            let attemptsText = previousAttempts == .fourOrMore ? " Previous attempts add preparation time." : ""
            return "Tapering respects \(Int(max(cigarettesPerDay, 0))) cigarettes per day\(dependenceText) while protecting \(mainChallenge.title.lowercased()).\(attemptsText)"
        }
    }

    private static func firstCigaretteDelayGoal(for timing: FirstCigaretteTiming) -> String {
        switch timing {
        case .withinFiveMinutes:
            return "Delay the first cigarette by 5 minutes before changing anything else."
        case .withinThirtyMinutes:
            return "Delay the first cigarette by 10 minutes and start with water or breathing."
        case .laterMorning:
            return "Protect the first morning cue with a 10-minute wait."
        case .afternoonOrEvening:
            return "Keep the first cigarette of the day behind one planned replacement."
        }
    }

    private static func protectedCigarettes(from triggers: [String]) -> [String] {
        let protected = triggers.filter { trigger in
            let lower = trigger.lowercased()
            return lower.contains("coffee") ||
                lower.contains("meal") ||
                lower.contains("work") ||
                lower.contains("morning") ||
                lower.contains("evening") ||
                lower.contains("alcohol")
        }
        return Array((protected.isEmpty ? triggers : protected).prefix(3))
    }

    private static func nextSevenDayTargets(
        startTarget: Double,
        step: Double,
        intervalDays: Int,
        strategyType: QuitStrategyType
    ) -> [DailyTaperTarget] {
        guard strategyType == .taper || strategyType == .preparation || strategyType == .awareness else {
            return []
        }
        return (1...7).map { day in
            let completedIntervals = max(day - 1, 0) / max(intervalDays, 1)
            let target = max(startTarget - Double(completedIntervals) * step, 0)
            return DailyTaperTarget(dayIndex: day, maximumCigarettes: target)
        }
    }

    private static func firstWeekDailyPlan(
        status: QuitStatus,
        triggers: [String],
        mainChallenge: SmokingChallenge,
        strategyType: QuitStrategyType
    ) -> [DailyFocusPlan] {
        let primary = triggers.first ?? mainChallenge.triggerLabel
        let secondary = triggers.dropFirst().first ?? primary
        let tertiary = triggers.dropFirst(2).first ?? secondary

        switch status {
        case .alreadyQuit:
            return [
                DailyFocusPlan(dayIndex: 1, title: "Protect the riskiest cue", action: "Start a 10-minute rescue before \(primary.lowercased()) peaks.", relatedTrigger: primary),
                DailyFocusPlan(dayIndex: 2, title: "Review warning signs", action: "Notice the first sign that \(secondary.lowercased()) is starting.", relatedTrigger: secondary),
                DailyFocusPlan(dayIndex: 3, title: "Rehearse backup", action: "Practice the backup action once while calm.", relatedTrigger: primary),
                DailyFocusPlan(dayIndex: 4, title: "Check your support path", action: "Choose who or what you will contact if the urge feels too high."),
                DailyFocusPlan(dayIndex: 5, title: "Protect the evening", action: "Keep the rescue button close during the highest-risk window."),
                DailyFocusPlan(dayIndex: 6, title: "Review what worked", action: "Move the most useful replacement to the top of the plan."),
                DailyFocusPlan(dayIndex: 7, title: "Adjust the plan", action: "Accept, edit, or dismiss one plan suggestion if TeoPateo has enough history.")
            ]
        case .readyToQuit:
            return [
                DailyFocusPlan(dayIndex: 1, title: "Rehearse the first rule", action: "Practice the \(primary.lowercased()) rule before the quit date.", relatedTrigger: primary),
                DailyFocusPlan(dayIndex: 2, title: "Prepare craving mode", action: "Pick the first replacement activity you will use when the urge starts."),
                DailyFocusPlan(dayIndex: 3, title: "Delay first cue", action: "Delay one \(secondary.lowercased()) cue by 10 minutes.", relatedTrigger: secondary),
                DailyFocusPlan(dayIndex: 4, title: "Set after-meal protection", action: "Have gum, water, or brushing ready before a meal ends.", relatedTrigger: "After meals"),
                DailyFocusPlan(dayIndex: 5, title: "Review risky window", action: "Notice when urges are strongest and log the trigger."),
                DailyFocusPlan(dayIndex: 6, title: "Add support fallback", action: "Choose one person, coach prompt, or quitline fallback."),
                DailyFocusPlan(dayIndex: 7, title: "Plan review", action: "Review what felt realistic and edit one assumption.")
            ]
        case .cuttingDown:
            return [
                DailyFocusPlan(dayIndex: 1, title: "Protect one cigarette", action: "Delay one \(primary.lowercased()) cigarette and use a replacement first.", relatedTrigger: primary),
                DailyFocusPlan(dayIndex: 2, title: "Keep the target visible", action: "Stay within today's taper maximum if possible."),
                DailyFocusPlan(dayIndex: 3, title: "Delay the first cigarette", action: "Use the first-cigarette delay goal before changing the rest."),
                DailyFocusPlan(dayIndex: 4, title: "Prepare after-meal plan", action: "Use brushing, gum, or water before the after-meal cue.", relatedTrigger: "After meals"),
                DailyFocusPlan(dayIndex: 5, title: "Review misses without blame", action: "If you go over target, log the trigger and hold the plan steady."),
                DailyFocusPlan(dayIndex: 6, title: "Repeat what helped", action: "Use yesterday's best replacement before the next protected cigarette."),
                DailyFocusPlan(dayIndex: 7, title: "Adjust taper", action: "Review whether the reduction pace felt realistic.")
            ]
        case .thinkingAboutIt:
            return [
                DailyFocusPlan(dayIndex: 1, title: "Notice one cue", action: "Notice the next \(primary.lowercased()) cue and try one replacement without pressure.", relatedTrigger: primary),
                DailyFocusPlan(dayIndex: 2, title: "Track the reason", action: "Write down what smoking was trying to solve."),
                DailyFocusPlan(dayIndex: 3, title: "Try a pause", action: "Pause for 10 minutes before one routine cigarette."),
                DailyFocusPlan(dayIndex: 4, title: "Map a pattern", action: "Log when \(secondary.lowercased()) shows up.", relatedTrigger: secondary),
                DailyFocusPlan(dayIndex: 5, title: "Review motivation", action: "Read your main reason before the first cigarette."),
                DailyFocusPlan(dayIndex: 6, title: "Try support", action: "Ask the coach to plan one risky moment."),
                DailyFocusPlan(dayIndex: 7, title: "Choose next step", action: "Decide whether to keep mapping, taper, or set a quit date.")
            ]
        case .unsure:
            return [
                DailyFocusPlan(dayIndex: 1, title: "Map one moment", action: "Log one smoking moment and what the \(mainChallenge.title.lowercased()) was asking for.", relatedTrigger: tertiary),
                DailyFocusPlan(dayIndex: 2, title: "Notice cost", action: "Check what a smoke-free day would put toward your savings goal."),
                DailyFocusPlan(dayIndex: 3, title: "Try one substitute", action: "Use one replacement before smoking, even if you still smoke after."),
                DailyFocusPlan(dayIndex: 4, title: "Name a cue", action: "Pick whether the strongest cue is time, emotion, place, or people."),
                DailyFocusPlan(dayIndex: 5, title: "Protect one easy win", action: "Choose the easiest cigarette to delay by 5 minutes."),
                DailyFocusPlan(dayIndex: 6, title: "Review your reason", action: "Edit your reason so it sounds like you."),
                DailyFocusPlan(dayIndex: 7, title: "Choose the next experiment", action: "Keep awareness mode or switch to taper when ready.")
            ]
        }
    }

    private static func generatedFirstWeekGoal(
        status: QuitStatus,
        strategyType: QuitStrategyType,
        triggers: [String],
        taperTarget: Double
    ) -> String {
        let trigger = triggers.first ?? "your strongest cue"
        switch status {
        case .alreadyQuit:
            return "Keep the quit attempt alive by protecting \(trigger.lowercased()) before the urge peaks."
        case .readyToQuit:
            return "Rehearse craving rescue and trigger rules before the quit date."
        case .cuttingDown:
            return "Hold the daily maximum near \(Int(taperTarget)) cigarettes while protecting \(trigger.lowercased())."
        case .thinkingAboutIt:
            return "Map the cues and practice one low-pressure pause."
        case .unsure:
            return "Build awareness of triggers, cost, and which replacement feels realistic."
        }
    }

    private static func generatedNextBestAction(
        status: QuitStatus,
        strategyType: QuitStrategyType,
        triggers: [String],
        replacementActions: [String]
    ) -> String {
        let trigger = triggers.first ?? "your next smoking cue"
        let action = replacementActions.first ?? "the 10-minute rescue"
        switch strategyType {
        case .relapsePrevention:
            return "Before \(trigger.lowercased()), start the rescue timer and use \(action.lowercased())."
        case .taper:
            return "Delay the next \(trigger.lowercased()) cigarette by 10 minutes and start with \(action.lowercased())."
        case .coldTurkey:
            return "Prepare \(action.lowercased()) before the quit date, then use it as soon as \(trigger.lowercased()) appears."
        case .preparation:
            return "Practice \(action.lowercased()) once before a craving so it is familiar later."
        case .awareness:
            return status == .unsure
                ? "Log one smoking moment and what triggered it before changing the plan."
                : "Notice one cue and choose a small pause."
        }
    }

    private static func primaryRescueScript(
        triggers: [String],
        replacementActions: [String],
        mainChallenge: SmokingChallenge
    ) -> String {
        let trigger = triggers.first ?? mainChallenge.triggerLabel
        let firstAction = replacementActions.first ?? "drink water"
        let secondAction = replacementActions.dropFirst().first ?? "box breathing"
        return "If the urge appears around \(trigger.lowercased()), do \(firstAction.lowercased()) first, then start the 10-minute timer. If the urge is still high after 3 minutes, switch to \(secondAction.lowercased())."
    }

    private static func backupRescueAction(mainChallenge: SmokingChallenge) -> String {
        switch mainChallenge {
        case .stress, .withdrawal:
            return "Step away, slow your breathing, and choose the smallest next action."
        case .alcohol, .socialPressure:
            return "Move away from the smoking group and keep both hands busy."
        case .boredom, .habitRoutine:
            return "Change rooms and start a five-minute reset task."
        default:
            return "Change location and keep the timer running before deciding."
        }
    }

    private static func slipRecoveryPlan(
        previousAttempts: PreviousQuitAttemptCount,
        longestQuitAttempt: LongestQuitAttempt,
        mainChallenge: SmokingChallenge,
        confidence: Double
    ) -> SlipRecoveryPlan {
        let repeatedAttempts = previousAttempts == .twoToThree || previousAttempts == .fourOrMore
        let preserve = repeatedAttempts || confidence <= 6 || longestQuitAttempt != .yearOrMore
        let message = preserve
            ? "If you smoke, do not restart the whole plan automatically. Log the trigger, choose the next protected moment, and keep today's next choice small."
            : "If you smoke, treat it as a signal. Capture what changed and return to the next planned pause."
        let support: String
        switch mainChallenge {
        case .stress, .withdrawal:
            support = "Ask the coach for a smaller stress-specific plan or contact a quitline counselor."
        case .alcohol, .socialPressure:
            support = "Plan a support text before the next social or alcohol cue."
        default:
            support = "Use the coach or 1-800-QUIT-NOW if the same cue repeats."
        }
        return SlipRecoveryPlan(
            message: message,
            reflectionQuestions: [
                "What trigger showed up?",
                "What happened in the 10 minutes before smoking?",
                "What is the next protected moment?"
            ],
            defaultRecoveryAction: "Log the trigger, use one replacement before the next cigarette, and keep the quit attempt active.",
            preserveQuitAttemptByDefault: preserve,
            suggestedSupportAction: support
        )
    }

    private static func generatedSavingsPlan(
        cigarettesPerDay: Double,
        costPerPack: Double,
        cigarettesPerPack: Int,
        savingsGoalTitle: String,
        customSavingsGoal: String
    ) -> SavingsPlan {
        let packSize = max(cigarettesPerPack, 1)
        let weeklyAvoided = max(cigarettesPerDay, 0) * 7
        let weeklySavings = weeklyAvoided * max(costPerPack, 0) / Double(packSize)
        let goal = savingsGoalTitle == "Custom" && !trimmed(customSavingsGoal).isEmpty
            ? trimmed(customSavingsGoal)
            : trimmed(savingsGoalTitle)
        let firstMilestone = weeklySavings > 0 ? max(5, (weeklySavings / 2).rounded()) : 0
        let goalText = goal.isEmpty ? "your savings goal" : goal.lowercased()
        return SavingsPlan(
            costPerPack: max(costPerPack, 0),
            cigarettesPerPack: packSize,
            savingsGoal: goal,
            weeklySavingsBaseline: weeklySavings,
            cigarettesAvoidedBaseline: weeklyAvoided,
            firstMilestoneAmount: firstMilestone,
            savingsGoalMessage: "At your current baseline, every smoke-free week puts about \(moneySummary(weeklySavings)) toward \(goalText).",
            dashboardMessage: "A smoke-free day is worth about \(moneySummary(weeklySavings / 7)) toward \(goalText)."
        )
    }

    private static func prioritizedActivityIDs(
        activities: [ReplacementActivity],
        generatedRules: [GeneratedTriggerRule],
        selectedActions: [String]
    ) -> [UUID] {
        let ruleTriggers = generatedRules.map(\.trigger)
        let matched = activities.filter { activity in
            ruleTriggers.contains { trigger in
                triggerMatches(activity.linkedTrigger, trigger)
            }
        }
        let willing = selectedActions.compactMap { action in
            activities.first { activity in
                activity.title.caseInsensitiveCompare(onboardingActivityTitle(forAction: action)) == .orderedSame
            }
        }
        return Array((matched + willing + activities).uniquedByID().prefix(4).map(\.id))
    }

    private static func onboardingReplacementActivities(
        for triggers: [String],
        selectedActions: [String],
        now: Date
    ) -> [ReplacementActivity] {
        let triggerActivities = triggers.prefix(4).map { trigger in
            ReplacementActivity(
                title: onboardingActivityTitle(for: trigger),
                instruction: onboardingActivityInstruction(for: trigger),
                category: onboardingActivityCategory(for: trigger),
                linkedTrigger: trigger,
                createdAt: now,
                updatedAt: now
            )
        }
        let actionActivities = selectedActions.map { action in
            ReplacementActivity(
                title: onboardingActivityTitle(forAction: action),
                instruction: onboardingActivityInstruction(forAction: action),
                category: onboardingActivityCategory(forAction: action),
                createdAt: now,
                updatedAt: now
            )
        }
        return (triggerActivities + actionActivities).uniquedByTitle()
    }

    private static func onboardingRiskySituations(
        generatedRules: [GeneratedTriggerRule],
        mainChallenge: SmokingChallenge,
        now: Date
    ) -> [RiskySituation] {
        generatedRules.map { rule in
            RiskySituation(
                title: rule.trigger,
                expectedContext: "Risk may rise when \(rule.trigger.lowercased()) overlaps with \(mainChallenge.title.lowercased()).",
                preventionPlan: rule.replacementAction,
                backupAction: rule.backupAction,
                createdAt: now,
                updatedAt: now
            )
        }
    }

    private static func onboardingAction(
        for trigger: String,
        selectedReplacementActions: [String],
        mainChallenge: SmokingChallenge
    ) -> String {
        let preferredAction = selectedReplacementActions.first.map { " Start with \($0.lowercased())." } ?? ""
        switch trigger {
        case "Coffee", "After coffee":
            return "Drink a full glass of water first, then wait 10 minutes before deciding.\(preferredAction)"
        case "After meals":
            return "Brush teeth or chew gum as soon as the meal ends.\(preferredAction)"
        case "Work stress", "Work breaks", "Work pressure", "Stress":
            return "Step away from the task, walk for 10 minutes, then choose the next small action."
        case "Driving", "Driving or commute":
            return "Keep cigarettes out of reach and start a short breathing reset before the trip."
        case "Alcohol":
            return "Keep a drink in hand, avoid stepping outside with smokers, and start the rescue timer if the urge spikes."
        case "Boredom":
            return "Start a five-minute reset task before making any smoking decision."
        case "Social smoking", "Friends who smoke", "Social pressure":
            return "Tell one person you are pausing for 10 minutes and stay away from the smoking spot."
        case "Morning", "Morning routine":
            return "Change the first 10 minutes: water, shower, or a short walk before coffee."
        case "Evening", "Before bed", "Evening wind-down":
            return "Put cigarettes out of sight and start the rescue timer before settling in."
        case "Anger", "Anxiety", "Loneliness":
            return "Name the feeling, slow your breathing, and wait 10 minutes before making a smoking decision."
        case "Being outside", "Phone scrolling", "Waiting":
            return "Keep your hands busy and start a replacement action before autopilot takes over."
        default:
            return "Pause for 10 minutes, name the \(mainChallenge.title.lowercased()) cue, and choose one substitute."
        }
    }

    private static func warningSign(for trigger: String, mainChallenge: SmokingChallenge) -> String {
        switch trigger {
        case "After coffee":
            return "Finishing coffee and reaching for your phone or keys."
        case "After meals":
            return "Standing up from the table or heading toward the usual smoking spot."
        case "Work stress", "Work pressure", "Stress":
            return "A tense task, frustration, or the thought that a cigarette will reset the moment."
        case "Alcohol":
            return "Someone steps outside or the next drink lowers your guard."
        case "Boredom":
            return "Scrolling, waiting, or looking for something to change the mood."
        case "Friends who smoke", "Social pressure":
            return "A friend lights up or invites you outside."
        default:
            return "The first automatic move toward smoking when \(mainChallenge.title.lowercased()) shows up."
        }
    }

    private static func cravingPrompt(for trigger: String) -> String {
        "Delay \(trigger.lowercased()) by 10 minutes before deciding."
    }

    private static func reminderHint(for trigger: String) -> String? {
        let lower = trigger.lowercased()
        if lower.contains("meal") {
            return "Post-meal reminder"
        }
        if lower.contains("morning") || lower.contains("coffee") {
            return "Morning plan reminder"
        }
        if lower.contains("work") || lower.contains("evening") || lower.contains("bed") {
            return "Risk-window reminder"
        }
        return nil
    }

    private static func onboardingActivityTitle(for trigger: String) -> String {
        switch trigger {
        case "Coffee", "After coffee":
            return "Cold water first"
        case "After meals":
            return "Brush or chew"
        case "Work stress", "Work breaks", "Work pressure", "Stress":
            return "Walk one block"
        case "Driving", "Driving or commute":
            return "Commute breathing"
        case "Alcohol":
            return "Step back inside"
        case "Boredom":
            return "Five-minute reset"
        case "Social smoking", "Friends who smoke", "Social pressure":
            return "Stay with the room"
        case "Morning", "Morning routine":
            return "Change the first 10"
        case "Evening", "Before bed", "Evening wind-down":
            return "Hands-busy reset"
        case "Anger", "Anxiety", "Loneliness":
            return "Name the feeling"
        case "Being outside", "Phone scrolling", "Waiting":
            return "Hands-busy pause"
        default:
            return "10-minute substitute"
        }
    }

    private static func onboardingActivityInstruction(for trigger: String) -> String {
        switch trigger {
        case "Coffee", "After coffee":
            return "Finish one full glass of cold water before deciding anything."
        case "After meals":
            return "Brush teeth or chew gum until the urge drops."
        case "Work stress", "Work breaks", "Work pressure", "Stress":
            return "Walk away from the task until the timer drops below 6:00."
        case "Driving", "Driving or commute":
            return "Take five slow breaths before starting the car or leaving transit."
        case "Alcohol":
            return "Move away from the smoking cue and keep both hands busy before going outside."
        case "Boredom":
            return "Tidy one small area or start one quick errand until the urge changes."
        case "Social smoking", "Friends who smoke", "Social pressure":
            return "Stay inside for 10 minutes and choose one hands-busy reset."
        case "Morning", "Morning routine":
            return "Drink water and move for two minutes before coffee or phone checks."
        case "Evening", "Before bed", "Evening wind-down":
            return "Hold a cold drink, stretch, or keep both hands busy until the timer ends."
        case "Anger", "Anxiety", "Loneliness":
            return "Write one sentence that names the feeling, then breathe for one minute."
        case "Being outside", "Phone scrolling", "Waiting":
            return "Keep both hands busy and delay the smoking decision until the timer drops."
        default:
            return "Choose one substitute and stay with it until the timer ends."
        }
    }

    private static func onboardingActivityCategory(for trigger: String) -> ReplacementActivityCategory {
        switch trigger {
        case "Work stress", "Work breaks", "Work pressure", "Stress", "Morning", "Morning routine":
            return .movement
        case "Driving", "Driving or commute", "Anxiety":
            return .breathing
        case "Coffee", "After coffee", "After meals", "Evening", "Before bed", "Evening wind-down", "Alcohol":
            return .sensory
        case "Anger", "Loneliness":
            return .journaling
        case "Social smoking", "Friends who smoke", "Social pressure":
            return .distraction
        default:
            return .distraction
        }
    }

    private static func onboardingActivityTitle(forAction action: String) -> String {
        switch action {
        case "Drink water":
            return "Drink cold water"
        case "Walk":
            return "Walk for 10"
        case "Breathing":
            return "Box breathing"
        case "Chewing gum":
            return "Chew through the urge"
        case "Brush teeth":
            return "Brush teeth"
        case "Message someone":
            return "Message a person"
        case "Journal":
            return "Write one sentence"
        case "Short task":
            return "Five-minute reset"
        default:
            return action
        }
    }

    private static func onboardingActivityInstruction(forAction action: String) -> String {
        switch action {
        case "Drink water":
            return "Finish one full glass before deciding anything."
        case "Walk":
            return "Walk until the timer drops below 6:00."
        case "Breathing":
            return "Breathe in 4, hold 4, out 4, hold 4. Repeat five times."
        case "Chewing gum":
            return "Chew gum until the first wave of the urge drops."
        case "Brush teeth":
            return "Brush teeth as soon as the cue ends."
        case "Message someone":
            return "Send a short text before stepping toward the smoking cue."
        case "Journal":
            return "Name the trigger and the next right action."
        case "Short task":
            return "Tidy one small area or finish one two-minute task."
        default:
            return "Use this as the first 10-minute substitute."
        }
    }

    private static func onboardingActivityCategory(forAction action: String) -> ReplacementActivityCategory {
        switch action {
        case "Walk":
            return .movement
        case "Breathing":
            return .breathing
        case "Drink water", "Chewing gum", "Brush teeth":
            return .sensory
        case "Message someone":
            return .distraction
        case "Journal":
            return .journaling
        default:
            return .distraction
        }
    }

    private static func uniqueStrings(_ values: [String]) -> [String] {
        values.reduce(into: [String]()) { result, value in
            if !result.contains(where: { $0.caseInsensitiveCompare(value) == .orderedSame }) {
                result.append(value)
            }
        }
    }

    private static func triggerMatches(_ lhs: String, _ rhs: String) -> Bool {
        let left = lhs.lowercased()
        let right = rhs.lowercased()
        return !left.isEmpty && (left.contains(right) || right.contains(left))
    }

    private static func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func moneySummary(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_US")
        formatter.currencyCode = "USD"
        formatter.minimumFractionDigits = amount.rounded() == amount ? 0 : 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }
}

enum PlanAdjustmentEngine {
    static func updatedSuggestions(
        existing: [PlanAdjustmentSuggestion],
        quitPlan: QuitPlan,
        cravingEvents: [CravingEvent],
        slipEvents: [SlipEvent],
        dailyCheckIns: [DailyCheckIn],
        replacementActivities: [ReplacementActivity],
        notificationSettings: NotificationSettings,
        now: Date,
        calendar: Calendar
    ) -> [PlanAdjustmentSuggestion] {
        let candidates = generatedCandidates(
            quitPlan: quitPlan,
            cravingEvents: cravingEvents,
            slipEvents: slipEvents,
            dailyCheckIns: dailyCheckIns,
            replacementActivities: replacementActivities,
            notificationSettings: notificationSettings,
            now: now,
            calendar: calendar
        )
        let newSuggestions = candidates.filter { candidate in
            !existing.contains {
                $0.type == candidate.type &&
                    $0.evidenceKey == candidate.evidenceKey
            }
        }

        return (existing + newSuggestions).sorted {
            if $0.status != $1.status {
                return $0.status == .pending
            }
            return $0.createdAt > $1.createdAt
        }
    }

    private static func generatedCandidates(
        quitPlan: QuitPlan,
        cravingEvents: [CravingEvent],
        slipEvents: [SlipEvent],
        dailyCheckIns: [DailyCheckIn],
        replacementActivities: [ReplacementActivity],
        notificationSettings: NotificationSettings,
        now: Date,
        calendar: Calendar
    ) -> [PlanAdjustmentSuggestion] {
        var candidates: [PlanAdjustmentSuggestion] = []
        let loggedCravings = cravingEvents.filter { $0.outcome != .dismissedWithoutOutcome }
        let cravingTriggerCounts = triggerCounts(loggedCravings.map(\.selectedTriggers))
        let slipTriggerCounts = triggerCounts(slipEvents.map(\.selectedTriggers))

        if loggedCravings.count >= 3,
           let top = cravingTriggerCounts.first,
           top.count >= 2,
           matchingRule(for: top.name, in: quitPlan.triggerRules) == nil {
            let evidence = top.count == loggedCravings.count
                ? "\(top.name) appeared in all \(top.count) logged cravings."
                : "\(top.name) appeared in \(top.count) of \(loggedCravings.count) logged cravings."
            candidates.append(PlanAdjustmentSuggestion(
                planID: quitPlan.id,
                type: .addTriggerRule,
                title: "Add a \(top.name.lowercased()) rule",
                explanation: "This trigger is repeating enough to deserve a specific before-the-urge action.",
                evidenceSummary: evidence,
                suggestedAction: "Add: start a 10-minute rescue and use a replacement before deciding.",
                affectedPlanArea: "High-risk moments",
                confidence: loggedCravings.count >= 8 ? 0.82 : 0.62,
                evidenceKey: "craving-trigger:\(top.name.lowercased()):\(top.count):\(loggedCravings.count)",
                trigger: top.name,
                replacementAction: "Start a 10-minute substitute before deciding whether to smoke.",
                backupAction: "Change location and keep the rescue timer running.",
                createdAt: now,
                updatedAt: now
            ))
        }

        if slipEvents.count >= 2,
           let topSlip = slipTriggerCounts.first,
           topSlip.count >= 2 {
            let action = "Add a backup plan for \(topSlip.name.lowercased()) and keep the quit attempt active after a slip."
            candidates.append(PlanAdjustmentSuggestion(
                planID: quitPlan.id,
                type: .updateSlipRecovery,
                title: "Add a \(topSlip.name.lowercased()) recovery backup",
                explanation: "Repeated slips around one trigger need a recovery step before shame or reset thinking takes over.",
                evidenceSummary: "\(topSlip.name) appeared in \(topSlip.count) slip logs.",
                suggestedAction: action,
                affectedPlanArea: "Slip recovery",
                confidence: topSlip.count >= 3 ? 0.84 : 0.68,
                evidenceKey: "slip-trigger:\(topSlip.name.lowercased()):\(topSlip.count):\(slipEvents.count)",
                trigger: topSlip.name,
                backupAction: "If \(topSlip.name.lowercased()) leads to smoking, log it, protect the next moment, and use support before the next cigarette.",
                createdAt: now,
                updatedAt: now
            ))
        }

        if loggedCravings.count >= 8,
           !notificationSettings.riskyWindowEnabled,
           let topWindow = riskWindow(from: loggedCravings, calendar: calendar) {
            candidates.append(PlanAdjustmentSuggestion(
                planID: quitPlan.id,
                type: .addRiskyWindowReminder,
                title: "Turn on a \(topWindow.startLabel) warning",
                explanation: "A reminder can reach you before the urge becomes automatic.",
                evidenceSummary: "\(topWindow.title) contains \(topWindow.cravingCount) logged cravings.",
                suggestedAction: "Enable risk-window reminders.",
                affectedPlanArea: "Reminders",
                confidence: topWindow.share >= 0.4 ? 0.8 : 0.64,
                evidenceKey: "risk-window:\(topWindow.startHour):\(topWindow.cravingCount):\(loggedCravings.count)",
                createdAt: now,
                updatedAt: now
            ))
        }

        if let helpfulActivity = helpfulActivitySuggestion(
            quitPlan: quitPlan,
            cravingEvents: loggedCravings,
            replacementActivities: replacementActivities,
            now: now
        ) {
            candidates.append(helpfulActivity)
        }

        let missedTargets = recentMissedTargets(dailyCheckIns: dailyCheckIns, now: now, calendar: calendar)
        if quitPlan.quitMode == "Taper", missedTargets >= 3 {
            let nextInterval = min(max(quitPlan.taperReductionIntervalDays + 2, 3), 10)
            candidates.append(PlanAdjustmentSuggestion(
                planID: quitPlan.id,
                type: .adjustTaperPace,
                title: "Slow this taper step",
                explanation: "The target has been missed often enough that holding the current level is more useful than forcing a reset.",
                evidenceSummary: "You were over target on \(missedTargets) of the last 7 check-in days.",
                suggestedAction: "Reduce every \(nextInterval) days instead of every \(quitPlan.taperReductionIntervalDays) days.",
                affectedPlanArea: "Quit strategy",
                confidence: 0.74,
                evidenceKey: "taper-missed:\(missedTargets):\(quitPlan.taperReductionIntervalDays)",
                taperReductionIntervalDays: nextInterval,
                createdAt: now,
                updatedAt: now
            ))
        }

        if stressNeedsSmallerFocus(cravingEvents: loggedCravings, dailyCheckIns: dailyCheckIns),
           !quitPlan.generatedDailyFocus.lowercased().contains("stress") {
            candidates.append(PlanAdjustmentSuggestion(
                planID: quitPlan.id,
                type: .changeDailyFocus,
                title: "Make today's focus smaller",
                explanation: "High stress plus cravings is a signal to protect one moment instead of trying to perfect the day.",
                evidenceSummary: "Stress was 7 or higher on repeated check-ins with recent cravings.",
                suggestedAction: "Today: protect one stress cue with breathing before any other goal.",
                affectedPlanArea: "Daily focus",
                confidence: 0.66,
                evidenceKey: "stress-focus:\(loggedCravings.count):\(dailyCheckIns.count)",
                trigger: "Stress",
                dailyFocusTitle: "Protect one stress cue",
                dailyFocusAction: "Use one minute of breathing before the next stress-linked cigarette.",
                createdAt: now,
                updatedAt: now
            ))
        }

        return candidates
    }

    private static func helpfulActivitySuggestion(
        quitPlan: QuitPlan,
        cravingEvents: [CravingEvent],
        replacementActivities: [ReplacementActivity],
        now: Date
    ) -> PlanAdjustmentSuggestion? {
        let handled = cravingEvents.filter { $0.outcome == .completedWithoutSmoking }
        let counts = Dictionary(grouping: handled.compactMap(\.helpedActivityID), by: { $0 })
            .map { id, values in (id: id, count: values.count) }
            .sorted {
                if $0.count != $1.count {
                    return $0.count > $1.count
                }
                return $0.id.uuidString < $1.id.uuidString
            }
        guard let top = counts.first,
              top.count >= 2,
              let activity = replacementActivities.first(where: { $0.id == top.id }),
              replacementActivities.first?.id != activity.id
        else {
            return nil
        }

        return PlanAdjustmentSuggestion(
            planID: quitPlan.id,
            type: .reorderReplacementActivities,
            title: "Move \(activity.title.lowercased()) higher",
            explanation: "This replacement has helped more than once, so craving mode should offer it earlier.",
            evidenceSummary: "\(activity.title) helped in \(top.count) handled cravings.",
            suggestedAction: "Move \(activity.title) to the top of craving mode.",
            affectedPlanArea: "Craving rescue",
            confidence: 0.76,
            evidenceKey: "helped-activity:\(activity.id.uuidString):\(top.count)",
            activityID: activity.id,
            createdAt: now,
            updatedAt: now
        )
    }

    private static func triggerCounts(_ triggerLists: [[String]]) -> [TriggerCount] {
        var counts: [String: Int] = [:]
        for triggers in triggerLists {
            for trigger in Set(triggers.map(trimmed).filter { !$0.isEmpty }) {
                let existing = counts.keys.first { $0.caseInsensitiveCompare(trigger) == .orderedSame }
                counts[existing ?? trigger, default: 0] += 1
            }
        }
        return counts
            .map { TriggerCount(name: $0.key, count: $0.value) }
            .sorted {
                if $0.count != $1.count {
                    return $0.count > $1.count
                }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
    }

    private static func riskWindow(
        from cravingEvents: [CravingEvent],
        calendar: Calendar
    ) -> RiskWindowInsight? {
        guard !cravingEvents.isEmpty else { return nil }
        let counts = cravingEvents.reduce(into: [Int: Int]()) { result, event in
            result[calendar.component(.hour, from: event.startedAt), default: 0] += 1
        }
        let total = Double(cravingEvents.count)
        return counts
            .map { RiskWindowInsight(startHour: $0.key, cravingCount: $0.value, share: Double($0.value) / total) }
            .sorted {
                if $0.cravingCount != $1.cravingCount {
                    return $0.cravingCount > $1.cravingCount
                }
                return $0.startHour < $1.startHour
            }
            .first
    }

    private static func recentMissedTargets(
        dailyCheckIns: [DailyCheckIn],
        now: Date,
        calendar: Calendar
    ) -> Int {
        guard let start = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now)) else {
            return 0
        }
        return dailyCheckIns.filter { checkIn in
            let day = calendar.startOfDay(for: checkIn.date)
            return day >= start &&
                day <= calendar.startOfDay(for: now) &&
                checkIn.stayedWithinTaperTarget == false
        }.count
    }

    private static func stressNeedsSmallerFocus(
        cravingEvents: [CravingEvent],
        dailyCheckIns: [DailyCheckIn]
    ) -> Bool {
        guard cravingEvents.count >= 3 else { return false }
        let highStressDays = dailyCheckIns.filter { $0.stress >= 7 }.count
        let stressCravings = cravingEvents.filter { event in
            event.selectedTriggers.contains { $0.localizedCaseInsensitiveContains("stress") }
        }.count
        return highStressDays >= 2 && stressCravings >= 2
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

    private static func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private struct TriggerCount {
        let name: String
        let count: Int
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
    var privacySettings: PrivacySettings?
    var userProfile: UserProfile?
    var quitReadiness: QuitReadiness?
    var smokingBackground: SmokingBackground?
    var savingsGoal: SavingsGoal?
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
        privacySettings: PrivacySettings? = nil,
        userProfile: UserProfile? = nil,
        quitReadiness: QuitReadiness? = nil,
        smokingBackground: SmokingBackground? = nil,
        savingsGoal: SavingsGoal? = nil,
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
        self.privacySettings = privacySettings
        self.userProfile = userProfile
        self.quitReadiness = quitReadiness
        self.smokingBackground = smokingBackground
        self.savingsGoal = savingsGoal
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

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen: Set<Element> = []
        var result: [Element] = []
        for element in self where !seen.contains(element) {
            seen.insert(element)
            result.append(element)
        }
        return result
    }
}

private extension Array where Element: Identifiable {
    func uniquedByID() -> [Element] {
        var seen: Set<Element.ID> = []
        var result: [Element] = []
        for element in self where !seen.contains(element.id) {
            seen.insert(element.id)
            result.append(element)
        }
        return result
    }
}

private extension Array where Element == ReplacementActivity {
    func uniquedByTitle() -> [ReplacementActivity] {
        reduce(into: [ReplacementActivity]()) { result, activity in
            if !result.contains(where: { $0.title.caseInsensitiveCompare(activity.title) == .orderedSame }) {
                result.append(activity)
            }
        }
    }
}
