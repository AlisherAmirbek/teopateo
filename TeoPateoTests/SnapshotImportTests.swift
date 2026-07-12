import XCTest
@testable import TeoPateo

/// Repository-level coverage for the local snapshot import/export primitives.
/// These remain useful for migrations and a future user-controlled file export,
/// without sending health data to iCloud.
final class SnapshotImportTests: TeoPateoTestCase {
    func testSnapshotJSONRoundTripThroughImportPreservesData() throws {
        let source = try makeRepository()
        let chatID = fixedUUID(90)

        try source.saveAppSettings(AppSettings(onboardingCompleted: true, updatedAt: fixedDate(10)))
        try source.saveQuitPlan(makeQuitPlan(id: 1, triggerRules: [
            TriggerRule(id: fixedUUID(2), trigger: "Coffee", action: "Drink water.")
        ]))
        try source.saveDailyCheckIn(makeCheckIn(id: 3, date: fixedDate(30), smokedToday: false))
        try source.saveCravingEvent(makeCraving(id: 4, startedAt: fixedDate(40), triggers: ["Coffee"]))
        try source.replaceUserReasons([
            UserReason(
                id: fixedUUID(5),
                text: "Breathing",
                sortOrder: 0,
                isPrimary: true,
                createdAt: fixedDate(1),
                updatedAt: fixedDate(2)
            )
        ])
        try source.replaceCoachChats([
            CoachChat(
                id: chatID,
                title: "First chat",
                messages: [
                    CoachMessage(
                        id: fixedUUID(91),
                        text: "I want to smoke.",
                        isUser: true,
                        createdAt: fixedDate(1)
                    )
                ],
                createdAt: fixedDate(1),
                updatedAt: fixedDate(2)
            )
        ], selectedChatID: chatID)

        let original = try source.loadSnapshot()
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PersistedTeoPateoSnapshot.self, from: data)

        let destination = try makeRepository()
        try destination.importSnapshot(decoded)

        let restored = try destination.loadSnapshot()
        XCTAssertEqual(restored, original)
        XCTAssertEqual(restored.selectedCoachChatID, chatID)
    }

    func testImportSnapshotReplacesExistingData() throws {
        let repository = try makeRepository()
        try repository.saveQuitPlan(makeQuitPlan(id: 1))
        try repository.saveDailyCheckIn(makeCheckIn(id: 1, date: fixedDate(100), smokedToday: true))

        let replacement = PersistedTeoPateoSnapshot(
            appSettings: AppSettings(onboardingCompleted: true, updatedAt: fixedDate(50)),
            quitPlan: makeQuitPlan(id: 2),
            userReasons: [
                UserReason(
                    id: fixedUUID(9),
                    text: "New reason",
                    isPrimary: true,
                    createdAt: fixedDate(1),
                    updatedAt: fixedDate(2)
                )
            ]
        )

        try repository.importSnapshot(replacement)

        let snapshot = try repository.loadSnapshot()
        XCTAssertEqual(snapshot.quitPlan?.id, fixedUUID(2))
        XCTAssertTrue(snapshot.dailyCheckIns.isEmpty)
        XCTAssertEqual(snapshot.userReasons.map(\.text), ["New reason"])
    }
}
