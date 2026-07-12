import CryptoKit
import XCTest
import UserNotifications
@testable import TeoPateo

final class ModelAndPlannerTests: TeoPateoTestCase {
    func testCravingCountdownUsesWallClockElapsedTime() {
        let startedAt = fixedDate(1_000)
        let ninetySecondsLater = startedAt.addingTimeInterval(90)
        let fifteenMinutesLater = startedAt.addingTimeInterval(900)

        XCTAssertEqual(
            CravingCountdownClock.remainingSeconds(
                startedAt: startedAt,
                now: ninetySecondsLater,
                hasStarted: true
            ),
            510
        )
        XCTAssertEqual(
            CravingCountdownClock.elapsedSeconds(
                startedAt: startedAt,
                now: fifteenMinutesLater,
                hasStarted: true
            ),
            600
        )
        XCTAssertEqual(
            CravingCountdownClock.remainingSeconds(
                startedAt: startedAt,
                now: fifteenMinutesLater,
                hasStarted: true
            ),
            0
        )
    }

    func testCravingCountdownExcludesExplicitPauseTime() {
        let startedAt = fixedDate(2_000)
        let pausedAt = startedAt.addingTimeInterval(120)
        let whilePaused = startedAt.addingTimeInterval(420)
        let afterResume = startedAt.addingTimeInterval(480)

        XCTAssertEqual(
            CravingCountdownClock.elapsedSeconds(
                startedAt: startedAt,
                now: whilePaused,
                hasStarted: true,
                pausedAt: pausedAt
            ),
            120
        )
        XCTAssertEqual(
            CravingCountdownClock.elapsedSeconds(
                startedAt: startedAt,
                now: afterResume,
                hasStarted: true,
                accumulatedPausedSeconds: 300
            ),
            180
        )
    }

    func testReminderTimeClampsAndFormatsBoundaries() {
        let tooEarly = ReminderTime(hour: -5, minute: -30)
        XCTAssertEqual(tooEarly.hour, 0)
        XCTAssertEqual(tooEarly.minute, 0)
        XCTAssertEqual(tooEarly.minuteOfDay, 0)
        XCTAssertEqual(tooEarly.displayLabel, "12:00 AM")

        let tooLate = ReminderTime(hour: 29, minute: 90)
        XCTAssertEqual(tooLate.hour, 23)
        XCTAssertEqual(tooLate.minute, 59)
        XCTAssertEqual(tooLate.minuteOfDay, 1439)
        XCTAssertEqual(tooLate.displayLabel, "11:59 PM")

        XCTAssertEqual(ReminderTime(hour: 12, minute: 5).displayLabel, "12:05 PM")
        XCTAssertEqual(ReminderTime(hour: 0, minute: 10).addingMinutes(-30), ReminderTime(hour: 23, minute: 40))
        XCTAssertEqual(ReminderTime(hour: 23, minute: 45).addingMinutes(30), ReminderTime(hour: 0, minute: 15))
    }

    func testNotificationSettingsEnablementAndTimesCoverEveryVisibleKind() {
        var settings = NotificationSettings(updatedAt: fixedDate(1))
        XCTAssertFalse(settings.hasEnabledReminders)

        for kind in NotificationKind.userVisibleCases {
            settings.setEnabled(true, for: kind)
            XCTAssertTrue(settings.isEnabled(kind), "\(kind) should be enabled")

            if kind.supportsFixedTime {
                let time = ReminderTime(hour: 6 + kind.rawValue.count % 12, minute: 17)
                settings.setTime(time, for: kind)
                XCTAssertEqual(settings.time(for: kind), time)
            } else {
                let before = settings
                settings.setTime(ReminderTime(hour: 3, minute: 3), for: kind)
                XCTAssertEqual(settings, before)
                XCTAssertNil(settings.time(for: kind))
            }

            settings.setEnabled(false, for: kind)
            XCTAssertFalse(settings.isEnabled(kind), "\(kind) should be disabled")
        }
    }

