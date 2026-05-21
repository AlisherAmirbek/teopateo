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

    private func fixedDate(_ seconds: Int) -> Date {
        Date(timeIntervalSince1970: TimeInterval(seconds))
    }

    private func fixedUUID(_ value: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", value))!
    }
}
