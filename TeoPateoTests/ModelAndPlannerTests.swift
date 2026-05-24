import XCTest
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

        XCTAssertEqual(ReplacementActivityCategory.allCases.map(\.title), [
            "Movement",
            "Breathing",
            "Sensory",
            "Support",
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
}
