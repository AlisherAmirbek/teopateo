import XCTest
@testable import TeoPateo

final class StoreBehaviorTests: TeoPateoTestCase {
    func testPlanUpdatesClampPersistAndAffectTaperSchedule() throws {
        let repository = try makeRepository()
        let calendar = makeCalendar()
        let now = makeDate(year: 2026, month: 5, day: 23, calendar: calendar)
        try repository.saveQuitPlan(makeQuitPlan(
            quitDate: makeDate(year: 2026, month: 5, day: 20, calendar: calendar),
            attemptStartedAt: makeDate(year: 2026, month: 5, day: 20, calendar: calendar)
        ))

        let store = TeoPateoStore(repository: repository, now: { now }, calendar: calendar)
        let nextQuitDate = makeDate(year: 2026, month: 5, day: 30, calendar: calendar)

        store.updateQuitDate(nextQuitDate)
        store.updateProgressBaseline(cigarettesPerDay: -4, costPerPack: -8, cigarettesPerPack: 0)
        store.updateTaperSettings(targetCigarettesPerDay: 20, reductionStep: -2, reductionIntervalDays: 0)

        XCTAssertEqual(store.currentQuitPlan.quitDate, nextQuitDate)
        XCTAssertEqual(store.currentQuitPlan.baselineCigarettesPerDay, 0)
        XCTAssertEqual(store.currentQuitPlan.costPerPack, 0)
        XCTAssertEqual(store.currentQuitPlan.cigarettesPerPack, 1)
        XCTAssertEqual(store.currentQuitPlan.taperTargetCigarettesPerDay, 0)
        XCTAssertEqual(store.currentQuitPlan.taperReductionStep, 0)
        XCTAssertEqual(store.currentQuitPlan.taperReductionIntervalDays, 1)
        XCTAssertEqual(store.taperSchedule(days: 2).map(\.targetCigarettes), [0, 0])

        store.quitMode = "Cold turkey"
        XCTAssertNil(store.todayTaperTarget)
        XCTAssertTrue(store.taperSchedule(days: 2).isEmpty)
        XCTAssertEqual(try repository.fetchQuitPlan()?.quitMode, "Cold turkey")
    }

    func testCurrentWeekPlanAdherenceClassifiesDailyResults() throws {
        let repository = try makeRepository()
        let calendar = makeCalendar()
        let monday = calendar.startOfDay(for: makeDate(year: 2026, month: 5, day: 25, calendar: calendar))
        let tuesday = calendar.startOfDay(for: makeDate(year: 2026, month: 5, day: 26, calendar: calendar))
        let wednesday = calendar.startOfDay(for: makeDate(year: 2026, month: 5, day: 27, calendar: calendar))

        try repository.saveQuitPlan(makeQuitPlan(
            quitDate: monday,
            taperTargetCigarettesPerDay: 4,
            taperReductionStep: 0,
            attemptStartedAt: monday
        ))
        try repository.saveDailyCheckIn(DailyCheckIn(
            id: fixedUUID(201),
            date: monday,
            mood: 7,
            stress: 5,
            confidence: 8,
            smokedToday: true,
            cigarettesSmoked: 4,
            taperTargetCigarettes: 4,
            stayedWithinTaperTarget: true,
            slipNote: "",
            createdAt: fixedDate(201),
            updatedAt: fixedDate(202)
        ))
        try repository.saveDailyCheckIn(DailyCheckIn(
            id: fixedUUID(202),
            date: tuesday,
            mood: 7,
            stress: 5,
            confidence: 8,
            smokedToday: true,
            cigarettesSmoked: 5,
            taperTargetCigarettes: 4,
            stayedWithinTaperTarget: false,
            slipNote: "One over target.",
            createdAt: fixedDate(203),
            updatedAt: fixedDate(204)
        ))
        try repository.saveDailyCheckIn(DailyCheckIn(
            id: fixedUUID(203),
            date: wednesday,
            mood: 7,
            stress: 5,
            confidence: 8,
            smokedToday: true,
            cigarettesSmoked: 7,
            taperTargetCigarettes: 4,
            stayedWithinTaperTarget: false,
            slipNote: "Above target.",
            createdAt: fixedDate(205),
            updatedAt: fixedDate(206)
        ))

        let store = TeoPateoStore(repository: repository, now: { wednesday }, calendar: calendar)
        let week = store.currentWeekPlanAdherence

        XCTAssertEqual(week.count, 7)
        XCTAssertEqual(week.first?.date, monday)
        XCTAssertEqual(week.map(\.status).prefix(4), [.achieved, .slightMiss, .missed, nil])
        XCTAssertEqual(week[2].cigarettesSmoked, 7)
        XCTAssertTrue(week[2].isToday)
    }