    func testModelComputedPropertiesExposeUserFacingLabels() {
        XCTAssertEqual(SaveStatus.saved("Saved").message, "Saved")
        XCTAssertNil(SaveStatus.idle.message)
        XCTAssertTrue(SaveStatus.failed("No").isFailure)
        XCTAssertFalse(SaveStatus.saved("Yes").isFailure)

        XCTAssertEqual(SupportRole.cravingAlert.title, "Craving alert")
        XCTAssertEqual(SupportRole.eveningCheckIn.title, "Evening check-in")
        XCTAssertEqual(SupportRole.quitline.title, "Quitline")
        XCTAssertEqual(SupportRole.backup.title, "Backup")

        XCTAssertEqual(NotificationPermissionStatus.unknown.title, "Checking permission")
        XCTAssertEqual(NotificationPermissionStatus.notDetermined.title, "Permission needed")
        XCTAssertEqual(NotificationPermissionStatus.denied.title, "Notifications blocked")
        XCTAssertEqual(NotificationPermissionStatus.authorized.title, "Notifications allowed")
        XCTAssertTrue(NotificationPermissionStatus.provisional.canScheduleNotifications)
        XCTAssertTrue(NotificationPermissionStatus.ephemeral.canScheduleNotifications)

        XCTAssertEqual(ReplacementActivityCategory.userVisibleCases.map(\.title), [
            "Movement",
            "Breathing",
            "Sensory",
            "Journaling",
            "Distraction"
        ])
    }

    func testInsightFormattingHandlesMidnightNoonAndPercentages() {
        let midnight = RiskWindowInsight(startHour: 0, cravingCount: 1, share: 0.333)
        XCTAssertEqual(midnight.title, "12:00 AM-1:00 AM")
        XCTAssertEqual(midnight.startLabel, "12:00 AM")
        XCTAssertEqual(midnight.shareSummary, "33%")

        let noon = RiskWindowInsight(startHour: 12, cravingCount: 3, share: 0.667)
        XCTAssertEqual(noon.title, "12:00 PM-1:00 PM")
        XCTAssertEqual(noon.startLabel, "12:00 PM")
        XCTAssertEqual(noon.shareSummary, "67%")

        XCTAssertEqual(TriggerInsight(name: "Coffee", count: 2, share: 0.125).shareSummary, "13%")
        XCTAssertEqual(CalculatedInsights(
            smokeFreeDays: 0,
            smokeFreeSummary: "0 days",
            cravingsLogged: 0,
            cravingsHandled: 0,
            slippedCravings: 0,
            cigarettesAvoided: 0,
            moneySaved: 0,
            moneySavedSummary: "$0",
            riskWindows: [],
            topTriggers: [],
            topSlipTriggers: [],
            heatMapDays: [],
            planAdjustment: PlanAdjustmentInsight(title: "", detail: "", actionTitle: ""),
            todayRisk: RiskLevelInsight(level: .low, summary: "", actionTitle: ""),
            dataConfidenceSummary: ""
        ).nextRiskSummary, "Log cravings")
    }

    func testQuitPlanCostPerCigaretteHandlesZeroPackSize() {
        XCTAssertEqual(makeQuitPlan(costPerPack: 15, cigarettesPerPack: 20).costPerCigarette, 0.75)
        XCTAssertEqual(makeQuitPlan(costPerPack: 15, cigarettesPerPack: 0).costPerCigarette, 0)
    }

