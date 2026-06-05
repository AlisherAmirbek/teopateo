import XCTest
@testable import TeoPateo

final class RepositoryMutationTests: TeoPateoTestCase {
    func testSavingQuitPlanReplacesTriggerRulesAndPreservesOrder() throws {
        let repository = try makeRepository()
        var plan = makeQuitPlan(triggerRules: [
            TriggerRule(id: fixedUUID(10), trigger: "Coffee", action: "Drink water."),
            TriggerRule(id: fixedUUID(11), trigger: "Alcohol", action: "Stay inside.")
        ])

        try repository.saveQuitPlan(plan)

        plan.triggerRules = [
            TriggerRule(id: fixedUUID(12), trigger: "After dinner", action: "Brush teeth."),
            TriggerRule(id: fixedUUID(13), trigger: "Commute", action: "Breathe.", isEnabled: false)
        ]
        plan.updatedAt = fixedDate(200)
        try repository.saveQuitPlan(plan)

        XCTAssertEqual(try repository.fetchQuitPlan()?.triggerRules.map(\.trigger), [
            "After dinner",
            "Commute"
        ])
        XCTAssertEqual(try repository.fetchQuitPlan()?.triggerRules.map(\.isEnabled), [true, false])
    }

    func testSavingCravingAndSlipEventsReplacesTriggerJoinRows() throws {
        let repository = try makeRepository()
        let cravingID = fixedUUID(20)
        let slipID = fixedUUID(30)

        try repository.saveCravingEvent(CravingEvent(
            id: cravingID,
            startedAt: fixedDate(20),
            completedAt: fixedDate(21),
            durationSeconds: 60,
            selectedTriggers: ["Coffee", "Stress"],
            outcome: .completedWithoutSmoking,
            createdAt: fixedDate(20),
            updatedAt: fixedDate(21)
        ))
        try repository.saveCravingEvent(CravingEvent(
            id: cravingID,
            startedAt: fixedDate(20),
            completedAt: nil,
            durationSeconds: 90,
            selectedTriggers: ["After meal"],
            outcome: .dismissedWithoutOutcome,
            dismissedAt: fixedDate(22),
            createdAt: fixedDate(20),
            updatedAt: fixedDate(23)
        ))

        XCTAssertEqual(try repository.recentCravingEvents(limit: 10).first?.selectedTriggers, ["After meal"])
        XCTAssertEqual(try repository.recentCravingEvents(limit: 10).first?.outcome, .dismissedWithoutOutcome)

        try repository.saveSlipEvent(SlipEvent(
            id: slipID,
            occurredAt: fixedDate(30),
            cigarettesSmoked: 1,
            selectedTriggers: ["Social", "Alcohol"],
            note: "Original",
            recoveryAction: "Walk",
            createdAt: fixedDate(30),
            updatedAt: fixedDate(31)
        ))
        try repository.saveSlipEvent(SlipEvent(
            id: slipID,
            occurredAt: fixedDate(30),
            cigarettesSmoked: 2,
            selectedTriggers: ["Boredom"],
            note: "Updated",
            recoveryAction: "Call support",
            createdAt: fixedDate(30),
            updatedAt: fixedDate(32)
        ))

        let slip = try XCTUnwrap(repository.recentSlipEvents(limit: 10).first)
        XCTAssertEqual(slip.selectedTriggers, ["Boredom"])
        XCTAssertEqual(slip.cigarettesSmoked, 2)
        XCTAssertEqual(slip.recoveryAction, "Call support")
    }

