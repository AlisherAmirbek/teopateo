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
    let text: String
    let isUser: Bool
    let createdAt: Date

    init(id: UUID = UUID(), text: String, isUser: Bool, createdAt: Date = Date()) {
        self.id = id
        self.text = text
        self.isUser = isUser
        self.createdAt = createdAt
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
    let focusNote: String
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
        focusNote: String,
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
        self.focusNote = focusNote
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
    var isInterestedInMedicationSupport: Bool

    init(
        cigarettesPerDay: Double,
        costPerPack: Double,
        quitDate: Date,
        quitMode: String,
        selectedTriggers: [String],
        primaryReason: String,
        isInterestedInMedicationSupport: Bool = false
    ) {
        self.cigarettesPerDay = cigarettesPerDay
        self.costPerPack = costPerPack
        self.quitDate = quitDate
        self.quitMode = quitMode
        self.selectedTriggers = selectedTriggers
        self.primaryReason = primaryReason
        self.isInterestedInMedicationSupport = isInterestedInMedicationSupport
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
    var quitPlan: QuitPlan?
    var dailyCheckIns: [DailyCheckIn]
    var cravingEvents: [CravingEvent]
    var slipEvents: [SlipEvent]
    var replacementActivities: [ReplacementActivity]
    var supportContacts: [SupportContact]
    var userReasons: [UserReason]
    var coachMessages: [CoachMessage]

    init(
        appSettings: AppSettings? = nil,
        quitPlan: QuitPlan? = nil,
        dailyCheckIns: [DailyCheckIn] = [],
        cravingEvents: [CravingEvent] = [],
        slipEvents: [SlipEvent] = [],
        replacementActivities: [ReplacementActivity] = [],
        supportContacts: [SupportContact] = [],
        userReasons: [UserReason] = [],
        coachMessages: [CoachMessage] = []
    ) {
        self.appSettings = appSettings
        self.quitPlan = quitPlan
        self.dailyCheckIns = dailyCheckIns
        self.cravingEvents = cravingEvents
        self.slipEvents = slipEvents
        self.replacementActivities = replacementActivities
        self.supportContacts = supportContacts
        self.userReasons = userReasons
        self.coachMessages = coachMessages
    }
}
