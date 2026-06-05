import Foundation
import XCTest
import UserNotifications
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

    func makeOnboardingInput(
        nickname: String = "Alex",
        age: Int = 32,
        quitStatus: QuitStatus = .readyToQuit,
        confidence: Double = 6,
        openedAppReason: String = "",
        cigarettesPerDay: Double = 10,
        costPerPack: Double = 12,
        cigarettesPerPack: Int = 20,
        quitDate: Date? = nil,
        quitDatePreference: QuitDatePreference = .chooseDate,
        approachPreference: QuitApproachPreference = .taper,
        firstCigaretteTiming: FirstCigaretteTiming = .withinThirtyMinutes,
        previousQuitAttemptCount: PreviousQuitAttemptCount = .one,
        longestQuitAttempt: LongestQuitAttempt = .fewDays,
        mainChallenge: SmokingChallenge = .cravings,
        commonSmokingTimes: [String] = ["After coffee"],
        emotionalTriggers: [String] = [],
        situationalTriggers: [String] = [],
        replacementActions: [String] = ["Drink water", "Walk"],
        primaryReason: String = "My breathing",
        savingsGoalTitle: String = "Health",
        customSavingsGoal: String = ""
    ) -> OnboardingPlanInput {
        OnboardingPlanInput(
            nickname: nickname,
            age: age,
            quitStatus: quitStatus,
            confidence: confidence,
            openedAppReason: openedAppReason,
            ageStartedSmoking: 18,
            yearsSmoking: nil,
            cigarettesPerDay: cigarettesPerDay,
            firstCigaretteTiming: firstCigaretteTiming,
            previousQuitAttemptCount: previousQuitAttemptCount,
            longestQuitAttempt: longestQuitAttempt,
            mainChallenge: mainChallenge,
            commonSmokingTimes: commonSmokingTimes,
            emotionalTriggers: emotionalTriggers,
            situationalTriggers: situationalTriggers,
            quitDatePreference: quitDatePreference,
            costPerPack: costPerPack,
            cigarettesPerPack: cigarettesPerPack,
            quitDate: quitDate ?? fixedDate(50),
            approachPreference: approachPreference,
            replacementActions: replacementActions,
            primaryReason: primaryReason,
            savingsGoalTitle: savingsGoalTitle,
            customSavingsGoal: customSavingsGoal
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
        if Thread.isMainThread {
            RunLoop.main.run(until: Date().addingTimeInterval(0.02))
            return
        }

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

struct TestCoachError: Error, Equatable {}

final class TestCoachClient: CoachResponding {
    enum Response {
        case success(String)
        case successChunks([String])
        case chunksThenFailure([String], Error)
        case failure(Error)
    }

    private let response: Response
    private(set) var requests: [CoachRequest] = []

    init(response: Response = .success("Take one slow breath, name the trigger, and start water before deciding.")) {
        self.response = response
    }

    func reply(to request: CoachRequest) -> AsyncThrowingStream<String, Error> {
        requests.append(request)
        let response = response

        return AsyncThrowingStream { continuation in
            switch response {
            case .success(let message):
                continuation.yield(message)
                continuation.finish()
            case .successChunks(let chunks):
                for chunk in chunks {
                    continuation.yield(chunk)
                }
                continuation.finish()
            case .chunksThenFailure(let chunks, let error):
                for chunk in chunks {
                    continuation.yield(chunk)
                }
                continuation.finish(throwing: error)
            case .failure(let error):
                continuation.finish(throwing: error)
            }
        }
    }
}

final class TestUserNotificationCenter: UserNotificationCentering {
    var status: UNAuthorizationStatus
    var requestAuthorizationError: Error?
    var addErrorsByIdentifier: [String: Error] = [:]

    private(set) var authorizationStatusCalls = 0
    private(set) var requestAuthorizationOptions: UNAuthorizationOptions?
    private(set) var addedRequests: [UNNotificationRequest] = []
    private(set) var removedIdentifierGroups: [[String]] = []

    init(status: UNAuthorizationStatus = .notDetermined) {
        self.status = status
    }

    func authorizationStatus(
        completion: @escaping @Sendable (UNAuthorizationStatus) -> Void
    ) {
        authorizationStatusCalls += 1
        completion(status)
    }

    func requestAuthorization(
        options: UNAuthorizationOptions,
        completionHandler: @escaping @Sendable (Bool, Error?) -> Void
    ) {
        requestAuthorizationOptions = options
        completionHandler(requestAuthorizationError == nil, requestAuthorizationError)
    }

    func add(
        _ request: UNNotificationRequest,
        withCompletionHandler completionHandler: (@Sendable (Error?) -> Void)?
    ) {
        addedRequests.append(request)
        completionHandler?(addErrorsByIdentifier[request.identifier])
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        removedIdentifierGroups.append(identifiers)
    }
}

struct TestRepositoryError: Error, Equatable, LocalizedError {
    var errorDescription: String? {
        "Test repository failure."
    }
}

enum TestRepositoryOperation: Hashable {
    case loadSnapshot
    case saveQuitPlan
    case saveNotificationSettings
    case saveDailyCheckIn
    case saveCravingEvent
    case saveSlipEvent
    case saveCravingWithSlip
    case replaceUserReasons
    case replaceReplacementActivities
    case replaceRiskySituations
    case replaceCoachChats
    case recentCheckIns
}

final class ThrowingTeoPateoRepository: TeoPateoRepository {
    var failingOperations: Set<TestRepositoryOperation>

    private let base: TeoPateoRepository
    private let error = TestRepositoryError()

    init(
        base: TeoPateoRepository,
        failingOperations: Set<TestRepositoryOperation> = []
    ) {
        self.base = base
        self.failingOperations = failingOperations
    }

    func schemaVersion() throws -> Int {
        try base.schemaVersion()
    }

    func tableNames() throws -> Set<String> {
        try base.tableNames()
    }

    func loadSnapshot() throws -> PersistedTeoPateoSnapshot {
        try failIfNeeded(.loadSnapshot)
        return try base.loadSnapshot()
    }

    func fetchAppSettings() throws -> AppSettings? {
        try base.fetchAppSettings()
    }

    func saveAppSettings(_ settings: AppSettings) throws {
        try base.saveAppSettings(settings)
    }

    func fetchNotificationSettings() throws -> NotificationSettings? {
        try base.fetchNotificationSettings()
    }

    func saveNotificationSettings(_ settings: NotificationSettings) throws {
        try failIfNeeded(.saveNotificationSettings)
        try base.saveNotificationSettings(settings)
    }

    func fetchUserProfile() throws -> UserProfile? {
        try base.fetchUserProfile()
    }

    func saveUserProfile(_ profile: UserProfile) throws {
        try base.saveUserProfile(profile)
    }

    func fetchQuitReadiness() throws -> QuitReadiness? {
        try base.fetchQuitReadiness()
    }

    func saveQuitReadiness(_ readiness: QuitReadiness) throws {
        try base.saveQuitReadiness(readiness)
    }

    func fetchSmokingBackground() throws -> SmokingBackground? {
        try base.fetchSmokingBackground()
    }

    func saveSmokingBackground(_ background: SmokingBackground) throws {
        try base.saveSmokingBackground(background)
    }

    func fetchSavingsGoal() throws -> SavingsGoal? {
        try base.fetchSavingsGoal()
    }

    func saveSavingsGoal(_ goal: SavingsGoal) throws {
        try base.saveSavingsGoal(goal)
    }

    func fetchQuitPlan() throws -> QuitPlan? {
        try base.fetchQuitPlan()
    }

    func saveQuitPlan(_ plan: QuitPlan) throws {
        try failIfNeeded(.saveQuitPlan)
        try base.saveQuitPlan(plan)
    }

    func saveDailyCheckIn(_ checkIn: DailyCheckIn) throws {
        try failIfNeeded(.saveDailyCheckIn)
        try base.saveDailyCheckIn(checkIn)
    }

    func recentCheckIns(limit: Int) throws -> [DailyCheckIn] {
        try failIfNeeded(.recentCheckIns)
        return try base.recentCheckIns(limit: limit)
    }

    func deleteDailyCheckIn(_ id: UUID) throws {
        try base.deleteDailyCheckIn(id)
    }

    func saveCravingEvent(_ event: CravingEvent) throws {
        try failIfNeeded(.saveCravingEvent)
        try base.saveCravingEvent(event)
    }

    func saveCravingWithSlip(craving: CravingEvent, slip: SlipEvent) throws {
        try failIfNeeded(.saveCravingWithSlip)
        try base.saveCravingWithSlip(craving: craving, slip: slip)
    }

    func recentCravingEvents(limit: Int) throws -> [CravingEvent] {
        try base.recentCravingEvents(limit: limit)
    }

    func deleteCravingEvent(_ id: UUID) throws {
        try base.deleteCravingEvent(id)
    }

    func saveSlipEvent(_ event: SlipEvent) throws {
        try failIfNeeded(.saveSlipEvent)
        try base.saveSlipEvent(event)
    }

    func recentSlipEvents(limit: Int) throws -> [SlipEvent] {
        try base.recentSlipEvents(limit: limit)
    }

    func deleteSlipEvent(_ id: UUID) throws {
        try base.deleteSlipEvent(id)
    }

    func replaceReplacementActivities(_ activities: [ReplacementActivity]) throws {
        try failIfNeeded(.replaceReplacementActivities)
        try base.replaceReplacementActivities(activities)
    }

    func fetchReplacementActivities() throws -> [ReplacementActivity] {
        try base.fetchReplacementActivities()
    }

    func replaceRiskySituations(_ situations: [RiskySituation]) throws {
        try failIfNeeded(.replaceRiskySituations)
        try base.replaceRiskySituations(situations)
    }

    func fetchRiskySituations() throws -> [RiskySituation] {
        try base.fetchRiskySituations()
    }

    func replaceSupportContacts(_ contacts: [SupportContact]) throws {
        try base.replaceSupportContacts(contacts)
    }

    func fetchSupportContacts() throws -> [SupportContact] {
        try base.fetchSupportContacts()
    }

    func replaceUserReasons(_ reasons: [UserReason]) throws {
        try failIfNeeded(.replaceUserReasons)
        try base.replaceUserReasons(reasons)
    }

    func fetchUserReasons() throws -> [UserReason] {
        try base.fetchUserReasons()
    }

    func replaceCoachChats(_ chats: [CoachChat], selectedChatID: UUID?) throws {
        try failIfNeeded(.replaceCoachChats)
        try base.replaceCoachChats(chats, selectedChatID: selectedChatID)
    }

    func fetchCoachChats() throws -> [CoachChat] {
        try base.fetchCoachChats()
    }

    func fetchSelectedCoachChatID() throws -> UUID? {
        try base.fetchSelectedCoachChatID()
    }

    private func failIfNeeded(_ operation: TestRepositoryOperation) throws {
        if failingOperations.contains(operation) {
            throw error
        }
    }
}
