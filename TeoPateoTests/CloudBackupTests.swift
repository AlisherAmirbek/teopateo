import XCTest
@testable import TeoPateo

/// Repository-level tests: the backup envelope must round-trip every table through
/// encode → decode → `importSnapshot` without losing or corrupting data. This is the guard
/// against `importSnapshot`'s INSERT SQL drifting from the per-entity `saveX` methods.
final class CloudBackupRepositoryTests: TeoPateoTestCase {
    func testSnapshotRoundTripThroughImportPreservesAllData() throws {
        let source = try makeRepository()

        try source.saveAppSettings(AppSettings(onboardingCompleted: true, updatedAt: fixedDate(10)))
        try source.saveNotificationSettings(NotificationSettings(morningPlanEnabled: true, updatedAt: fixedDate(11)))
        try source.savePrivacySettings(PrivacySettings(
            coachDataConsentStatus: .granted,
            coachDataConsentUpdatedAt: fixedDate(12),
            updatedAt: fixedDate(12)
        ))
        try source.saveUserProfile(UserProfile(nickname: "Alex", age: 32, createdAt: fixedDate(1), updatedAt: fixedDate(2)))
        try source.saveQuitReadiness(QuitReadiness(status: .readyToQuit, confidence: 6, openedAppReason: "Health", createdAt: fixedDate(1), updatedAt: fixedDate(2)))
        try source.saveSmokingBackground(SmokingBackground(
            ageStartedSmoking: 18,
            yearsSmoking: 10,
            firstCigaretteTiming: .withinThirtyMinutes,
            previousQuitAttemptCount: .one,
            longestQuitAttempt: .fewDays,
            mainChallenge: .cravings,
            createdAt: fixedDate(1),
            updatedAt: fixedDate(2)
        ))
        try source.saveSavingsGoal(SavingsGoal(title: "Health", customText: "A trip", createdAt: fixedDate(1), updatedAt: fixedDate(2)))
        try source.saveQuitPlan(makeQuitPlan(id: 1, triggerRules: [
            TriggerRule(id: fixedUUID(2), trigger: "Coffee", action: "Water."),
            TriggerRule(id: fixedUUID(3), trigger: "Commute", action: "Breathe.", isEnabled: false)
        ]))
        try source.saveDailyCheckIn(makeCheckIn(id: 410, date: fixedDate(410), smokedToday: true))
        try source.saveDailyCheckIn(makeCheckIn(id: 411, date: fixedDate(420), smokedToday: false))
        try source.saveCravingEvent(makeCraving(id: 500, startedAt: fixedDate(500), triggers: ["Coffee", "Stress"]))
        try source.saveSlipEvent(SlipEvent(
            id: fixedUUID(600),
            occurredAt: fixedDate(600),
            cigarettesSmoked: 2,
            selectedTriggers: ["Boredom", "Alcohol"],
            mood: 4,
            stress: 8,
            context: "Bar",
            note: "Went outside.",
            recoveryAction: "Brush teeth.",
            createdAt: fixedDate(600),
            updatedAt: fixedDate(601)
        ))
        try source.replaceReplacementActivities([
            ReplacementActivity(id: fixedUUID(50), title: "Walk", instruction: "One block", category: .movement, durationSeconds: 300, linkedTrigger: "Coffee", isEnabled: true, createdAt: fixedDate(1), updatedAt: fixedDate(2))
        ])
        try source.replaceRiskySituations([
            RiskySituation(id: fixedUUID(60), title: "Bar", expectedContext: "Friday night", preventionPlan: "Leave early", backupAction: "Call a friend", isEnabled: true, createdAt: fixedDate(1), updatedAt: fixedDate(2))
        ])
        try source.replaceSupportContacts([
            SupportContact(id: fixedUUID(70), name: "Sam", detail: "Brother", phoneNumber: "5551234", preferredRole: .cravingAlert, defaultMessage: "Need help", createdAt: fixedDate(1), updatedAt: fixedDate(2))
        ])
        try source.replaceUserReasons([
            UserReason(id: fixedUUID(80), text: "Breathing", sortOrder: 0, isPrimary: true, category: "health", createdAt: fixedDate(1), updatedAt: fixedDate(2))
        ])
        let chatID = fixedUUID(90)
        try source.replaceCoachChats([
            CoachChat(
                id: chatID,
                title: "First chat",
                messages: [
                    CoachMessage(id: fixedUUID(91), text: "I want to smoke.", isUser: true, createdAt: fixedDate(1)),
                    CoachMessage(id: fixedUUID(92), text: "Name the trigger first.", isUser: false, createdAt: fixedDate(2))
                ],
                createdAt: fixedDate(1),
                updatedAt: fixedDate(2)
            )
        ], selectedChatID: chatID)

        let original = try source.loadSnapshot()

        // Round-trip through the JSON envelope, exactly as iCloud backup/restore would.
        let envelope = BackupEnvelope(
            schemaVersion: try source.schemaVersion(),
            exportedAt: fixedDate(900),
            deviceName: "Test iPhone",
            snapshot: original
        )
        let data = try JSONEncoder().encode(envelope)
        let decoded = try JSONDecoder().decode(BackupEnvelope.self, from: data)

        // Import into a fresh database (the "new device" case).
        let destinationURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("restored.sqlite")
        addTeardownBlock {
            try? FileManager.default.removeItem(at: destinationURL.deletingLastPathComponent())
        }
        let destination = try SQLiteTeoPateoRepository(databaseURL: destinationURL)
        try destination.importSnapshot(decoded.snapshot)

        let restored = try destination.loadSnapshot()
        XCTAssertEqual(restored, original)
        XCTAssertEqual(restored.selectedCoachChatID, chatID)
        XCTAssertEqual(restored.coachChats.first?.messages.count, 2)
    }

