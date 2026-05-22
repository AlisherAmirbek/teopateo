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
    private let now: () -> Date
    private let calendar: Calendar
    private var quitPlan = TeoPateoStore.defaultQuitPlan()
    private var isHydrating = false
    private static let estimatedCostPerCigarette = 0.50

    convenience init() {
        do {
            try self.init(repository: SQLiteTeoPateoRepository.live())
        } catch {
            self.init(repository: InMemoryTeoPateoRepository())
            persistenceError = error.localizedDescription
        }
    }

    init(
        repository: TeoPateoRepository,
        now: @escaping () -> Date = Date.init,
        calendar: Calendar = .current
    ) {
        self.repository = repository
        self.now = now
        self.calendar = calendar
        hydrateFromPersistence()
    }

    var metrics: [ProgressMetric] {
        let insights = calculatedInsights
        return [
            ProgressMetric(label: "Smoke-free", value: insights.smokeFreeSummary),
            ProgressMetric(label: "Cravings handled", value: "\(insights.cravingsHandled)"),
            ProgressMetric(label: "Saved", value: insights.moneySavedSummary)
        ]
    }

    var calculatedInsights: CalculatedInsights {
        Self.calculateInsights(
            dailyCheckIns: dailyCheckIns,
            cravingEvents: cravingEvents,
            triggerRules: triggerRules,
            now: now(),
            calendar: calendar
        )
    }

    @discardableResult
    func saveCheckIn(
        date: Date = Date(),
        focusNote: String,
        slipNote: String
    ) -> Bool {
        let now = now()
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
        let now = now()
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
        quitPlan.updatedAt = now()

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

    private static func calculateInsights(
        dailyCheckIns: [DailyCheckIn],
        cravingEvents: [CravingEvent],
        triggerRules: [TriggerRule],
        now: Date,
        calendar: Calendar
    ) -> CalculatedInsights {
        let checkInsByDay = latestCheckInsByDay(dailyCheckIns, calendar: calendar)
        let smokeFreeDays = smokeFreeStreakDays(
            from: checkInsByDay,
            now: now,
            calendar: calendar
        )
        let cravingsHandled = cravingEvents.filter(\.completedWithoutSmoking).count
        let smokeFreeCheckInDays = checkInsByDay.values.filter { $0.smokedToday == false }.count
        let cigarettesAvoided = smokeFreeCheckInDays + cravingsHandled
        let moneySaved = Double(cigarettesAvoided) * estimatedCostPerCigarette
        let riskWindows = calculatedRiskWindows(
            from: cravingEvents,
            calendar: calendar
        )
        let topTriggers = calculatedTopTriggers(from: cravingEvents)

        return CalculatedInsights(
            smokeFreeDays: smokeFreeDays,
            smokeFreeSummary: daySummary(smokeFreeDays),
            cravingsLogged: cravingEvents.count,
            cravingsHandled: cravingsHandled,
            cigarettesAvoided: cigarettesAvoided,
            moneySaved: moneySaved,
            moneySavedSummary: moneySummary(moneySaved),
            riskWindows: riskWindows,
            topTriggers: topTriggers,
            heatMapDays: calculatedHeatMapDays(
                from: cravingEvents,
                now: now,
                calendar: calendar
            ),
            planAdjustment: calculatedPlanAdjustment(
                topTriggers: topTriggers,
                riskWindows: riskWindows,
                triggerRules: triggerRules
            )
        )
    }

    private static func latestCheckInsByDay(
        _ checkIns: [DailyCheckIn],
        calendar: Calendar
    ) -> [Date: DailyCheckIn] {
        checkIns.reduce(into: [:]) { result, checkIn in
            let day = calendar.startOfDay(for: checkIn.date)
            guard let existing = result[day] else {
                result[day] = checkIn
                return
            }

            if checkIn.updatedAt > existing.updatedAt ||
                (checkIn.updatedAt == existing.updatedAt && checkIn.createdAt > existing.createdAt) {
                result[day] = checkIn
            }
        }
    }

    private static func smokeFreeStreakDays(
        from checkInsByDay: [Date: DailyCheckIn],
        now: Date,
        calendar: Calendar
    ) -> Int {
        let today = calendar.startOfDay(for: now)
        let recordedDays = checkInsByDay.keys.filter { $0 <= today }

        guard var cursor = recordedDays.max() else {
            return 0
        }

        var streak = 0
        while let checkIn = checkInsByDay[cursor], checkIn.smokedToday == false {
            streak += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: cursor) else {
                break
            }
            cursor = previousDay
        }

        return streak
    }

    private static func calculatedRiskWindows(
        from cravingEvents: [CravingEvent],
        calendar: Calendar
    ) -> [RiskWindowInsight] {
        guard !cravingEvents.isEmpty else {
            return []
        }

        let counts = cravingEvents.reduce(into: [Int: Int]()) { result, event in
            let hour = calendar.component(.hour, from: event.startedAt)
            result[hour, default: 0] += 1
        }
        let total = Double(cravingEvents.count)

        return counts
            .map { hour, count in
                RiskWindowInsight(
                    startHour: hour,
                    cravingCount: count,
                    share: Double(count) / total
                )
            }
            .sorted {
                if $0.cravingCount != $1.cravingCount {
                    return $0.cravingCount > $1.cravingCount
                }
                return $0.startHour < $1.startHour
            }
            .prefix(3)
            .map { $0 }
    }

    private static func calculatedTopTriggers(from cravingEvents: [CravingEvent]) -> [TriggerInsight] {
        guard !cravingEvents.isEmpty else {
            return []
        }

        var counts: [String: Int] = [:]
        for event in cravingEvents {
            let uniqueTriggers = Set(
                event.selectedTriggers.map {
                    $0.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                    .filter { !$0.isEmpty }
            )
            for trigger in uniqueTriggers {
                counts[trigger, default: 0] += 1
            }
        }

        let total = Double(cravingEvents.count)
        return counts
            .map { trigger, count in
                TriggerInsight(
                    name: trigger,
                    count: count,
                    share: Double(count) / total
                )
            }
            .sorted {
                if $0.count != $1.count {
                    return $0.count > $1.count
                }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
            .prefix(4)
            .map { $0 }
    }

    private static func calculatedHeatMapDays(
        from cravingEvents: [CravingEvent],
        now: Date,
        calendar: Calendar
    ) -> [CravingHeatDay] {
        let today = calendar.startOfDay(for: now)
        guard let firstDay = calendar.date(byAdding: .day, value: -27, to: today) else {
            return []
        }

        let countsByDay = cravingEvents.reduce(into: [Date: Int]()) { result, event in
            let day = calendar.startOfDay(for: event.startedAt)
            guard day >= firstDay && day <= today else {
                return
            }
            result[day, default: 0] += 1
        }

        return (0..<28).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: firstDay) else {
                return nil
            }
            let count = countsByDay[date, default: 0]
            return CravingHeatDay(date: date, count: count, level: min(count, 4))
        }
    }

    private static func calculatedPlanAdjustment(
        topTriggers: [TriggerInsight],
        riskWindows: [RiskWindowInsight],
        triggerRules: [TriggerRule]
    ) -> PlanAdjustmentInsight {
        if let topTrigger = topTriggers.first {
            if let existingRule = matchingRule(for: topTrigger.name, in: triggerRules) {
                return PlanAdjustmentInsight(
                    title: "Rehearse the \(topTrigger.name.lowercased()) rule",
                    detail: "\(topTrigger.name) appears in \(topTrigger.shareSummary) of logged cravings. Keep this rule ready: \(existingRule.action)",
                    actionTitle: "Open plan"
                )
            }

            let windowText = riskWindows.first.map { " around \($0.startLabel)" } ?? ""
            return PlanAdjustmentInsight(
                title: "Add a \(topTrigger.name.lowercased()) rule",
                detail: "\(topTrigger.name) is your most frequent logged trigger. Choose one replacement action and one support contact\(windowText).",
                actionTitle: "Open plan"
            )
        }

        if let riskWindow = riskWindows.first {
            return PlanAdjustmentInsight(
                title: "Prepare for \(riskWindow.startLabel)",
                detail: "This window has the highest share of logged cravings. Put one substitute activity and one support contact in your plan before it starts.",
                actionTitle: "Open plan"
            )
        }

        return PlanAdjustmentInsight(
            title: "Build the pattern map",
            detail: "Log a few cravings with triggers selected. TeoPateo will turn them into a specific plan adjustment here.",
            actionTitle: "Open plan"
        )
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

    private static func daySummary(_ days: Int) -> String {
        days == 1 ? "1 day" : "\(days) days"
    }

    private static func moneySummary(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = .current
        formatter.minimumFractionDigits = amount.rounded() == amount ? 0 : 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
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