    func testInvalidPlanLibraryInputsSetFailureAndDoNotMutateCollections() throws {
        let store = TeoPateoStore(repository: try makeRepository())
        let triggerCount = store.triggerRules.count
        let reasonCount = store.userReasons.count
        let activityCount = store.replacementActivities.count
        let riskyCount = store.riskySituations.count

        store.addTriggerRule(trigger: "   ", action: "Do something")
        XCTAssertTrue(store.lastSaveStatus.isFailure)
        XCTAssertEqual(store.triggerRules.count, triggerCount)

        store.addUserReason(" ")
        XCTAssertTrue(store.lastSaveStatus.isFailure)
        XCTAssertEqual(store.userReasons.count, reasonCount)

        store.addReplacementActivity(title: "Gum", instruction: " ", category: .sensory)
        XCTAssertTrue(store.lastSaveStatus.isFailure)
        XCTAssertEqual(store.replacementActivities.count, activityCount)

        store.addRiskySituation(title: " ", expectedContext: "", preventionPlan: "Keep distance.", backupAction: "")
        XCTAssertTrue(store.lastSaveStatus.isFailure)
        XCTAssertEqual(store.riskySituations.count, riskyCount)
    }

    func testCravingWrapperDismissalAndSessionResetPaths() throws {
        let repository = try makeRepository()
        let store = TeoPateoStore(repository: repository)

        store.selectedTriggers = ["Coffee"]
        store.startCravingSession()
        XCTAssertTrue(store.selectedTriggers.isEmpty)
        XCTAssertEqual(store.lastSaveStatus, .idle)

        store.selectedTriggers = ["Coffee"]
        XCTAssertTrue(store.completeCraving(
            startedAt: fixedDate(10),
            completedAt: fixedDate(11),
            durationSeconds: 120,
            completedWithoutSmoking: true
        ))
        XCTAssertEqual(store.cravingEvents.first?.outcome, .completedWithoutSmoking)

        store.selectedTriggers = ["Work stress"]
        XCTAssertTrue(store.completeCraving(
            startedAt: fixedDate(20),
            completedAt: fixedDate(21),
            durationSeconds: 90,
            completedWithoutSmoking: false
        ))
        XCTAssertEqual(store.cravingEvents.first?.outcome, .smokedAfterCraving)
        XCTAssertEqual(store.slipEvents.first?.context, "Craving mode")

        XCTAssertTrue(store.dismissCravingSession(
            startedAt: fixedDate(30),
            dismissedAt: fixedDate(31),
            durationSeconds: -30,
            initialIntensity: 7
        ))
        let dismissed = try XCTUnwrap(store.cravingEvents.first)
        XCTAssertEqual(dismissed.outcome, .dismissedWithoutOutcome)
        XCTAssertEqual(dismissed.durationSeconds, 0)
        XCTAssertEqual(dismissed.initialIntensity, 7)
    }

    func testOnboardingRejectsBlankReasonAndFallsBackToDefaultTriggers() throws {
        let repository = try makeRepository()
        let store = TeoPateoStore(repository: repository)

        XCTAssertFalse(store.completeOnboarding(makeOnboardingInput(primaryReason: "   ")))
        XCTAssertFalse(store.isOnboardingCompleted)
        XCTAssertTrue(store.lastSaveStatus.isFailure)

        XCTAssertTrue(store.completeOnboarding(makeOnboardingInput(
            cigarettesPerDay: -5,
            costPerPack: -1,
            quitDate: fixedDate(60),
            approachPreference: .notSure,
            commonSmokingTimes: ["After coffee", "After coffee"],
            primaryReason: "My breathing"
        )))

        XCTAssertEqual(store.currentQuitPlan.quitMode, "Taper")
        XCTAssertEqual(store.currentQuitPlan.baselineCigarettesPerDay, 0)
        XCTAssertEqual(store.currentQuitPlan.costPerPack, 0)
        XCTAssertEqual(store.triggerRules.map(\.trigger), ["After coffee", "Cravings"])
        XCTAssertEqual(store.userProfile?.nickname, "Alex")
        XCTAssertEqual(store.quitReadiness?.status, .readyToQuit)
        XCTAssertEqual(store.savingsGoal?.displayTitle, "Health")

        let reloaded = TeoPateoStore(repository: repository)
        XCTAssertTrue(reloaded.isOnboardingCompleted)
        XCTAssertEqual(reloaded.triggerRules.map(\.trigger), ["After coffee", "Cravings"])
    }