    func testImportSnapshotReplacesExistingData() throws {
        let repository = try makeRepository()
        try repository.saveQuitPlan(makeQuitPlan(id: 1))
        try repository.saveDailyCheckIn(makeCheckIn(id: 1, date: fixedDate(100), smokedToday: true))

        let replacement = PersistedTeoPateoSnapshot(
            appSettings: AppSettings(onboardingCompleted: true, updatedAt: fixedDate(50)),
            quitPlan: makeQuitPlan(id: 2),
            userReasons: [UserReason(id: fixedUUID(9), text: "New reason", isPrimary: true, createdAt: fixedDate(1), updatedAt: fixedDate(2))]
        )

        try repository.importSnapshot(replacement)

        let snapshot = try repository.loadSnapshot()
        XCTAssertEqual(snapshot.quitPlan?.id, fixedUUID(2))
        XCTAssertTrue(snapshot.dailyCheckIns.isEmpty) // old check-in cleared
        XCTAssertEqual(snapshot.userReasons.map(\.text), ["New reason"])
    }
}

/// Store-level tests covering the backup/restore wiring with an injected fake CloudKit service.
@MainActor
final class CloudBackupStoreTests: TeoPateoTestCase {
    private func makeStore(
        repository: TeoPateoRepository,
        cloudBackup: FakeCloudBackupService,
        enabled: Bool = true
    ) -> TeoPateoStore {
        let settings = CloudBackupSettings(defaults: UserDefaults(suiteName: "cloudtest-\(UUID().uuidString)")!)
        settings.isEnabled = enabled
        return TeoPateoStore(
            repository: repository,
            notificationScheduler: TestNotificationScheduler(),
            coachClient: TestCoachClient(),
            now: { self.fixedDate(1000) },
            calendar: makeCalendar(),
            cloudBackup: cloudBackup,
            cloudBackupSettings: settings
        )
    }

    private func backedUpEnvelope(schemaVersion: Int) -> BackupEnvelope {
        let snapshot = PersistedTeoPateoSnapshot(
            appSettings: AppSettings(onboardingCompleted: true, updatedAt: fixedDate(500)),
            quitPlan: makeQuitPlan(id: 7),
            dailyCheckIns: [makeCheckIn(id: 20, date: fixedDate(800), smokedToday: false)],
            userReasons: [UserReason(id: fixedUUID(30), text: "Health", isPrimary: true, createdAt: fixedDate(1), updatedAt: fixedDate(2))]
        )
        return BackupEnvelope(schemaVersion: schemaVersion, exportedAt: fixedDate(900), deviceName: "Backed-up iPhone", snapshot: snapshot)
    }

    private func waitUntil(timeout: TimeInterval = 2, _ condition: @escaping () -> Bool) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() && Date() < deadline {
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
    }

    func testManualRestorePullsCloudDataIntoStore() async throws {
        let repository = try makeRepository()
        let fake = FakeCloudBackupService(availability: .available, stored: backedUpEnvelope(schemaVersion: try repository.schemaVersion()))
        let store = makeStore(repository: repository, cloudBackup: fake)

        let restored = await store.restoreFromCloud()

        XCTAssertTrue(restored)
        XCTAssertTrue(store.isOnboardingCompleted)
        XCTAssertEqual(store.currentQuitPlan.id, fixedUUID(7))
        XCTAssertEqual(store.dailyCheckIns.count, 1)
        XCTAssertEqual(try repository.fetchQuitPlan()?.id, fixedUUID(7))
        XCTAssertEqual(fake.fetchCount, 1)
    }

