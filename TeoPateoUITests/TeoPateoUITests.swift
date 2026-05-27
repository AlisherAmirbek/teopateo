import XCTest

final class TeoPateoUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
    }

    func testOnboardingCreatesPlanAndDismissesToToday() {
        launchApp(seedCompleted: false)

        XCTAssertTrue(app.staticTexts["What should TeoPateo call you?"].waitForExistence(timeout: 5))
        let nicknameField = app.textFields["onboarding-nickname-field"]
        XCTAssertTrue(nicknameField.waitForExistence(timeout: 3))
        nicknameField.tap()
        nicknameField.typeText("Alex")
        app.staticTexts["What should TeoPateo call you?"].tap()
        app.buttons["onboarding-next-button"].tap()

        let reasonField = app.textFields["onboarding-reason-field"]
        XCTAssertTrue(reasonField.waitForExistence(timeout: 3))
        reasonField.tap()
        reasonField.typeText("I want clear mornings")

        app.staticTexts["Where are you in the quit journey?"].tap()
        app.buttons["onboarding-next-button"].tap()
        app.buttons["onboarding-next-button"].tap()
        app.buttons["onboarding-next-button"].tap()
        app.buttons["onboarding-next-button"].tap()
        app.buttons["onboarding-next-button"].tap()
        XCTAssertTrue(app.staticTexts["TeoPateo will start with this rescue setup."].waitForExistence(timeout: 3))
        app.buttons["onboarding-next-button"].tap()

        XCTAssertTrue(app.staticTexts["Pause before the cigarette."].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["continue-setup-button"].exists)
    }

    func testCravingRescueTimerRecoveredFlowAndSave() {
        launchApp()

        app.buttons["start-rescue-button"].tap()
        let timer = app.staticTexts["craving-timer-label"]
        XCTAssertTrue(timer.waitForExistence(timeout: 5))
        XCTAssertEqual(timer.label, "10:00")

        app.buttons["craving-start-pause-button"].tap()
        XCTAssertTrue(waitUntil(timeout: 3) { timer.label != "10:00" })

        app.buttons["craving-reset-button"].tap()
        XCTAssertEqual(timer.label, "10:00")

        app.buttons["craving-recovered-button"].tap()
        let noteField = app.textFields["craving-note-field"]
        XCTAssertTrue(noteField.waitForExistence(timeout: 3))
        noteField.tap()
        noteField.typeText("Water helped")
        app.buttons["craving-outcome-save-button"].tap()

        XCTAssertTrue(app.staticTexts["Pause before the cigarette."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Craving saved as handled."].waitForExistence(timeout: 3))
    }

    func testCheckInRecordsSlip() {
        launchApp()

        app.tabBars.buttons["Check-in"].tap()
        XCTAssertTrue(app.staticTexts["Record today without judging it."].waitForExistence(timeout: 5))
        app.buttons["checkin-choice-I smoked"].tap()

        let context = app.textFields["checkin-slip-context-field"]
        XCTAssertTrue(context.waitForExistence(timeout: 3))
        context.tap()
        context.typeText("Lunch break")

        let note = element("checkin-slip-note-editor")
        note.tap()
        note.typeText("Stress after lunch")

        app.buttons["checkin-save-button"].tap()
        XCTAssertTrue(app.staticTexts["Slip saved as plan data."].waitForExistence(timeout: 5))
    }

    func testHistoryDetailEditDelete() {
        launchApp(seedHistory: true)

        app.tabBars.buttons["Insights"].tap()
        XCTAssertTrue(app.staticTexts["Your risk is predictable."].waitForExistence(timeout: 5))
        openHistory()
        openSlipDetail()

        app.buttons["history-edit-save-notes-button"].tap()
        let historyNote = element("history-note-editor")
        XCTAssertTrue(historyNote.waitForExistence(timeout: 3))
        historyNote.tap()
        historyNote.typeText(" Updated")
        app.buttons["history-edit-save-notes-button"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Updated")).firstMatch.waitForExistence(timeout: 3))

        app.buttons["history-delete-record-button"].tap()
        XCTAssertTrue(app.alerts.buttons["Delete"].waitForExistence(timeout: 3))
        app.alerts.buttons["Delete"].tap()
        XCTAssertFalse(app.buttons["history-row-Slip-Slip: 2 cigarettes"].waitForExistence(timeout: 2))
    }

    func testPlanEditingAddsRuleReasonAndActivity() {
        launchApp()

        app.tabBars.buttons["Plan"].tap()
        XCTAssertTrue(app.staticTexts["Your plan stays specific."].waitForExistence(timeout: 5))

        tapWhenVisible(app.buttons["plan-add-trigger-rule-button"])
        app.textFields["plan-trigger-field"].tap()
        app.textFields["plan-trigger-field"].typeText("Lunch break")
        app.textFields["plan-action-field"].tap()
        app.textFields["plan-action-field"].typeText("Walk outside first")
        app.buttons["plan-sheet-save-button"].tap()
        XCTAssertTrue(app.staticTexts["Lunch break"].waitForExistence(timeout: 3))

        tapWhenVisible(app.buttons["plan-add-reason-button"])
        app.textFields["plan-reason-field"].tap()
        app.textFields["plan-reason-field"].typeText("I want steady energy")
        app.buttons["plan-sheet-save-button"].tap()
        XCTAssertTrue(app.staticTexts["I want steady energy"].waitForExistence(timeout: 3))

        tapWhenVisible(app.buttons["plan-add-activity-button"])
        app.textFields["plan-activity-title-field"].tap()
        app.textFields["plan-activity-title-field"].typeText("Stretch reset")
        app.textFields["plan-activity-instruction-field"].tap()
        app.textFields["plan-activity-instruction-field"].typeText("Stretch for two minutes")
        app.buttons["plan-sheet-save-button"].tap()
        XCTAssertTrue(app.staticTexts["Stretch reset"].waitForExistence(timeout: 3))
    }

    func testNotificationSettingsToggleBuildsSchedulePreview() {
        launchApp()

        app.buttons["notifications-button"].tap()
        XCTAssertTrue(app.staticTexts["Notifications allowed"].waitForExistence(timeout: 5))

        let morningToggle = app.switches["notification-morning_plan-toggle"]
        XCTAssertTrue(morningToggle.waitForExistence(timeout: 3))
        morningToggle.tap()
        XCTAssertTrue(app.staticTexts["Review today's quit plan"].waitForExistence(timeout: 3))

        app.buttons["notification-close-button"].tap()
        XCTAssertTrue(app.staticTexts["Pause before the cigarette."].waitForExistence(timeout: 3))
    }

    func testCoachPromptAndTypedMessageFlow() {
        launchApp()

        app.tabBars.buttons["Coach"].tap()
        XCTAssertTrue(app.staticTexts["Get help before you smoke."].waitForExistence(timeout: 5))

        app.buttons["coach-prompt-I want to smoke now"].tap()
        XCTAssertTrue(app.staticTexts["I want to smoke now. Help me get through the next 10 minutes."].waitForExistence(timeout: 3))

        let input = app.textFields["coach-input-field"]
        input.tap()
        input.typeText("Coffee craving")
        app.buttons["coach-send-button"].tap()

        XCTAssertTrue(app.staticTexts["Coffee craving"].waitForExistence(timeout: 3))
    }

    private func launchApp(
        seedCompleted: Bool = true,
        seedHistory: Bool = false,
        notificationStatus: String = "authorized"
    ) {
        app = XCUIApplication()
        app.launchArguments = ["-teopateo-ui-testing"]
        if seedCompleted {
            app.launchArguments.append("-teopateo-ui-seed-completed")
        }
        if seedHistory {
            app.launchArguments.append("-teopateo-ui-seed-history")
        }
        app.launchEnvironment["TEOPATEO_UI_TEST_DATABASE_NAME"] = UUID().uuidString
        app.launchEnvironment["TEOPATEO_UI_TEST_NOTIFICATION_STATUS"] = notificationStatus
        app.launch()
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    private func openHistory() {
        let identifiedButton = app.buttons["open-history-button"]
        let labeledButton = app.buttons["Open full history"]
        tapWhenVisible(identifiedButton.exists ? identifiedButton : labeledButton)
        XCTAssertTrue(app.staticTexts["Review what actually happened."].waitForExistence(timeout: 5))
    }

    private func openSlipDetail() {
        let row = app.buttons["history-row-Slip-Slip: 2 cigarettes"]
        tapWhenVisible(row)
        XCTAssertTrue(app.staticTexts["Slip: 2 cigarettes"].waitForExistence(timeout: 5))
    }

    private func tapWhenVisible(_ element: XCUIElement) {
        let scrollView = app.scrollViews.firstMatch
        for _ in 0..<8 {
            if element.exists && element.isHittable {
                element.tap()
                return
            }
            if scrollView.exists {
                scrollView.swipeUp()
            }
        }
        XCTAssertTrue(element.waitForExistence(timeout: 1), "Expected \(element) to exist")
        element.tap()
    }

    private func waitUntil(timeout: TimeInterval, predicate: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if predicate() {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return predicate()
    }
}