    func testOnboardingUsesMainChallengeWhenNoSurveyTriggersAreSelected() throws {
        let store = TeoPateoStore(repository: try makeRepository())

        XCTAssertTrue(store.completeOnboarding(makeOnboardingInput(
            cigarettesPerDay: 6,
            costPerPack: 10,
            quitDate: fixedDate(70),
            approachPreference: .coldTurkey,
            commonSmokingTimes: [],
            emotionalTriggers: [],
            situationalTriggers: [],
            primaryReason: "My family"
        )))

        XCTAssertEqual(store.triggerRules.map(\.trigger), ["Cravings"])
        XCTAssertTrue(store.replacementActivities.contains { $0.linkedTrigger == "Cravings" })
        XCTAssertEqual(store.currentQuitPlan.taperTargetCigarettesPerDay, 0)
    }

    func testCoachMessagesIgnoreBlankInputAndPersistReplies() async throws {
        let repository = try makeRepository()
        let coachClient = TestCoachClient()
        let store = TeoPateoStore(repository: repository, coachClient: coachClient)
        let originalCount = store.coachMessages.count
        XCTAssertEqual(originalCount, 0)
        XCTAssertEqual(store.coachChats.count, 1)

        await store.sendCoachMessage("   ")
        XCTAssertEqual(store.coachMessages.count, originalCount)

        await store.sendCoachMessage("I am about to smoke after coffee.")
        XCTAssertEqual(store.coachMessages.count, originalCount + 2)
        XCTAssertEqual(store.coachMessages.suffix(2).first?.text, "I am about to smoke after coffee.")
        XCTAssertEqual(
            store.coachMessages.last?.text,
            "Take one slow breath, name the trigger, and start water before deciding."
        )
        XCTAssertEqual(coachClient.requests.count, 1)
        XCTAssertTrue(coachClient.requests[0].contextSummary.contains("Quit mode"))
        XCTAssertFalse(try repository.fetchCoachChats().flatMap(\.messages).isEmpty)

        let reloaded = TeoPateoStore(repository: repository, coachClient: coachClient)
        XCTAssertEqual(reloaded.coachMessages.map(\.text), store.coachMessages.map(\.text))
        XCTAssertEqual(reloaded.coachMessages.map(\.isUser), store.coachMessages.map(\.isUser))
    }

    func testCoachStreamingChunksBuildOneAssistantMessage() async throws {
        let coachClient = TestCoachClient(response: .successChunks([
            "Take one slow breath, ",
            "name the trigger, ",
            "and drink water first."
        ]))
        let store = TeoPateoStore(repository: try makeRepository(), coachClient: coachClient)

        await store.sendCoachMessage("I want to smoke now.")

        XCTAssertEqual(store.coachMessages.count, 2)
        XCTAssertEqual(store.coachMessages.last?.isUser, false)
        XCTAssertEqual(
            store.coachMessages.last?.text,
            "Take one slow breath, name the trigger, and drink water first."
        )
    }

