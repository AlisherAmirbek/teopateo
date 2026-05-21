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

struct TriggerRule: Identifiable, Codable, Equatable {
    let id: UUID
    let trigger: String
    let action: String
    var isEnabled: Bool = true

    init(id: UUID = UUID(), trigger: String, action: String, isEnabled: Bool = true) {
        self.id = id
        self.trigger = trigger
        self.action = action
        self.isEnabled = isEnabled
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
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        quitDate: Date,
        quitMode: String,
        triggerRules: [TriggerRule],
        medicationNote: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.quitDate = quitDate
        self.quitMode = quitMode
        self.triggerRules = triggerRules
        self.medicationNote = medicationNote
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct DailyCheckIn: Identifiable, Codable, Equatable {
    let id: UUID
    let date: Date
    let mood: Double
    let stress: Double
    let confidence: Double
    let smokedToday: Bool?
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
    let completedWithoutSmoking: Bool
    let createdAt: Date
    let updatedAt: Date

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
        self.id = id
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.durationSeconds = durationSeconds
        self.selectedTriggers = selectedTriggers
        self.completedWithoutSmoking = completedWithoutSmoking
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct SupportContact: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var detail: String
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        detail: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.detail = detail
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct UserReason: Identifiable, Codable, Equatable {
    let id: UUID
    var text: String
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        text: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.text = text
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct PersistedTeoPateoSnapshot: Equatable {
    var quitPlan: QuitPlan?
    var dailyCheckIns: [DailyCheckIn]
    var cravingEvents: [CravingEvent]
    var supportContacts: [SupportContact]
    var userReasons: [UserReason]
    var coachMessages: [CoachMessage]

    init(
        quitPlan: QuitPlan? = nil,
        dailyCheckIns: [DailyCheckIn] = [],
        cravingEvents: [CravingEvent] = [],
        supportContacts: [SupportContact] = [],
        userReasons: [UserReason] = [],
        coachMessages: [CoachMessage] = []
    ) {
        self.quitPlan = quitPlan
        self.dailyCheckIns = dailyCheckIns
        self.cravingEvents = cravingEvents
        self.supportContacts = supportContacts
        self.userReasons = userReasons
        self.coachMessages = coachMessages
    }
}
