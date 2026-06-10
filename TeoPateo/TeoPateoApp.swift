import SwiftUI

import UIKit

@main
struct TeoPateoApp: App {
    @StateObject private var store = Self.makeStore()

    init() {
        Observability.start()

        // TextEditor draws on a UITextView whose opaque default background would
        // hide the themed `quietEditor` surface on iOS 15. Make it transparent so
        // the field treatment matches QuietFieldStyle everywhere.
        UITextView.appearance().backgroundColor = .clear
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }

    private static func makeStore() -> TeoPateoStore {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-teopateo-ui-testing") {
            return makeUITestStore()
        }
        #endif

        return TeoPateoStore()
    }

    #if DEBUG
    private static func makeUITestStore() -> TeoPateoStore {
        do {
            let repository = try makeUITestRepository()
            try seedUITestDataIfNeeded(repository)
            return TeoPateoStore(
                repository: repository,
                notificationScheduler: UITestNotificationScheduler(),
                coachClient: UITestCoachClient(),
                now: { makeUITestNow() }
            )
        } catch {
            return TeoPateoStore()
        }
    }

    private static func makeUITestRepository() throws -> SQLiteTeoPateoRepository {
        let environment = ProcessInfo.processInfo.environment
        let databaseName = environment["TEOPATEO_UI_TEST_DATABASE_NAME"] ?? UUID().uuidString
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(databaseName)
            .appendingPathExtension("sqlite")
        try? FileManager.default.removeItem(at: databaseURL)
        return try SQLiteTeoPateoRepository(databaseURL: databaseURL)
    }

    private static func makeUITestNow() -> Date {
        let environment = ProcessInfo.processInfo.environment
        if let value = environment["TEOPATEO_UI_TEST_NOW"],
           let date = ISO8601DateFormatter().date(from: value) {
            return date
        }
        return Date()
    }

    private static func seedUITestDataIfNeeded(_ repository: SQLiteTeoPateoRepository) throws {
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("-teopateo-ui-seed-completed") else {
            return
        }

        let calendar = Calendar.current
        let now = makeUITestNow()
        let quitDate = calendar.date(byAdding: .day, value: 7, to: now) ?? now
        let plan = QuitPlan(
            quitDate: quitDate,
            quitMode: "Taper",
            nextBestAction: "Drink cold water before your morning coffee.",
            triggerRules: [
                TriggerRule(trigger: "After coffee", action: "Drink cold water first."),
                TriggerRule(trigger: "After dinner", action: "Brush teeth before leaving the table.")
            ],
            medicationNote: "",
            baselineCigarettesPerDay: 10,
            costPerPack: 12,
            cigarettesPerPack: 20,
            taperTargetCigarettesPerDay: 8,
            taperReductionStep: 2,
            taperReductionIntervalDays: 3,
            attemptStartedAt: now,
            createdAt: now,
            updatedAt: now
        )

        try repository.saveQuitPlan(plan)
        try repository.saveAppSettings(AppSettings(onboardingCompleted: true, updatedAt: now))
        try repository.replaceUserReasons([
            UserReason(
                text: "I want mornings without chest tightness.",
                sortOrder: 0,
                isPrimary: true,
                createdAt: now,
                updatedAt: now
            )
        ])
        try repository.replaceReplacementActivities([
            ReplacementActivity(
                title: "Drink cold water",
                instruction: "Finish one full glass before deciding anything.",
                category: .sensory,
                linkedTrigger: "Coffee",
                createdAt: now,
                updatedAt: now
            ),
            ReplacementActivity(
                title: "Walk one block",
                instruction: "Move until the urge drops.",
                category: .movement,
                linkedTrigger: "Work stress",
                createdAt: now,
                updatedAt: now
            )
        ])

        if arguments.contains("-teopateo-ui-seed-plan-week") {
            try seedUITestPlanWeek(repository, now: now, calendar: calendar)
        }

        if arguments.contains("-teopateo-ui-seed-history") {
            let yesterday = calendar.date(byAdding: .day, value: -1, to: now) ?? now
            try repository.saveDailyCheckIn(DailyCheckIn(
                date: yesterday,
                mood: 5,
                stress: 8,
                confidence: 4,
                smokedToday: true,
                cigarettesSmoked: 1,
                taperTargetCigarettes: 8,
                stayedWithinTaperTarget: true,
                slipNote: "Dinner was the cue.",
                createdAt: yesterday,
                updatedAt: yesterday
            ))
            try repository.saveCravingEvent(CravingEvent(
                startedAt: yesterday,
                completedAt: yesterday.addingTimeInterval(600),
                durationSeconds: 600,
                selectedTriggers: ["After dinner"],
                outcome: .completedWithoutSmoking,
                initialIntensity: 8,
                finalIntensity: 3,
                reflectionNote: "Water helped.",
                createdAt: yesterday,
                updatedAt: yesterday
            ))
            try repository.saveSlipEvent(SlipEvent(
                occurredAt: now,
                cigarettesSmoked: 2,
                selectedTriggers: ["After dinner"],
                mood: 4,
                stress: 8,
                context: "Dinner",
                note: "Went outside after dinner.",
                recoveryAction: "Brush teeth before leaving the table.",
                createdAt: now,
                updatedAt: now
            ))
        }
    }

    private static func seedUITestPlanWeek(
        _ repository: SQLiteTeoPateoRepository,
        now: Date,
        calendar: Calendar
    ) throws {
        let weekStart = mondayWeekStart(containing: now, calendar: calendar)
        let dailyResults = [
            (offset: 0, cigarettes: 4, note: ""),
            (offset: 1, cigarettes: 5, note: "One over target."),
            (offset: 2, cigarettes: 7, note: "Above target.")
        ]

        for result in dailyResults {
            guard let date = calendar.date(byAdding: .day, value: result.offset, to: weekStart) else {
                continue
            }

            try repository.saveDailyCheckIn(DailyCheckIn(
                date: date,
                mood: 7,
                stress: 5,
                confidence: 8,
                smokedToday: true,
                cigarettesSmoked: result.cigarettes,
                taperTargetCigarettes: 4,
                stayedWithinTaperTarget: result.cigarettes <= 4,
                slipNote: result.note,
                createdAt: date,
                updatedAt: date
            ))
        }
    }

    private static func mondayWeekStart(containing date: Date, calendar: Calendar) -> Date {
        let day = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: day)
        let daysSinceMonday = (weekday + 5) % 7
        return calendar.date(byAdding: .day, value: -daysSinceMonday, to: day) ?? day
    }
    #endif
}

#if DEBUG
private final class UITestNotificationScheduler: NotificationScheduling {
    private var status: NotificationPermissionStatus {
        NotificationPermissionStatus(
            rawValue: ProcessInfo.processInfo.environment["TEOPATEO_UI_TEST_NOTIFICATION_STATUS"] ?? "authorized"
        ) ?? .authorized
    }

    func currentAuthorizationStatus(
        completion: @escaping (NotificationPermissionStatus) -> Void
    ) {
        completion(status)
    }

    func requestAuthorization(
        completion: @escaping (Result<NotificationPermissionStatus, Error>) -> Void
    ) {
        completion(.success(status))
    }

    func replaceScheduledNotifications(
        with items: [NotificationScheduleItem],
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        completion(.success(()))
    }

    func cancelScheduledNotifications(
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        completion(.success(()))
    }
}

private struct UITestCoachClient: CoachResponding {
    func reply(to request: CoachRequest) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield("Name the trigger, start one 10-minute substitute, and decide who gets the alert if the urge spikes.")
            continuation.finish()
        }
    }
}
#endif