    func testNewCoachChatStartsWithCleanRequestHistory() async throws {
        let repository = try makeRepository()
        let coachClient = TestCoachClient()
        let store = TeoPateoStore(repository: repository, coachClient: coachClient)

        await store.sendCoachMessage("I want to smoke after coffee.")
        let firstChatID = try XCTUnwrap(store.selectedCoachChatID)

        store.startNewCoachChat()
        let secondChatID = try XCTUnwrap(store.selectedCoachChatID)
        XCTAssertNotEqual(firstChatID, secondChatID)
        XCTAssertTrue(store.coachMessages.isEmpty)

        await store.sendCoachMessage("Now I am leaving work.")

        XCTAssertEqual(store.coachChats.count, 2)
        XCTAssertEqual(coachClient.requests.count, 2)
        XCTAssertTrue(coachClient.requests[0].messages.map(\.content).contains("I want to smoke after coffee."))
        XCTAssertFalse(coachClient.requests[1].messages.map(\.content).contains("I want to smoke after coffee."))
        XCTAssertTrue(coachClient.requests[1].messages.map(\.content).contains("Now I am leaving work."))

        let reloaded = TeoPateoStore(repository: repository, coachClient: coachClient)
        XCTAssertEqual(reloaded.selectedCoachChatID, secondChatID)
        XCTAssertEqual(reloaded.coachMessages.map(\.text), store.coachMessages.map(\.text))
    }

    func testNewCoachChatRequiresCurrentUserInput() async throws {
        let repository = try makeRepository()
        let store = TeoPateoStore(repository: repository, coachClient: TestCoachClient())
        let initialChatID = try XCTUnwrap(store.selectedCoachChatID)
        let initialChatCount = store.coachChats.count

        XCTAssertFalse(store.canStartNewCoachChat)
        store.startNewCoachChat()

        XCTAssertEqual(store.selectedCoachChatID, initialChatID)
        XCTAssertEqual(store.coachChats.count, initialChatCount)

        await store.sendCoachMessage("I am tense after lunch.")

        XCTAssertTrue(store.canStartNewCoachChat)
        store.startNewCoachChat()
        let emptyChatID = try XCTUnwrap(store.selectedCoachChatID)
        XCTAssertNotEqual(emptyChatID, initialChatID)
        XCTAssertFalse(store.canStartNewCoachChat)

        store.startNewCoachChat()

        XCTAssertEqual(store.selectedCoachChatID, emptyChatID)
        XCTAssertEqual(store.coachChats.count, initialChatCount + 1)
    }

    func testDeletingCoachChatSelectsNextAndKeepsOneBlankChat() async throws {
        let repository = try makeRepository()
        let store = TeoPateoStore(repository: repository, coachClient: TestCoachClient())

        await store.sendCoachMessage("I want to smoke after coffee.")
        let firstChatID = try XCTUnwrap(store.selectedCoachChatID)

        store.startNewCoachChat()
        await store.sendCoachMessage("I am leaving work.")
        let secondChatID = try XCTUnwrap(store.selectedCoachChatID)

        store.deleteCoachChat(secondChatID)

        XCTAssertEqual(store.selectedCoachChatID, firstChatID)
        XCTAssertEqual(store.coachChats.map(\.id), [firstChatID])
        XCTAssertTrue(store.coachMessages.contains { $0.text == "I want to smoke after coffee." })

        let reloaded = TeoPateoStore(repository: repository, coachClient: TestCoachClient())
        XCTAssertEqual(reloaded.selectedCoachChatID, firstChatID)
        XCTAssertEqual(reloaded.coachChats.map(\.id), [firstChatID])

        store.deleteCoachChat(firstChatID)

        XCTAssertEqual(store.coachChats.count, 1)
        XCTAssertTrue(store.coachMessages.isEmpty)
        XCTAssertFalse(store.canStartNewCoachChat)
        XCTAssertNotEqual(store.selectedCoachChatID, firstChatID)
    }

    func testCoachFailureKeepsUserMessageAndSetsFailureState() async throws {
        let store = TeoPateoStore(
            repository: try makeRepository(),
            coachClient: TestCoachClient(response: .failure(TestCoachError()))
        )
        let originalCount = store.coachMessages.count

        await store.sendCoachMessage("I slipped after dinner.")

        XCTAssertEqual(store.coachMessages.count, originalCount + 1)
        XCTAssertEqual(store.coachMessages.last?.text, "I slipped after dinner.")
        XCTAssertEqual(store.coachMessages.last?.isUser, true)
        XCTAssertEqual(
            store.coachResponseState.message,
            "The coach is unavailable right now. Your message was saved."
        )
    }