    func testAutomaticRestoreRestoresOnFreshDevice() async throws {
        let repository = try makeRepository()
        let fake = FakeCloudBackupService(availability: .available, stored: backedUpEnvelope(schemaVersion: try repository.schemaVersion()))
        let store = makeStore(repository: repository, cloudBackup: fake)
        XCTAssertFalse(store.isOnboardingCompleted)

        let restored = await store.runAutomaticRestoreIfEligible()

        XCTAssertTrue(restored)
        XCTAssertTrue(store.isOnboardingCompleted)
        XCTAssertEqual(store.currentQuitPlan.id, fixedUUID(7))
    }

    func testAutomaticRestoreSkippedWhenOnboardingCompleted() async throws {
        let repository = try makeRepository()
        try repository.saveAppSettings(AppSettings(onboardingCompleted: true, updatedAt: fixedDate(1)))
        try repository.saveQuitPlan(makeQuitPlan(id: 99))
        let fake = FakeCloudBackupService(availability: .available, stored: backedUpEnvelope(schemaVersion: try repository.schemaVersion()))
        let store = makeStore(repository: repository, cloudBackup: fake)
        XCTAssertTrue(store.isOnboardingCompleted)

        let restored = await store.runAutomaticRestoreIfEligible()

        XCTAssertFalse(restored)
        XCTAssertEqual(fake.fetchCount, 0) // the onboarding gate prevents any fetch
        XCTAssertEqual(store.currentQuitPlan.id, fixedUUID(99)) // local data untouched
    }

    func testRestoreRejectsBackupFromNewerSchema() async throws {
        let repository = try makeRepository()
        try repository.saveQuitPlan(makeQuitPlan(id: 99))
        let fake = FakeCloudBackupService(availability: .available, stored: backedUpEnvelope(schemaVersion: (try repository.schemaVersion()) + 1))
        let store = makeStore(repository: repository, cloudBackup: fake)

        let restored = await store.restoreFromCloud()

        XCTAssertFalse(restored)
        if case .failed = store.cloudBackupStatus {} else {
            XCTFail("Expected a failed status for an incompatible backup.")
        }
        XCTAssertEqual(try repository.fetchQuitPlan()?.id, fixedUUID(99)) // unchanged
    }

    func testRestoreUnavailableWhenNoAccount() async throws {
        let repository = try makeRepository()
        let fake = FakeCloudBackupService(availability: .noAccount, stored: backedUpEnvelope(schemaVersion: try repository.schemaVersion()))
        let store = makeStore(repository: repository, cloudBackup: fake)

        let restored = await store.restoreFromCloud()

        XCTAssertFalse(restored)
        XCTAssertEqual(fake.fetchCount, 0) // never fetched without an account
    }

    func testBackupPushesEnvelopeToCloud() async throws {
        let repository = try makeRepository()
        try repository.saveQuitPlan(makeQuitPlan(id: 5))
        let fake = FakeCloudBackupService(availability: .available)
        let store = makeStore(repository: repository, cloudBackup: fake)

        await store.backUpAndWait()

        XCTAssertEqual(fake.pushCount, 1)
        XCTAssertEqual(fake.stored?.snapshot.quitPlan?.id, fixedUUID(5))
        XCTAssertEqual(store.lastCloudBackupAt, fixedDate(1000))
        XCTAssertEqual(store.cloudBackupStatus, .success)
    }

    func testBackupDoesNotPushWhenAccountUnavailable() async throws {
        let repository = try makeRepository()
        let fake = FakeCloudBackupService(availability: .noAccount)
        let store = makeStore(repository: repository, cloudBackup: fake)

        await store.backUpAndWait()

        XCTAssertEqual(fake.pushCount, 0)
        XCTAssertNil(fake.stored)
    }

    func testDeletingLocalDataDeletesCloudBackup() async throws {
        let repository = try makeRepository()
        let fake = FakeCloudBackupService(availability: .available, stored: backedUpEnvelope(schemaVersion: try repository.schemaVersion()))
        let store = makeStore(repository: repository, cloudBackup: fake)

        XCTAssertTrue(store.deleteAllLocalData())

        await waitUntil { fake.deleteCount > 0 }
        XCTAssertGreaterThan(fake.deleteCount, 0)
        XCTAssertNil(fake.stored)
    }
}
