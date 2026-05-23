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

    func testMigrationCreatesDurableFeatureTables() throws {
        let repository = try makeRepository()

        let expectedTables: Set<String> = [
            "quit_plans",
            "trigger_rules",
            "daily_check_ins",
            "craving_events",
            "craving_event_triggers",
            "slip_events",
            "slip_event_triggers",
            "replacement_activities",
            "support_contacts",
            "user_reasons",
            "coach_messages",
            "app_settings"
        ]

        XCTAssertEqual(try repository.schemaVersion(), 3)
        XCTAssertTrue(try repository.tableNames().isSuperset(of: expectedTables))
    }

    func testAppSettingsRoundTrip() throws {
        let repository = try makeRepository()
        let settings = AppSettings(
            onboardingCompleted: true,
            updatedAt: fixedDate(12)
        )

        XCTAssertEqual(try repository.fetchAppSettings()?.onboardingCompleted, false)

        try repository.saveAppSettings(settings)

        XCTAssertEqual(try repository.fetchAppSettings(), settings)
        XCTAssertEqual(try repository.loadSnapshot().appSettings, settings)
    }

    func testQuitPlanSupportReasonsAndActivitiesRoundTrip() throws {
        let repository = try makeRepository()
        let contactID = fixedUUID(20)
        let plan = makeQuitPlan(quitMode: "Cold turkey", supportContactID: contactID)
        let contacts = [
            SupportContact(
                id: contactID,
                name: "Maya",
                detail: "Craving alert",
                phoneNumber: "5551234567",
                preferredRole: .cravingAlert,
                defaultMessage: "Stay with me for 10 minutes.",
                createdAt: fixedDate(20),
                updatedAt: fixedDate(21)
            )
        ]
        let reasons = [
            UserReason(
                id: fixedUUID(30),
                text: "Run without chest tightness",
                sortOrder: 0,
                isPrimary: true,
                category: "health",
                createdAt: fixedDate(30),
                updatedAt: fixedDate(31)
            )
        ]
        let activities = [
            ReplacementActivity(
                id: fixedUUID(35),
                title: "Walk outside",
                instruction: "Walk one block before deciding.",
                category: .movement,
                durationSeconds: 600,
                linkedTrigger: "Work stress",
                createdAt: fixedDate(35),
                updatedAt: fixedDate(36)
            )
        ]

        try repository.saveQuitPlan(plan)
        try repository.replaceSupportContacts(contacts)
        try repository.replaceUserReasons(reasons)
        try repository.replaceReplacementActivities(activities)

        XCTAssertEqual(try repository.fetchQuitPlan(), plan)
        XCTAssertEqual(try repository.fetchSupportContacts(), contacts)
        XCTAssertEqual(try repository.fetchUserReasons(), reasons)
        XCTAssertEqual(try repository.fetchReplacementActivities(), activities)
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
            cigarettesSmoked: 2,
            focusNote: "Delay the first cigarette by 10 minutes.",
            slipNote: "Bought cigarettes after a stressful commute.",
            createdAt: fixedDate(41),
            updatedAt: fixedDate(42)
        )

        try repository.saveDailyCheckIn(checkIn)

        XCTAssertEqual(try repository.recentCheckIns(limit: 10), [checkIn])
    }

    func testCravingRecoveryPathPersistsOutcomeIntensityActivityAndSupport() throws {
        let repository = try makeRepository()
        let activityID = fixedUUID(35)
        let supportID = fixedUUID(20)
        let event = CravingEvent(
            id: fixedUUID(50),
            startedAt: fixedDate(50),
            completedAt: fixedDate(51),
            durationSeconds: 480,
            selectedTriggers: ["Coffee", "Work stress", "After meal"],
            outcome: .smokedAfterCraving,
            initialIntensity: 9,
            finalIntensity: 5,
            helpedActivityID: activityID,
            supportContactID: supportID,
            reflectionNote: "Walk helped, but I still smoked after coffee.",
            createdAt: fixedDate(52),
            updatedAt: fixedDate(53)
        )

        try repository.saveCravingEvent(event)

        XCTAssertEqual(try repository.recentCravingEvents(limit: 10), [event])
    }

    func testStructuredSlipRecoveryPersistsContextAndTriggers() throws {
        let repository = try makeRepository()
        let event = SlipEvent(
            id: fixedUUID(60),
            occurredAt: fixedDate(60),
            cigarettesSmoked: 2,
            selectedTriggers: ["Alcohol", "Social"],
            mood: 4,
            stress: 8,
            context: "Dinner with friends",
            note: "Smoked when others went outside.",
            recoveryAction: "Text support before the next drink.",
            createdAt: fixedDate(61),
            updatedAt: fixedDate(62)
        )

        try repository.saveSlipEvent(event)

        XCTAssertEqual(try repository.recentSlipEvents(limit: 10), [event])
    }

    func testStoreSupportMotivationAndActivityLibrary() throws {
        let store = TeoPateoStore(repository: try makeRepository())

        store.addSupportContact(
            name: "Sam",
            detail: "Backup for late cravings",
            phoneNumber: "5550001111",
            preferredRole: .backup,
            defaultMessage: "Can you check in with me tonight?"
        )
        XCTAssertTrue(store.supportContacts.contains { $0.name == "Sam" })

        let firstContact = try XCTUnwrap(store.supportContacts.first)
        store.draftSupportMessage(for: firstContact)
        XCTAssertFalse(store.supportMessageDraft.isEmpty)

        store.addUserReason("I want to hike without wheezing.", isPrimary: true)
        XCTAssertEqual(store.reasonForCravingMode(), "I want to hike without wheezing.")
        let addedReason = try XCTUnwrap(store.userReasons.first { $0.text == "I want to hike without wheezing." })
        store.deleteUserReason(addedReason.id)
        XCTAssertFalse(store.userReasons.contains(addedReason))
        XCTAssertTrue(store.userReasons.contains(where: \.isPrimary))

        store.addReplacementActivity(
            title: "Chew gum",
            instruction: "Chew gum until the timer reaches 5:00.",
            category: .sensory,
            linkedTrigger: "Coffee"
        )
        let activities = store.activitiesForCurrentCraving(triggers: ["Coffee"])
        XCTAssertTrue(activities.contains { $0.title == "Chew gum" || $0.title == "Drink cold water" })
    }

    func testStoreCompletesOnboardingIntoActionablePlan() throws {
        let repository = try makeRepository()
        let store = TeoPateoStore(repository: repository)

        XCTAssertFalse(store.isOnboardingCompleted)

        XCTAssertTrue(store.completeOnboarding(
            OnboardingPlanInput(
                cigarettesPerDay: 12,
                costPerPack: 14,
                quitDate: fixedDate(200),
                quitMode: "Cold turkey",
                selectedTriggers: ["Coffee", "Work stress"],
                primaryReason: "I want to breathe easier.",
                isInterestedInMedicationSupport: true
            )
        ))

        XCTAssertTrue(store.isOnboardingCompleted)
        XCTAssertFalse(store.isOnboardingPresented)
        XCTAssertEqual(store.currentQuitPlan.quitMode, "Cold turkey")
        XCTAssertEqual(store.currentQuitPlan.baselineCigarettesPerDay, 12)
        XCTAssertEqual(store.currentQuitPlan.costPerPack, 14)
        XCTAssertEqual(store.triggerRules.map(\.trigger), ["Coffee", "Work stress"])
        XCTAssertEqual(store.userReasons.first?.text, "I want to breathe easier.")
        XCTAssertTrue(store.supportContacts.isEmpty)
        XCTAssertTrue(store.replacementActivities.contains { $0.linkedTrigger == "Coffee" })
        XCTAssertTrue(store.currentQuitPlan.medicationNote.contains("You marked interest"))

        let reloadedStore = TeoPateoStore(repository: repository)
        XCTAssertTrue(reloadedStore.isOnboardingCompleted)
        XCTAssertEqual(reloadedStore.currentQuitPlan.quitMode, "Cold turkey")
        XCTAssertEqual(reloadedStore.userReasons.first?.text, "I want to breathe easier.")
        XCTAssertTrue(reloadedStore.supportContacts.isEmpty)
    }

    func testStoreRecordsCravingSlipAndHistory() throws {
        let store = TeoPateoStore(repository: try makeRepository())
        let activityID = try XCTUnwrap(store.replacementActivities.first?.id)
        let supportID = try XCTUnwrap(store.supportContactForCraving()?.id)

        store.startCravingSession()
        store.selectedTriggers = ["Coffee"]
        XCTAssertTrue(store.completeCravingWithoutSmoking(
            startedAt: fixedDate(70),
            completedAt: fixedDate(71),
            durationSeconds: 600,
            initialIntensity: 8,
            finalIntensity: 2,
            helpedActivityID: activityID,
            supportContactID: supportID,
            reflectionNote: "Water helped."
        ))

        XCTAssertEqual(store.cravingEvents.first?.outcome, .completedWithoutSmoking)
        XCTAssertEqual(store.cravingEvents.first?.initialIntensity, 8)

        store.selectedTriggers = ["Work stress"]
        XCTAssertTrue(store.completeCravingWithSlip(
            startedAt: fixedDate(80),
            completedAt: fixedDate(81),
            durationSeconds: 120,
            cigarettesSmoked: 1,
            slipNote: "Smoked after work.",
            recoveryAction: "Walk before checking messages."
        ))

        XCTAssertEqual(store.slipEvents.count, 1)
        XCTAssertTrue(store.historyEntries().contains { $0.kind == .slip })
        XCTAssertTrue(store.historyEntries().contains { $0.kind == .craving })
    }

    func testStoreCheckInFeedbackAndSameDayUpsert() throws {
        let store = TeoPateoStore(repository: try makeRepository())

        XCTAssertFalse(store.saveCheckIn(
            date: fixedDate(90),
            focusNote: "No status yet.",
            slipNote: ""
        ))
        XCTAssertTrue(store.lastSaveStatus.isFailure)

        store.smokedToday = false
        XCTAssertTrue(store.saveCheckIn(
            date: fixedDate(90),
            focusNote: "Use rescue plan.",
            slipNote: "Ignored because no smoke."
        ))
        XCTAssertEqual(store.dailyCheckIns.count, 1)
        XCTAssertEqual(store.dailyCheckIns[0].slipNote, "")

        store.mood = 9
        XCTAssertTrue(store.saveCheckIn(
            date: fixedDate(90),
            focusNote: "Updated focus.",
            slipNote: ""
        ))
        XCTAssertEqual(store.dailyCheckIns.count, 1)
        XCTAssertEqual(store.dailyCheckIns[0].mood, 9)
    }

    func testStoreCalculatesDeeperInsightsRiskAndProgress() throws {
        let repository = try makeRepository()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = makeDate(year: 2026, month: 5, day: 22, hour: 21, calendar: calendar)

        try repository.saveQuitPlan(makeQuitPlan(quitMode: "Taper"))
        try repository.saveDailyCheckIn(makeCheckIn(
            id: 90,
            date: makeDate(year: 2026, month: 5, day: 20, calendar: calendar),
            smokedToday: false
        ))
        try repository.saveDailyCheckIn(makeCheckIn(
            id: 91,
            date: makeDate(year: 2026, month: 5, day: 21, calendar: calendar),
            smokedToday: false
        ))
        try repository.saveDailyCheckIn(DailyCheckIn(
            id: fixedUUID(92),
            date: makeDate(year: 2026, month: 5, day: 22, calendar: calendar),
            mood: 4,
            stress: 9,
            confidence: 3,
            smokedToday: false,
            focusNote: "Use support.",
            slipNote: "",
            createdAt: fixedDate(92),
            updatedAt: fixedDate(93)
        ))

        try repository.saveCravingEvent(makeCraving(
            id: 100,
            startedAt: makeDate(year: 2026, month: 5, day: 21, hour: 21, calendar: calendar),
            triggers: ["Coffee", "Work stress"],
            completedWithoutSmoking: true
        ))
        try repository.saveCravingEvent(makeCraving(
            id: 101,
            startedAt: makeDate(year: 2026, month: 5, day: 22, hour: 21, calendar: calendar),
            triggers: ["Coffee"],
            completedWithoutSmoking: true
        ))
        try repository.saveSlipEvent(SlipEvent(
            id: fixedUUID(110),
            occurredAt: makeDate(year: 2026, month: 5, day: 22, hour: 20, calendar: calendar),
            cigarettesSmoked: 1,
            selectedTriggers: ["Coffee"],
            note: "Smoked after coffee.",
            recoveryAction: "Drink water first.",
            createdAt: fixedDate(110),
            updatedAt: fixedDate(111)
        ))

        let store = TeoPateoStore(
            repository: repository,
            now: { now },
            calendar: calendar
        )

        let insights = store.calculatedInsights

        XCTAssertEqual(insights.smokeFreeDays, 3)
        XCTAssertEqual(insights.cravingsLogged, 2)
        XCTAssertEqual(insights.cravingsHandled, 2)
        XCTAssertEqual(insights.cigarettesAvoided, 16)
        XCTAssertEqual(insights.moneySaved, 8, accuracy: 0.001)
        XCTAssertEqual(insights.moneySavedSummary, "$8")
        XCTAssertEqual(insights.riskWindows.first?.startHour, 21)
        XCTAssertEqual(insights.topSlipTriggers.first?.name, "Coffee")
        XCTAssertEqual(insights.todayRisk.level, .high)
        XCTAssertEqual(insights.dataConfidenceSummary, "Useful early signal from recent history.")
        XCTAssertTrue(store.progressSummary.milestones.contains("First craving handled"))
    }

    func testHistoryDeleteRemovesAccidentalRecords() throws {
        let store = TeoPateoStore(repository: try makeRepository())

        store.smokedToday = false
        XCTAssertTrue(store.saveCheckIn(date: fixedDate(120), focusNote: "A", slipNote: ""))
        store.selectedTriggers = ["Social"]
        XCTAssertTrue(store.completeCravingWithoutSmoking(
            startedAt: fixedDate(121),
            completedAt: fixedDate(122),
            durationSeconds: 60
        ))

        let checkInID = try XCTUnwrap(store.dailyCheckIns.first?.id)
        let cravingID = try XCTUnwrap(store.cravingEvents.first?.id)
        XCTAssertEqual(store.historyEntries().count, 2)

        store.deleteDailyCheckIn(checkInID)
        store.deleteCravingEvent(cravingID)

        XCTAssertTrue(store.dailyCheckIns.isEmpty)
        XCTAssertTrue(store.cravingEvents.isEmpty)
        XCTAssertTrue(store.historyEntries().isEmpty)
    }

    private func makeRepository() throws -> SQLiteTeoPateoRepository {
        try SQLiteTeoPateoRepository(databaseURL: databaseURL)
    }

    private func makeQuitPlan(
        quitMode: String,
        supportContactID: UUID? = nil
    ) -> QuitPlan {
        QuitPlan(
            id: fixedUUID(1),
            quitDate: fixedDate(10),
            quitMode: quitMode,
            triggerRules: [
                TriggerRule(
                    id: fixedUUID(2),
                    trigger: "After coffee",
                    action: "Drink water first.",
                    isEnabled: true,
                    supportContactID: supportContactID
                ),
                TriggerRule(
                    id: fixedUUID(3),
                    trigger: "Leaving work",
                    action: "Walk one block.",
                    isEnabled: false
                )
            ],
            medicationNote: "Ask a clinician before medication decisions.",
            baselineCigarettesPerDay: 5,
            costPerPack: 10,
            cigarettesPerPack: 20,
            taperTargetCigarettesPerDay: 3,
            taperReductionStep: 1,
            taperReductionIntervalDays: 2,
            attemptStartedAt: fixedDate(5),
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
