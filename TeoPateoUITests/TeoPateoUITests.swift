import XCTest

final class TeoPateoUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
    }

    func testOnboardingCreatesPlanAndDismissesToToday() {
        launchApp(seedCompleted: false)

        // Name (conversational first screen + medical boundary).
        XCTAssertTrue(app.staticTexts["What should I call you?"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["TeoPateo is quit support, not medical care."].waitForExistence(timeout: 3))
        let nicknameField = app.textFields["onboarding-nickname-field"]
        XCTAssertTrue(nicknameField.waitForExistence(timeout: 3))
        nicknameField.tap()
        nicknameField.typeText("Alex")
        app.staticTexts["What should I call you?"].tap()
        app.buttons["onboarding-next-button"].tap()

        // One decision per screen — single-choice cards advance on tap.
        tapOnboardingChoiceAndWaitFor("My health", next: "Where are you with quitting?")
        tapOnboardingChoiceAndWaitFor("Ready to quit", next: "How much do you smoke?")
        tapOnboardingChoiceAndWaitFor("Around 10", next: "When do cravings hit hardest?")

        // Multi-select screens start empty — pick at least one, then Continue.
        selectOnboardingTag("After coffee")
        tapOnboardingNextAndWaitFor("What feelings set them off?")
        tapOnboardingNextAndWaitFor("What could you do instead?")
        selectOnboardingTag("Drink water")
        tapOnboardingNextAndWaitFor("When's your quit day?")

        tapOnboardingChoiceAndWaitFor("Help me choose", next: "How do you want to quit?")
        tapOnboardingChoiceAndWaitFor("Cold turkey", next: "How confident do you feel?")
        tapOnboardingChoiceAndWaitFor("Pretty confident", next: "Here's your starter plan.")

        app.buttons["onboarding-next-button"].tap()

        XCTAssertTrue(app.buttons["start-rescue-button"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["continue-setup-button"].exists)
    }

    func testTodayShowsPlanWeekAdherenceStrip() {
        launchApp(seedPlanWeek: true)

        XCTAssertTrue(element("plan-week-card").waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["May 2026"].waitForExistence(timeout: 3))

        let achieved = firstElement("plan-week-day-achieved")
        let slightMiss = firstElement("plan-week-day-slight-miss")
        let missed = firstElement("plan-week-day-missed")
        let notLogged = firstElement("plan-week-day-not-logged")

        XCTAssertTrue(achieved.waitForExistence(timeout: 3))
        XCTAssertTrue(slightMiss.waitForExistence(timeout: 3))
        XCTAssertTrue(missed.waitForExistence(timeout: 3))
        XCTAssertTrue(notLogged.waitForExistence(timeout: 3))
        XCTAssertTrue(achieved.label.contains("plan achieved"))
        XCTAssertTrue(slightMiss.label.contains("slightly missed plan"))
        XCTAssertTrue(missed.label.contains("missed plan"))
        XCTAssertTrue(notLogged.label.contains("not logged"))
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

        XCTAssertTrue(app.buttons["start-rescue-button"].waitForExistence(timeout: 5))
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
        XCTAssertTrue(app.staticTexts["Today's playbook."].waitForExistence(timeout: 5))

        openPlanDetails()
        tapWhenVisible(app.buttons["plan-add-trigger-rule-button"])
        typeText("Lunch break", intoTextField: "plan-trigger-field")
        typeText("Walk outside first", intoTextField: "plan-action-field")
        app.buttons["plan-sheet-save-button"].tap()
        XCTAssertTrue(app.staticTexts["Today's playbook."].waitForExistence(timeout: 3))

        openPlanDetails()
        XCTAssertTrue(app.staticTexts["Lunch break"].waitForExistence(timeout: 3))
        tapWhenVisible(app.buttons["plan-add-reason-button"])
        typeText("I want steady energy", intoTextField: "plan-reason-field")
        app.buttons["plan-sheet-save-button"].tap()
        XCTAssertTrue(app.staticTexts["Today's playbook."].waitForExistence(timeout: 3))

        openPlanDetails()
        XCTAssertTrue(app.staticTexts["I want steady energy"].waitForExistence(timeout: 3))
        tapWhenVisible(app.buttons["plan-add-activity-button"])
        typeText("Stretch reset", intoTextField: "plan-activity-title-field")
        typeText("Stretch for two minutes", intoTextField: "plan-activity-instruction-field")
        app.buttons["plan-sheet-save-button"].tap()
        XCTAssertTrue(app.staticTexts["Today's playbook."].waitForExistence(timeout: 3))

        openPlanDetails()
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
        XCTAssertTrue(app.buttons["start-rescue-button"].waitForExistence(timeout: 3))
    }

    func testCoachPromptAndTypedMessageFlow() {
        launchApp()

        app.tabBars.buttons["Coach"].tap()
        XCTAssertTrue(app.staticTexts["Get help before you smoke."].waitForExistence(timeout: 5))

        tapWhenVisible(app.buttons["coach-prompt-I want to smoke now"])
        XCTAssertTrue(app.staticTexts["Allow AI coach replies?"].waitForExistence(timeout: 3))
        app.buttons["coach-consent-allow-button"].tap()
        XCTAssertTrue(app.staticTexts["I want to smoke now. Help me get through the next 10 minutes."].waitForExistence(timeout: 3))
        XCTAssertTrue(element("coach-ai-generated-label").waitForExistence(timeout: 3))
        let reportButton = app.buttons["coach-report-unsafe-reply-button"].firstMatch
        tapWhenVisible(reportButton)
        XCTAssertTrue(app.staticTexts["Coach reply marked for review. Use 988, 911, or a trusted person now if safety feels urgent."].waitForExistence(timeout: 3))

        let input = app.textFields["coach-input-field"]
        tapWhenVisible(input)
        input.typeText("Coffee craving")
        app.buttons["coach-send-button"].tap()

        XCTAssertTrue(app.staticTexts["Coffee craving"].waitForExistence(timeout: 3))
    }

    private func launchApp(
        seedCompleted: Bool = true,
        seedHistory: Bool = false,
        seedPlanWeek: Bool = false,
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
        if seedPlanWeek {
            app.launchArguments.append("-teopateo-ui-seed-plan-week")
        }
        app.launchEnvironment["TEOPATEO_UI_TEST_DATABASE_NAME"] = UUID().uuidString
        app.launchEnvironment["TEOPATEO_UI_TEST_NOW"] = "2026-05-27T12:00:00Z"
        app.launchEnvironment["TEOPATEO_UI_TEST_NOTIFICATION_STATUS"] = notificationStatus
        app.launch()
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    private func firstElement(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
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

    private func openPlanDetails() {
        tapWhenVisible(app.buttons["plan-edit-details-button"])
        XCTAssertTrue(app.staticTexts["Edit plan details"].waitForExistence(timeout: 5))
    }

    private func typeText(_ text: String, intoTextField identifier: String) {
        let field = app.textFields[identifier]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        expectation(
            for: NSPredicate(format: "hasKeyboardFocus == true"),
            evaluatedWith: field
        )
        waitForExpectations(timeout: 2)
        field.typeText(text)
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

    private func tapOnboardingNextAndWaitFor(_ label: String) {
        app.buttons["onboarding-next-button"].tap()
        XCTAssertTrue(app.staticTexts[label].waitForExistence(timeout: 5))
    }

    private func tapOnboardingChoiceAndWaitFor(_ choice: String, next: String) {
        let button = app.buttons["onboarding-choice-\(choice)"]
        XCTAssertTrue(button.waitForExistence(timeout: 5), "Expected onboarding choice \(choice)")
        button.tap()
        XCTAssertTrue(app.staticTexts[next].waitForExistence(timeout: 5), "Expected next onboarding screen \(next)")
    }

    private func selectOnboardingTag(_ item: String) {
        let tag = app.buttons["tag-\(item)"]
        XCTAssertTrue(tag.waitForExistence(timeout: 5), "Expected onboarding tag \(item)")
        tapWhenVisible(tag)
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
