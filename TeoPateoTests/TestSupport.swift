import Foundation
import XCTest
@testable import TeoPateo

class TeoPateoTestCase: XCTestCase {
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

    func makeRepository() throws -> SQLiteTeoPateoRepository {
        try SQLiteTeoPateoRepository(databaseURL: databaseURL)
    }

    func fixedDate(_ seconds: Int) -> Date {
        Date(timeIntervalSince1970: TimeInterval(seconds))
    }

    func fixedUUID(_ value: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", value))!
    }

    func makeDate(
        year: Int,
        month: Int,
        day: Int,
        hour: Int = 12,
        minute: Int = 0,
        calendar: Calendar
    ) -> Date {
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components)!
    }

    func makeCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    func makeQuitPlan(
        id: Int = 1,
        quitDate: Date? = nil,
        quitMode: String = "Taper",
        triggerRules: [TriggerRule]? = nil,
        baselineCigarettesPerDay: Double = 10,
        costPerPack: Double = 12,
        cigarettesPerPack: Int = 20,
        taperTargetCigarettesPerDay: Double = 8,
        taperReductionStep: Double = 2,
        taperReductionIntervalDays: Int = 3,
        attemptStartedAt: Date? = nil
    ) -> QuitPlan {
        let date = quitDate ?? fixedDate(10)
        return QuitPlan(
            id: fixedUUID(id),
            quitDate: date,
            quitMode: quitMode,
            triggerRules: triggerRules ?? [
                TriggerRule(
                    id: fixedUUID(2),
                    trigger: "After coffee",
                    action: "Drink water first.",
                    isEnabled: true
                ),
                TriggerRule(
                    id: fixedUUID(3),
                    trigger: "Leaving work",
                    action: "Walk one block.",
                    isEnabled: false
                )
            ],
            medicationNote: "",
            baselineCigarettesPerDay: baselineCigarettesPerDay,
            costPerPack: costPerPack,
            cigarettesPerPack: cigarettesPerPack,
            taperTargetCigarettesPerDay: taperTargetCigarettesPerDay,
            taperReductionStep: taperReductionStep,
            taperReductionIntervalDays: taperReductionIntervalDays,
            attemptStartedAt: attemptStartedAt ?? date,
            createdAt: fixedDate(1),
            updatedAt: fixedDate(2)
        )
    }

    func makeCheckIn(
        id: Int,
        date: Date,
        smokedToday: Bool?,
        cigarettesSmoked: Int = 0,
        stress: Double = 5,
        confidence: Double = 8,
        updatedAt: Date? = nil
    ) -> DailyCheckIn {
        DailyCheckIn(
            id: fixedUUID(id),
            date: date,
            mood: 7,
            stress: stress,
            confidence: confidence,
            smokedToday: smokedToday,
            cigarettesSmoked: cigarettesSmoked,
            slipNote: smokedToday == true ? "Smoked after a trigger." : "",
            createdAt: fixedDate(id),
            updatedAt: updatedAt ?? fixedDate(id + 1)
        )
    }

    func makeCraving(
        id: Int,
        startedAt: Date,
        triggers: [String],
        outcome: CravingOutcome = .completedWithoutSmoking,
        durationSeconds: Int = 600
    ) -> CravingEvent {
        CravingEvent(
            id: fixedUUID(id),
            startedAt: startedAt,
            completedAt: outcome == .dismissedWithoutOutcome
                ? nil
                : startedAt.addingTimeInterval(TimeInterval(durationSeconds)),
            durationSeconds: durationSeconds,
            selectedTriggers: triggers,
            outcome: outcome,
            dismissedAt: outcome == .dismissedWithoutOutcome
                ? startedAt.addingTimeInterval(60)
                : nil,
            createdAt: fixedDate(id),
            updatedAt: fixedDate(id + 1)
        )
    }

    func waitForMainQueue(file: StaticString = #filePath, line: UInt = #line) {
        let expectation = expectation(description: "main queue")
        DispatchQueue.main.async {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)
    }
}

final class TestNotificationScheduler: NotificationScheduling {
    var currentStatus: NotificationPermissionStatus
    var requestResult: Result<NotificationPermissionStatus, Error>
    var replaceResult: Result<Void, Error> = .success(())
    var cancelResult: Result<Void, Error> = .success(())

    private(set) var currentAuthorizationCalls = 0
    private(set) var requestAuthorizationCalls = 0
    private(set) var replaceScheduledCalls = 0
    private(set) var cancelScheduledCalls = 0
    private(set) var scheduledItems: [NotificationScheduleItem] = []

    init(
        currentStatus: NotificationPermissionStatus = .notDetermined,
        requestResult: Result<NotificationPermissionStatus, Error> = .success(.authorized)
    ) {
        self.currentStatus = currentStatus
        self.requestResult = requestResult
    }

    func currentAuthorizationStatus(
        completion: @escaping (NotificationPermissionStatus) -> Void
    ) {
        currentAuthorizationCalls += 1
        completion(currentStatus)
    }

    func requestAuthorization(
        completion: @escaping (Result<NotificationPermissionStatus, Error>) -> Void
    ) {
        requestAuthorizationCalls += 1
        completion(requestResult)
    }

    func replaceScheduledNotifications(
        with items: [NotificationScheduleItem],
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        replaceScheduledCalls += 1
        scheduledItems = items
        completion(replaceResult)
    }

    func cancelScheduledNotifications(
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        cancelScheduledCalls += 1
        scheduledItems = []
        completion(cancelResult)
    }
}

struct TestSchedulerError: Error, Equatable {}
