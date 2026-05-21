import Foundation

final class TeoPateoStore: ObservableObject {
    @Published var selectedTab: AppTab = .today
    @Published var isCravingModePresented = false
    @Published var quitMode = "Taper" {
        didSet {
            updateQuitMode()
        }
    }
    @Published var mood = 6.0
    @Published var stress = 7.0
    @Published var confidence = 5.0
    @Published var smokedToday: Bool?
    @Published var selectedTriggers: Set<String> = ["Coffee", "Work stress"]
    @Published private(set) var triggerRules: [TriggerRule] = []
    @Published private(set) var supportContacts: [SupportContact] = []
    @Published private(set) var userReasons: [UserReason] = []
    @Published private(set) var dailyCheckIns: [DailyCheckIn] = []
    @Published private(set) var cravingEvents: [CravingEvent] = []
    @Published private(set) var coachMessages: [CoachMessage] = []
    @Published private(set) var persistenceError: String?

    private let repository: TeoPateoRepository
    private var quitPlan = TeoPateoStore.defaultQuitPlan()
    private var isHydrating = false

    convenience init() {
        do {
            try self.init(repository: SQLiteTeoPateoRepository.live())
        } catch {
            self.init(repository: InMemoryTeoPateoRepository())
            persistenceError = error.localizedDescription
        }
    }

    init(repository: TeoPateoRepository) {
        self.repository = repository
        hydrateFromPersistence()
    }

    var metrics: [ProgressMetric] {
        [
            ProgressMetric(label: "Smoke-free", value: smokeFreeSummary),
            ProgressMetric(label: "Cravings handled", value: "\(cravingEvents.count)"),
            ProgressMetric(label: "Saved", value: "$42")
        ]
    }

    @discardableResult
    func saveCheckIn(
        date: Date = Date(),
        focusNote: String,
        slipNote: String
    ) -> Bool {
        let now = Date()
        let checkIn = DailyCheckIn(
            date: date,
            mood: mood,
            stress: stress,
            confidence: confidence,
            smokedToday: smokedToday,
            focusNote: focusNote,
            slipNote: smokedToday == true ? slipNote : "",
            createdAt: now,
            updatedAt: now
        )

        do {
            try repository.saveDailyCheckIn(checkIn)
            dailyCheckIns = try repository.recentCheckIns(limit: 10_000)
            persistenceError = nil
            return true
        } catch {
            persistenceError = error.localizedDescription
            return false
        }
    }

    @discardableResult
    func completeCraving(
        startedAt: Date,
        completedAt: Date = Date(),
        durationSeconds: Int,
        completedWithoutSmoking: Bool
    ) -> Bool {
        let now = Date()
        let event = CravingEvent(
            startedAt: startedAt,
            completedAt: completedAt,
            durationSeconds: durationSeconds,
            selectedTriggers: selectedTriggers.sorted(),
            completedWithoutSmoking: completedWithoutSmoking,
            createdAt: now,
            updatedAt: now
        )

        do {
            try repository.saveCravingEvent(event)
            cravingEvents = try repository.recentCravingEvents(limit: 10_000)
            persistenceError = nil
            return true
        } catch {
            persistenceError = error.localizedDescription
            return false
        }
    }

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
        persistCoachMessages()
    }

    private func hydrateFromPersistence() {
        isHydrating = true
        defer { isHydrating = false }

        do {
            let snapshot = try repository.loadSnapshot()

            let loadedPlan = snapshot.quitPlan ?? Self.defaultQuitPlan()
            quitPlan = loadedPlan
            quitMode = loadedPlan.quitMode
            triggerRules = loadedPlan.triggerRules

            supportContacts = snapshot.supportContacts.isEmpty
                ? Self.defaultSupportContacts()
                : snapshot.supportContacts
            userReasons = snapshot.userReasons.isEmpty
                ? Self.defaultUserReasons()
                : snapshot.userReasons
            coachMessages = snapshot.coachMessages.isEmpty
                ? Self.defaultCoachMessages()
                : snapshot.coachMessages
            dailyCheckIns = snapshot.dailyCheckIns
            cravingEvents = snapshot.cravingEvents

            try persistDefaultsIfNeeded(snapshot: snapshot)
            persistenceError = nil
        } catch {
            persistenceError = error.localizedDescription
            applyDefaultState()
        }
    }

    private func applyDefaultState() {
        let plan = Self.defaultQuitPlan()
        quitPlan = plan
        quitMode = plan.quitMode
        triggerRules = plan.triggerRules
        supportContacts = Self.defaultSupportContacts()
        userReasons = Self.defaultUserReasons()
        coachMessages = Self.defaultCoachMessages()
        dailyCheckIns = []
        cravingEvents = []
    }

    private func persistDefaultsIfNeeded(snapshot: PersistedTeoPateoSnapshot) throws {
        if snapshot.quitPlan == nil {
            try repository.saveQuitPlan(quitPlan)
        }
        if snapshot.supportContacts.isEmpty {
            try repository.replaceSupportContacts(supportContacts)
        }
        if snapshot.userReasons.isEmpty {
            try repository.replaceUserReasons(userReasons)
        }
        if snapshot.coachMessages.isEmpty {
            try repository.replaceCoachMessages(coachMessages)
        }
    }

    private func updateQuitMode() {
        guard !isHydrating else { return }
        quitPlan.quitMode = quitMode
        quitPlan.updatedAt = Date()

        do {
            try repository.saveQuitPlan(quitPlan)
            persistenceError = nil
        } catch {
            persistenceError = error.localizedDescription
        }
    }

    private func persistCoachMessages() {
        do {
            try repository.replaceCoachMessages(coachMessages)
            persistenceError = nil
        } catch {
            persistenceError = error.localizedDescription
        }
    }

    private var smokeFreeSummary: String {
        guard let latestSmoke = dailyCheckIns.first(where: { $0.smokedToday == true }) else {
            return dailyCheckIns.isEmpty ? "0 days" : "\(dailyCheckIns.count) days"
        }

        let days = Calendar.current.dateComponents([.day], from: latestSmoke.date, to: Date()).day ?? 0
        return "\(max(days, 0)) days"
    }

    private static func defaultQuitPlan() -> QuitPlan {
        let now = Date()
        let quitDate = Calendar.current.date(byAdding: .day, value: 11, to: now) ?? now
        return QuitPlan(
            quitDate: quitDate,
            quitMode: "Taper",
            triggerRules: [
                TriggerRule(trigger: "After coffee", action: "Drink water first, wait 10 minutes, log the urge."),
                TriggerRule(trigger: "Leaving work", action: "Walk one block before checking messages."),
                TriggerRule(trigger: "Alcohol", action: "Text support before the first drink."),
                TriggerRule(trigger: "After meals", action: "Brush teeth or chew gum immediately.")
            ],
            medicationNote: "Nicotine replacement therapy and prescription quit medicines can help some people. Talk with a doctor, pharmacist, or quitline counselor before making medication decisions.",
            createdAt: now,
            updatedAt: now
        )
    }

    private static func defaultSupportContacts() -> [SupportContact] {
        [
            SupportContact(name: "Maya", detail: "Craving alert and evening check-in"),
            SupportContact(name: "1-800-QUIT-NOW", detail: "US quitline support")
        ]
    }

    private static func defaultUserReasons() -> [UserReason] {
        [
            UserReason(text: "I want mornings without chest tightness, and I want to keep promises I made when I was calm.")
        ]
    }

    private static func defaultCoachMessages() -> [CoachMessage] {
        [
            CoachMessage(
                text: "After work is your highest-risk pattern. Want to plan the first 10 minutes after you leave?",
                isUser: false
            )
        ]
    }
}

