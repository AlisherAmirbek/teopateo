import XCTest
@testable import TeoPateo

final class LocalPersistenceTests: XCTestCase {
    private var temporaryDirectory: URL!
    private var databaseURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true
        )
        databaseURL = temporaryDirectory.appendingPathComponent("teopateo.sqlite")
    }

    override func tearDownWithError() throws {
        if let temporaryDirectory {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
        try super.tearDownWithError()
    }

    func testMigrationCreatesDurableLocalTables() throws {
        let repository = try makeRepository()

        let expectedTables: Set<String> = [
            "quit_plans",
            "trigger_rules",
            "daily_check_ins",
            "craving_events",
            "craving_event_triggers",
            "support_contacts",
            "user_reasons",
            "coach_messages"
        ]

        XCTAssertEqual(try repository.schemaVersion(), 1)
        XCTAssertTrue(try repository.tableNames().isSuperset(of: expectedTables))
    }

    func testQuitPlanRoundTripsWithTriggerRulesSupportAndReasons() throws {
        let repository = try makeRepository()
        let plan = makeQuitPlan(quitMode: "Cold turkey")
        let contacts = [
            SupportContact(
                id: fixedUUID(20),
                name: "Maya",
                detail: "Craving alert",
                createdAt: fixedDate(20),
                updatedAt: fixedDate(21)
            )
        ]
        let reasons = [
            UserReason(
                id: fixedUUID(30),
                text: "Run without chest tightness",
                createdAt: fixedDate(30),
                updatedAt: fixedDate(31)
            )
        ]

        try repository.saveQuitPlan(plan)
        try repository.replaceSupportContacts(contacts)
        try repository.replaceUserReasons(reasons)

        XCTAssertEqual(try repository.fetchQuitPlan(), plan)
        XCTAssertEqual(try repository.fetchSupportContacts(), contacts)
        XCTAssertEqual(try repository.fetchUserReasons(), reasons)
    }

    func testDailyCheckInPersistsEverySubmittedField() throws {
        let repository = try makeRepository()
        let checkIn = DailyCheckIn(
            id: fixedUUID(40),
            date: fixedDate(40),
            mood: 8,
            stress: 6,
            confidence: 7,
            smokedToday: true,
            focusNote: "Delay the first cigarette by 10 minutes.",
            slipNote: "Bought cigarettes after a stressful commute.",
            createdAt: fixedDate(41),
            updatedAt: fixedDate(42)
        )

        try repository.saveDailyCheckIn(checkIn)

        XCTAssertEqual(try repository.recentCheckIns(limit: 10), [checkIn])
    }

    func testCravingEventPersistsOutcomeAndOrderedTriggers() throws {
        let repository = try makeRepository()
        let event = CravingEvent(
            id: fixedUUID(50),
            startedAt: fixedDate(50),
            completedAt: fixedDate(51),
            durationSeconds: 480,
            selectedTriggers: ["Coffee", "Work stress", "After meal"],
            completedWithoutSmoking: true,
            createdAt: fixedDate(52),
            updatedAt: fixedDate(53)
        )

        try repository.saveCravingEvent(event)

        XCTAssertEqual(try repository.recentCravingEvents(limit: 10), [event])
    }

    func testCoachMessagesPersistInConversationOrder() throws {
        let repository = try makeRepository()
        let messages = [
            CoachMessage(
                id: fixedUUID(60),
                text: "After work is your risky window.",
                isUser: false,
                createdAt: fixedDate(60)
            ),
            CoachMessage(
                id: fixedUUID(61),
                text: "I am craving after coffee.",
                isUser: true,
                createdAt: fixedDate(61)
            )
        ]

        try repository.replaceCoachMessages(messages)

        XCTAssertEqual(try repository.fetchCoachMessages(), messages)
    }

    func testStoreLoadsPersistedPlanAndWritesCheckInAndCravingEvents() throws {
        let repository = try makeRepository()
        let plan = makeQuitPlan(quitMode: "Cold turkey")
        try repository.saveQuitPlan(plan)

        let store = TeoPateoStore(repository: repository)

        XCTAssertEqual(store.quitMode, "Cold turkey")
        XCTAssertEqual(store.triggerRules, plan.triggerRules)

        store.mood = 9
        store.stress = 4
        store.confidence = 8
        store.smokedToday = false

        XCTAssertTrue(store.saveCheckIn(
            date: fixedDate(70),
            focusNote: "Take a walk before opening messages.",
            slipNote: "Should not be saved when no smoke was recorded."
        ))

        let checkIns = try repository.recentCheckIns(limit: 10)
        XCTAssertEqual(checkIns.count, 1)
        XCTAssertEqual(checkIns[0].mood, 9)
        XCTAssertEqual(checkIns[0].stress, 4)
        XCTAssertEqual(checkIns[0].confidence, 8)
        XCTAssertEqual(checkIns[0].smokedToday, false)
        XCTAssertEqual(checkIns[0].focusNote, "Take a walk before opening messages.")
        XCTAssertEqual(checkIns[0].slipNote, "")

        store.selectedTriggers = ["Coffee", "Social"]
        XCTAssertTrue(store.completeCraving(
            startedAt: fixedDate(80),
            completedAt: fixedDate(81),
            durationSeconds: 600,
            completedWithoutSmoking: true
        ))

        let cravings = try repository.recentCravingEvents(limit: 10)
        XCTAssertEqual(cravings.count, 1)
        XCTAssertEqual(Set(cravings[0].selectedTriggers), ["Coffee", "Social"])
        XCTAssertTrue(cravings[0].completedWithoutSmoking)
    }

    func testStoreCalculatesInsightsFromPersistedHistory() throws {
        let repository = try makeRepository()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = makeDate(year: 2026, month: 5, day: 22, hour: 18, calendar: calendar)

        try repository.saveDailyCheckIn(makeCheckIn(
            id: 90,
            date: makeDate(year: 2026, month: 5, day: 18, calendar: calendar),
            smokedToday: true
        ))
        try repository.saveDailyCheckIn(makeCheckIn(
            id: 91,
            date: makeDate(year: 2026, month: 5, day: 19, calendar: calendar),
            smokedToday: false
        ))
        try repository.saveDailyCheckIn(makeCheckIn(
            id: 92,
            date: makeDate(year: 2026, month: 5, day: 20, calendar: calendar),
            smokedToday: false
        ))
        try repository.saveDailyCheckIn(makeCheckIn(
            id: 93,
            date: makeDate(year: 2026, month: 5, day: 21, calendar: calendar),
            smokedToday: false
        ))
        try repository.saveDailyCheckIn(makeCheckIn(
            id: 94,
            date: makeDate(year: 2026, month: 5, day: 22, calendar: calendar),
            smokedToday: false
        ))

        try repository.saveCravingEvent(makeCraving(
            id: 100,
            startedAt: makeDate(year: 2026, month: 5, day: 20, hour: 21, calendar: calendar),
            triggers: ["Coffee", "Work stress"],
            completedWithoutSmoking: true
        ))
        try repository.saveCravingEvent(makeCraving(
            id: 101,
            startedAt: makeDate(year: 2026, month: 5, day: 21, hour: 21, calendar: calendar),
            triggers: ["Coffee"],
            completedWithoutSmoking: true
        ))
        try repository.saveCravingEvent(makeCraving(
            id: 102,
            startedAt: makeDate(year: 2026, month: 5, day: 22, hour: 18, calendar: calendar),
            triggers: ["Social"],
            completedWithoutSmoking: false
        ))
        try repository.saveCravingEvent(makeCraving(
            id: 103,
            startedAt: makeDate(year: 2026, month: 5, day: 22, hour: 21, calendar: calendar),
            triggers: ["Work stress"],
            completedWithoutSmoking: true
        ))

        let store = TeoPateoStore(
            repository: repository,
            now: { now },
            calendar: calendar
        )

        let insights = store.calculatedInsights

        XCTAssertEqual(insights.smokeFreeDays, 4)
        XCTAssertEqual(insights.smokeFreeSummary, "4 days")
        XCTAssertEqual(insights.cravingsLogged, 4)
        XCTAssertEqual(insights.cravingsHandled, 3)
        XCTAssertEqual(insights.cigarettesAvoided, 7)
        XCTAssertEqual(insights.moneySaved, 3.5, accuracy: 0.001)
        XCTAssertEqual(insights.riskWindows.first?.startHour, 21)
        XCTAssertEqual(insights.riskWindows.first?.cravingCount, 3)
        XCTAssertEqual(insights.riskWindows.first?.shareSummary, "75%")
        XCTAssertEqual(insights.topTriggers.first?.name, "Coffee")
        XCTAssertEqual(insights.topTriggers.first?.count, 2)
        XCTAssertEqual(insights.topTriggers.first?.shareSummary, "50%")
        XCTAssertEqual(insights.heatMapDays.last?.count, 2)
        XCTAssertEqual(insights.heatMapDays.last?.level, 2)
    }

    private func makeRepository() throws -> SQLiteTeoPateoRepository {
        try SQLiteTeoPateoRepository(databaseURL: databaseURL)
    }

    private func makeQuitPlan(quitMode: String) -> QuitPlan {
        QuitPlan(
            id: fixedUUID(1),
            quitDate: fixedDate(10),
            quitMode: quitMode,
            triggerRules: [
                TriggerRule(
                    id: fixedUUID(2),
                    trigger: "After coffee",
                    action: "Drink water first.",
                    isEnabled: true
                ),
                TriggerRule(
                    id: fixedUUID(3),
                    trigger: "Leaving work",
                    action: "Walk one block.",
                    isEnabled: false
                )
            ],
            medicationNote: "Ask a clinician before medication decisions.",
            createdAt: fixedDate(1),
            updatedAt: fixedDate(2)
        )
    }

    private func makeCheckIn(
        id: Int,
        date: Date,
        smokedToday: Bool
    ) -> DailyCheckIn {
        DailyCheckIn(
            id: fixedUUID(id),
            date: date,
            mood: 7,
            stress: 5,
            confidence: 8,
            smokedToday: smokedToday,
            focusNote: "Use the rescue plan.",
            slipNote: smokedToday ? "Smoked after a trigger." : "",
            createdAt: fixedDate(id),
            updatedAt: fixedDate(id + 1)
        )
    }

    private func makeCraving(
        id: Int,
        startedAt: Date,
        triggers: [String],
        completedWithoutSmoking: Bool
    ) -> CravingEvent {
        CravingEvent(
            id: fixedUUID(id),
            startedAt: startedAt,
            completedAt: startedAt.addingTimeInterval(600),
            durationSeconds: 600,
            selectedTriggers: triggers,
            completedWithoutSmoking: completedWithoutSmoking,
            createdAt: fixedDate(id),
            updatedAt: fixedDate(id + 1)
        )
    }

    private func makeDate(
        year: Int,
        month: Int,
        day: Int,
        hour: Int = 12,
        calendar: Calendar
    ) -> Date {
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        return calendar.date(from: components)!
    }

    private func fixedDate(_ seconds: Int) -> Date {
        Date(timeIntervalSince1970: TimeInterval(seconds))
    }

    private func fixedUUID(_ value: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", value))!
    }
}