    func testSavingCravingWithSlipPersistsBothRecordsTogether() throws {
        let repository = try makeRepository()

        try repository.saveCravingWithSlip(
            craving: CravingEvent(
                id: fixedUUID(40),
                startedAt: fixedDate(40),
                completedAt: fixedDate(41),
                durationSeconds: 120,
                selectedTriggers: ["Work stress"],
                outcome: .smokedAfterCraving,
                reflectionNote: "Smoked after a tense call.",
                createdAt: fixedDate(40),
                updatedAt: fixedDate(41)
            ),
            slip: SlipEvent(
                id: fixedUUID(41),
                occurredAt: fixedDate(41),
                cigarettesSmoked: 1,
                selectedTriggers: ["Work stress"],
                context: "Craving mode",
                note: "Smoked after a tense call.",
                recoveryAction: "Walk before checking messages.",
                createdAt: fixedDate(41),
                updatedAt: fixedDate(42)
            )
        )

        let craving = try XCTUnwrap(repository.recentCravingEvents(limit: 10).first)
        let slip = try XCTUnwrap(repository.recentSlipEvents(limit: 10).first)
        XCTAssertEqual(craving.outcome, .smokedAfterCraving)
        XCTAssertEqual(craving.selectedTriggers, ["Work stress"])
        XCTAssertEqual(slip.context, "Craving mode")
        XCTAssertEqual(slip.selectedTriggers, ["Work stress"])
    }

    func testRecentQueriesHonorOrderingAndLimit() throws {
        let repository = try makeRepository()
        for index in 0..<5 {
            try repository.saveDailyCheckIn(makeCheckIn(
                id: 100 + index,
                date: fixedDate(100 + index),
                smokedToday: index.isMultiple(of: 2)
            ))
            try repository.saveCravingEvent(makeCraving(
                id: 200 + index,
                startedAt: fixedDate(200 + index),
                triggers: ["Trigger \(index)"]
            ))
            try repository.saveSlipEvent(SlipEvent(
                id: fixedUUID(300 + index),
                occurredAt: fixedDate(300 + index),
                cigarettesSmoked: 1,
                selectedTriggers: ["Trigger \(index)"],
                note: "Slip \(index)",
                recoveryAction: "Reset",
                createdAt: fixedDate(300 + index),
                updatedAt: fixedDate(301 + index)
            ))
        }

        XCTAssertEqual(try repository.recentCheckIns(limit: 2).map(\.id), [
            fixedUUID(104),
            fixedUUID(103)
        ])
        XCTAssertEqual(try repository.recentCravingEvents(limit: 2).map(\.id), [
            fixedUUID(204),
            fixedUUID(203)
        ])
        XCTAssertEqual(try repository.recentSlipEvents(limit: 2).map(\.id), [
            fixedUUID(304),
            fixedUUID(303)
        ])
    }

    func testDeletesRemoveRecordsFromSnapshots() throws {
        let repository = try makeRepository()
        let checkIn = makeCheckIn(id: 400, date: fixedDate(400), smokedToday: false)
        let craving = makeCraving(id: 401, startedAt: fixedDate(401), triggers: ["Coffee"])
        let slip = SlipEvent(
            id: fixedUUID(402),
            occurredAt: fixedDate(402),
            cigarettesSmoked: 1,
            selectedTriggers: ["Stress"],
            note: "Slip",
            recoveryAction: "Reset",
            createdAt: fixedDate(402),
            updatedAt: fixedDate(403)
        )

        try repository.saveDailyCheckIn(checkIn)
        try repository.saveCravingEvent(craving)
        try repository.saveSlipEvent(slip)

        try repository.deleteDailyCheckIn(checkIn.id)
        try repository.deleteCravingEvent(craving.id)
        try repository.deleteSlipEvent(slip.id)

        let snapshot = try repository.loadSnapshot()
        XCTAssertTrue(snapshot.dailyCheckIns.isEmpty)
        XCTAssertTrue(snapshot.cravingEvents.isEmpty)
        XCTAssertTrue(snapshot.slipEvents.isEmpty)
    }

    func testDefaultSeedRowsExistBeforeAnyUserSave() throws {
        let repository = try makeRepository()

        XCTAssertEqual(try repository.fetchAppSettings(), AppSettings(onboardingCompleted: false, updatedAt: fixedDate(0)))
        XCTAssertEqual(try repository.fetchNotificationSettings()?.morningPlanTime, ReminderTime(hour: 8, minute: 30))
        XCTAssertEqual(try repository.fetchNotificationSettings()?.eveningCheckInTime, ReminderTime(hour: 20, minute: 30))
    }
}
