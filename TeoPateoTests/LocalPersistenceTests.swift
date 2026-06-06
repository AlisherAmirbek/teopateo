import XCTest
@testable import TeoPateo

@MainActor
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
            "coach_chats",
            "coach_messages",
            "app_settings",
            "notification_settings",
            "privacy_settings",
            "risky_situations",
            "user_profile",
            "quit_readiness",
            "smoking_background",
            "savings_goal"
        ]

        XCTAssertEqual(try repository.schemaVersion(), 10)
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

    func testNotificationSettingsRoundTrip() throws {
        let repository = try makeRepository()
        let settings = NotificationSettings(
            morningPlanEnabled: true,
            riskyWindowEnabled: true,
            postMealEnabled: false,
            eveningCheckInEnabled: true,
            morningPlanTime: ReminderTime(hour: 7, minute: 45),
            postMealTime: ReminderTime(hour: 14, minute: 10),
            eveningCheckInTime: ReminderTime(hour: 21, minute: 5),
            updatedAt: fixedDate(15)
        )

        XCTAssertEqual(try repository.fetchNotificationSettings()?.morningPlanEnabled, false)

        try repository.saveNotificationSettings(settings)

        XCTAssertEqual(try repository.fetchNotificationSettings(), settings)
        XCTAssertEqual(try repository.loadSnapshot().notificationSettings, settings)
    }

    func testPrivacySettingsRoundTrip() throws {
        let repository = try makeRepository()
        let settings = PrivacySettings(
            coachDataConsentStatus: .granted,
            coachDataConsentUpdatedAt: fixedDate(16),
            policyVersion: "test-policy",
            updatedAt: fixedDate(17)
        )

        XCTAssertEqual(try repository.fetchPrivacySettings()?.coachDataConsentStatus, .notDetermined)

        try repository.savePrivacySettings(settings)

        XCTAssertEqual(try repository.fetchPrivacySettings(), settings)
        XCTAssertEqual(try repository.loadSnapshot().privacySettings, settings)
    }

    func testCoachChatsRoundTripWithSelectedChat() throws {
        let repository = try makeRepository()
        let chats = [
            CoachChat(
                id: fixedUUID(80),
                title: "Coffee craving",
                messages: [
                    CoachMessage(
                        id: fixedUUID(81),
                        text: "I want to smoke after coffee.",
                        isUser: true,
                        createdAt: fixedDate(81)
                    ),
                    CoachMessage(
                        id: fixedUUID(82),
                        text: "**Start water first**, then walk for 10 minutes.",
                        isUser: false,
                        isReportedUnsafe: true,
                        createdAt: fixedDate(82)
                    )
                ],
                createdAt: fixedDate(80),
                updatedAt: fixedDate(82)
            ),
            CoachChat(
                id: fixedUUID(83),
                title: "Slip recovery",
                messages: [],
                createdAt: fixedDate(83),
                updatedAt: fixedDate(83)
            )
        ]

        try repository.replaceCoachChats(chats, selectedChatID: fixedUUID(83))

        XCTAssertEqual(try repository.fetchCoachChats(), chats)
        XCTAssertEqual(try repository.fetchSelectedCoachChatID(), fixedUUID(83))
        XCTAssertEqual(try repository.loadSnapshot().coachChats, chats)
        XCTAssertEqual(try repository.loadSnapshot().selectedCoachChatID, fixedUUID(83))
    }

    func testQuitPlanLegacyContactsReasonsAndActivitiesRoundTrip() throws {
        let repository = try makeRepository()
        let contactID = fixedUUID(20)
        let plan = makeQuitPlan(quitMode: "Cold turkey", supportContactID: contactID)
        let contacts = [
            SupportContact(
                id: contactID,
                name: "Legacy contact",
                detail: "Legacy alert",
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
        let riskySituations = [
            RiskySituation(
                id: fixedUUID(36),
                title: "Friday drinks",
                expectedContext: "Bar after work",
                preventionPlan: "Keep a drink in hand and stay inside.",
                backupAction: "Start rescue before going outside.",
                isEnabled: true,
                createdAt: fixedDate(36),
                updatedAt: fixedDate(37)
            )
        ]

        try repository.saveQuitPlan(plan)
        try repository.replaceSupportContacts(contacts)
        try repository.replaceUserReasons(reasons)
        try repository.replaceReplacementActivities(activities)
        try repository.replaceRiskySituations(riskySituations)

        XCTAssertEqual(try repository.fetchQuitPlan(), plan)
        XCTAssertEqual(try repository.fetchSupportContacts(), contacts)
        XCTAssertEqual(try repository.fetchUserReasons(), reasons)
        XCTAssertEqual(try repository.fetchReplacementActivities(), activities)
        XCTAssertEqual(try repository.fetchRiskySituations(), riskySituations)
        XCTAssertEqual(try repository.loadSnapshot().riskySituations, riskySituations)
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
            taperTargetCigarettes: 3,
            stayedWithinTaperTarget: true,
            slipNote: "Bought cigarettes after a stressful commute.",
            createdAt: fixedDate(41),
            updatedAt: fixedDate(42)
        )

        try repository.saveDailyCheckIn(checkIn)

        XCTAssertEqual(try repository.recentCheckIns(limit: 10), [checkIn])
    }

    func testCravingRecoveryPathPersistsOutcomeIntensityActivityAndLegacyContact() throws {
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
            recoveryAction: "Start rescue before the next drink.",
            createdAt: fixedDate(61),
            updatedAt: fixedDate(62)
        )

        try repository.saveSlipEvent(event)

        XCTAssertEqual(try repository.recentSlipEvents(limit: 10), [event])
    }

    func testStoreMotivationAndActivityLibrary() throws {
        let store = TeoPateoStore(repository: try makeRepository())

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

    func testMotivationVaultUsesPrimaryLatestAndFallbackReasons() throws {
        let repository = try makeRepository()
        try repository.replaceUserReasons([
            UserReason(
                id: fixedUUID(150),
                text: "Older reason",
                sortOrder: 0,
                isPrimary: false,
                createdAt: fixedDate(150),
                updatedAt: fixedDate(151)
            ),
            UserReason(
                id: fixedUUID(151),
                text: "Latest reason",
                sortOrder: 1,
                isPrimary: false,
                createdAt: fixedDate(152),
                updatedAt: fixedDate(153)
            )
        ])

        let store = TeoPateoStore(repository: repository)

        XCTAssertEqual(store.reasonForCravingMode(), "Latest reason")
        XCTAssertEqual(store.reasonsForCravingMode().map(\.text), ["Latest reason", "Older reason"])

        store.setPrimaryUserReason(fixedUUID(150))
        XCTAssertEqual(store.reasonForCravingMode(), "Older reason")
        XCTAssertEqual(store.reasonsForCravingMode().first?.id, fixedUUID(150))

        let reloadedStore = TeoPateoStore(repository: repository)
        XCTAssertEqual(reloadedStore.reasonForCravingMode(), "Older reason")
        XCTAssertEqual(reloadedStore.reasonsForCravingMode().first?.id, fixedUUID(150))

        store.deleteUserReason(fixedUUID(150))
        store.deleteUserReason(fixedUUID(151))
        XCTAssertEqual(
            store.reasonForCravingMode(),
            "Pause for 10 minutes before deciding. This urge can pass."
        )

        let emptyReloadedStore = TeoPateoStore(repository: repository)
        XCTAssertTrue(emptyReloadedStore.userReasons.isEmpty)
        XCTAssertEqual(
            emptyReloadedStore.reasonForCravingMode(),
            "Pause for 10 minutes before deciding. This urge can pass."
        )
    }

    func testStoreManagesQuitPlanRefinements() throws {
        let repository = try makeRepository()
        let store = TeoPateoStore(repository: repository)

        let firstRule = try XCTUnwrap(store.triggerRules.first)
        store.updateTriggerRule(
            id: firstRule.id,
            trigger: "After coffee",
            action: "Brush teeth before coffee.",
            isEnabled: false
        )
        XCTAssertEqual(store.triggerRules.first?.action, "Brush teeth before coffee.")
        XCTAssertEqual(store.triggerRules.first?.isEnabled, false)
        store.moveTriggerRule(firstRule.id, direction: 1)
        XCTAssertNotEqual(store.triggerRules.first?.id, firstRule.id)
        store.deleteTriggerRule(firstRule.id)
        XCTAssertFalse(store.triggerRules.contains { $0.id == firstRule.id })

        let firstReason = try XCTUnwrap(store.userReasons.first)
        store.addUserReason("I want better sleep.")
        let secondReason = try XCTUnwrap(store.userReasons.first { $0.text == "I want better sleep." })
        store.updateUserReason(firstReason.id, text: "I want easier mornings.")
        store.moveUserReason(secondReason.id, direction: -1)
        XCTAssertEqual(store.userReasons.first?.id, secondReason.id)
        XCTAssertTrue(store.userReasons.map(\.sortOrder).elementsEqual(0..<store.userReasons.count))

        let firstActivity = try XCTUnwrap(store.replacementActivities.first)
        store.updateReplacementActivity(
            id: firstActivity.id,
            title: "Cold water first",
            instruction: "Drink water before deciding.",
            category: .sensory,
            linkedTrigger: "Coffee",
            isEnabled: false
        )
        XCTAssertEqual(store.replacementActivities.first?.title, "Cold water first")
        XCTAssertEqual(store.replacementActivities.first?.isEnabled, false)
        store.moveReplacementActivity(firstActivity.id, direction: 1)
        XCTAssertNotEqual(store.replacementActivities.first?.id, firstActivity.id)
        store.deleteReplacementActivity(firstActivity.id)
        XCTAssertFalse(store.replacementActivities.contains { $0.id == firstActivity.id })

        store.addRiskySituation(
            title: "Late commute",
            expectedContext: "Driving home",
            preventionPlan: "Keep gum in the car.",
            backupAction: "Start rescue in the driveway."
        )
        let risky = try XCTUnwrap(store.riskySituations.first)
        store.updateRiskySituation(
            id: risky.id,
            title: "Late commute home",
            expectedContext: "Driving home after work",
            preventionPlan: "Keep gum in the car.",
            backupAction: "Start rescue before parking.",
            isEnabled: false
        )
        XCTAssertEqual(store.riskySituations.first?.title, "Late commute home")
        XCTAssertEqual(store.riskySituations.first?.isEnabled, false)

        let reloadedStore = TeoPateoStore(repository: repository)
        XCTAssertEqual(reloadedStore.riskySituations.first?.title, "Late commute home")
        XCTAssertFalse(reloadedStore.riskySituations.first?.isEnabled ?? true)
    }

    func testStoreTaperScheduleAndCheckInTarget() throws {
        let repository = try makeRepository()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let start = makeDate(
            year: 2026,
            month: 5,
            day: 20,
            calendar: calendar
        )
        try repository.saveQuitPlan(QuitPlan(
            id: fixedUUID(1),
            quitDate: start,
            quitMode: "Taper",
            triggerRules: [],
            medicationNote: "",
            baselineCigarettesPerDay: 10,
            costPerPack: 10,
            cigarettesPerPack: 20,
            taperTargetCigarettesPerDay: 8,
            taperReductionStep: 2,
            taperReductionIntervalDays: 2,
            attemptStartedAt: start,
            createdAt: fixedDate(1),
            updatedAt: fixedDate(2)
        ))

        let now = makeDate(year: 2026, month: 5, day: 23, calendar: calendar)
        let store = TeoPateoStore(repository: repository, now: { now }, calendar: calendar)

        XCTAssertEqual(store.todayTaperTarget, 6)
        XCTAssertEqual(store.taperSchedule(days: 3).map(\.targetCigarettes), [6, 4, 4])

        store.smokedToday = true
        store.cigarettesSmoked = 7
        XCTAssertTrue(store.saveCheckIn(date: now, slipNote: ""))
        XCTAssertEqual(store.dailyCheckIns.first?.taperTargetCigarettes, 6)
        XCTAssertEqual(store.dailyCheckIns.first?.stayedWithinTaperTarget, false)
    }

    func testStoreCompletesOnboardingIntoActionablePlan() throws {
        let repository = try makeRepository()
        let store = TeoPateoStore(repository: repository)

        XCTAssertFalse(store.isOnboardingCompleted)

        XCTAssertTrue(store.completeOnboarding(
            OnboardingPlanInput(
                nickname: "Mira",
                age: 34,
                quitStatus: .readyToQuit,
                confidence: 7,
                openedAppReason: "I nearly smoked after work.",
                ageStartedSmoking: 19,
                yearsSmoking: nil,
                cigarettesPerDay: 12,
                firstCigaretteTiming: .withinThirtyMinutes,
                previousQuitAttemptCount: .twoToThree,
                longestQuitAttempt: .fewWeeks,
                mainChallenge: .stress,
                commonSmokingTimes: ["After coffee"],
                emotionalTriggers: ["Stress"],
                situationalTriggers: ["Work pressure"],
                quitDatePreference: .chooseDate,
                costPerPack: 14,
                cigarettesPerPack: 20,
                quitDate: fixedDate(200),
                approachPreference: .coldTurkey,
                replacementActions: ["Drink water", "Walk"],
                primaryReason: "I want to breathe easier.",
                savingsGoalTitle: "Trip",
                customSavingsGoal: ""
            )
        ))

        XCTAssertTrue(store.isOnboardingCompleted)
        XCTAssertFalse(store.isOnboardingPresented)
        XCTAssertEqual(store.currentQuitPlan.quitMode, "Cold turkey")
        XCTAssertEqual(store.currentQuitPlan.baselineCigarettesPerDay, 12)
        XCTAssertEqual(store.currentQuitPlan.costPerPack, 14)
        XCTAssertEqual(store.currentQuitPlan.quitStatus, .readyToQuit)
        XCTAssertEqual(store.currentQuitPlan.readinessStage, "Quit-date preparation")
        XCTAssertFalse(store.currentQuitPlan.generatedDailyFocus.isEmpty)
        XCTAssertEqual(store.triggerRules.map(\.trigger), ["After coffee", "Stress", "Work pressure"])
        XCTAssertEqual(store.userReasons.first?.text, "I want to breathe easier.")
        XCTAssertEqual(store.userProfile?.nickname, "Mira")
        XCTAssertEqual(store.quitReadiness?.openedAppReason, "I nearly smoked after work.")
        XCTAssertEqual(store.smokingBackground?.mainChallenge, .stress)
        XCTAssertEqual(store.savingsGoal?.displayTitle, "Trip")
        XCTAssertTrue(store.supportContacts.isEmpty)
        XCTAssertTrue(store.replacementActivities.contains { $0.linkedTrigger == "After coffee" })
        XCTAssertFalse(store.riskySituations.isEmpty)
        XCTAssertTrue(store.currentQuitPlan.medicationNote.isEmpty)

        let reloadedStore = TeoPateoStore(repository: repository)
        XCTAssertTrue(reloadedStore.isOnboardingCompleted)
        XCTAssertEqual(reloadedStore.currentQuitPlan.quitMode, "Cold turkey")
        XCTAssertEqual(reloadedStore.userReasons.first?.text, "I want to breathe easier.")
        XCTAssertEqual(reloadedStore.userProfile?.nickname, "Mira")
        XCTAssertEqual(reloadedStore.savingsGoal?.displayTitle, "Trip")
        XCTAssertTrue(reloadedStore.supportContacts.isEmpty)
    }

    func testStoreRecordsCravingSlipAndHistory() throws {
        let store = TeoPateoStore(repository: try makeRepository())
        let activityID = try XCTUnwrap(store.replacementActivities.first?.id)

        store.startCravingSession()
        store.selectedTriggers = ["Coffee"]
        XCTAssertTrue(store.completeCravingWithoutSmoking(
            startedAt: fixedDate(70),
            completedAt: fixedDate(71),
            durationSeconds: 600,
            initialIntensity: 8,
            finalIntensity: 2,
            helpedActivityID: activityID,
            supportContactID: nil,
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
            slipNote: ""
        ))
        XCTAssertTrue(store.lastSaveStatus.isFailure)

        store.smokedToday = false
        XCTAssertTrue(store.saveCheckIn(
            date: fixedDate(90),
            slipNote: "Ignored because no smoke."
        ))
        XCTAssertEqual(store.dailyCheckIns.count, 1)
        XCTAssertEqual(store.dailyCheckIns[0].slipNote, "")

        store.mood = 9
        XCTAssertTrue(store.saveCheckIn(
            date: fixedDate(90),
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

    func testStoreAppliesInsightSuggestionToPlan() throws {
        let repository = try makeRepository()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = makeDate(year: 2026, month: 5, day: 22, hour: 21, calendar: calendar)

        try repository.saveQuitPlan(QuitPlan(
            id: fixedUUID(1),
            quitDate: fixedDate(10),
            quitMode: "Taper",
            triggerRules: [],
            medicationNote: "",
            createdAt: fixedDate(1),
            updatedAt: fixedDate(2)
        ))
        try repository.saveSlipEvent(SlipEvent(
            id: fixedUUID(120),
            occurredAt: now,
            cigarettesSmoked: 1,
            selectedTriggers: ["After dinner"],
            note: "Smoked after dinner.",
            recoveryAction: "Brush teeth first.",
            createdAt: fixedDate(120),
            updatedAt: fixedDate(121)
        ))

        let store = TeoPateoStore(repository: repository, now: { now }, calendar: calendar)

        XCTAssertTrue(store.canApplyPlanAdjustmentSuggestion)
        XCTAssertTrue(store.applyPlanAdjustmentSuggestion())
        XCTAssertEqual(store.triggerRules.first?.trigger, "After dinner")
        XCTAssertFalse(store.canApplyPlanAdjustmentSuggestion)

        let reloadedStore = TeoPateoStore(repository: repository, now: { now }, calendar: calendar)
        XCTAssertEqual(reloadedStore.triggerRules.first?.trigger, "After dinner")
    }

    func testNotificationPlannerBuildsOptInScheduleFromRiskWindows() throws {
        var settings = NotificationSettings(updatedAt: fixedDate(130))
        settings.morningPlanEnabled = true
        settings.riskyWindowEnabled = true
        settings.eveningCheckInEnabled = true
        settings.morningPlanTime = ReminderTime(hour: 7, minute: 15)
        settings.eveningCheckInTime = ReminderTime(hour: 20, minute: 45)

        let items = NotificationPlanner.scheduleItems(
            settings: settings,
            quitPlan: makeQuitPlan(quitMode: "Taper"),
            riskWindows: [
                RiskWindowInsight(startHour: 21, cravingCount: 3, share: 0.6),
                RiskWindowInsight(startHour: 8, cravingCount: 2, share: 0.4)
            ],
            topTriggers: [
                TriggerInsight(name: "After coffee", count: 3, share: 0.6)
            ]
        )

        XCTAssertEqual(items.count, 4)
        XCTAssertTrue(items.contains {
            $0.kind == .morningPlan && $0.time == ReminderTime(hour: 7, minute: 15)
        })
        XCTAssertTrue(items.contains {
            $0.kind == .riskyWindow &&
                $0.time == ReminderTime(hour: 20, minute: 30) &&
                $0.body.contains("Drink water first.")
        })
        XCTAssertTrue(items.contains {
            $0.kind == .eveningCheckIn && $0.time == ReminderTime(hour: 20, minute: 45)
        })
    }

    func testStoreBuildsHistoryTimelineRecapAndEditsNotes() throws {
        let repository = try makeRepository()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let monday = makeDate(year: 2026, month: 5, day: 18, calendar: calendar)
        let tuesday = makeDate(year: 2026, month: 5, day: 19, hour: 20, calendar: calendar)
        let wednesday = makeDate(year: 2026, month: 5, day: 20, hour: 21, calendar: calendar)

        try repository.saveQuitPlan(QuitPlan(
            id: fixedUUID(1),
            quitDate: monday,
            quitMode: "Taper",
            triggerRules: [],
            medicationNote: "",
            createdAt: fixedDate(1),
            updatedAt: fixedDate(2)
        ))
        try repository.saveDailyCheckIn(DailyCheckIn(
            id: fixedUUID(140),
            date: monday,
            mood: 8,
            stress: 4,
            confidence: 7,
            smokedToday: false,
            slipNote: "",
            createdAt: fixedDate(140),
            updatedAt: fixedDate(141)
        ))
        try repository.saveDailyCheckIn(DailyCheckIn(
            id: fixedUUID(141),
            date: tuesday,
            mood: 5,
            stress: 8,
            confidence: 4,
            smokedToday: true,
            cigarettesSmoked: 1,
            slipNote: "Smoked after dinner.",
            createdAt: fixedDate(142),
            updatedAt: fixedDate(143)
        ))
        try repository.saveCravingEvent(makeCraving(
            id: 142,
            startedAt: tuesday,
            triggers: ["After dinner", "Coffee"],
            completedWithoutSmoking: true
        ))
        try repository.saveSlipEvent(SlipEvent(
            id: fixedUUID(143),
            occurredAt: wednesday,
            cigarettesSmoked: 2,
            selectedTriggers: ["After dinner"],
            note: "Smoked outside after dinner.",
            recoveryAction: "Brush teeth before leaving the table.",
            createdAt: fixedDate(144),
            updatedAt: fixedDate(145)
        ))

        let store = TeoPateoStore(repository: repository, now: { wednesday }, calendar: calendar)
        let recap = store.weeklyRecap(for: wednesday)

        XCTAssertEqual(store.historyGroups.count, 3)
        XCTAssertEqual(store.historyEntries().first?.kind, .slip)
        XCTAssertEqual(recap.cravingsLogged, 1)
        XCTAssertEqual(recap.cravingsHandled, 1)
        XCTAssertEqual(recap.smokeFreeCheckInDays, 1)
        XCTAssertEqual(recap.topTrigger, "After dinner")
        XCTAssertEqual(recap.planAdjustment.title, "Add a after dinner rule")

        store.updateDailyCheckInSlipNote(
            id: fixedUUID(141),
            slipNote: "Dinner was the cue."
        )
        XCTAssertEqual(
            store.dailyCheckIns.first { $0.id == fixedUUID(141) }?.slipNote,
            "Dinner was the cue."
        )

        store.updateSlipEventNotes(
            id: fixedUUID(143),
            note: "Updated slip note.",
            recoveryAction: "Updated recovery action."
        )
        XCTAssertEqual(store.slipEvents.first?.note, "Updated slip note.")
        XCTAssertEqual(store.slipEvents.first?.recoveryAction, "Updated recovery action.")

        let rangedEntries = store.historyEntries(range: monday...tuesday)
        XCTAssertTrue(rangedEntries.contains { $0.id == fixedUUID(140) })
        XCTAssertFalse(rangedEntries.contains { $0.id == fixedUUID(143) })
    }

    func testHistoryDeleteRemovesAccidentalRecords() throws {
        let store = TeoPateoStore(repository: try makeRepository())

        store.smokedToday = false
        XCTAssertTrue(store.saveCheckIn(date: fixedDate(120), slipNote: ""))
        store.selectedTriggers = ["Social"]
        XCTAssertTrue(store.completeCravingWithoutSmoking(
            startedAt: fixedDate(121),
            completedAt: fixedDate(122),
            durationSeconds: 60
        ))
        XCTAssertTrue(store.saveSlipEvent(
            occurredAt: fixedDate(123),
            cigarettesSmoked: 1,
            triggers: ["Social"],
            context: "Dinner",
            note: "Accidental record.",
            recoveryAction: "Return to plan."
        ))

        let checkInID = try XCTUnwrap(store.dailyCheckIns.first?.id)
        let cravingID = try XCTUnwrap(store.cravingEvents.first?.id)
        let slipID = try XCTUnwrap(store.slipEvents.first?.id)
        XCTAssertEqual(store.historyEntries().count, 3)

        store.deleteDailyCheckIn(checkInID)
        store.deleteCravingEvent(cravingID)
        store.deleteSlipEvent(slipID)

        XCTAssertTrue(store.dailyCheckIns.isEmpty)
        XCTAssertTrue(store.cravingEvents.isEmpty)
        XCTAssertTrue(store.slipEvents.isEmpty)
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
            planSummary: PlanSummary(
                planStartDate: fixedDate(4),
                quitDate: fixedDate(10)
            ),
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
            medicationNote: "",
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
