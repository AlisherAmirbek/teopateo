import XCTest
@testable import TeoPateo

@MainActor
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
        XCTAssertEqual(store.currentQuitPlan.savingsPlan.weeklySavingsBaseline, 0)
        XCTAssertEqual(store.currentQuitPlan.savingsPlan.firstMilestoneAmount, 0)
        XCTAssertEqual(store.currentQuitPlan.taperTargetCigarettesPerDay, 0)
        XCTAssertEqual(store.currentQuitPlan.taperReductionStep, 0)
        XCTAssertEqual(store.currentQuitPlan.taperReductionIntervalDays, 1)
        XCTAssertEqual(store.taperSchedule(days: 2).map(\.targetCigarettes), [0, 0])

        store.quitMode = "Cold turkey"
        XCTAssertNil(store.todayTaperTarget)
        XCTAssertTrue(store.taperSchedule(days: 2).isEmpty)
        XCTAssertEqual(try repository.fetchQuitPlan()?.quitMode, "Cold turkey")
    }

    func testZeroTaperStepIsCorrectedForPositiveTargets() throws {
        let repository = try makeRepository()
        let calendar = makeCalendar()
        let start = makeDate(year: 2026, month: 5, day: 20, calendar: calendar)
        try repository.saveQuitPlan(makeQuitPlan(
            baselineCigarettesPerDay: 10,
            taperTargetCigarettesPerDay: 8,
            taperReductionStep: 0,
            taperReductionIntervalDays: 1,
            attemptStartedAt: start
        ))

        let store = TeoPateoStore(repository: repository, now: { start }, calendar: calendar)

        XCTAssertEqual(store.taperSchedule(days: 3).map(\.targetCigarettes), [8, 7, 6])

        store.updateTaperSettings(
            targetCigarettesPerDay: 8,
            reductionStep: 0,
            reductionIntervalDays: 1
        )

        XCTAssertEqual(store.currentQuitPlan.taperReductionStep, 1)
        XCTAssertEqual(try repository.fetchQuitPlan()?.taperReductionStep, 1)
    }

    func testCurrentWeekPlanAdherenceClassifiesDailyResults() throws {
        let repository = try makeRepository()
        var calendar = makeCalendar()
        calendar.firstWeekday = 2
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
        try repository.saveSlipEvent(SlipEvent(
            id: fixedUUID(204),
            occurredAt: monday.addingTimeInterval(3600),
            cigarettesSmoked: 1,
            selectedTriggers: ["Coffee"],
            context: "Morning",
            note: "Extra cigarette after check-in.",
            recoveryAction: "Return to taper.",
            createdAt: fixedDate(207),
            updatedAt: fixedDate(208)
        ))

        let store = TeoPateoStore(repository: repository, now: { wednesday }, calendar: calendar)
        let week = store.currentWeekPlanAdherence

        XCTAssertEqual(week.count, 7)
        XCTAssertEqual(week.first?.date, monday)
        XCTAssertEqual(week.map(\.status).prefix(4), [.slightMiss, .slightMiss, .missed, nil])
        XCTAssertEqual(week[0].cigarettesSmoked, 5)
        XCTAssertEqual(week[2].cigarettesSmoked, 7)
        XCTAssertTrue(week[2].isToday)
    }

    func testPlanAdherenceWeekUsesCalendarFirstWeekday() throws {
        let repository = try makeRepository()
        var calendar = makeCalendar()
        calendar.firstWeekday = 1
        let sunday = calendar.startOfDay(for: makeDate(year: 2026, month: 5, day: 24, calendar: calendar))
        let wednesday = calendar.startOfDay(for: makeDate(year: 2026, month: 5, day: 27, calendar: calendar))

        try repository.saveQuitPlan(makeQuitPlan(
            quitDate: sunday,
            taperTargetCigarettesPerDay: 4,
            taperReductionStep: 0,
            attemptStartedAt: sunday
        ))

        let store = TeoPateoStore(repository: repository, now: { wednesday }, calendar: calendar)
        let week = store.planAdherenceWeek(containing: wednesday)

        XCTAssertEqual(week.first?.date, sunday)
        XCTAssertEqual(week.last?.date, calendar.date(byAdding: .day, value: 6, to: sunday))
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
        XCTAssertEqual(store.selectedTriggers, ["Coffee"])
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

    func testCravingCompletionCanUseSessionLocalTriggers() throws {
        let repository = try makeRepository()
        let store = TeoPateoStore(repository: repository)

        store.selectedTriggers = ["Global"]
        XCTAssertTrue(store.completeCravingWithoutSmoking(
            startedAt: fixedDate(50),
            completedAt: fixedDate(51),
            durationSeconds: 120,
            selectedTriggers: ["Local"]
        ))

        XCTAssertEqual(store.selectedTriggers, ["Global"])
        XCTAssertEqual(store.cravingEvents.first?.selectedTriggers, ["Local"])
    }

    func testCravingWithSlipFailureDoesNotSavePartialCraving() throws {
        let baseRepository = try makeRepository()
        let repository = ThrowingTeoPateoRepository(
            base: baseRepository,
            failingOperations: [.saveCravingWithSlip]
        )
        let store = TeoPateoStore(repository: repository)

        store.selectedTriggers = ["Work stress"]
        XCTAssertFalse(store.completeCraving(
            startedAt: fixedDate(40),
            completedAt: fixedDate(41),
            durationSeconds: 120,
            completedWithoutSmoking: false
        ))

        XCTAssertTrue(store.lastSaveStatus.isFailure)
        XCTAssertTrue(store.cravingEvents.isEmpty)
        XCTAssertTrue(store.slipEvents.isEmpty)
        XCTAssertTrue(try baseRepository.recentCravingEvents(limit: 10).isEmpty)
        XCTAssertTrue(try baseRepository.recentSlipEvents(limit: 10).isEmpty)
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

    func testCoachStreamFailurePreservesPartialAssistantReply() async throws {
        let repository = try makeRepository()
        let coachClient = TestCoachClient(response: .chunksThenFailure(
            [
                "Take one slow breath, ",
                "then put water in your hand."
            ],
            URLError(.networkConnectionLost)
        ))
        let store = TeoPateoStore(repository: repository, coachClient: coachClient)

        await store.sendCoachMessage("I want to smoke after coffee.")

        XCTAssertEqual(store.coachMessages.count, 2)
        XCTAssertEqual(store.coachMessages.first?.text, "I want to smoke after coffee.")
        XCTAssertEqual(store.coachMessages.last?.isUser, false)
        XCTAssertEqual(
            store.coachMessages.last?.text,
            "Take one slow breath, then put water in your hand."
        )
        XCTAssertEqual(
            store.coachResponseState.message,
            "The coach response was interrupted. Partial reply saved."
        )

        let reloaded = TeoPateoStore(repository: repository, coachClient: coachClient)
        XCTAssertEqual(reloaded.coachMessages.map(\.text), store.coachMessages.map(\.text))
        XCTAssertEqual(reloaded.coachMessages.map(\.isUser), store.coachMessages.map(\.isUser))
    }

    func testCoachCancellationPreservesPartialReplyAndClearsSendingState() async throws {
        let store = TeoPateoStore(
            repository: try makeRepository(),
            coachClient: TestCoachClient(response: .chunksThenFailure(
                ["Name the trigger and wait."],
                CancellationError()
            ))
        )

        await store.sendCoachMessage("I am leaving work and want to smoke.")

        XCTAssertFalse(store.isCoachResponding)
        XCTAssertNil(store.coachResponseState.message)
        XCTAssertEqual(store.coachMessages.count, 2)
        XCTAssertEqual(store.coachMessages.last?.isUser, false)
        XCTAssertEqual(store.coachMessages.last?.text, "Name the trigger and wait.")
    }

    func testCoachCancellationWithoutReplyClearsPlaceholderAndSendingState() async throws {
        let store = TeoPateoStore(
            repository: try makeRepository(),
            coachClient: TestCoachClient(response: .failure(CancellationError()))
        )

        await store.sendCoachMessage("I am craving after lunch.")

        XCTAssertFalse(store.isCoachResponding)
        XCTAssertNil(store.coachResponseState.message)
        XCTAssertEqual(store.coachMessages.count, 1)
        XCTAssertEqual(store.coachMessages.last?.text, "I am craving after lunch.")
        XCTAssertEqual(store.coachMessages.last?.isUser, true)
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

    func testCoachChatPersistenceFailureRestoresPersistedChats() async throws {
        let baseRepository = try makeRepository()
        let repository = ThrowingTeoPateoRepository(base: baseRepository)
        let coachClient = TestCoachClient()
        let now = fixedDate(530)
        let store = TeoPateoStore(repository: repository, coachClient: coachClient, now: { now })

        await store.sendCoachMessage("I want to smoke after coffee.")
        let originalChats = store.coachChats
        let originalSelectedChatID = store.selectedCoachChatID
        repository.failingOperations = [.replaceCoachChats]

        store.startNewCoachChat()

        XCTAssertTrue(store.lastSaveStatus.isFailure)
        XCTAssertEqual(store.coachChats.stableChatFields, originalChats.stableChatFields)
        XCTAssertEqual(store.selectedCoachChatID, originalSelectedChatID)
        XCTAssertEqual(try baseRepository.fetchCoachChats().stableChatFields, originalChats.stableChatFields)
        XCTAssertEqual(try baseRepository.fetchSelectedCoachChatID(), originalSelectedChatID)
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

    func testAcceptedPlanSuggestionUpdatesPlanAfterRepeatedCravingTrigger() throws {
        let repository = try makeRepository()
        try repository.saveQuitPlan(makeQuitPlan(triggerRules: []))
        let store = TeoPateoStore(repository: repository)

        for index in 0..<3 {
            store.selectedTriggers = ["Coffee"]
            XCTAssertTrue(store.completeCravingWithoutSmoking(
                startedAt: fixedDate(700 + index),
                completedAt: fixedDate(710 + index),
                durationSeconds: 300
            ))
        }

        let suggestion = try XCTUnwrap(store.highestPriorityPendingPlanSuggestion)
        XCTAssertEqual(suggestion.type, .addTriggerRule)
        XCTAssertEqual(suggestion.trigger, "Coffee")

        XCTAssertTrue(store.acceptPlanSuggestion(suggestion.id))
        XCTAssertEqual(store.triggerRules.first?.trigger, "Coffee")
        XCTAssertEqual(
            store.currentQuitPlan.pendingPlanSuggestions.first { $0.id == suggestion.id }?.status,
            .accepted
        )

        let reloaded = TeoPateoStore(repository: repository)
        XCTAssertEqual(reloaded.triggerRules.first?.trigger, "Coffee")
        XCTAssertEqual(
            reloaded.currentQuitPlan.pendingPlanSuggestions.first { $0.id == suggestion.id }?.status,
            .accepted
        )
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

    func testStoreSaveDefaultsUseInjectedClock() throws {
        let repository = try makeRepository()
        let calendar = makeCalendar()
        let now = makeDate(year: 2026, month: 6, day: 1, hour: 9, calendar: calendar)
        let store = TeoPateoStore(repository: repository, now: { now }, calendar: calendar)

        store.smokedToday = false
        XCTAssertTrue(store.saveCheckIn(slipNote: ""))
        XCTAssertEqual(store.dailyCheckIns.first?.date, now)
        XCTAssertEqual(store.dailyCheckIns.first?.createdAt, now)

        XCTAssertTrue(store.completeCravingWithoutSmoking(
            startedAt: now.addingTimeInterval(-120),
            durationSeconds: 120,
            selectedTriggers: ["Coffee"]
        ))
        XCTAssertEqual(store.cravingEvents.first?.completedAt, now)
        XCTAssertEqual(store.cravingEvents.first?.createdAt, now)

        XCTAssertTrue(store.saveSlipEvent(
            cigarettesSmoked: 1,
            triggers: ["Stress"],
            context: "Check",
            note: "Clock test.",
            recoveryAction: "Return to plan."
        ))
        XCTAssertEqual(store.slipEvents.first?.occurredAt, now)
        XCTAssertEqual(store.slipEvents.first?.createdAt, now)
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

    func testCravingAndSlipPersistenceFailuresRestorePersistedHistory() throws {
        let baseRepository = try makeRepository()
        let persistedCraving = makeCraving(
            id: 501,
            startedAt: fixedDate(501),
            triggers: ["Persisted craving"]
        )
        let persistedSlip = SlipEvent(
            id: fixedUUID(502),
            occurredAt: fixedDate(502),
            cigarettesSmoked: 1,
            selectedTriggers: ["Persisted slip"],
            context: "Stored",
            note: "Already saved.",
            recoveryAction: "Resume plan.",
            createdAt: fixedDate(503),
            updatedAt: fixedDate(504)
        )
        try baseRepository.saveCravingEvent(persistedCraving)
        try baseRepository.saveSlipEvent(persistedSlip)

        let repository = ThrowingTeoPateoRepository(base: baseRepository)
        let store = TeoPateoStore(repository: repository)

        repository.failingOperations = [.saveCravingEvent]
        XCTAssertFalse(store.completeCravingWithoutSmoking(
            startedAt: fixedDate(505),
            completedAt: fixedDate(506),
            durationSeconds: 60,
            selectedTriggers: ["New craving"]
        ))
        XCTAssertEqual(store.cravingEvents, [persistedCraving])

        repository.failingOperations = [.saveSlipEvent]
        XCTAssertFalse(store.saveSlipEvent(
            cigarettesSmoked: 1,
            triggers: ["New slip"],
            context: "Failure test",
            note: "Should roll back.",
            recoveryAction: "Return to plan."
        ))
        XCTAssertEqual(store.slipEvents, [persistedSlip])
        XCTAssertTrue(store.lastSaveStatus.isFailure)
    }

    func testQuitPlanPersistenceFailureRestoresPersistedState() throws {
        let baseRepository = try makeRepository()
        let originalRules = [
            TriggerRule(
                id: fixedUUID(510),
                trigger: "After coffee",
                action: "Drink water first.",
                isEnabled: true
            )
        ]
        try baseRepository.saveQuitPlan(makeQuitPlan(triggerRules: originalRules))

        let repository = ThrowingTeoPateoRepository(base: baseRepository)
        let store = TeoPateoStore(repository: repository)
        repository.failingOperations = [.saveQuitPlan]

        store.addTriggerRule(trigger: "Work stress", action: "Walk outside.")

        XCTAssertTrue(store.lastSaveStatus.isFailure)
        XCTAssertEqual(store.triggerRules, originalRules)
        XCTAssertEqual(store.currentQuitPlan.triggerRules, originalRules)
        XCTAssertEqual(try baseRepository.fetchQuitPlan()?.triggerRules, originalRules)
    }

    func testCollectionPersistenceFailuresRestorePersistedState() throws {
        let baseRepository = try makeRepository()
        let originalReasons = [
            UserReason(
                id: fixedUUID(520),
                text: "I want to breathe easier.",
                sortOrder: 0,
                isPrimary: true,
                createdAt: fixedDate(520),
                updatedAt: fixedDate(521)
            )
        ]
        let originalActivities = [
            ReplacementActivity(
                id: fixedUUID(522),
                title: "Cold water",
                instruction: "Finish one glass.",
                category: .sensory,
                linkedTrigger: "Coffee",
                createdAt: fixedDate(522),
                updatedAt: fixedDate(523)
            )
        ]
        let originalSituations = [
            RiskySituation(
                id: fixedUUID(524),
                title: "After dinner",
                expectedContext: "Kitchen",
                preventionPlan: "Leave the table.",
                backupAction: "Text support.",
                createdAt: fixedDate(524),
                updatedAt: fixedDate(525)
            )
        ]
        try baseRepository.saveAppSettings(AppSettings(
            onboardingCompleted: true,
            updatedAt: fixedDate(526)
        ))
        try baseRepository.replaceUserReasons(originalReasons)
        try baseRepository.replaceReplacementActivities(originalActivities)
        try baseRepository.replaceRiskySituations(originalSituations)

        let repository = ThrowingTeoPateoRepository(base: baseRepository)
        let store = TeoPateoStore(repository: repository)

        repository.failingOperations = [.replaceUserReasons]
        store.addUserReason("A new reason")
        XCTAssertTrue(store.lastSaveStatus.isFailure)
        XCTAssertEqual(store.userReasons, originalReasons)
        XCTAssertEqual(try baseRepository.fetchUserReasons(), originalReasons)

        repository.failingOperations = [.replaceReplacementActivities]
        store.addReplacementActivity(
            title: "Take a walk",
            instruction: "Walk one block.",
            category: .movement
        )
        XCTAssertTrue(store.lastSaveStatus.isFailure)
        XCTAssertEqual(store.replacementActivities, originalActivities)
        XCTAssertEqual(try baseRepository.fetchReplacementActivities(), originalActivities)

        repository.failingOperations = [.replaceRiskySituations]
        store.addRiskySituation(
            title: "Work stress",
            expectedContext: "Parking lot",
            preventionPlan: "Drive a different route.",
            backupAction: "Call support."
        )
        XCTAssertTrue(store.lastSaveStatus.isFailure)
        XCTAssertEqual(store.riskySituations, originalSituations)
        XCTAssertEqual(try baseRepository.fetchRiskySituations(), originalSituations)
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

private struct StableCoachChatFields: Equatable {
    let id: UUID
    let title: String
    let messages: [StableCoachMessageFields]
}

private struct StableCoachMessageFields: Equatable {
    let id: UUID
    let text: String
    let isUser: Bool
}

private extension Array where Element == CoachChat {
    var stableChatFields: [StableCoachChatFields] {
        map { chat in
            StableCoachChatFields(
                id: chat.id,
                title: chat.title,
                messages: chat.messages.map { message in
                    StableCoachMessageFields(
                        id: message.id,
                        text: message.text,
                        isUser: message.isUser
                    )
                }
            )
        }
    }
}