enum AppTab: String, CaseIterable {
    case today = "Today"
    case plan = "Plan"
    case checkIn = "Check-in"
    case insights = "Insights"
    case coach = "Coach"
}

private final class InMemoryTeoPateoRepository: TeoPateoRepository {
    private var quitPlan: QuitPlan?
    private var dailyCheckIns: [DailyCheckIn] = []
    private var cravingEvents: [CravingEvent] = []
    private var supportContacts: [SupportContact] = []
    private var userReasons: [UserReason] = []
    private var coachMessages: [CoachMessage] = []

    func schemaVersion() throws -> Int { 0 }
    func tableNames() throws -> Set<String> { [] }

    func loadSnapshot() throws -> PersistedTeoPateoSnapshot {
        PersistedTeoPateoSnapshot(
            quitPlan: quitPlan,
            dailyCheckIns: dailyCheckIns,
            cravingEvents: cravingEvents,
            supportContacts: supportContacts,
            userReasons: userReasons,
            coachMessages: coachMessages
        )
    }

    func fetchQuitPlan() throws -> QuitPlan? {
        quitPlan
    }

    func saveQuitPlan(_ plan: QuitPlan) throws {
        quitPlan = plan
    }

    func saveDailyCheckIn(_ checkIn: DailyCheckIn) throws {
        dailyCheckIns.removeAll { $0.id == checkIn.id }
        dailyCheckIns.append(checkIn)
    }

    func recentCheckIns(limit: Int) throws -> [DailyCheckIn] {
        Array(dailyCheckIns.sorted { $0.date > $1.date }.prefix(limit))
    }

    func saveCravingEvent(_ event: CravingEvent) throws {
        cravingEvents.removeAll { $0.id == event.id }
        cravingEvents.append(event)
    }

    func recentCravingEvents(limit: Int) throws -> [CravingEvent] {
        Array(cravingEvents.sorted { $0.startedAt > $1.startedAt }.prefix(limit))
    }

    func replaceSupportContacts(_ contacts: [SupportContact]) throws {
        supportContacts = contacts
    }

    func fetchSupportContacts() throws -> [SupportContact] {
        supportContacts
    }

    func replaceUserReasons(_ reasons: [UserReason]) throws {
        userReasons = reasons
    }

    func fetchUserReasons() throws -> [UserReason] {
        userReasons
    }

    func replaceCoachMessages(_ messages: [CoachMessage]) throws {
        coachMessages = messages
    }

    func fetchCoachMessages() throws -> [CoachMessage] {
        coachMessages
    }
}