    func testQuitPlanGeneratorChoosesStrategyByQuitStage() {
        let calendar = makeCalendar()
        let now = makeDate(year: 2026, month: 5, day: 28, calendar: calendar)
        let cases: [(QuitStatus, QuitApproachPreference, Double, Double, FirstCigaretteTiming, QuitStrategyType)] = [
            (.alreadyQuit, .notSure, 5, 12, .withinThirtyMinutes, .relapsePrevention),
            (.readyToQuit, .notSure, 8, 6, .laterMorning, .coldTurkey),
            (.cuttingDown, .notSure, 5, 15, .withinThirtyMinutes, .taper),
            (.thinkingAboutIt, .coldTurkey, 7, 8, .laterMorning, .preparation),
            (.unsure, .taper, 6, 10, .withinThirtyMinutes, .awareness)
        ]

        for (status, preference, confidence, cigarettes, timing, expectedStrategy) in cases {
            let output = QuitPlanGenerator.generate(
                from: makeOnboardingInput(
                    quitStatus: status,
                    confidence: confidence,
                    cigarettesPerDay: cigarettes,
                    approachPreference: preference,
                    firstCigaretteTiming: timing,
                    commonSmokingTimes: ["After coffee"],
                    emotionalTriggers: ["Stress"],
                    situationalTriggers: ["Alcohol"]
                ),
                existingPlan: makeQuitPlan(),
                now: now,
                calendar: calendar
            )

            XCTAssertEqual(output.quitPlan.strategyPlan.strategyType, expectedStrategy, "\(status.title)")
            XCTAssertFalse(output.quitPlan.planSummary.summary.isEmpty)
            XCTAssertFalse(output.quitPlan.nextBestAction.isEmpty)
            XCTAssertEqual(output.quitPlan.generatedTriggerRules.count, 3)
        }
    }

    func testQuitPlanGeneratorVariesTaperPaceAndSlipRecovery() {
        let calendar = makeCalendar()
        let now = makeDate(year: 2026, month: 5, day: 28, calendar: calendar)

        let fast = QuitPlanGenerator.generate(
            from: makeOnboardingInput(
                quitStatus: .cuttingDown,
                confidence: 9,
                cigarettesPerDay: 6,
                approachPreference: .taper,
                firstCigaretteTiming: .afternoonOrEvening,
                previousQuitAttemptCount: .none,
                longestQuitAttempt: .fewMonths
            ),
            existingPlan: makeQuitPlan(),
            now: now,
            calendar: calendar
        ).quitPlan

        XCTAssertEqual(fast.taperReductionStep, 2)
        XCTAssertEqual(fast.taperReductionIntervalDays, 2)
        XCTAssertEqual(
            Array(fast.strategyPlan.nextSevenDayTargets.prefix(3).map(\.maximumCigarettes)),
            [6.0, 6.0, 4.0]
        )

        let gentle = QuitPlanGenerator.generate(
            from: makeOnboardingInput(
                quitStatus: .cuttingDown,
                confidence: 3,
                cigarettesPerDay: 24,
                approachPreference: .taper,
                firstCigaretteTiming: .withinFiveMinutes,
                previousQuitAttemptCount: .fourOrMore,
                longestQuitAttempt: .lessThanDay,
                mainChallenge: .withdrawal
            ),
            existingPlan: makeQuitPlan(),
            now: now,
            calendar: calendar
        ).quitPlan

        XCTAssertEqual(gentle.taperReductionStep, 1)
        XCTAssertEqual(gentle.taperReductionIntervalDays, 5)
        XCTAssertTrue(gentle.slipRecoveryPlan.preserveQuitAttemptByDefault)
        XCTAssertTrue(gentle.slipRecoveryPlan.message.localizedCaseInsensitiveContains("do not restart"))
    }

    func testQuitPlanGeneratorPreservesTaperAttemptStartWhenRegenerated() {
        let calendar = makeCalendar()
        let attemptStart = makeDate(year: 2026, month: 5, day: 1, calendar: calendar)
        let now = makeDate(year: 2026, month: 5, day: 28, calendar: calendar)
        let existingPlan = makeQuitPlan(
            quitDate: attemptStart,
            quitMode: "Taper",
            attemptStartedAt: attemptStart
        )

        let regenerated = QuitPlanGenerator.generate(
            from: makeOnboardingInput(
                quitStatus: .cuttingDown,
                cigarettesPerDay: 8,
                approachPreference: .taper
            ),
            existingPlan: existingPlan,
            now: now,
            calendar: calendar
        ).quitPlan

        XCTAssertEqual(regenerated.attemptStartedAt, attemptStart)
        XCTAssertEqual(regenerated.updatedAt, now)
    }

