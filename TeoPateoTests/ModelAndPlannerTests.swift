import XCTest
import UserNotifications
@testable import TeoPateo

final class ModelAndPlannerTests: TeoPateoTestCase {
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
    }

    #if !DEBUG
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