    func testCoachOfflineFailureKeepsUserMessageAndShowsFriendlyState() async throws {
        let store = TeoPateoStore(
            repository: try makeRepository(),
            coachClient: TestCoachClient(response: .failure(URLError(.notConnectedToInternet)))
        )

        await store.sendCoachMessage("I am craving after coffee.")

        XCTAssertEqual(store.coachMessages.count, 1)
        XCTAssertEqual(store.coachMessages.last?.text, "I am craving after coffee.")
        XCTAssertEqual(
            store.coachResponseState.message,
            "You appear to be offline. Your message was saved; try again when you're connected."
        )
    }

    func testCoachRateLimitFailureKeepsUserMessageAndShowsFriendlyState() async throws {
        let store = TeoPateoStore(
            repository: try makeRepository(),
            coachClient: TestCoachClient(response: .failure(CoachClientError.requestFailed(statusCode: 429)))
        )

        await store.sendCoachMessage("I am craving after dinner.")

        XCTAssertEqual(store.coachMessages.count, 1)
        XCTAssertEqual(store.coachMessages.last?.text, "I am craving after dinner.")
        XCTAssertEqual(
            store.coachResponseState.message,
            "The coach is getting too many requests. Try again in a minute."
        )
    }

    func testInsightEdgesCoverSparseModerateAndStrongHistory() throws {
        let repository = try makeRepository()
        let calendar = makeCalendar()
        let now = makeDate(year: 2026, month: 5, day: 28, hour: 10, calendar: calendar)
        try repository.saveQuitPlan(makeQuitPlan(
            baselineCigarettesPerDay: 5,
            costPerPack: 10,
            cigarettesPerPack: 20
        ))

        let emptyStore = TeoPateoStore(repository: repository, now: { now }, calendar: calendar)
        XCTAssertEqual(emptyStore.calculatedInsights.smokeFreeDays, 0)
        XCTAssertEqual(emptyStore.calculatedInsights.todayRisk.level, .low)
        XCTAssertEqual(
            emptyStore.calculatedInsights.planAdjustment.title,
            "Build the pattern map"
        )
        XCTAssertEqual(
            emptyStore.calculatedInsights.dataConfidenceSummary,
            "Early pattern. Log a few more cravings before trusting percentages."
        )

        try repository.saveDailyCheckIn(makeCheckIn(
            id: 100,
            date: makeDate(year: 2026, month: 5, day: 28, calendar: calendar),
            smokedToday: false,
            stress: 9,
            confidence: 8
        ))
        try repository.saveCravingEvent(makeCraving(
            id: 101,
            startedAt: makeDate(year: 2026, month: 5, day: 28, hour: 10, calendar: calendar),
            triggers: ["Coffee"]
        ))
        let moderateStore = TeoPateoStore(repository: repository, now: { now }, calendar: calendar)
        XCTAssertEqual(moderateStore.calculatedInsights.todayRisk.level, .moderate)

        for offset in 0..<7 {
            try repository.saveCravingEvent(makeCraving(
                id: 200 + offset,
                startedAt: makeDate(
                    year: 2026,
                    month: 5,
                    day: 21 + offset,
                    hour: 21,
                    calendar: calendar
                ),
                triggers: ["Evening"]
            ))
        }
        let strongStore = TeoPateoStore(repository: repository, now: { now }, calendar: calendar)
        XCTAssertEqual(strongStore.calculatedInsights.dataConfidenceSummary, "Strong signal from repeated logged patterns.")
        XCTAssertEqual(strongStore.calculatedInsights.heatMapDays.count, 28)
        XCTAssertEqual(strongStore.calculatedInsights.topTriggers.first?.name, "Evening")
    }

    func testHistoryLookupAndNoteUpdatesIgnoreMissingOrNoSmokeRecords() throws {
        let store = TeoPateoStore(repository: try makeRepository())

        store.smokedToday = false
        XCTAssertTrue(store.saveCheckIn(date: fixedDate(90), slipNote: "Ignored"))
        let checkInID = try XCTUnwrap(store.dailyCheckIns.first?.id)

        store.updateDailyCheckInSlipNote(id: checkInID, slipNote: "Still ignored")
        XCTAssertEqual(store.dailyCheckIns.first?.slipNote, "")
        store.updateDailyCheckInSlipNote(id: fixedUUID(999), slipNote: "Missing")
        store.updateSlipEventNotes(id: fixedUUID(998), note: "Missing", recoveryAction: "Missing")

        XCTAssertNotNil(store.historyEntry(for: checkInID, kind: .checkIn))
        XCTAssertNil(store.historyEntry(for: checkInID, kind: .slip))
    }