    func testQuitPlanGeneratorDoesNotCreatePhantomSavingsMilestone() {
        let calendar = makeCalendar()
        let now = makeDate(year: 2026, month: 5, day: 28, calendar: calendar)

        let plan = QuitPlanGenerator.generate(
            from: makeOnboardingInput(
                cigarettesPerDay: 0,
                costPerPack: 0,
                cigarettesPerPack: 20
            ),
            existingPlan: makeQuitPlan(),
            now: now,
            calendar: calendar
        ).quitPlan

        XCTAssertEqual(plan.savingsPlan.weeklySavingsBaseline, 0)
        XCTAssertEqual(plan.savingsPlan.firstMilestoneAmount, 0)
    }

    func testQuitPlanGeneratorNormalizesAlreadyQuitDate() {
        let calendar = makeCalendar()
        let now = makeDate(year: 2026, month: 5, day: 28, hour: 15, calendar: calendar)
        let selected = makeDate(year: 2026, month: 5, day: 20, hour: 23, calendar: calendar)

        let plan = QuitPlanGenerator.generate(
            from: makeOnboardingInput(
                quitStatus: .alreadyQuit,
                quitDate: selected,
                quitDatePreference: .alreadyQuit
            ),
            existingPlan: makeQuitPlan(),
            now: now,
            calendar: calendar
        ).quitPlan

        XCTAssertEqual(plan.quitDate, calendar.startOfDay(for: selected))
    }

    func testPlanAdjustmentEngineCreatesEvidenceBackedSuggestionsAndHonorsDismissal() {
        let calendar = makeCalendar()
        let now = makeDate(year: 2026, month: 5, day: 28, hour: 20, calendar: calendar)
        let plan = makeQuitPlan(triggerRules: [])
        let coffeeCravings = (0..<3).map { offset in
            makeCraving(
                id: 300 + offset,
                startedAt: makeDate(year: 2026, month: 5, day: 26 + offset, hour: 9, calendar: calendar),
                triggers: ["Coffee"]
            )
        }

        let suggestions = PlanAdjustmentEngine.updatedSuggestions(
            existing: [],
            quitPlan: plan,
            cravingEvents: coffeeCravings,
            slipEvents: [],
            dailyCheckIns: [],
            replacementActivities: [],
            notificationSettings: NotificationSettings(),
            now: now,
            calendar: calendar
        )

        let triggerSuggestion = suggestions.first { $0.type == .addTriggerRule }
        XCTAssertEqual(triggerSuggestion?.trigger, "Coffee")
        XCTAssertTrue(triggerSuggestion?.evidenceSummary.contains("3 logged cravings") == true)

        var dismissed = try! XCTUnwrap(triggerSuggestion)
        dismissed.status = .dismissed
        let repeatedSuggestions = PlanAdjustmentEngine.updatedSuggestions(
            existing: [dismissed],
            quitPlan: plan,
            cravingEvents: coffeeCravings,
            slipEvents: [],
            dailyCheckIns: [],
            replacementActivities: [],
            notificationSettings: NotificationSettings(),
            now: now,
            calendar: calendar
        )
        XCTAssertEqual(repeatedSuggestions.filter { $0.status == .pending }.count, 0)

        let slipSuggestions = PlanAdjustmentEngine.updatedSuggestions(
            existing: [],
            quitPlan: plan,
            cravingEvents: [],
            slipEvents: [
                SlipEvent(
                    id: fixedUUID(330),
                    occurredAt: fixedDate(330),
                    cigarettesSmoked: 1,
                    selectedTriggers: ["Alcohol"],
                    note: "Smoked outside.",
                    recoveryAction: "Return inside."
                ),
                SlipEvent(
                    id: fixedUUID(331),
                    occurredAt: fixedDate(331),
                    cigarettesSmoked: 1,
                    selectedTriggers: ["Alcohol"],
                    note: "Smoked after drinks.",
                    recoveryAction: "Text someone."
                )
            ],
            dailyCheckIns: [],
            replacementActivities: [],
            notificationSettings: NotificationSettings(),
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(slipSuggestions.first { $0.type == .updateSlipRecovery }?.trigger, "Alcohol")
    }

    func testCoachProxyRequestDoesNotContainProviderSecrets() throws {
        let client = CoachProxyClient(configuration: CoachProxyConfiguration(
            endpointURL: URL(string: "https://coach.example.test/v1/coach/reply")!,
            accessToken: "proxy-token"
        ))

        let request = try client.makeURLRequest(for: CoachRequest(
            contextSummary: "Quit mode: Taper",
            messages: [
                CoachChatMessage(role: .user, content: "I am craving after coffee."),
                CoachChatMessage(role: .assistant, content: "Start with cold water.")
            ]
        ))
        let body = try XCTUnwrap(String(data: try XCTUnwrap(request.httpBody), encoding: .utf8))

        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer proxy-token")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-TeoPateo-Client"), "TeoPateo-iOS")
        XCTAssertTrue(body.contains("Quit mode: Taper"))
        XCTAssertTrue(body.contains("I am craving after coffee."))
        XCTAssertFalse(body.contains("OPENROUTER_API_KEY"))
        XCTAssertFalse(body.contains("sk-or-v1"))
        XCTAssertFalse(body.contains("Authorization"))