    func testRefreshAuthorizationSyncsExistingEnabledReminders() throws {
        let repository = try makeRepository()
        try repository.saveQuitPlan(makeQuitPlan())
        try repository.saveNotificationSettings(NotificationSettings(
            morningPlanEnabled: true,
            riskyWindowEnabled: true,
            updatedAt: fixedDate(1)
        ))
        try repository.saveCravingEvent(makeCraving(
            id: 20,
            startedAt: fixedDate(20),
            triggers: ["After coffee"]
        ))
        let scheduler = TestNotificationScheduler(currentStatus: .authorized)
        let store = TeoPateoStore(repository: repository, notificationScheduler: scheduler)

        store.refreshNotificationAuthorization()
        waitForMainQueue()

        XCTAssertEqual(store.notificationPermissionStatus, .authorized)
        XCTAssertEqual(scheduler.currentAuthorizationCalls, 1)
        XCTAssertEqual(scheduler.replaceScheduledCalls, 1)
        XCTAssertTrue(scheduler.scheduledItems.contains { $0.kind == .morningPlan })
        XCTAssertTrue(scheduler.scheduledItems.contains { $0.kind == .riskyWindow })
    }

    func testEnablingNotificationRequestsPermissionPersistsAndSchedules() throws {
        let repository = try makeRepository()
        let scheduler = TestNotificationScheduler(
            currentStatus: .notDetermined,
            requestResult: .success(.authorized)
        )
        let store = TeoPateoStore(repository: repository, notificationScheduler: scheduler)

        store.setNotificationEnabled(.morningPlan, isEnabled: true)
        waitForMainQueue()

        XCTAssertEqual(store.notificationPermissionStatus, .authorized)
        XCTAssertTrue(store.notificationSettings.morningPlanEnabled)
        XCTAssertTrue(try XCTUnwrap(repository.fetchNotificationSettings()).morningPlanEnabled)
        XCTAssertEqual(scheduler.requestAuthorizationCalls, 1)
        XCTAssertEqual(scheduler.replaceScheduledCalls, 1)
        XCTAssertEqual(scheduler.scheduledItems.map(\.kind), [.morningPlan])
    }

    func testDeniedNotificationPermissionDoesNotPersistEnabledReminder() throws {
        let repository = try makeRepository()
        let scheduler = TestNotificationScheduler(currentStatus: .denied)
        let store = TeoPateoStore(repository: repository, notificationScheduler: scheduler)

        store.refreshNotificationAuthorization()
        waitForMainQueue()
        store.setNotificationEnabled(.eveningCheckIn, isEnabled: true)

        XCTAssertFalse(store.notificationSettings.eveningCheckInEnabled)
        XCTAssertFalse(try XCTUnwrap(repository.fetchNotificationSettings()).eveningCheckInEnabled)
        XCTAssertEqual(scheduler.requestAuthorizationCalls, 0)
        XCTAssertTrue(store.lastSaveStatus.isFailure)
    }

    func testDisablingLastReminderCancelsScheduledNotifications() throws {
        let repository = try makeRepository()
        try repository.saveNotificationSettings(NotificationSettings(
            morningPlanEnabled: true,
            updatedAt: fixedDate(1)
        ))
        let scheduler = TestNotificationScheduler(currentStatus: .authorized)
        let store = TeoPateoStore(repository: repository, notificationScheduler: scheduler)

        store.refreshNotificationAuthorization()
        waitForMainQueue()
        store.setNotificationEnabled(.morningPlan, isEnabled: false)
        waitForMainQueue()

        XCTAssertFalse(store.notificationSettings.hasEnabledReminders)
        XCTAssertEqual(scheduler.cancelScheduledCalls, 1)
        XCTAssertFalse(try XCTUnwrap(repository.fetchNotificationSettings()).morningPlanEnabled)
    }

    func testNotificationTimeUpdatePersistsAndReschedulesOnlyFixedTimeKinds() throws {
        let repository = try makeRepository()
        try repository.saveNotificationSettings(NotificationSettings(
            morningPlanEnabled: true,
            updatedAt: fixedDate(1)
        ))
        let scheduler = TestNotificationScheduler(currentStatus: .authorized)
        let store = TeoPateoStore(repository: repository, notificationScheduler: scheduler)

        store.refreshNotificationAuthorization()
        waitForMainQueue()
        let initialReplaceCount = scheduler.replaceScheduledCalls

        store.updateNotificationTime(.morningPlan, time: ReminderTime(hour: 6, minute: 5))
        waitForMainQueue()
        XCTAssertEqual(store.notificationSettings.morningPlanTime, ReminderTime(hour: 6, minute: 5))
        XCTAssertEqual(try repository.fetchNotificationSettings()?.morningPlanTime, ReminderTime(hour: 6, minute: 5))
        XCTAssertEqual(scheduler.replaceScheduledCalls, initialReplaceCount + 1)

        store.updateNotificationTime(.riskyWindow, time: ReminderTime(hour: 3, minute: 3))
        waitForMainQueue()
        XCTAssertEqual(scheduler.replaceScheduledCalls, initialReplaceCount + 1)
    }

    func testHydrationFailureAppliesDefaultsAndReportsPersistenceError() throws {
        let repository = ThrowingTeoPateoRepository(
            base: try makeRepository(),
            failingOperations: [.loadSnapshot]
        )

        let store = TeoPateoStore(repository: repository)

        XCTAssertTrue(store.isOnboardingPresented)
        XCTAssertFalse(store.isOnboardingCompleted)
        XCTAssertEqual(store.persistenceError, TestRepositoryError().localizedDescription)
        XCTAssertTrue(store.lastSaveStatus.isFailure)
        XCTAssertFalse(store.triggerRules.isEmpty)
    }

    func testCheckInPersistenceFailureDoesNotAddHistory() throws {
        let repository = ThrowingTeoPateoRepository(base: try makeRepository())
        let store = TeoPateoStore(repository: repository)
        repository.failingOperations = [.saveDailyCheckIn]

        store.smokedToday = false
        let saved = store.saveCheckIn(date: fixedDate(400), slipNote: "")

        XCTAssertFalse(saved)
        XCTAssertTrue(store.dailyCheckIns.isEmpty)
        XCTAssertEqual(store.persistenceError, TestRepositoryError().localizedDescription)
        XCTAssertTrue(store.lastSaveStatus.isFailure)
    }

    func testNotificationPreferenceSaveFailureRollsBackAndDoesNotSchedule() throws {
        let repository = ThrowingTeoPateoRepository(base: try makeRepository())
        let scheduler = TestNotificationScheduler(currentStatus: .authorized)
        let store = TeoPateoStore(repository: repository, notificationScheduler: scheduler)
        store.refreshNotificationAuthorization()
        waitForMainQueue()
        repository.failingOperations = [.saveNotificationSettings]

        store.setNotificationEnabled(.morningPlan, isEnabled: true)
        waitForMainQueue()

        XCTAssertFalse(store.notificationSettings.morningPlanEnabled)
        XCTAssertFalse(try XCTUnwrap(repository.fetchNotificationSettings()).morningPlanEnabled)
        XCTAssertEqual(store.persistenceError, TestRepositoryError().localizedDescription)
        XCTAssertEqual(scheduler.replaceScheduledCalls, 0)
        XCTAssertTrue(store.lastSaveStatus.isFailure)
    }

    func testScheduledNotificationFailureKeepsPreferenceAndReportsStatus() throws {
        let scheduler = TestNotificationScheduler(currentStatus: .authorized)
        scheduler.replaceResult = .failure(TestSchedulerError())
        let store = TeoPateoStore(repository: try makeRepository(), notificationScheduler: scheduler)
        store.refreshNotificationAuthorization()
        waitForMainQueue()

        store.setNotificationEnabled(.morningPlan, isEnabled: true)
        waitForMainQueue()

        XCTAssertTrue(store.notificationSettings.morningPlanEnabled)
        XCTAssertEqual(scheduler.replaceScheduledCalls, 1)
        XCTAssertNil(store.persistenceError)
        XCTAssertTrue(store.lastSaveStatus.isFailure)
    }
}