        let accessRequest = try client.makeCoachAccessURLRequest(
            signedTransaction: "apple-signed-transaction"
        )
        let accessBody = try XCTUnwrap(
            String(data: try XCTUnwrap(accessRequest.httpBody), encoding: .utf8)
        )

        XCTAssertEqual(accessRequest.url?.path, "/v1/coach/access")
        XCTAssertEqual(accessRequest.httpMethod, "POST")
        XCTAssertEqual(accessRequest.value(forHTTPHeaderField: "Authorization"), "Bearer proxy-token")
        XCTAssertTrue(accessBody.contains("apple-signed-transaction"))
    }

    func testAppAttestClientDataBindsChallengeBodyAndRequestTarget() throws {
        let challenge = Data([1, 2, 3])
        let body = Data("coach request".utf8)
        let encoded = try AppAttestClientData.encoded(
            challenge: challenge,
            requestBody: body,
            method: "POST",
            path: "/v1/coach/reply"
        )
        let repeated = try AppAttestClientData.encoded(
            challenge: challenge,
            requestBody: body,
            method: "POST",
            path: "/v1/coach/reply"
        )
        let decoded = try JSONDecoder().decode(AppAttestClientData.self, from: encoded)

        XCTAssertEqual(encoded, repeated)
        XCTAssertEqual(decoded.challenge, "AQID")
        XCTAssertEqual(decoded.method, "POST")
        XCTAssertEqual(decoded.path, "/v1/coach/reply")
        XCTAssertEqual(
            decoded.bodySha256,
            Data(SHA256.hash(data: body)).base64EncodedString()
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "=", with: "")
        )
        XCTAssertNotEqual(
            encoded,
            try AppAttestClientData.encoded(
                challenge: challenge,
                requestBody: Data("changed".utf8),
                method: "POST",
                path: "/v1/coach/reply"
            )
        )
    }

    func testProductionAppAttestHandshakeWhenExplicitlyEnabled() async throws {
        guard ProcessInfo.processInfo.environment["RUN_APP_ATTEST_INTEGRATION"] == "1" else {
            return
        }

        let endpoint = try XCTUnwrap(
            URL(string: "https://82.38.4.88.sslip.io/v1/coach/reply")
        )
        let body = Data(
            """
            {"contextSummary":"","messages":[],"stream":false}
            """.utf8
        )
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let authorizer = LiveAppAttestAuthorizer(endpointURL: endpoint)
        let authorizedRequest = try await authorizer.authorize(request)
        let (_, response) = try await URLSession.shared.data(for: authorizedRequest)
        let httpResponse = try XCTUnwrap(response as? HTTPURLResponse)

        XCTAssertEqual(
            httpResponse.statusCode,
            400,
            "A 400 response proves App Attest authorization succeeded and request validation ran."
        )
    }

    #if DEBUG
    func testOpenRouterCoachPromptRetainsSafetyBoundaries() {
        let prompt = OpenRouterCoachClient.safetySystemPromptForTesting

        XCTAssertTrue(prompt.contains("not medical care"))
        XCTAssertTrue(prompt.contains("Do not diagnose"))
        XCTAssertTrue(prompt.contains("doctor, pharmacist, or quitline counselor"))
        XCTAssertTrue(prompt.contains("988"))
        XCTAssertTrue(prompt.contains("911"))
        XCTAssertTrue(prompt.contains("1-800-QUIT-NOW"))
    }
    #endif

    #if !DEBUG
    func testReleaseBuildHasProductionProxyEndpoint() throws {
        let configuration = try XCTUnwrap(CoachProxyConfiguration.live(environment: [:]))

        XCTAssertEqual(
            configuration.endpointURL.absoluteString,
            "https://82.38.4.88.sslip.io/v1/coach/reply"
        )
    }

    func testReleaseBuildWithoutProxyCannotUseDirectOpenRouter() async {
        let client = LiveCoachClient(proxyConfiguration: nil)

        do {
            for try await _ in client.reply(to: CoachRequest(
                contextSummary: "Release proxy-only check",
                messages: [CoachChatMessage(role: .user, content: "I am craving.")]
            )) {
                XCTFail("Release builds should not produce direct OpenRouter chunks.")
            }
            XCTFail("Expected release client without proxy configuration to fail.")
        } catch {
            XCTAssertEqual(error as? CoachClientError, .missingProxyConfiguration)
        }
    }
    #endif

    func testNotificationPlannerBuildsSortedIdentifiersAndFallbackBodies() {
        var settings = NotificationSettings(updatedAt: fixedDate(1))
        settings.morningPlanEnabled = true
        settings.postMealEnabled = true
        settings.eveningCheckInEnabled = true
        settings.riskyWindowEnabled = true
        settings.morningPlanTime = ReminderTime(hour: 9, minute: 0)
        settings.postMealTime = ReminderTime(hour: 13, minute: 0)
        settings.eveningCheckInTime = ReminderTime(hour: 20, minute: 0)

        let items = NotificationPlanner.scheduleItems(
            settings: settings,
            quitPlan: makeQuitPlan(triggerRules: [
                TriggerRule(trigger: "After dinner", action: "Brush teeth first.", isEnabled: false)
            ]),
            riskWindows: [
                RiskWindowInsight(startHour: 0, cravingCount: 4, share: 0.5),
                RiskWindowInsight(startHour: 21, cravingCount: 3, share: 0.375),
                RiskWindowInsight(startHour: 8, cravingCount: 1, share: 0.125),
                RiskWindowInsight(startHour: 17, cravingCount: 1, share: 0.125)
            ],
            topTriggers: [
                TriggerInsight(name: "After dinner", count: 4, share: 0.5)
            ]
        )

        XCTAssertEqual(items.map(\.time.minuteOfDay), items.map(\.time.minuteOfDay).sorted())
        XCTAssertEqual(items.filter { $0.kind == .riskyWindow }.count, 3)
        XCTAssertTrue(items.contains {
            $0.kind == .riskyWindow &&
                $0.time == ReminderTime(hour: 23, minute: 30) &&
                $0.body.contains("Keep your 10-minute rescue ready.")
        })
        XCTAssertEqual(Set(NotificationPlanner.allManagedIdentifiers).count, NotificationPlanner.allManagedIdentifiers.count)
        XCTAssertEqual(NotificationPlanner.allManagedIdentifiers.count, 28)
    }

    func testLocalNotificationSchedulerBuildsManagedRequestsForNotificationCenter() {
        let center = TestUserNotificationCenter(status: .authorized)
        let scheduler = LocalNotificationScheduler(center: center)
        let morning = NotificationScheduleItem(
            identifier: "teopateo.notification.morning_plan",
            kind: .morningPlan,
            title: "Review today's quit plan",
            body: "Protect the first trigger.",
            time: ReminderTime(hour: 7, minute: 45)
        )
        let evening = NotificationScheduleItem(
            identifier: "teopateo.notification.evening_check_in",
            kind: .eveningCheckIn,
            title: "Check in without judgment",
            body: "Record what happened today.",
            time: ReminderTime(hour: 20, minute: 5)
        )

        waitForScheduler("schedule managed request") { done in
            scheduler.replaceScheduledNotifications(with: [morning, evening]) { result in
                if case .failure(let error) = result {
                    XCTFail("Expected scheduling to succeed, got \(error).")
                }
                done()
            }
        }

        XCTAssertEqual(center.removedIdentifierGroups, [NotificationPlanner.allManagedIdentifiers])
        XCTAssertEqual(center.addedRequests.map(\.identifier), [morning.identifier, evening.identifier])

        let request = center.addedRequests.first
        XCTAssertEqual(request?.content.title, morning.title)
        XCTAssertEqual(request?.content.body, morning.body)

        let trigger = request?.trigger as? UNCalendarNotificationTrigger
        XCTAssertEqual(trigger?.dateComponents.hour, morning.time.hour)
        XCTAssertEqual(trigger?.dateComponents.minute, morning.time.minute)
        XCTAssertEqual(trigger?.repeats, true)
    }

    func testLocalNotificationSchedulerRequestsPermissionAndMapsStatus() {
        let center = TestUserNotificationCenter(status: .provisional)
        let scheduler = LocalNotificationScheduler(center: center)

        waitForScheduler("read authorization status") { done in
            scheduler.currentAuthorizationStatus { status in
                XCTAssertEqual(status, .provisional)
                done()
            }
        }

        center.status = .authorized
        waitForScheduler("request authorization") { done in
            scheduler.requestAuthorization { result in
                switch result {
                case .success(let status):
                    XCTAssertEqual(status, .authorized)
                case .failure(let error):
                    XCTFail("Expected authorization success, got \(error).")
                }
                done()
            }
        }

        XCTAssertEqual(center.authorizationStatusCalls, 2)
        XCTAssertTrue(center.requestAuthorizationOptions?.contains(.alert) == true)
        XCTAssertTrue(center.requestAuthorizationOptions?.contains(.badge) == true)
        XCTAssertTrue(center.requestAuthorizationOptions?.contains(.sound) == true)
    }

    func testLocalNotificationSchedulerReportsAddFailuresAfterAttemptingRequests() {
        let center = TestUserNotificationCenter(status: .authorized)
        let scheduler = LocalNotificationScheduler(center: center)
        let morning = NotificationScheduleItem(
            identifier: "teopateo.notification.morning_plan",
            kind: .morningPlan,
            title: "Review today's quit plan",
            body: "Protect the first trigger.",
            time: ReminderTime(hour: 7, minute: 45)
        )
        let evening = NotificationScheduleItem(
            identifier: "teopateo.notification.evening_check_in",
            kind: .eveningCheckIn,
            title: "Check in without judgment",
            body: "Record what happened today.",
            time: ReminderTime(hour: 20, minute: 5)
        )
        center.addErrorsByIdentifier[evening.identifier] = TestSchedulerError()

        waitForScheduler("schedule with add failure") { done in
            scheduler.replaceScheduledNotifications(with: [morning, evening]) { result in
                switch result {
                case .success:
                    XCTFail("Expected scheduling failure.")
                case .failure:
                    break
                }
                done()
            }
        }

        XCTAssertEqual(center.removedIdentifierGroups, [NotificationPlanner.allManagedIdentifiers])
        XCTAssertEqual(center.addedRequests.map(\.identifier), [morning.identifier, evening.identifier])
    }

    private func waitForScheduler(
        _ description: String,
        file: StaticString = #filePath,
        line: UInt = #line,
        action: (@escaping () -> Void) -> Void
    ) {
        let expectation = expectation(description: description)
        action {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3)
    }
}
