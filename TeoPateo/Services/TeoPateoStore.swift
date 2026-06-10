import Foundation
import OSLog
#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class TeoPateoStore: ObservableObject {
    @Published var selectedTab: AppTab = .today
    @Published var isCravingModePresented = false
    @Published var isOnboardingPresented = false
    @Published var quitMode = "Taper" {
        didSet {
            updateQuitMode()
        }
    }
    @Published var mood = 6.0
    @Published var stress = 7.0
    @Published var confidence = 5.0
    @Published var smokedToday: Bool?
    @Published var cigarettesSmoked = 1
    @Published var selectedTriggers: Set<String> = []
    @Published var selectedSlipTriggers: Set<String> = []
    @Published private(set) var triggerRules: [TriggerRule] = []
    @Published private(set) var supportContacts: [SupportContact] = []
    @Published private(set) var userReasons: [UserReason] = []
    @Published private(set) var dailyCheckIns: [DailyCheckIn] = []
    @Published private(set) var cravingEvents: [CravingEvent] = []
    @Published private(set) var slipEvents: [SlipEvent] = []
    @Published private(set) var replacementActivities: [ReplacementActivity] = []
    @Published private(set) var riskySituations: [RiskySituation] = []
    @Published private(set) var coachChats: [CoachChat] = []
    @Published private(set) var selectedCoachChatID: UUID?
    @Published private(set) var coachResponseState: CoachResponseState = .ready
    @Published private(set) var userProfile: UserProfile?
    @Published private(set) var quitReadiness: QuitReadiness?
    @Published private(set) var smokingBackground: SmokingBackground?
    @Published private(set) var savingsGoal: SavingsGoal?
    @Published private(set) var privacySettings = PrivacySettings()
    @Published private(set) var notificationSettings = NotificationSettings()
    @Published private(set) var notificationPermissionStatus: NotificationPermissionStatus = .unknown
    @Published private(set) var isOnboardingCompleted = false
    @Published private(set) var persistenceError: String?
    @Published private(set) var lastSaveStatus: SaveStatus = .idle {
        didSet {
            // Any successful local save is a change worth backing up. This single hook covers
            // every `.saved` site. Suppressed during hydration and while applying a cloud
            // restore (the data already matches the cloud in that case).
            guard !isHydrating, !isApplyingCloudRestore else { return }
            if case .saved = lastSaveStatus {
                scheduleCloudPushDebounced()
            }
        }
    }
    @Published private(set) var isTutorialActive = false

    // iCloud backup state (see the "iCloud Backup" extension below).
    @Published private(set) var isCloudBackupEnabled = true
    @Published private(set) var cloudBackupAvailability: CloudBackupAvailability = .couldNotDetermine
    @Published private(set) var lastCloudBackupAt: Date?
    @Published private(set) var lastCloudBackupDevice: String?
    @Published private(set) var cloudBackupStatus: CloudBackupStatus = .idle

    private var hasSeenTutorial = false
    private static let tutorialDefaultsKey = "teopateo.hasSeenTutorial"

    private let repository: TeoPateoRepository
    private let notificationScheduler: NotificationScheduling
    private let coachClient: CoachResponding
    private let now: () -> Date
    private let calendar: Calendar
    private let cloudBackup: CloudBackupService
    private let cloudBackupSettings: CloudBackupSettings
    private var cloudPushTask: Task<Void, Never>?
    private var isApplyingCloudRestore = false
    private var hasAttemptedCloudRestore = false
    private var quitPlan = TeoPateoStore.defaultQuitPlan()
    private var isHydrating = false
    private static let coachSafetyLogger = Logger(
        subsystem: "com.teopateo.TeoPateo",
        category: "CoachSafety"
    )

    convenience init() {
        do {
            try self.init(
                repository: SQLiteTeoPateoRepository.live(),
                cloudBackup: CloudKitBackupService()
            )
        } catch {
            // SQLite is unavailable. Stay fully local with a no-op backup so we never push
            // empty in-memory data over a good iCloud backup, and never try to restore into a
            // throwaway store.
            self.init(repository: InMemoryTeoPateoRepository())
            recordPersistenceError(error)
            lastSaveStatus = .failed("Local storage is unavailable. Changes may not persist.")
        }
    }

    init(
        repository: TeoPateoRepository,
        notificationScheduler: NotificationScheduling = LocalNotificationScheduler(),
        coachClient: CoachResponding = LiveCoachClient(),
        now: @escaping () -> Date = Date.init,
        calendar: Calendar = .current,
        cloudBackup: CloudBackupService = NoopCloudBackupService(),
        cloudBackupSettings: CloudBackupSettings = CloudBackupSettings()
    ) {
        self.repository = repository
        self.notificationScheduler = notificationScheduler
        self.coachClient = coachClient
        self.now = now
        self.calendar = calendar
        self.cloudBackup = cloudBackup
        self.cloudBackupSettings = cloudBackupSettings
        self.isCloudBackupEnabled = cloudBackupSettings.isEnabled
        self.lastCloudBackupAt = cloudBackupSettings.lastBackupAt
        self.lastCloudBackupDevice = cloudBackupSettings.lastBackupDevice
        self.hasSeenTutorial = Self.loadHasSeenTutorial()
        hydrateFromPersistence()
        maybeStartTutorial()
    }

    /// Surface a persistence failure to the UI and report it to Sentry as a
    /// non-fatal, so field write failures are visible. Routed through one place
    /// so every catch site reports consistently.
    private func recordPersistenceError(_ error: Error) {
        persistenceError = error.localizedDescription
        Observability.record(error, category: "persistence")
    }

    var currentQuitPlan: QuitPlan {
        quitPlan
    }

    var displayName: String {
        let nickname = userProfile?.nickname.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return nickname.isEmpty ? "you" : nickname
    }

    var firstPlanSummary: String {
        let summary = quitPlan.planSummary.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        if !summary.isEmpty {
            return summary
        }
        let generated = quitPlan.generatedPlanSummary.trimmingCharacters(in: .whitespacesAndNewlines)
        if !generated.isEmpty {
            return generated
        }
        return "Keep one trigger rule and one 10-minute substitute ready before the next urge shows up."
    }

    var dailyFocus: String {
        let focus = todaysFocusPlan?.action.trimmingCharacters(in: .whitespacesAndNewlines) ??
            quitPlan.generatedDailyFocus.trimmingCharacters(in: .whitespacesAndNewlines)
        return focus.isEmpty ? quitPlan.quitStatus.defaultDailyFocus : focus
    }

    var todaysFocusPlan: DailyFocusPlan? {
        guard !quitPlan.dailyFocusPlan.isEmpty else { return nil }
        let elapsed = max(
            calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: quitPlan.planSummary.planStartDate),
                to: calendar.startOfDay(for: now())
            ).day ?? 0,
            0
        )
        let index = min(elapsed + 1, 7)
        return quitPlan.dailyFocusPlan.first { $0.dayIndex == index } ?? quitPlan.dailyFocusPlan.first
    }

    var highestPriorityPendingPlanSuggestion: PlanAdjustmentSuggestion? {
        quitPlan.pendingPlanSuggestions
            .filter { $0.status == .pending }
            .sorted {
                if $0.confidence != $1.confidence {
                    return $0.confidence > $1.confidence
                }
                return $0.createdAt > $1.createdAt
            }
            .first
    }

    var savingsGoalSummary: String? {
        let generated = quitPlan.savingsPlan.savingsGoalMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        if !generated.isEmpty {
            return generated
        }
        guard let savingsGoal else { return nil }
        let title = savingsGoal.displayTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return nil }
        return "Savings goal: \(title)"
    }

    var cravingTriggerOptions: [String] {
        let planned = triggerRules.map(\.trigger)
        let recent = calculatedInsights.topTriggers.map(\.name)
        let fallback = ["After coffee", "After meals", "Work stress", "Boredom", "Alcohol", "Social pressure"]
        return Self.uniqueStrings(planned + recent + fallback).prefix(8).map { $0 }
    }

    var selectedCoachChat: CoachChat? {
        guard let selectedCoachChatID else { return coachChats.first }
        return coachChats.first { $0.id == selectedCoachChatID } ?? coachChats.first
    }

    var coachMessages: [CoachMessage] {
        selectedCoachChat?.messages ?? []
    }

    var canStartNewCoachChat: Bool {
        !isCoachResponding && coachMessages.contains { $0.isUser }
    }

    var canDeleteSelectedCoachChat: Bool {
        !isCoachResponding && selectedCoachChat != nil
    }

    var canSendCoachDataOffDevice: Bool {
        privacySettings.coachDataConsentStatus.isGranted
    }

    var coachDataConsentStatus: CoachDataConsentStatus {
        privacySettings.coachDataConsentStatus
    }

    var todayTaperTarget: Double? {
        taperTarget(on: now())
    }

    var todayCheckIn: DailyCheckIn? {
        latestCheckIn(on: now())
    }

    var currentWeekPlanAdherence: [DailyPlanAdherenceDay] {
        planAdherenceWeek(containing: now())
    }

    var metrics: [ProgressMetric] {
        let insights = calculatedInsights
        return [
            ProgressMetric(label: "Smoke-free", value: insights.smokeFreeSummary),
            ProgressMetric(label: "Cravings handled", value: "\(insights.cravingsHandled)"),
            ProgressMetric(label: "Saved", value: insights.moneySavedSummary)
        ]
    }

    var calculatedInsights: CalculatedInsights {
        Self.calculateInsights(
            quitPlan: quitPlan,
            dailyCheckIns: dailyCheckIns,
            cravingEvents: cravingEvents,
            slipEvents: slipEvents,
            triggerRules: triggerRules,
            now: now(),
            calendar: calendar
        )
    }

    var progressSummary: ProgressSummary {
        let insights = calculatedInsights
        return ProgressSummary(
            smokeFreeDays: insights.smokeFreeDays,
            cigarettesAvoided: insights.cigarettesAvoided,
            moneySaved: insights.moneySaved,
            cravingsHandled: insights.cravingsHandled,
            milestones: earnedMilestones(
                smokeFreeDays: insights.smokeFreeDays,
                cravingsHandled: insights.cravingsHandled,
                slipCount: slipEvents.count,
                moneySaved: insights.moneySaved
            )
        )
    }

    var plannedNotificationItems: [NotificationScheduleItem] {
        NotificationPlanner.scheduleItems(
            settings: notificationSettings,
            quitPlan: quitPlan,
            riskWindows: calculatedInsights.riskWindows,
            topTriggers: calculatedInsights.topTriggers
        )
    }

    var historyGroups: [HistoryDayGroup] {
        let entries = historyEntries()
        let grouped = Dictionary(grouping: entries) { entry in
            calendar.startOfDay(for: entry.date)
        }

        return grouped
            .map { day, entries in
                HistoryDayGroup(
                    day: day,
                    entries: entries.sorted { $0.date > $1.date }
                )
            }
            .sorted { $0.day > $1.day }
    }

    @discardableResult
    func saveCheckIn(
        date: Date? = nil,
        slipNote: String
    ) -> Bool {
        guard smokedToday != nil else {
            lastSaveStatus = .failed("Choose whether you smoked today before saving.")
            return false
        }

        let now = now()
        let checkInDate = date ?? now
        let existing = latestCheckIn(on: checkInDate)
        let cigarettesSmoked = smokedToday == true ? max(cigarettesSmoked, 1) : 0
        let taperTarget = taperTarget(on: checkInDate)
        let checkIn = DailyCheckIn(
            id: existing?.id ?? UUID(),
            date: checkInDate,
            mood: mood,
            stress: stress,
            confidence: confidence,
            smokedToday: smokedToday,
            cigarettesSmoked: cigarettesSmoked,
            taperTargetCigarettes: taperTarget,
            stayedWithinTaperTarget: taperTarget.map { Double(cigarettesSmoked) <= $0 },
            slipNote: smokedToday == true ? slipNote : "",
            createdAt: existing?.createdAt ?? now,
            updatedAt: now
        )

        do {
            try repository.saveDailyCheckIn(checkIn)
            dailyCheckIns = try repository.recentCheckIns(limit: 10_000)
            refreshPlanAdjustmentSuggestions()
            persistenceError = nil
            lastSaveStatus = .saved(existing == nil ? "Check-in saved." : "Today check-in updated.")
            return true
        } catch {
            restorePersistedStateAfterSaveFailure()
            recordPersistenceError(error)
            lastSaveStatus = .failed("Check-in could not be saved.")
            return false
        }
    }

    @discardableResult
    func completeCraving(
        startedAt: Date,
        completedAt: Date? = nil,
        durationSeconds: Int,
        completedWithoutSmoking: Bool,
        selectedTriggers: Set<String>? = nil
    ) -> Bool {
        let resolvedCompletedAt = completedAt ?? now()
        if completedWithoutSmoking {
            return completeCravingWithoutSmoking(
                startedAt: startedAt,
                completedAt: resolvedCompletedAt,
                durationSeconds: durationSeconds,
                selectedTriggers: selectedTriggers
            )
        }

        return completeCravingWithSlip(
            startedAt: startedAt,
            completedAt: resolvedCompletedAt,
            durationSeconds: durationSeconds,
            cigarettesSmoked: 1,
            slipNote: "Smoked during a craving.",
            recoveryAction: "Return to the next planned 10-minute pause.",
            selectedTriggers: selectedTriggers
        )
    }

    @discardableResult
    func completeCravingWithoutSmoking(
        startedAt: Date,
        completedAt: Date? = nil,
        durationSeconds: Int,
        initialIntensity: Double? = nil,
        finalIntensity: Double? = nil,
        helpedActivityID: UUID? = nil,
        supportContactID: UUID? = nil,
        reflectionNote: String = "",
        selectedTriggers: Set<String>? = nil
    ) -> Bool {
        let resolvedCompletedAt = completedAt ?? now()
        let event = makeCravingEvent(
            startedAt: startedAt,
            completedAt: resolvedCompletedAt,
            durationSeconds: durationSeconds,
            outcome: .completedWithoutSmoking,
            initialIntensity: initialIntensity,
            finalIntensity: finalIntensity,
            helpedActivityID: helpedActivityID,
            supportContactID: supportContactID,
            reflectionNote: reflectionNote,
            dismissedAt: nil,
            selectedTriggers: selectedTriggers
        )

        return persistCravingEvent(event, successMessage: "Craving saved as handled.")
    }

    @discardableResult
    func completeCravingWithSlip(
        startedAt: Date,
        completedAt: Date? = nil,
        durationSeconds: Int,
        initialIntensity: Double? = nil,
        finalIntensity: Double? = nil,
        helpedActivityID: UUID? = nil,
        supportContactID: UUID? = nil,
        cigarettesSmoked: Int,
        slipNote: String,
        recoveryAction: String,
        selectedTriggers: Set<String>? = nil
    ) -> Bool {
        let resolvedCompletedAt = completedAt ?? now()
        let triggerSelection = selectedTriggers ?? self.selectedTriggers
        let event = makeCravingEvent(
            startedAt: startedAt,
            completedAt: resolvedCompletedAt,
            durationSeconds: durationSeconds,
            outcome: .smokedAfterCraving,
            initialIntensity: initialIntensity,
            finalIntensity: finalIntensity,
            helpedActivityID: helpedActivityID,
            supportContactID: supportContactID,
            reflectionNote: slipNote,
            dismissedAt: nil,
            selectedTriggers: triggerSelection
        )

        let now = now()
        let slipEvent = SlipEvent(
            occurredAt: resolvedCompletedAt,
            cigarettesSmoked: max(cigarettesSmoked, 1),
            selectedTriggers: triggerSelection.sorted(),
            mood: mood,
            stress: stress,
            context: "Craving mode",
            note: slipNote,
            recoveryAction: recoveryAction,
            createdAt: now,
            updatedAt: now
        )

        do {
            try repository.saveCravingWithSlip(craving: event, slip: slipEvent)
            cravingEvents = try repository.recentCravingEvents(limit: 10_000)
            slipEvents = try repository.recentSlipEvents(limit: 10_000)
            refreshPlanAdjustmentSuggestions()
            persistenceError = nil
            lastSaveStatus = .saved("Craving and slip saved.")
            syncScheduledNotifications(showSuccess: false)
            return true
        } catch {
            restorePersistedStateAfterSaveFailure()
            recordPersistenceError(error)
            lastSaveStatus = .failed("Craving and slip could not be saved.")
            return false
        }
    }

    @discardableResult
    func dismissCravingSession(
        startedAt: Date,
        dismissedAt: Date? = nil,
        durationSeconds: Int,
        initialIntensity: Double? = nil,
        selectedTriggers: Set<String>? = nil
    ) -> Bool {
        let resolvedDismissedAt = dismissedAt ?? now()
        let event = makeCravingEvent(
            startedAt: startedAt,
            completedAt: nil,
            durationSeconds: durationSeconds,
            outcome: .dismissedWithoutOutcome,
            initialIntensity: initialIntensity,
            finalIntensity: nil,
            helpedActivityID: nil,
            supportContactID: nil,
            reflectionNote: "",
            dismissedAt: resolvedDismissedAt,
            selectedTriggers: selectedTriggers
        )

        return persistCravingEvent(event, successMessage: "Craving saved for later review.")
    }

    @discardableResult
    func saveSlipEvent(
        occurredAt: Date? = nil,
        cigarettesSmoked: Int,
        triggers: Set<String>,
        mood: Double? = nil,
        stress: Double? = nil,
        context: String,
        note: String,
        recoveryAction: String
    ) -> Bool {
        let now = now()
        let resolvedOccurredAt = occurredAt ?? now
        let event = SlipEvent(
            occurredAt: resolvedOccurredAt,
            cigarettesSmoked: max(cigarettesSmoked, 1),
            selectedTriggers: triggers.sorted(),
            mood: mood,
            stress: stress,
            context: context,
            note: note,
            recoveryAction: recoveryAction,
            createdAt: now,
            updatedAt: now
        )

        do {
            try repository.saveSlipEvent(event)
            slipEvents = try repository.recentSlipEvents(limit: 10_000)
            refreshPlanAdjustmentSuggestions()
            persistenceError = nil
            lastSaveStatus = .saved("Slip saved as plan data.")
            return true
        } catch {
            restorePersistedStateAfterSaveFailure()
            recordPersistenceError(error)
            lastSaveStatus = .failed("Slip could not be saved.")
            return false
        }
    }

    func startCravingSession() {
        lastSaveStatus = .idle
    }

    var isCoachResponding: Bool {
        coachResponseState.isSending
    }

    func startNewCoachChat() {
        guard canStartNewCoachChat else { return }

        let chat = makeEmptyCoachChat()
        coachChats.insert(chat, at: 0)
        selectedCoachChatID = chat.id
        coachResponseState = .ready
        persistCoachChats()
    }

    func deleteCoachChat(_ chatID: UUID) {
        guard !isCoachResponding,
              let deletedIndex = coachChats.firstIndex(where: { $0.id == chatID })
        else { return }

        let wasSelected = selectedCoachChat?.id == chatID
        coachChats.remove(at: deletedIndex)

        if coachChats.isEmpty {
            let chat = makeEmptyCoachChat()
            coachChats = [chat]
            selectedCoachChatID = chat.id
        } else if wasSelected {
            let nextIndex = min(deletedIndex, coachChats.count - 1)
            selectedCoachChatID = coachChats[nextIndex].id
        } else {
            selectedCoachChatID = Self.validSelectedCoachChatID(selectedCoachChatID, in: coachChats)
        }

        coachResponseState = .ready
        persistCoachChats()
    }

    func selectCoachChat(_ chatID: UUID) {
        guard coachChats.contains(where: { $0.id == chatID }) else { return }
        guard selectedCoachChatID != chatID else { return }

        selectedCoachChatID = chatID
        coachResponseState = .ready
        persistCoachChats()
    }

    @MainActor
    func sendCoachMessage(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isCoachResponding else { return }
        guard canSendCoachDataOffDevice else {
            coachResponseState = .failed(Self.coachConsentRequiredMessage)
            return
        }

        let chatID = ensureSelectedCoachChat()
        appendCoachMessage(
            CoachMessage(text: trimmed, isUser: true, createdAt: now()),
            to: chatID,
            updateTitleFromUserText: trimmed
        )
        coachResponseState = .sending
        persistCoachChats()

        var assistantMessageID: UUID?
        var reply = ""
        do {
            guard !Task.isCancelled else {
                throw CancellationError()
            }

            let coachRequest = makeCoachRequest(for: chatID)
            let pendingAssistantMessageID = UUID()
            assistantMessageID = pendingAssistantMessageID
            appendCoachMessage(
                CoachMessage(id: pendingAssistantMessageID, text: "", isUser: false, createdAt: now()),
                to: chatID
            )

            for try await chunk in coachClient.reply(to: coachRequest) {
                guard !Task.isCancelled else {
                    throw CancellationError()
                }
                reply += chunk
                updateCoachMessage(pendingAssistantMessageID, in: chatID, text: reply)
            }

            guard !Task.isCancelled else {
                throw CancellationError()
            }

            let trimmedReply = reply.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedReply.isEmpty else {
                deleteCoachMessage(pendingAssistantMessageID, from: chatID)
                throw CoachClientError.emptyResponse
            }
            updateCoachMessage(pendingAssistantMessageID, in: chatID, text: trimmedReply)
            coachResponseState = .ready
            persistCoachChats()
        } catch {
            let trimmedReply = reply.trimmingCharacters(in: .whitespacesAndNewlines)
            if let assistantMessageID {
                if trimmedReply.isEmpty {
                    deleteCoachMessage(assistantMessageID, from: chatID)
                } else {
                    updateCoachMessage(assistantMessageID, in: chatID, text: trimmedReply)
                }
                persistCoachChats()
            }

            if Task.isCancelled || Self.isCancellation(error) {
                coachResponseState = .ready
            } else {
                Self.recordUnexpectedCoachError(error)
                if !trimmedReply.isEmpty {
                    coachResponseState = .failed(Self.partialCoachReplySavedMessage)
                } else {
                    coachResponseState = .failed(Self.coachErrorMessage(for: error))
                }
            }
        }
    }

    @discardableResult
    func reportUnsafeCoachMessage(_ messageID: UUID) -> Bool {
        guard !isCoachResponding,
              let chatIndex = coachChats.firstIndex(where: { chat in
                  chat.messages.contains { $0.id == messageID }
              }),
              let messageIndex = coachChats[chatIndex].messages.firstIndex(where: { $0.id == messageID })
        else {
            return false
        }

        let message = coachChats[chatIndex].messages[messageIndex]
        guard !message.isUser else { return false }

        if message.isReportedUnsafe {
            coachResponseState = .failed(Self.coachReplyAlreadyReportedMessage)
            return true
        }

        var chat = coachChats[chatIndex]
        chat.messages[messageIndex].isReportedUnsafe = true
        chat.updatedAt = now()
        coachChats[chatIndex] = chat
        persistCoachChats()

        Self.coachSafetyLogger.warning(
            "Unsafe coach reply reported. chatID=\(chat.id.uuidString, privacy: .public) messageID=\(message.id.uuidString, privacy: .public) characters=\(message.text.count, privacy: .public)"
        )
        coachResponseState = .failed(Self.coachReplyReportedMessage)
        return true
    }

    @discardableResult
    func grantCoachDataConsent() -> Bool {
        updateCoachDataConsent(.granted, successMessage: "Coach sharing is on.")
    }

    @discardableResult
    func declineCoachDataConsent() -> Bool {
        updateCoachDataConsent(.denied, successMessage: "Coach sharing is off.")
    }

    @discardableResult
    func revokeCoachDataConsent() -> Bool {
        updateCoachDataConsent(.denied, successMessage: "Coach sharing is off.")
    }

    @discardableResult
    func deleteAllLocalData() -> Bool {
        do {
            try repository.deleteAllUserData()
            let wasHydrating = isHydrating
            isHydrating = true
            applyDefaultState()
            isHydrating = wasHydrating
            selectedTab = .today
            persistenceError = nil
            lastSaveStatus = .saved("Local data deleted.")
            // Honor the deletion in iCloud too: cancel the debounced push the line above just
            // scheduled, then remove the cloud backup so the deleted data cannot resurface on
            // this or another device.
            cloudPushTask?.cancel()
            let backupService = cloudBackup
            Task { try? await backupService.deleteBackup() }
            notificationScheduler.cancelScheduledNotifications { [weak self] result in
                DispatchQueue.main.async {
                    guard let self else { return }
                    if case .failure = result {
                        self.lastSaveStatus = .failed("Local data was deleted, but notifications could not be cleared.")
                    }
                }
            }
            return true
        } catch {
            restorePersistedStateAfterSaveFailure()
            recordPersistenceError(error)
            lastSaveStatus = .failed("Local data could not be deleted.")
            return false
        }
    }

    func updateQuitDate(_ date: Date) {
        quitPlan.quitDate = date
        quitPlan.planSummary.quitDate = date
        quitPlan.strategyPlan.quitDate = date
        quitPlan.updatedAt = now()
        persistQuitPlan(successMessage: "Quit date updated.")
    }

    func updateProgressBaseline(
        cigarettesPerDay: Double,
        costPerPack: Double,
        cigarettesPerPack: Int
    ) {
        quitPlan.baselineCigarettesPerDay = max(cigarettesPerDay, 0)
        quitPlan.costPerPack = max(costPerPack, 0)
        quitPlan.cigarettesPerPack = max(cigarettesPerPack, 1)
        updateSavingsPlanForCurrentBaseline()
        quitPlan.updatedAt = now()
        persistQuitPlan(successMessage: "Progress baseline updated.")
    }

    func updateTaperSettings(
        targetCigarettesPerDay: Double,
        reductionStep: Double,
        reductionIntervalDays: Int
    ) {
        quitPlan.taperTargetCigarettesPerDay = min(
            max(targetCigarettesPerDay, 0),
            max(quitPlan.baselineCigarettesPerDay, 0)
        )
        let clampedStep = max(reductionStep, 0)
        quitPlan.taperReductionStep = quitPlan.taperTargetCigarettesPerDay > 0
            ? max(clampedStep, 1)
            : 0
        quitPlan.taperReductionIntervalDays = max(reductionIntervalDays, 1)
        quitPlan.strategyPlan.taperTarget = quitPlan.taperTargetCigarettesPerDay
        quitPlan.strategyPlan.taperStep = quitPlan.taperReductionStep
        quitPlan.strategyPlan.taperIntervalDays = quitPlan.taperReductionIntervalDays
        quitPlan.updatedAt = now()
        persistQuitPlan(successMessage: "Taper schedule updated.")
    }

    func taperTarget(on date: Date) -> Double? {
        guard quitPlan.quitMode == "Taper" else {
            return nil
        }

        let startDay = calendar.startOfDay(for: quitPlan.attemptStartedAt)
        let targetDay = calendar.startOfDay(for: date)
        let elapsedDays = max(
            calendar.dateComponents([.day], from: startDay, to: targetDay).day ?? 0,
            0
        )
        let interval = max(quitPlan.taperReductionIntervalDays, 1)
        let completedIntervals = elapsedDays / interval
        let reduction = Double(completedIntervals) * effectiveTaperReductionStep()
        return max(quitPlan.taperTargetCigarettesPerDay - reduction, 0)
    }

    private func effectiveTaperReductionStep() -> Double {
        let step = max(quitPlan.taperReductionStep, 0)
        guard quitPlan.taperTargetCigarettesPerDay > 0 else {
            return 0
        }
        return max(step, 1)
    }

    func taperSchedule(days: Int = 7) -> [TaperScheduleDay] {
        guard quitPlan.quitMode == "Taper", days > 0 else {
            return []
        }

        let today = calendar.startOfDay(for: now())
        return (0..<days).compactMap { offset in
            guard
                let date = calendar.date(byAdding: .day, value: offset, to: today),
                let target = taperTarget(on: date)
            else {
                return nil
            }

            return TaperScheduleDay(
                date: date,
                targetCigarettes: target,
                isToday: calendar.isDate(date, inSameDayAs: today)
            )
        }
    }

    func planAdherenceWeek(containing date: Date) -> [DailyPlanAdherenceDay] {
        let today = calendar.startOfDay(for: now())
        let start = weekStart(containing: date)

        return (0..<7).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else {
                return nil
            }

            let checkIn = latestCheckIn(on: day)
            let slipCigarettes = slipEvents
                .filter { calendar.isDate($0.occurredAt, inSameDayAs: day) }
                .reduce(0) { $0 + $1.cigarettesSmoked }
            let target = checkIn?.taperTargetCigarettes ?? taperTarget(on: day) ?? 0
            let cigarettes = Self.effectiveCigarettesSmoked(
                checkIn: checkIn,
                slipCigarettes: slipCigarettes
            )

            return DailyPlanAdherenceDay(
                date: day,
                targetCigarettes: target,
                cigarettesSmoked: cigarettes,
                status: day <= today
                    ? Self.dailyPlanAdherenceStatus(cigarettesSmoked: cigarettes, targetCigarettes: target)
                    : nil,
                isToday: calendar.isDate(day, inSameDayAs: today)
            )
        }
    }

    @discardableResult
    func completeOnboarding(_ input: OnboardingPlanInput) -> Bool {
        let now = now()
        let nickname = input.nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !nickname.isEmpty else {
            lastSaveStatus = .failed("Add a name or nickname before creating the plan.")
            return false
        }

        let primaryReason = input.primaryReason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !primaryReason.isEmpty else {
            lastSaveStatus = .failed("Add one reason before creating the plan.")
            return false
        }

        let generatedPlan = QuitPlanGenerator.generate(
            from: input,
            existingPlan: quitPlan,
            now: now,
            calendar: calendar
        )
        let nextProfile = UserProfile(
            nickname: nickname,
            age: max(input.age, 0),
            createdAt: userProfile?.createdAt ?? now,
            updatedAt: now
        )
        let nextReadiness = QuitReadiness(
            status: input.quitStatus,
            confidence: min(max(input.confidence, 1), 10),
            openedAppReason: input.openedAppReason.trimmingCharacters(in: .whitespacesAndNewlines),
            createdAt: quitReadiness?.createdAt ?? now,
            updatedAt: now
        )
        let nextBackground = SmokingBackground(
            ageStartedSmoking: input.ageStartedSmoking,
            yearsSmoking: input.yearsSmoking,
            firstCigaretteTiming: input.firstCigaretteTiming,
            previousQuitAttemptCount: input.previousQuitAttemptCount,
            longestQuitAttempt: input.longestQuitAttempt,
            mainChallenge: input.mainChallenge,
            createdAt: smokingBackground?.createdAt ?? now,
            updatedAt: now
        )
        let nextSavingsGoal = SavingsGoal(
            title: input.savingsGoalTitle.trimmingCharacters(in: .whitespacesAndNewlines),
            customText: input.customSavingsGoal.trimmingCharacters(in: .whitespacesAndNewlines),
            createdAt: savingsGoal?.createdAt ?? now,
            updatedAt: now
        )

        let nextPlan = generatedPlan.quitPlan

        let nextSettings = AppSettings(onboardingCompleted: true, updatedAt: now)

        do {
            try repository.saveUserProfile(nextProfile)
            try repository.saveQuitReadiness(nextReadiness)
            try repository.saveSmokingBackground(nextBackground)
            try repository.saveSavingsGoal(nextSavingsGoal)
            try repository.saveQuitPlan(nextPlan)
            try repository.replaceSupportContacts([])
            try repository.replaceUserReasons(generatedPlan.userReasons)
            try repository.replaceReplacementActivities(generatedPlan.replacementActivities)
            try repository.replaceRiskySituations(generatedPlan.riskySituations)
            try repository.saveAppSettings(nextSettings)

            isHydrating = true
            userProfile = nextProfile
            quitReadiness = nextReadiness
            smokingBackground = nextBackground
            savingsGoal = nextSavingsGoal
            quitPlan = nextPlan
            quitMode = nextPlan.quitMode
            triggerRules = generatedPlan.triggerRules
            supportContacts = []
            userReasons = generatedPlan.userReasons
            replacementActivities = generatedPlan.replacementActivities
            riskySituations = generatedPlan.riskySituations
            self.selectedTriggers = Set(generatedPlan.triggerRules.map(\.trigger))
            confidence = input.confidence
            isOnboardingCompleted = true
            isOnboardingPresented = false
            selectedTab = .today
            isHydrating = false

            persistenceError = nil
            lastSaveStatus = .saved("Your quit plan is ready.")
            scheduleTutorialStart()
            return true
        } catch {
            isHydrating = false
            recordPersistenceError(error)
            lastSaveStatus = .failed("Onboarding could not be saved.")
            return false
        }
    }

    func presentOnboarding() {
        isOnboardingPresented = true
    }

    func dismissOnboardingForNow() {
        isOnboardingPresented = false
        selectedTab = .today
    }

    // MARK: - Tutorial (one-time coach marks on Today)

    /// Ends the tour and remembers it so it never auto-shows again.
    func completeTutorial() {
        isTutorialActive = false
        guard !hasSeenTutorial else { return }
        hasSeenTutorial = true
        if !Self.isUITesting {
            UserDefaults.standard.set(true, forKey: Self.tutorialDefaultsKey)
        }
    }

    /// Shows the tour once the user is on Today with a finished plan.
    private func maybeStartTutorial() {
        guard !isTutorialActive, !hasSeenTutorial else { return }
        guard isOnboardingCompleted, !isOnboardingPresented else { return }
        if Self.isUITesting && !Self.forceShowTutorial { return }
        isTutorialActive = true
    }

    /// Used right after onboarding so the coach marks fade in once the
    /// onboarding cover has dismissed, not on top of it.
    private func scheduleTutorialStart() {
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 450_000_000)
            self?.maybeStartTutorial()
        }
    }

    private static func loadHasSeenTutorial() -> Bool {
        if isUITesting { return false }
        return UserDefaults.standard.bool(forKey: tutorialDefaultsKey)
    }

    private static var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("-teopateo-ui-testing")
    }

    private static var forceShowTutorial: Bool {
        ProcessInfo.processInfo.arguments.contains("-teopateo-ui-show-tutorial")
    }

    func addTriggerRule(trigger: String, action: String) {
        let trimmedTrigger = trigger.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAction = action.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTrigger.isEmpty, !trimmedAction.isEmpty else {
            lastSaveStatus = .failed("Trigger and action are required.")
            return
        }
        triggerRules.append(TriggerRule(trigger: trimmedTrigger, action: trimmedAction))
        quitPlan.triggerRules = triggerRules
        quitPlan.updatedAt = now()
        persistQuitPlan(successMessage: "Trigger rule added.")
    }

    func updateTriggerRule(
        id: UUID,
        trigger: String,
        action: String,
        isEnabled: Bool
    ) {
        let trimmedTrigger = trigger.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAction = action.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTrigger.isEmpty, !trimmedAction.isEmpty else {
            lastSaveStatus = .failed("Trigger and action are required.")
            return
        }
        guard let index = triggerRules.firstIndex(where: { $0.id == id }) else {
            return
        }

        triggerRules[index].trigger = trimmedTrigger
        triggerRules[index].action = trimmedAction
        triggerRules[index].isEnabled = isEnabled
        quitPlan.triggerRules = triggerRules
        quitPlan.updatedAt = now()
        persistQuitPlan(successMessage: "Trigger rule updated.")
    }

    func setTriggerRuleEnabled(_ id: UUID, isEnabled: Bool) {
        guard let index = triggerRules.firstIndex(where: { $0.id == id }) else {
            return
        }

        triggerRules[index].isEnabled = isEnabled
        quitPlan.triggerRules = triggerRules
        quitPlan.updatedAt = now()
        persistQuitPlan(successMessage: isEnabled ? "Trigger rule enabled." : "Trigger rule disabled.")
    }

    func deleteTriggerRule(_ id: UUID) {
        guard triggerRules.contains(where: { $0.id == id }) else {
            return
        }

        triggerRules.removeAll { $0.id == id }
        quitPlan.triggerRules = triggerRules
        quitPlan.updatedAt = now()
        persistQuitPlan(successMessage: "Trigger rule removed.")
    }

    func moveTriggerRule(_ id: UUID, direction: Int) {
        guard
            direction != 0,
            let fromIndex = triggerRules.firstIndex(where: { $0.id == id })
        else {
            return
        }

        let toIndex = min(max(fromIndex + direction, 0), triggerRules.count - 1)
        guard toIndex != fromIndex else {
            return
        }

        triggerRules.move(from: fromIndex, to: toIndex)
        quitPlan.triggerRules = triggerRules
        quitPlan.updatedAt = now()
        persistQuitPlan(successMessage: "Trigger rules reordered.")
    }

    func addUserReason(_ text: String, isPrimary: Bool = false) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            lastSaveStatus = .failed("Reason cannot be empty.")
            return
        }

        if isPrimary {
            userReasons = userReasons.map { reason in
                var updated = reason
                updated.isPrimary = false
                updated.updatedAt = now()
                return updated
            }
        }

        userReasons.append(
            UserReason(
                text: trimmed,
                sortOrder: userReasons.count,
                isPrimary: isPrimary || userReasons.isEmpty,
                createdAt: now(),
                updatedAt: now()
            )
        )
        persistUserReasons(successMessage: "Reason saved.")
    }

    func setPrimaryUserReason(_ id: UUID) {
        userReasons = userReasons.map { reason in
            var updated = reason
            updated.isPrimary = reason.id == id
            updated.updatedAt = now()
            return updated
        }
        persistUserReasons(successMessage: "Primary reason updated.")
    }

    func updateUserReason(_ id: UUID, text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            lastSaveStatus = .failed("Reason cannot be empty.")
            return
        }
        guard let index = userReasons.firstIndex(where: { $0.id == id }) else {
            return
        }

        userReasons[index].text = trimmed
        userReasons[index].updatedAt = now()
        persistUserReasons(successMessage: "Reason updated.")
    }

    func moveUserReason(_ id: UUID, direction: Int) {
        guard
            direction != 0,
            let fromIndex = userReasons.firstIndex(where: { $0.id == id })
        else {
            return
        }

        let toIndex = min(max(fromIndex + direction, 0), userReasons.count - 1)
        guard toIndex != fromIndex else {
            return
        }

        userReasons.move(from: fromIndex, to: toIndex)
        userReasons = normalizedUserReasons(userReasons)
        persistUserReasons(successMessage: "Reasons reordered.")
    }

    func deleteUserReason(_ id: UUID) {
        guard userReasons.contains(where: { $0.id == id }) else {
            return
        }

        userReasons.removeAll { $0.id == id }

        var nextReasons = userReasons.enumerated().map { index, reason in
            var updated = reason
            updated.sortOrder = index
            updated.updatedAt = now()
            return updated
        }

        if !nextReasons.isEmpty && !nextReasons.contains(where: \.isPrimary) {
            nextReasons[0].isPrimary = true
            nextReasons[0].updatedAt = now()
        }

        userReasons = nextReasons
        persistUserReasons(successMessage: "Reason removed.")
    }

    func addReplacementActivity(
        title: String,
        instruction: String,
        category: ReplacementActivityCategory,
        linkedTrigger: String = ""
    ) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedInstruction = instruction.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty, !trimmedInstruction.isEmpty else {
            lastSaveStatus = .failed("Activity title and instruction are required.")
            return
        }
        replacementActivities.append(
            ReplacementActivity(
                title: trimmedTitle,
                instruction: trimmedInstruction,
                category: category,
                linkedTrigger: linkedTrigger,
                createdAt: now(),
                updatedAt: now()
            )
        )
        persistReplacementActivities(successMessage: "Replacement activity saved.")
    }

    func updateReplacementActivity(
        id: UUID,
        title: String,
        instruction: String,
        category: ReplacementActivityCategory,
        linkedTrigger: String,
        isEnabled: Bool
    ) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedInstruction = instruction.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTrigger = linkedTrigger.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty, !trimmedInstruction.isEmpty else {
            lastSaveStatus = .failed("Activity title and instruction are required.")
            return
        }
        guard let index = replacementActivities.firstIndex(where: { $0.id == id }) else {
            return
        }

        replacementActivities[index].title = trimmedTitle
        replacementActivities[index].instruction = trimmedInstruction
        replacementActivities[index].category = category
        replacementActivities[index].linkedTrigger = trimmedTrigger
        replacementActivities[index].isEnabled = isEnabled
        replacementActivities[index].updatedAt = now()
        persistReplacementActivities(successMessage: "Replacement activity updated.")
    }

    func setReplacementActivityEnabled(_ id: UUID, isEnabled: Bool) {
        guard let index = replacementActivities.firstIndex(where: { $0.id == id }) else {
            return
        }

        replacementActivities[index].isEnabled = isEnabled
        replacementActivities[index].updatedAt = now()
        persistReplacementActivities(successMessage: isEnabled ? "Replacement activity enabled." : "Replacement activity disabled.")
    }

    func deleteReplacementActivity(_ id: UUID) {
        guard replacementActivities.contains(where: { $0.id == id }) else {
            return
        }

        replacementActivities.removeAll { $0.id == id }
        persistReplacementActivities(successMessage: "Replacement activity removed.")
    }

    func moveReplacementActivity(_ id: UUID, direction: Int) {
        guard
            direction != 0,
            let fromIndex = replacementActivities.firstIndex(where: { $0.id == id })
        else {
            return
        }

        let toIndex = min(max(fromIndex + direction, 0), replacementActivities.count - 1)
        guard toIndex != fromIndex else {
            return
        }

        replacementActivities.move(from: fromIndex, to: toIndex)
        persistReplacementActivities(successMessage: "Replacement activities reordered.")
    }

    func addRiskySituation(
        title: String,
        expectedContext: String,
        preventionPlan: String,
        backupAction: String
    ) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContext = expectedContext.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPlan = preventionPlan.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBackup = backupAction.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty, !trimmedPlan.isEmpty else {
            lastSaveStatus = .failed("Risky situation and prevention plan are required.")
            return
        }

        riskySituations.append(
            RiskySituation(
                title: trimmedTitle,
                expectedContext: trimmedContext,
                preventionPlan: trimmedPlan,
                backupAction: trimmedBackup,
                createdAt: now(),
                updatedAt: now()
            )
        )
        persistRiskySituations(successMessage: "Risky situation saved.")
    }

    func updateRiskySituation(
        id: UUID,
        title: String,
        expectedContext: String,
        preventionPlan: String,
        backupAction: String,
        isEnabled: Bool
    ) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContext = expectedContext.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPlan = preventionPlan.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBackup = backupAction.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty, !trimmedPlan.isEmpty else {
            lastSaveStatus = .failed("Risky situation and prevention plan are required.")
            return
        }
        guard let index = riskySituations.firstIndex(where: { $0.id == id }) else {
            return
        }

        riskySituations[index].title = trimmedTitle
        riskySituations[index].expectedContext = trimmedContext
        riskySituations[index].preventionPlan = trimmedPlan
        riskySituations[index].backupAction = trimmedBackup
        riskySituations[index].isEnabled = isEnabled
        riskySituations[index].updatedAt = now()
        persistRiskySituations(successMessage: "Risky situation updated.")
    }

    func setRiskySituationEnabled(_ id: UUID, isEnabled: Bool) {
        guard let index = riskySituations.firstIndex(where: { $0.id == id }) else {
            return
        }

        riskySituations[index].isEnabled = isEnabled
        riskySituations[index].updatedAt = now()
        persistRiskySituations(successMessage: isEnabled ? "Risky situation enabled." : "Risky situation disabled.")
    }

    func deleteRiskySituation(_ id: UUID) {
        guard riskySituations.contains(where: { $0.id == id }) else {
            return
        }

        riskySituations.removeAll { $0.id == id }
        persistRiskySituations(successMessage: "Risky situation removed.")
    }

    func activitiesForCurrentCraving(triggers: Set<String>) -> [ReplacementActivity] {
        let enabled = replacementActivities.filter { activity in
            activity.isEnabled && activity.category != .support
        }
        guard !enabled.isEmpty else {
            return []
        }

        let normalizedTriggers = triggers.map { $0.lowercased() }
        let matched = enabled.filter { activity in
            let trigger = activity.linkedTrigger.lowercased()
            return !trigger.isEmpty && normalizedTriggers.contains { selected in
                trigger.contains(selected) || selected.contains(trigger)
            }
        }
        let prioritized = quitPlan.cravingRescuePlan.prioritizedActivityIDs.compactMap { id in
            enabled.first { $0.id == id }
        }

        let categoryFallbacks = ReplacementActivityCategory.userVisibleCases.compactMap { category in
            enabled.first { $0.category == category }
        }

        return Array((matched + prioritized + categoryFallbacks + enabled).uniquedByID().prefix(4))
    }

    func reasonsForCravingMode() -> [UserReason] {
        if let primaryID = quitPlan.cravingRescuePlan.primaryReasonID,
           let primary = userReasons.first(where: { $0.id == primaryID }) {
            let remaining = userReasons
                .filter { $0.id != primary.id }
                .sorted { lhs, rhs in
                    if lhs.sortOrder != rhs.sortOrder {
                        return lhs.sortOrder < rhs.sortOrder
                    }
                    return lhs.updatedAt > rhs.updatedAt
                }
            return [primary] + remaining
        }

        if let primary = userReasons.first(where: \.isPrimary) {
            let remaining = userReasons
                .filter { $0.id != primary.id }
                .sorted { lhs, rhs in
                    if lhs.sortOrder != rhs.sortOrder {
                        return lhs.sortOrder < rhs.sortOrder
                    }
                    return lhs.updatedAt > rhs.updatedAt
                }
            return [primary] + remaining
        }

        return userReasons.sorted {
            if $0.updatedAt != $1.updatedAt {
                return $0.updatedAt > $1.updatedAt
            }
            return $0.createdAt > $1.createdAt
        }
    }

    func refreshNotificationAuthorization() {
        notificationScheduler.currentAuthorizationStatus { [weak self] status in
            DispatchQueue.main.async {
                self?.notificationPermissionStatus = status
                if status.canScheduleNotifications {
                    self?.syncScheduledNotifications(showSuccess: false)
                }
            }
        }
    }

    func requestNotificationAuthorization() {
        notificationScheduler.requestAuthorization { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success(let status):
                    self.notificationPermissionStatus = status
                    if status.canScheduleNotifications {
                        self.lastSaveStatus = .saved("Notifications allowed. Choose the reminders you want.")
                        self.syncScheduledNotifications(showSuccess: false)
                    } else {
                        self.lastSaveStatus = .failed("Notifications were not allowed.")
                    }
                case .failure:
                    self.lastSaveStatus = .failed("Notification permission could not be requested.")
                }
            }
        }
    }

    func setNotificationEnabled(_ kind: NotificationKind, isEnabled: Bool) {
        if isEnabled && !notificationPermissionStatus.canScheduleNotifications {
            guard notificationPermissionStatus != .denied else {
                lastSaveStatus = .failed("Notifications are blocked in iOS Settings.")
                return
            }

            notificationScheduler.requestAuthorization { [weak self] result in
                DispatchQueue.main.async {
                    guard let self else { return }
                    switch result {
                    case .success(let status):
                        self.notificationPermissionStatus = status
                        guard status.canScheduleNotifications else {
                            self.lastSaveStatus = .failed("Notifications were not allowed.")
                            return
                        }
                        self.saveNotificationPreference(kind, isEnabled: true)
                    case .failure:
                        self.lastSaveStatus = .failed("Notification permission could not be requested.")
                    }
                }
            }
            return
        }

        saveNotificationPreference(kind, isEnabled: isEnabled)
    }

    func updateNotificationTime(_ kind: NotificationKind, time: ReminderTime) {
        guard kind.supportsFixedTime else { return }
        var next = notificationSettings
        next.setTime(time, for: kind)
        next.updatedAt = now()
        guard persistNotificationSettings(next, successMessage: "\(kind.title) time updated.") else {
            return
        }
        syncScheduledNotifications(showSuccess: false)
    }

    func reasonForCravingMode() -> String {
        if let reason = reasonsForCravingMode().first {
            return reason.text
        }
        return Self.motivationFallback
    }

    var canApplyPlanAdjustmentSuggestion: Bool {
        if highestPriorityPendingPlanSuggestion != nil {
            return true
        }

        let insights = calculatedInsights
        if let topTrigger = (insights.topSlipTriggers.first ?? insights.topTriggers.first) {
            return matchingTriggerRule(for: topTrigger.name) == nil
        }
        return false
    }

    @discardableResult
    func applyPlanAdjustmentSuggestion() -> Bool {
        if let suggestion = highestPriorityPendingPlanSuggestion {
            return acceptPlanSuggestion(suggestion.id)
        }

        let insights = calculatedInsights
        if let topTrigger = (insights.topSlipTriggers.first ?? insights.topTriggers.first) {
            guard matchingTriggerRule(for: topTrigger.name) == nil else {
                lastSaveStatus = .failed("That trigger already has a rule.")
                return false
            }

            let windowText = insights.riskWindows.first.map { " near \($0.startLabel)" } ?? ""
            triggerRules.append(
                TriggerRule(
                    trigger: topTrigger.name,
                    action: "Start a 10-minute substitute\(windowText) before deciding whether to smoke."
                )
            )
            quitPlan.triggerRules = triggerRules
            quitPlan.updatedAt = now()
            persistQuitPlan(successMessage: "Insight added a trigger rule.")
            return true
        }

        lastSaveStatus = .failed("Log more cravings before applying a suggestion.")
        return false
    }

    @discardableResult
    func acceptPlanSuggestion(_ id: UUID) -> Bool {
        guard let index = quitPlan.pendingPlanSuggestions.firstIndex(where: { $0.id == id }) else {
            lastSaveStatus = .failed("Suggestion not found.")
            return false
        }

        let suggestion = quitPlan.pendingPlanSuggestions[index]
        switch suggestion.type {
        case .addTriggerRule, .updateTriggerRule:
            applyTriggerSuggestion(suggestion)
        case .reorderTriggerRules:
            applyTriggerReorderSuggestion(suggestion)
        case .addReplacementActivity:
            applyReplacementActivitySuggestion(suggestion)
        case .reorderReplacementActivities:
            applyActivityReorderSuggestion(suggestion)
        case .adjustTaperPace:
            if let interval = suggestion.taperReductionIntervalDays {
                quitPlan.taperReductionIntervalDays = interval
                quitPlan.strategyPlan.taperIntervalDays = interval
            }
        case .addRiskyWindowReminder:
            setNotificationEnabled(.riskyWindow, isEnabled: true)
        case .changeDailyFocus:
            applyDailyFocusSuggestion(suggestion)
        case .updateSlipRecovery:
            applySlipRecoverySuggestion(suggestion)
        }

        quitPlan.pendingPlanSuggestions[index].status = .accepted
        quitPlan.pendingPlanSuggestions[index].updatedAt = now()
        quitPlan.updatedAt = now()
        persistQuitPlan(successMessage: "Plan suggestion accepted.")
        return true
    }

    func editPlanSuggestion(_ id: UUID) {
        updatePlanSuggestionStatus(id, status: .edited, successMessage: "Suggestion marked for editing.")
        selectedTab = .plan
    }

    func dismissPlanSuggestion(_ id: UUID) {
        updatePlanSuggestionStatus(id, status: .dismissed, successMessage: "Suggestion dismissed.")
    }

    func deleteCravingEvent(_ id: UUID) {
        do {
            try repository.deleteCravingEvent(id)
            cravingEvents = try repository.recentCravingEvents(limit: 10_000)
            lastSaveStatus = .saved("Craving record deleted.")
            syncScheduledNotifications(showSuccess: false)
        } catch {
            recordPersistenceError(error)
            lastSaveStatus = .failed("Craving record could not be deleted.")
        }
    }

    func deleteDailyCheckIn(_ id: UUID) {
        do {
            try repository.deleteDailyCheckIn(id)
            dailyCheckIns = try repository.recentCheckIns(limit: 10_000)
            lastSaveStatus = .saved("Check-in deleted.")
        } catch {
            recordPersistenceError(error)
            lastSaveStatus = .failed("Check-in could not be deleted.")
        }
    }

    func deleteSlipEvent(_ id: UUID) {
        do {
            try repository.deleteSlipEvent(id)
            slipEvents = try repository.recentSlipEvents(limit: 10_000)
            lastSaveStatus = .saved("Slip record deleted.")
        } catch {
            recordPersistenceError(error)
            lastSaveStatus = .failed("Slip record could not be deleted.")
        }
    }

    func updateDailyCheckInSlipNote(
        id: UUID,
        slipNote: String
    ) {
        guard let existing = dailyCheckIns.first(where: { $0.id == id }) else {
            return
        }

        let checkIn = DailyCheckIn(
            id: existing.id,
            date: existing.date,
            mood: existing.mood,
            stress: existing.stress,
            confidence: existing.confidence,
            smokedToday: existing.smokedToday,
            cigarettesSmoked: existing.cigarettesSmoked,
            taperTargetCigarettes: existing.taperTargetCigarettes,
            stayedWithinTaperTarget: existing.stayedWithinTaperTarget,
            slipNote: existing.smokedToday == true
                ? slipNote.trimmingCharacters(in: .whitespacesAndNewlines)
                : "",
            createdAt: existing.createdAt,
            updatedAt: now()
        )

        do {
            try repository.saveDailyCheckIn(checkIn)
            dailyCheckIns = try repository.recentCheckIns(limit: 10_000)
            persistenceError = nil
            lastSaveStatus = .saved("Check-in note updated.")
        } catch {
            recordPersistenceError(error)
            lastSaveStatus = .failed("Check-in note could not be updated.")
        }
    }

    func updateSlipEventNotes(
        id: UUID,
        note: String,
        recoveryAction: String
    ) {
        guard let existing = slipEvents.first(where: { $0.id == id }) else {
            return
        }

        let event = SlipEvent(
            id: existing.id,
            occurredAt: existing.occurredAt,
            cigarettesSmoked: existing.cigarettesSmoked,
            selectedTriggers: existing.selectedTriggers,
            mood: existing.mood,
            stress: existing.stress,
            context: existing.context,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            recoveryAction: recoveryAction.trimmingCharacters(in: .whitespacesAndNewlines),
            createdAt: existing.createdAt,
            updatedAt: now()
        )

        do {
            try repository.saveSlipEvent(event)
            slipEvents = try repository.recentSlipEvents(limit: 10_000)
            persistenceError = nil
            lastSaveStatus = .saved("Slip note updated.")
        } catch {
            recordPersistenceError(error)
            lastSaveStatus = .failed("Slip note could not be updated.")
        }
    }

    func clearStatus() {
        lastSaveStatus = .idle
        persistenceError = nil
    }

    func weeklyRecap(for date: Date? = nil) -> WeeklyRecap {
        let range = weekRange(containing: date ?? now())
        let checkInsByDay = Self.latestCheckInsByDay(
            dailyCheckIns.filter { range.contains($0.date) },
            calendar: calendar
        )
        let weeklyCravings = cravingEvents.filter {
            range.contains($0.completedAt ?? $0.dismissedAt ?? $0.startedAt) &&
                $0.outcome != .dismissedWithoutOutcome
        }
        let weeklySlips = slipEvents.filter { range.contains($0.occurredAt) }
        let topTriggers = Self.calculatedTriggerCounts(
            triggerLists: weeklyCravings.map(\.selectedTriggers) + weeklySlips.map(\.selectedTriggers),
            total: Double(max(weeklyCravings.count + weeklySlips.count, 1))
        )
        let riskWindows = Self.calculatedRiskWindows(from: weeklyCravings, calendar: calendar)

        return WeeklyRecap(
            weekStart: range.lowerBound,
            weekEnd: range.upperBound,
            cravingsLogged: weeklyCravings.count,
            cravingsHandled: weeklyCravings.filter { $0.outcome == .completedWithoutSmoking }.count,
            smokeFreeCheckInDays: checkInsByDay.values.filter { $0.smokedToday == false }.count,
            topTrigger: topTriggers.first?.name,
            planAdjustment: Self.calculatedPlanAdjustment(
                topTriggers: topTriggers,
                riskWindows: riskWindows,
                triggerRules: triggerRules
            )
        )
    }

    func historyEntries(range: ClosedRange<Date>? = nil) -> [HistoryEntry] {
        let cravingEntries = cravingEvents.map { event in
            HistoryEntry(
                id: event.id,
                kind: .craving,
                date: event.completedAt ?? event.dismissedAt ?? event.startedAt,
                title: cravingHistoryTitle(event),
                detail: cravingHistoryDetail(event)
            )
        }

        let checkInEntries = dailyCheckIns.map { checkIn in
            HistoryEntry(
                id: checkIn.id,
                kind: .checkIn,
                date: checkIn.date,
                title: checkIn.smokedToday == true ? "Check-in: smoked" : "Check-in: no smoke",
                detail: checkInHistoryDetail(checkIn)
            )
        }

        let slipEntries = slipEvents.map { event in
            HistoryEntry(
                id: event.id,
                kind: .slip,
                date: event.occurredAt,
                title: "Slip: \(event.cigarettesSmoked) cigarette\(event.cigarettesSmoked == 1 ? "" : "s")",
                detail: slipHistoryDetail(event)
            )
        }

        return (cravingEntries + checkInEntries + slipEntries)
            .filter { entry in
                guard let range else { return true }
                return range.contains(entry.date)
            }
            .sorted { $0.date > $1.date }
    }

    func historyEntry(for id: UUID, kind: HistoryEntry.Kind) -> HistoryEntry? {
        historyEntries().first { $0.id == id && $0.kind == kind }
    }

    private func hydrateFromPersistence() {
        isHydrating = true
        defer { isHydrating = false }

        do {
            let snapshot = try repository.loadSnapshot()
            applyPersistedSnapshot(snapshot)
            try persistDefaultsIfNeeded(snapshot: snapshot)
            persistenceError = nil
        } catch {
            recordPersistenceError(error)
            lastSaveStatus = .failed("Local data could not be loaded.")
            applyDefaultState()
        }
    }

    private func applyDefaultState() {
        let plan = Self.defaultQuitPlan()
        quitPlan = plan
        quitMode = plan.quitMode
        triggerRules = plan.triggerRules
        supportContacts = []
        userReasons = Self.defaultUserReasons()
        replacementActivities = Self.defaultReplacementActivities()
        riskySituations = []
        coachChats = Self.defaultCoachChats()
        selectedCoachChatID = coachChats.first?.id
        userProfile = nil
        quitReadiness = nil
        smokingBackground = nil
        savingsGoal = nil
        privacySettings = PrivacySettings()
        notificationSettings = NotificationSettings()
        isOnboardingCompleted = false
        isOnboardingPresented = true
        dailyCheckIns = []
        cravingEvents = []
        slipEvents = []
    }

    private func applyPersistedSnapshot(_ snapshot: PersistedTeoPateoSnapshot) {
        isOnboardingCompleted = snapshot.appSettings?.onboardingCompleted ?? false
        isOnboardingPresented = !isOnboardingCompleted
        notificationSettings = snapshot.notificationSettings ?? NotificationSettings()
        privacySettings = snapshot.privacySettings ?? PrivacySettings()
        userProfile = snapshot.userProfile
        quitReadiness = snapshot.quitReadiness
        smokingBackground = snapshot.smokingBackground
        savingsGoal = snapshot.savingsGoal

        let loadedPlan = snapshot.quitPlan ?? Self.defaultQuitPlan()
        quitPlan = loadedPlan
        quitMode = loadedPlan.quitMode
        triggerRules = loadedPlan.triggerRules

        supportContacts = snapshot.supportContacts
        let shouldSeedDefaultData = Self.shouldSeedDefaultData(appSettings: snapshot.appSettings)
        userReasons = snapshot.userReasons.isEmpty && shouldSeedDefaultData
            ? Self.defaultUserReasons()
            : snapshot.userReasons
        replacementActivities = snapshot.replacementActivities.isEmpty
            ? Self.defaultReplacementActivities()
            : snapshot.replacementActivities
        riskySituations = snapshot.riskySituations
        coachChats = snapshot.coachChats.isEmpty
            ? Self.defaultCoachChats()
            : snapshot.coachChats
        selectedCoachChatID = Self.validSelectedCoachChatID(
            snapshot.selectedCoachChatID,
            in: coachChats
        )
        dailyCheckIns = snapshot.dailyCheckIns
        cravingEvents = snapshot.cravingEvents
        slipEvents = snapshot.slipEvents
    }

    private func restorePersistedStateAfterSaveFailure() {
        let wasHydrating = isHydrating
        isHydrating = true
        defer { isHydrating = wasHydrating }

        do {
            applyPersistedSnapshot(try repository.loadSnapshot())
        } catch {
            // Keep the local failure status from the original save; a reload failure
            // should not hide the operation that first failed.
        }
    }

    private func persistDefaultsIfNeeded(snapshot: PersistedTeoPateoSnapshot) throws {
        let shouldSeedDefaultData = Self.shouldSeedDefaultData(appSettings: snapshot.appSettings)
        if shouldSeedDefaultData {
            try repository.saveAppSettings(AppSettings(onboardingCompleted: isOnboardingCompleted))
        }
        if snapshot.notificationSettings == nil {
            try repository.saveNotificationSettings(notificationSettings)
        }
        if snapshot.privacySettings == nil {
            try repository.savePrivacySettings(privacySettings)
        }
        if snapshot.quitPlan == nil {
            try repository.saveQuitPlan(quitPlan)
        }
        if snapshot.userReasons.isEmpty && shouldSeedDefaultData {
            try repository.replaceUserReasons(userReasons)
        }
        if snapshot.replacementActivities.isEmpty {
            try repository.replaceReplacementActivities(replacementActivities)
        }
        if !riskySituations.isEmpty && snapshot.riskySituations.isEmpty {
            try repository.replaceRiskySituations(riskySituations)
        }
        if snapshot.coachChats.isEmpty {
            try repository.replaceCoachChats(coachChats, selectedChatID: selectedCoachChatID)
        }
    }

    private func updateQuitMode() {
        guard !isHydrating else { return }
        quitPlan.quitMode = quitMode
        quitPlan.strategyPlan.strategyType = quitMode == "Cold turkey" ? .coldTurkey : .taper
        quitPlan.updatedAt = now()
        persistQuitPlan(successMessage: "Quit approach updated.")
    }

    private func persistQuitPlan(successMessage: String) {
        do {
            quitPlan.triggerRules = triggerRules
            try repository.saveQuitPlan(quitPlan)
            persistenceError = nil
            lastSaveStatus = .saved(successMessage)
            syncScheduledNotifications(showSuccess: false)
        } catch {
            restorePersistedStateAfterSaveFailure()
            recordPersistenceError(error)
            lastSaveStatus = .failed("Quit plan could not be saved.")
        }
    }

    private func persistUserReasons(successMessage: String) {
        do {
            try repository.replaceUserReasons(userReasons)
            persistenceError = nil
            lastSaveStatus = .saved(successMessage)
        } catch {
            restorePersistedStateAfterSaveFailure()
            recordPersistenceError(error)
            lastSaveStatus = .failed("Reasons could not be saved.")
        }
    }

    private func persistReplacementActivities(successMessage: String) {
        do {
            try repository.replaceReplacementActivities(replacementActivities)
            persistenceError = nil
            lastSaveStatus = .saved(successMessage)
        } catch {
            restorePersistedStateAfterSaveFailure()
            recordPersistenceError(error)
            lastSaveStatus = .failed("Replacement activities could not be saved.")
        }
    }

    private func persistRiskySituations(successMessage: String) {
        do {
            try repository.replaceRiskySituations(riskySituations)
            persistenceError = nil
            lastSaveStatus = .saved(successMessage)
        } catch {
            restorePersistedStateAfterSaveFailure()
            recordPersistenceError(error)
            lastSaveStatus = .failed("Risky situations could not be saved.")
        }
    }

    private func persistCoachChats() {
        do {
            try repository.replaceCoachChats(coachChats, selectedChatID: selectedCoachChatID)
            persistenceError = nil
        } catch {
            restorePersistedStateAfterSaveFailure()
            recordPersistenceError(error)
            lastSaveStatus = .failed("Coach chats could not be saved.")
        }
    }

    private func updateCoachDataConsent(
        _ status: CoachDataConsentStatus,
        successMessage: String
    ) -> Bool {
        let previous = privacySettings
        let timestamp = now()
        privacySettings = PrivacySettings(
            coachDataConsentStatus: status,
            coachDataConsentUpdatedAt: timestamp,
            policyVersion: PrivacySettings.currentPolicyVersion,
            updatedAt: timestamp
        )

        do {
            try repository.savePrivacySettings(privacySettings)
            persistenceError = nil
            lastSaveStatus = .saved(successMessage)
            if status.isGranted {
                coachResponseState = .ready
            }
            return true
        } catch {
            privacySettings = previous
            recordPersistenceError(error)
            lastSaveStatus = .failed("Privacy settings could not be saved.")
            return false
        }
    }

    @discardableResult
    private func ensureSelectedCoachChat() -> UUID {
        if let selectedCoachChatID,
           coachChats.contains(where: { $0.id == selectedCoachChatID }) {
            return selectedCoachChatID
        }

        let chat = makeEmptyCoachChat()
        coachChats.insert(chat, at: 0)
        selectedCoachChatID = chat.id
        return chat.id
    }

    private func makeEmptyCoachChat() -> CoachChat {
        let createdAt = now()
        return CoachChat(
            title: "New chat",
            messages: [],
            createdAt: createdAt,
            updatedAt: createdAt
        )
    }

    private func appendCoachMessage(
        _ message: CoachMessage,
        to chatID: UUID,
        updateTitleFromUserText userText: String? = nil
    ) {
        guard let index = coachChats.firstIndex(where: { $0.id == chatID }) else {
            return
        }

        var chat = coachChats[index]
        chat.messages.append(message)
        chat.updatedAt = message.createdAt
        if let userText, Self.shouldReplaceCoachChatTitle(chat.title) {
            chat.title = Self.coachChatTitle(from: userText)
        }
        coachChats[index] = chat
    }

    private func updateCoachMessage(_ messageID: UUID, in chatID: UUID, text: String) {
        guard let chatIndex = coachChats.firstIndex(where: { $0.id == chatID }),
              let messageIndex = coachChats[chatIndex].messages.firstIndex(where: { $0.id == messageID })
        else {
            return
        }

        var chat = coachChats[chatIndex]
        chat.messages[messageIndex].text = text
        chat.updatedAt = now()
        coachChats[chatIndex] = chat
    }

    private func deleteCoachMessage(_ messageID: UUID, from chatID: UUID) {
        guard let chatIndex = coachChats.firstIndex(where: { $0.id == chatID }) else {
            return
        }

        var chat = coachChats[chatIndex]
        chat.messages.removeAll { $0.id == messageID }
        chat.updatedAt = now()
        coachChats[chatIndex] = chat
    }

    private static func shouldReplaceCoachChatTitle(_ title: String) -> Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || trimmed == "New chat"
    }

    private static func coachChatTitle(from text: String) -> String {
        let collapsed = text
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
        guard collapsed.count > 36 else { return collapsed }

        let endIndex = collapsed.index(collapsed.startIndex, offsetBy: 36)
        return String(collapsed[..<endIndex])
            .trimmingCharacters(in: .whitespacesAndNewlines) + "..."
    }

    private func makeCoachRequest(for chatID: UUID) -> CoachRequest {
        let messages = coachChats.first { $0.id == chatID }?.messages ?? []
        return CoachRequest(
            contextSummary: coachContextSummary(),
            messages: messages.suffix(12).map { message in
                CoachChatMessage(
                    role: message.isUser ? .user : .assistant,
                    content: message.text
                )
            }
        )
    }

    private func coachContextSummary() -> String {
        let insights = calculatedInsights
        var lines = [
            "User: \(displayName)\(userProfile.map { ", age \($0.age)" } ?? "")",
            "Quit status: \(quitPlan.quitStatus.title)",
            "Readiness stage: \(quitPlan.readinessStage)",
            "Daily focus: \(dailyFocus)",
            "Quit mode: \(quitPlan.quitMode)",
            "Quit date: \(Self.coachDateLabel(quitPlan.quitDate))",
            "Primary reason: \(reasonForCravingMode())",
            "Today risk: \(insights.todayRisk.level.rawValue) - \(insights.todayRisk.summary)",
            "Progress: \(insights.smokeFreeSummary), \(insights.cravingsHandled) cravings handled, \(insights.moneySavedSummary) saved."
        ]

        if let quitReadiness {
            lines.append("Confidence: \(Self.coachScoreLabel(quitReadiness.confidence)).")
            if !quitReadiness.openedAppReason.isEmpty {
                lines.append("Opened app because: \(quitReadiness.openedAppReason)")
            }
        }

        if let smokingBackground {
            lines.append(
                "Smoking background: first cigarette \(smokingBackground.firstCigaretteTiming.title.lowercased()), previous attempts \(smokingBackground.previousQuitAttemptCount.title), longest quit \(smokingBackground.longestQuitAttempt.title.lowercased()), main challenge \(smokingBackground.mainChallenge.title.lowercased())."
            )
        }

        if let savingsGoalSummary {
            lines.append(savingsGoalSummary)
        }

        let planSummary = firstPlanSummary
        if !planSummary.isEmpty {
            lines.append("Generated plan summary: \(planSummary)")
        }

        let strategy = quitPlan.strategyPlan
        lines.append("Strategy: \(strategy.strategyType.title). \(strategy.rationale)")

        let nextBestAction = quitPlan.nextBestAction.trimmingCharacters(in: .whitespacesAndNewlines)
        if !nextBestAction.isEmpty {
            lines.append("Next best action: \(nextBestAction)")
        }

        if !quitPlan.generatedTriggerRules.isEmpty {
            lines.append(
                "Generated trigger rules: " + quitPlan.generatedTriggerRules
                    .sorted { $0.priority < $1.priority }
                    .prefix(3)
                    .map { "\($0.trigger) -> \($0.replacementAction), backup: \($0.backupAction)" }
                    .joined(separator: "; ")
            )
        }

        lines.append("Craving rescue script: \(quitPlan.cravingRescuePlan.primaryScript)")
        lines.append("Craving rescue backup: \(quitPlan.cravingRescuePlan.backupAction)")
        lines.append("Slip recovery preference: \(quitPlan.slipRecoveryPlan.defaultRecoveryAction)")

        if let suggestion = highestPriorityPendingPlanSuggestion {
            lines.append(
                "Pending plan suggestion: \(suggestion.title). Evidence: \(suggestion.evidenceSummary). Suggested action: \(suggestion.suggestedAction)"
            )
        }

        if let taperTarget = todayTaperTarget {
            lines.append("Today's taper target: \(Self.coachCigaretteLabel(taperTarget)).")
        }

        if let checkIn = todayCheckIn {
            lines.append(
                "Today check-in: mood \(Self.coachScoreLabel(checkIn.mood)), stress \(Self.coachScoreLabel(checkIn.stress)), confidence \(Self.coachScoreLabel(checkIn.confidence)), smoked today: \(Self.coachSmokeStatus(checkIn))."
            )
        }

        let enabledRules = triggerRules.filter(\.isEnabled).prefix(5)
        if !enabledRules.isEmpty {
            lines.append(
                "Trigger rules: " + enabledRules
                    .map { "\($0.trigger) -> \($0.action)" }
                    .joined(separator: "; ")
            )
        }

        if !insights.topTriggers.isEmpty {
            lines.append(
                "Top craving triggers: " + insights.topTriggers
                    .prefix(3)
                    .map { "\($0.name) (\($0.shareSummary))" }
                    .joined(separator: ", ")
            )
        }

        if let riskWindow = insights.riskWindows.first {
            lines.append("Highest-risk window: \(riskWindow.title) with \(riskWindow.cravingCount) logged cravings.")
        }

        let enabledActivities = replacementActivities.filter(\.isEnabled).prefix(4)
        if !enabledActivities.isEmpty {
            lines.append(
                "Replacement activities: " + enabledActivities
                    .map { "\($0.title): \($0.instruction)" }
                    .joined(separator: "; ")
            )
        }

        if let cravingSummary = coachRecentCravingSummary() {
            lines.append(cravingSummary)
        }

        if let slipSummary = coachRecentSlipSummary() {
            lines.append(slipSummary)
        }

        return lines.joined(separator: "\n")
    }

    private func coachRecentCravingSummary() -> String? {
        let recent = cravingEvents.prefix(3)
        guard !recent.isEmpty else { return nil }

        return "Recent cravings: " + recent.map { event in
            let triggers = event.selectedTriggers.isEmpty
                ? "no trigger logged"
                : event.selectedTriggers.joined(separator: ", ")
            return "\(Self.coachDateLabel(event.startedAt)) - \(triggers), \(event.outcome.rawValue)"
        }
        .joined(separator: "; ")
    }

    private func coachRecentSlipSummary() -> String? {
        let recent = slipEvents.prefix(2)
        guard !recent.isEmpty else { return nil }

        return "Recent slips: " + recent.map { event in
            let triggers = event.selectedTriggers.isEmpty
                ? "no trigger logged"
                : event.selectedTriggers.joined(separator: ", ")
            let recovery = event.recoveryAction.trimmingCharacters(in: .whitespacesAndNewlines)
            return "\(Self.coachDateLabel(event.occurredAt)) - \(triggers), recovery: \(recovery.isEmpty ? "not recorded" : recovery)"
        }
        .joined(separator: "; ")
    }

    private static func coachErrorMessage(for error: Error) -> String {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost, .timedOut:
                return "You appear to be offline. Your message was saved; try again when you're connected."
            default:
                return "The coach is unavailable right now. Your message was saved."
            }
        }

        if
            let coachError = error as? CoachClientError,
            let description = coachError.errorDescription
        {
            return description
        }

        return "The coach is unavailable right now. Your message was saved."
    }

    private static var partialCoachReplySavedMessage: String {
        "The coach response was interrupted. Partial reply saved."
    }

    private static var coachConsentRequiredMessage: String {
        "Allow coach data sharing before sending a message."
    }

    private static var coachReplyReportedMessage: String {
        "Coach reply marked for review. Use 988, 911, or a trusted person now if safety feels urgent."
    }

    private static var coachReplyAlreadyReportedMessage: String {
        "Coach reply is already marked for review."
    }

    private static func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError {
            return true
        }

        if let urlError = error as? URLError, urlError.code == .cancelled {
            return true
        }

        return false
    }

    /// Report coach failures that indicate a bug or a server/contract problem,
    /// while ignoring expected operational cases (offline, rate limiting, or a
    /// coach proxy that simply isn't configured yet). No message content is sent.
    private static func recordUnexpectedCoachError(_ error: Error) {
        guard shouldReportCoachError(error) else { return }
        Observability.record(error, category: "coach")
    }

    private static func shouldReportCoachError(_ error: Error) -> Bool {
        if isCancellation(error) {
            return false
        }

        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .cannotFindHost,
                 .cannotConnectToHost, .timedOut, .dataNotAllowed, .internationalRoamingOff:
                return false
            default:
                return true
            }
        }

        if let coachError = error as? CoachClientError {
            switch coachError {
            case .missingProxyConfiguration, .requestFailed(statusCode: 429):
                return false
            #if DEBUG
            case .missingAPIKey:
                return false
            #endif
            default:
                return true
            }
        }

        return true
    }

    private static func coachDateLabel(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }

    private static func coachScoreLabel(_ value: Double) -> String {
        "\(Int(value.rounded()))/10"
    }

    private static func coachCigaretteLabel(_ value: Double) -> String {
        let rounded = value.rounded()
        let label = abs(value - rounded) < 0.01
            ? "\(Int(rounded))"
            : String(format: "%.1f", value)
        return "\(label) cigarette\(abs(value - 1) < 0.01 ? "" : "s")"
    }

    private static func coachSmokeStatus(_ checkIn: DailyCheckIn) -> String {
        switch checkIn.smokedToday {
        case .some(true):
            return "yes, \(checkIn.cigarettesSmoked) cigarette\(checkIn.cigarettesSmoked == 1 ? "" : "s")"
        case .some(false):
            return "no"
        case .none:
            return "not answered"
        }
    }

    private func saveNotificationPreference(
        _ kind: NotificationKind,
        isEnabled: Bool
    ) {
        var next = notificationSettings
        next.setEnabled(isEnabled, for: kind)
        next.updatedAt = now()

        let message = isEnabled
            ? "\(kind.title) reminder enabled."
            : "\(kind.title) reminder disabled."
        guard persistNotificationSettings(next, successMessage: message) else {
            return
        }
        syncScheduledNotifications(showSuccess: false)
    }

    @discardableResult
    private func persistNotificationSettings(
        _ settings: NotificationSettings,
        successMessage: String
    ) -> Bool {
        let previous = notificationSettings
        notificationSettings = settings

        do {
            try repository.saveNotificationSettings(settings)
            persistenceError = nil
            lastSaveStatus = .saved(successMessage)
            return true
        } catch {
            notificationSettings = previous
            recordPersistenceError(error)
            lastSaveStatus = .failed("Notification settings could not be saved.")
            return false
        }
    }

    private func syncScheduledNotifications(showSuccess: Bool) {
        if !notificationSettings.hasEnabledReminders {
            guard notificationPermissionStatus.canScheduleNotifications else {
                return
            }
            notificationScheduler.cancelScheduledNotifications { [weak self] result in
                DispatchQueue.main.async {
                    guard let self else { return }
                    if case .failure = result {
                        self.lastSaveStatus = .failed("Scheduled notifications could not be updated.")
                    } else if showSuccess {
                        self.lastSaveStatus = .saved("Notifications updated.")
                    }
                }
            }
            return
        }

        guard notificationPermissionStatus.canScheduleNotifications else {
            return
        }

        notificationScheduler.replaceScheduledNotifications(
            with: plannedNotificationItems
        ) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success:
                    if showSuccess {
                        self.lastSaveStatus = .saved("Notifications updated.")
                    }
                case .failure:
                    self.lastSaveStatus = .failed("Scheduled notifications could not be updated.")
                }
            }
        }
    }

    private func makeCravingEvent(
        startedAt: Date,
        completedAt: Date?,
        durationSeconds: Int,
        outcome: CravingOutcome,
        initialIntensity: Double?,
        finalIntensity: Double?,
        helpedActivityID: UUID?,
        supportContactID: UUID?,
        reflectionNote: String,
        dismissedAt: Date?,
        selectedTriggers: Set<String>? = nil
    ) -> CravingEvent {
        let now = now()
        let triggerSelection = selectedTriggers ?? self.selectedTriggers
        return CravingEvent(
            startedAt: startedAt,
            completedAt: completedAt,
            durationSeconds: max(durationSeconds, 0),
            selectedTriggers: triggerSelection.sorted(),
            outcome: outcome,
            initialIntensity: initialIntensity,
            finalIntensity: finalIntensity,
            helpedActivityID: helpedActivityID,
            supportContactID: supportContactID,
            reflectionNote: reflectionNote,
            dismissedAt: dismissedAt,
            createdAt: now,
            updatedAt: now
        )
    }

    private func persistCravingEvent(_ event: CravingEvent, successMessage: String) -> Bool {
        do {
            try repository.saveCravingEvent(event)
            cravingEvents = try repository.recentCravingEvents(limit: 10_000)
            refreshPlanAdjustmentSuggestions()
            persistenceError = nil
            lastSaveStatus = .saved(successMessage)
            syncScheduledNotifications(showSuccess: false)
            return true
        } catch {
            restorePersistedStateAfterSaveFailure()
            recordPersistenceError(error)
            lastSaveStatus = .failed("Craving could not be saved.")
            return false
        }
    }

    private func normalizedUserReasons(_ reasons: [UserReason]) -> [UserReason] {
        reasons.enumerated().map { index, reason in
            var updated = reason
            updated.sortOrder = index
            updated.updatedAt = now()
            return updated
        }
    }

    private func updateSavingsPlanForCurrentBaseline() {
        let weeklyAvoided = max(quitPlan.baselineCigarettesPerDay, 0) * 7
        let weeklySavings = weeklyAvoided * quitPlan.costPerCigarette
        let title = savingsGoal?.displayTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let goal = title?.isEmpty == false ? title ?? quitPlan.savingsPlan.savingsGoal : quitPlan.savingsPlan.savingsGoal
        let goalText = goal.isEmpty ? "your savings goal" : goal.lowercased()

        quitPlan.savingsPlan.costPerPack = quitPlan.costPerPack
        quitPlan.savingsPlan.cigarettesPerPack = quitPlan.cigarettesPerPack
        quitPlan.savingsPlan.savingsGoal = goal
        quitPlan.savingsPlan.weeklySavingsBaseline = weeklySavings
        quitPlan.savingsPlan.cigarettesAvoidedBaseline = weeklyAvoided
        quitPlan.savingsPlan.firstMilestoneAmount = weeklySavings > 0 ? max(5, (weeklySavings / 2).rounded()) : 0
        quitPlan.savingsPlan.savingsGoalMessage = "At your current baseline, every smoke-free week puts about \(Self.moneySummary(weeklySavings)) toward \(goalText)."
        quitPlan.savingsPlan.dashboardMessage = "A smoke-free day is worth about \(Self.moneySummary(weeklySavings / 7)) toward \(goalText)."
    }

    private func refreshPlanAdjustmentSuggestions() {
        let nextSuggestions = PlanAdjustmentEngine.updatedSuggestions(
            existing: quitPlan.pendingPlanSuggestions,
            quitPlan: quitPlan,
            cravingEvents: cravingEvents,
            slipEvents: slipEvents,
            dailyCheckIns: dailyCheckIns,
            replacementActivities: replacementActivities,
            notificationSettings: notificationSettings,
            now: now(),
            calendar: calendar
        )

        guard nextSuggestions != quitPlan.pendingPlanSuggestions else {
            return
        }

        quitPlan.pendingPlanSuggestions = nextSuggestions
        quitPlan.updatedAt = now()

        do {
            quitPlan.triggerRules = triggerRules
            try repository.saveQuitPlan(quitPlan)
            persistenceError = nil
        } catch {
            restorePersistedStateAfterSaveFailure()
            recordPersistenceError(error)
            lastSaveStatus = .failed("Plan suggestions could not be saved.")
        }
    }

    private func applyTriggerSuggestion(_ suggestion: PlanAdjustmentSuggestion) {
        let trigger = suggestion.trigger?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trigger.isEmpty else { return }
        let action = suggestion.replacementAction?.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackAction = "Start a 10-minute substitute before deciding whether to smoke."
        if let index = triggerRules.firstIndex(where: { rule in
            rule.trigger.localizedCaseInsensitiveContains(trigger) ||
                trigger.localizedCaseInsensitiveContains(rule.trigger)
        }) {
            triggerRules[index].action = action?.isEmpty == false ? action ?? fallbackAction : fallbackAction
            triggerRules[index].isEnabled = true
        } else {
            triggerRules.append(TriggerRule(
                trigger: trigger,
                action: action?.isEmpty == false ? action ?? fallbackAction : fallbackAction
            ))
        }

        if !quitPlan.generatedTriggerRules.contains(where: { $0.trigger.caseInsensitiveCompare(trigger) == .orderedSame }) {
            quitPlan.generatedTriggerRules.append(GeneratedTriggerRule(
                trigger: trigger,
                warningSign: "This trigger has repeated in recent logs.",
                replacementAction: action?.isEmpty == false ? action ?? fallbackAction : fallbackAction,
                backupAction: suggestion.backupAction ?? "Change location and keep the rescue timer running.",
                cravingModePrompt: "Delay \(trigger.lowercased()) by 10 minutes before deciding.",
                reminderHint: nil,
                priority: quitPlan.generatedTriggerRules.count + 1
            ))
        }
        quitPlan.triggerRules = triggerRules
    }

    private func applyTriggerReorderSuggestion(_ suggestion: PlanAdjustmentSuggestion) {
        guard let trigger = suggestion.trigger,
              let index = triggerRules.firstIndex(where: {
                  $0.trigger.localizedCaseInsensitiveContains(trigger) ||
                      trigger.localizedCaseInsensitiveContains($0.trigger)
              }),
              index > 0
        else {
            return
        }
        triggerRules.move(from: index, to: 0)
        quitPlan.triggerRules = triggerRules
    }

    private func applyReplacementActivitySuggestion(_ suggestion: PlanAdjustmentSuggestion) {
        let title = suggestion.activityTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let instruction = suggestion.activityInstruction?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !title.isEmpty, !instruction.isEmpty else { return }
        replacementActivities.insert(
            ReplacementActivity(
                title: title,
                instruction: instruction,
                category: .distraction,
                linkedTrigger: suggestion.trigger ?? "",
                createdAt: now(),
                updatedAt: now()
            ),
            at: 0
        )
        persistReplacementActivities(successMessage: "Replacement activity added.")
    }

    private func applyActivityReorderSuggestion(_ suggestion: PlanAdjustmentSuggestion) {
        guard let activityID = suggestion.activityID,
              let index = replacementActivities.firstIndex(where: { $0.id == activityID }),
              index > 0
        else {
            return
        }
        replacementActivities.move(from: index, to: 0)
        quitPlan.cravingRescuePlan.prioritizedActivityIDs.removeAll { $0 == activityID }
        quitPlan.cravingRescuePlan.prioritizedActivityIDs.insert(activityID, at: 0)
        persistReplacementActivities(successMessage: "Replacement activities reordered.")
    }

    private func applyDailyFocusSuggestion(_ suggestion: PlanAdjustmentSuggestion) {
        let title = suggestion.dailyFocusTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let action = suggestion.dailyFocusAction?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !title.isEmpty, !action.isEmpty else { return }
        let currentIndex = todaysFocusPlan?.dayIndex ?? 1
        if let index = quitPlan.dailyFocusPlan.firstIndex(where: { $0.dayIndex == currentIndex }) {
            quitPlan.dailyFocusPlan[index].title = title
            quitPlan.dailyFocusPlan[index].action = action
            quitPlan.dailyFocusPlan[index].relatedTrigger = suggestion.trigger
            quitPlan.dailyFocusPlan[index].isUserEdited = true
        } else {
            quitPlan.dailyFocusPlan.insert(
                DailyFocusPlan(
                    dayIndex: currentIndex,
                    title: title,
                    action: action,
                    relatedTrigger: suggestion.trigger,
                    isUserEdited: true
                ),
                at: 0
            )
        }
        quitPlan.generatedDailyFocus = action
    }

    private func applySlipRecoverySuggestion(_ suggestion: PlanAdjustmentSuggestion) {
        let backup = suggestion.backupAction?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !backup.isEmpty {
            quitPlan.slipRecoveryPlan.defaultRecoveryAction = backup
        }
        if let trigger = suggestion.trigger, !trigger.isEmpty {
            quitPlan.slipRecoveryPlan.message = "If \(trigger.lowercased()) leads to smoking, keep the attempt alive and protect the next choice."
        }
    }

    private func updatePlanSuggestionStatus(
        _ id: UUID,
        status: PlanSuggestionStatus,
        successMessage: String
    ) {
        guard let index = quitPlan.pendingPlanSuggestions.firstIndex(where: { $0.id == id }) else {
            lastSaveStatus = .failed("Suggestion not found.")
            return
        }
        quitPlan.pendingPlanSuggestions[index].status = status
        quitPlan.pendingPlanSuggestions[index].updatedAt = now()
        quitPlan.updatedAt = now()
        persistQuitPlan(successMessage: successMessage)
    }

    private func matchingTriggerRule(for trigger: String) -> TriggerRule? {
        let triggerText = trigger.lowercased()
        return triggerRules.first { rule in
            guard rule.isEnabled else { return false }
            let ruleText = rule.trigger.lowercased()
            return ruleText.contains(triggerText) || triggerText.contains(ruleText)
        }
    }

    private func latestCheckIn(on date: Date) -> DailyCheckIn? {
        let day = calendar.startOfDay(for: date)
        return dailyCheckIns
            .filter { calendar.startOfDay(for: $0.date) == day }
            .sorted {
                if $0.updatedAt != $1.updatedAt {
                    return $0.updatedAt > $1.updatedAt
                }
                return $0.createdAt > $1.createdAt
            }
            .first
    }

    private func weekStart(containing date: Date) -> Date {
        if let interval = calendar.dateInterval(of: .weekOfYear, for: date) {
            return calendar.startOfDay(for: interval.start)
        }

        return calendar.startOfDay(for: date)
    }

    private static func effectiveCigarettesSmoked(
        checkIn: DailyCheckIn?,
        slipCigarettes: Int
    ) -> Int? {
        let checkInCigarettes: Int?
        switch checkIn?.smokedToday {
        case .some(true):
            checkInCigarettes = max(checkIn?.cigarettesSmoked ?? 0, 1)
        case .some(false):
            checkInCigarettes = 0
        case nil:
            checkInCigarettes = nil
        }

        let slipTotal = max(slipCigarettes, 0)
        guard checkInCigarettes != nil || slipTotal > 0 else {
            return nil
        }

        return max(checkInCigarettes ?? 0, 0) + slipTotal
    }

    private static func dailyPlanAdherenceStatus(
        cigarettesSmoked: Int?,
        targetCigarettes: Double
    ) -> DailyPlanAdherenceStatus? {
        guard let cigarettesSmoked else {
            return nil
        }

        let smoked = Double(cigarettesSmoked)
        if smoked <= targetCigarettes {
            return .achieved
        }

        let overTarget = smoked - targetCigarettes
        let slightMissAllowance = max(1, ceil(targetCigarettes * 0.25))
        return overTarget <= slightMissAllowance ? .slightMiss : .missed
    }

    private func cravingHistoryTitle(_ event: CravingEvent) -> String {
        switch event.outcome {
        case .completedWithoutSmoking:
            return "Craving handled"
        case .smokedAfterCraving:
            return "Craving ended in smoking"
        case .dismissedWithoutOutcome:
            return "Craving saved for later"
        }
    }

    private func cravingHistoryDetail(_ event: CravingEvent) -> String {
        var details = [durationSummary(event.durationSeconds)]
        if !event.selectedTriggers.isEmpty {
            details.append(event.selectedTriggers.joined(separator: ", "))
        } else {
            details.append("No trigger selected")
        }
        if let activityID = event.helpedActivityID,
           let activity = replacementActivities.first(where: { $0.id == activityID }) {
            details.append(activity.title)
        }
        return details.joined(separator: " | ")
    }

    private func checkInHistoryDetail(_ checkIn: DailyCheckIn) -> String {
        var details = [
            "Mood \(Int(checkIn.mood))",
            "Stress \(Int(checkIn.stress))",
            "Confidence \(Int(checkIn.confidence))"
        ]
        if let target = checkIn.taperTargetCigarettes {
            details.append("Target \(Int(target))")
        }
        return details.joined(separator: " | ")
    }

    private func slipHistoryDetail(_ event: SlipEvent) -> String {
        var details = [
            "\(event.cigarettesSmoked) cigarette\(event.cigarettesSmoked == 1 ? "" : "s")"
        ]
        if !event.selectedTriggers.isEmpty {
            details.append(event.selectedTriggers.joined(separator: ", "))
        }
        if !event.recoveryAction.isEmpty {
            details.append(event.recoveryAction)
        }
        return details.joined(separator: " | ")
    }

    private func durationSummary(_ seconds: Int) -> String {
        let minutes = max(seconds, 0) / 60
        if minutes <= 0 {
            return "Under 1 minute"
        }
        return minutes == 1 ? "1 minute" : "\(minutes) minutes"
    }

    private func weekRange(containing date: Date) -> ClosedRange<Date> {
        let start = weekStart(containing: date)
        let end = calendar.date(byAdding: .day, value: 7, to: start) ?? start
        return start...end.addingTimeInterval(-1)
    }

    private func earnedMilestones(
        smokeFreeDays: Int,
        cravingsHandled: Int,
        slipCount: Int,
        moneySaved: Double
    ) -> [String] {
        var milestones: [String] = []
        if cravingsHandled > 0 {
            milestones.append("First craving handled")
        }
        if smokeFreeDays > 0 {
            milestones.append("First smoke-free day")
        }
        if slipCount > 0 {
            milestones.append("Recovered after a slip")
        }
        if smokeFreeDays >= 7 {
            milestones.append("First smoke-free week")
        }
        if moneySaved >= 10 {
            milestones.append("Saved \(Self.moneySummary(moneySaved))")
        }
        return milestones
    }

    private static func calculateInsights(
        quitPlan: QuitPlan,
        dailyCheckIns: [DailyCheckIn],
        cravingEvents: [CravingEvent],
        slipEvents: [SlipEvent],
        triggerRules: [TriggerRule],
        now: Date,
        calendar: Calendar
    ) -> CalculatedInsights {
        let checkInsByDay = latestCheckInsByDay(dailyCheckIns, calendar: calendar)
        let smokeFreeDays = smokeFreeStreakDays(
            from: checkInsByDay,
            now: now,
            calendar: calendar
        )
        let handledCravings = cravingEvents.filter { $0.outcome == .completedWithoutSmoking }
        let slippedCravings = cravingEvents.filter { $0.outcome == .smokedAfterCraving }
        let smokeFreeCheckInDays = checkInsByDay.values.filter { $0.smokedToday == false }.count
        let slipCigarettes = slipEvents.reduce(0) { $0 + $1.cigarettesSmoked }
        let checkInCigarettes = checkInsByDay.values.reduce(0) { $0 + $1.cigarettesSmoked }
        let avoidedFromDays = Int((Double(smokeFreeCheckInDays) * quitPlan.baselineCigarettesPerDay).rounded())
        let cigarettesAvoided = max(0, avoidedFromDays + handledCravings.count - slipCigarettes - checkInCigarettes)
        let moneySaved = Double(cigarettesAvoided) * quitPlan.costPerCigarette
        let riskWindows = calculatedRiskWindows(
            from: cravingEvents.filter { $0.outcome != .dismissedWithoutOutcome },
            calendar: calendar
        )
        let topTriggers = calculatedTopTriggers(from: cravingEvents)
        let topSlipTriggers = calculatedTopSlipTriggers(from: slipEvents)
        let todayRisk = calculatedTodayRisk(
            latestCheckIn: checkInsByDay[calendar.startOfDay(for: now)],
            riskWindows: riskWindows,
            cravingEvents: cravingEvents,
            slipEvents: slipEvents,
            now: now,
            calendar: calendar
        )

        return CalculatedInsights(
            smokeFreeDays: smokeFreeDays,
            smokeFreeSummary: daySummary(smokeFreeDays),
            cravingsLogged: cravingEvents.filter { $0.outcome != .dismissedWithoutOutcome }.count,
            cravingsHandled: handledCravings.count,
            slippedCravings: slippedCravings.count,
            cigarettesAvoided: cigarettesAvoided,
            moneySaved: moneySaved,
            moneySavedSummary: moneySummary(moneySaved),
            riskWindows: riskWindows,
            topTriggers: topTriggers,
            topSlipTriggers: topSlipTriggers,
            heatMapDays: calculatedHeatMapDays(
                from: cravingEvents,
                now: now,
                calendar: calendar
            ),
            planAdjustment: calculatedPlanAdjustment(
                topTriggers: topSlipTriggers.isEmpty ? topTriggers : topSlipTriggers,
                riskWindows: riskWindows,
                triggerRules: triggerRules
            ),
            todayRisk: todayRisk,
            dataConfidenceSummary: dataConfidenceSummary(
                cravingCount: cravingEvents.count,
                slipCount: slipEvents.count
            )
        )
    }

    private static func latestCheckInsByDay(
        _ checkIns: [DailyCheckIn],
        calendar: Calendar
    ) -> [Date: DailyCheckIn] {
        checkIns.reduce(into: [:]) { result, checkIn in
            let day = calendar.startOfDay(for: checkIn.date)
            guard let existing = result[day] else {
                result[day] = checkIn
                return
            }

            if checkIn.updatedAt > existing.updatedAt ||
                (checkIn.updatedAt == existing.updatedAt && checkIn.createdAt > existing.createdAt) {
                result[day] = checkIn
            }
        }
    }

    private static func smokeFreeStreakDays(
        from checkInsByDay: [Date: DailyCheckIn],
        now: Date,
        calendar: Calendar
    ) -> Int {
        let today = calendar.startOfDay(for: now)
        let recordedDays = checkInsByDay.keys.filter { $0 <= today }

        guard var cursor = recordedDays.max() else {
            return 0
        }

        var streak = 0
        while let checkIn = checkInsByDay[cursor], checkIn.smokedToday == false {
            streak += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: cursor) else {
                break
            }
            cursor = previousDay
        }

        return streak
    }

    private static func calculatedRiskWindows(
        from cravingEvents: [CravingEvent],
        calendar: Calendar
    ) -> [RiskWindowInsight] {
        guard !cravingEvents.isEmpty else {
            return []
        }

        let counts = cravingEvents.reduce(into: [Int: Int]()) { result, event in
            let hour = calendar.component(.hour, from: event.startedAt)
            result[hour, default: 0] += 1
        }
        let total = Double(cravingEvents.count)

        return counts
            .map { hour, count in
                RiskWindowInsight(
                    startHour: hour,
                    cravingCount: count,
                    share: Double(count) / total
                )
            }
            .sorted {
                if $0.cravingCount != $1.cravingCount {
                    return $0.cravingCount > $1.cravingCount
                }
                return $0.startHour < $1.startHour
            }
            .prefix(3)
            .map { $0 }
    }

    private static func calculatedTopTriggers(from cravingEvents: [CravingEvent]) -> [TriggerInsight] {
        let relevant = cravingEvents.filter { $0.outcome != .dismissedWithoutOutcome }
        guard !relevant.isEmpty else {
            return []
        }

        return calculatedTriggerCounts(
            triggerLists: relevant.map(\.selectedTriggers),
            total: Double(relevant.count)
        )
    }

    private static func calculatedTopSlipTriggers(from slipEvents: [SlipEvent]) -> [TriggerInsight] {
        guard !slipEvents.isEmpty else {
            return []
        }

        return calculatedTriggerCounts(
            triggerLists: slipEvents.map(\.selectedTriggers),
            total: Double(slipEvents.count)
        )
    }

    private static func calculatedTriggerCounts(
        triggerLists: [[String]],
        total: Double
    ) -> [TriggerInsight] {
        var counts: [String: Int] = [:]
        for triggers in triggerLists {
            let uniqueTriggers = Set(
                triggers.map {
                    $0.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                    .filter { !$0.isEmpty }
            )
            for trigger in uniqueTriggers {
                counts[trigger, default: 0] += 1
            }
        }

        return counts
            .map { trigger, count in
                TriggerInsight(
                    name: trigger,
                    count: count,
                    share: Double(count) / total
                )
            }
            .sorted {
                if $0.count != $1.count {
                    return $0.count > $1.count
                }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
            .prefix(4)
            .map { $0 }
    }

    private static func calculatedHeatMapDays(
        from cravingEvents: [CravingEvent],
        now: Date,
        calendar: Calendar
    ) -> [CravingHeatDay] {
        let today = calendar.startOfDay(for: now)
        guard let firstDay = calendar.date(byAdding: .day, value: -27, to: today) else {
            return []
        }

        let countsByDay = cravingEvents
            .filter { $0.outcome != .dismissedWithoutOutcome }
            .reduce(into: [Date: Int]()) { result, event in
                let day = calendar.startOfDay(for: event.startedAt)
                guard day >= firstDay && day <= today else {
                    return
                }
                result[day, default: 0] += 1
            }

        return (0..<28).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: firstDay) else {
                return nil
            }
            let count = countsByDay[date, default: 0]
            return CravingHeatDay(date: date, count: count, level: min(count, 4))
        }
    }

    private static func calculatedTodayRisk(
        latestCheckIn: DailyCheckIn?,
        riskWindows: [RiskWindowInsight],
        cravingEvents: [CravingEvent],
        slipEvents: [SlipEvent],
        now: Date,
        calendar: Calendar
    ) -> RiskLevelInsight {
        var score = 0
        let currentHour = calendar.component(.hour, from: now)
        if riskWindows.contains(where: { abs($0.startHour - currentHour) <= 1 }) {
            score += 2
        }
        if let latestCheckIn {
            if latestCheckIn.stress >= 8 {
                score += 1
            }
            if latestCheckIn.confidence <= 4 {
                score += 1
            }
        }

        let today = calendar.startOfDay(for: now)
        let cravingsToday = cravingEvents.filter { calendar.startOfDay(for: $0.startedAt) == today }.count
        let slipsToday = slipEvents.filter { calendar.startOfDay(for: $0.occurredAt) == today }.count
        if cravingsToday >= 2 {
            score += 1
        }
        if slipsToday > 0 {
            score += 2
        }

        if score >= 4 {
            return RiskLevelInsight(
                level: .high,
                summary: "High risk today. Keep the 10-minute rescue and one substitute ready.",
                actionTitle: "Start rescue"
            )
        }
        if score >= 2 {
            return RiskLevelInsight(
                level: .moderate,
                summary: "Moderate risk. Pick one substitute before the next urge arrives.",
                actionTitle: "Choose substitute"
            )
        }
        return RiskLevelInsight(
            level: .low,
            summary: "Low risk from recent logs. Keep the plan close.",
            actionTitle: "Review plan"
        )
    }

    private static func calculatedPlanAdjustment(
        topTriggers: [TriggerInsight],
        riskWindows: [RiskWindowInsight],
        triggerRules: [TriggerRule]
    ) -> PlanAdjustmentInsight {
        if let topTrigger = topTriggers.first {
            if let existingRule = matchingRule(for: topTrigger.name, in: triggerRules) {
                return PlanAdjustmentInsight(
                    title: "Rehearse the \(topTrigger.name.lowercased()) rule",
                    detail: "\(topTrigger.name) appears in \(topTrigger.shareSummary) of logged events. Keep this rule ready: \(existingRule.action)",
                    actionTitle: "Open plan"
                )
            }

            let windowText = riskWindows.first.map { " around \($0.startLabel)" } ?? ""
            return PlanAdjustmentInsight(
                title: "Add a \(topTrigger.name.lowercased()) rule",
                detail: "\(topTrigger.name) is your most frequent logged trigger. Choose one replacement action\(windowText).",
                actionTitle: "Open plan"
            )
        }

        if let riskWindow = riskWindows.first {
            return PlanAdjustmentInsight(
                title: "Prepare for \(riskWindow.startLabel)",
                detail: "This window has the highest share of logged cravings. Put one substitute activity in your plan before it starts.",
                actionTitle: "Open plan"
            )
        }

        return PlanAdjustmentInsight(
            title: "Build the pattern map",
            detail: "Log a few cravings with triggers selected. TeoPateo will turn them into a specific plan adjustment here.",
            actionTitle: "Open plan"
        )
    }

    private static func matchingRule(
        for trigger: String,
        in triggerRules: [TriggerRule]
    ) -> TriggerRule? {
        let triggerText = trigger.lowercased()
        return triggerRules.first { rule in
            guard rule.isEnabled else { return false }
            let ruleText = rule.trigger.lowercased()
            return ruleText.contains(triggerText) || triggerText.contains(ruleText)
        }
    }

    private static func dataConfidenceSummary(cravingCount: Int, slipCount: Int) -> String {
        let total = cravingCount + slipCount
        if total < 3 {
            return "Early pattern. Log a few more cravings before trusting percentages."
        }
        if total < 8 {
            return "Useful early signal from recent history."
        }
        return "Strong signal from repeated logged patterns."
    }

    private static func daySummary(_ days: Int) -> String {
        days == 1 ? "1 day" : "\(days) days"
    }

    private static func moneySummary(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_US")
        formatter.currencyCode = "USD"
        formatter.minimumFractionDigits = amount.rounded() == amount ? 0 : 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }

    private static var motivationFallback: String {
        "Pause for 10 minutes before deciding. This urge can pass."
    }

    private static func shouldSeedDefaultData(appSettings: AppSettings?) -> Bool {
        guard let appSettings else {
            return true
        }
        return appSettings.updatedAt.timeIntervalSince1970 <= 0
    }

    private static func normalizedOnboardingTriggers(_ triggers: [String]) -> [String] {
        let normalized = triggers
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let uniqueTriggers = uniqueStrings(normalized)

        return uniqueTriggers.isEmpty
            ? Array(QuitTriggerCatalog.onboardingTriggers.prefix(3))
            : Array(uniqueTriggers.prefix(6))
    }

    private static func normalizedReplacementActions(_ actions: [String]) -> [String] {
        let normalized = actions
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let uniqueActions = uniqueStrings(normalized)
        return uniqueActions.isEmpty ? ["Drink water", "Walk", "Breathing"] : uniqueActions
    }

    private static func uniqueStrings(_ values: [String]) -> [String] {
        values.reduce(into: [String]()) { result, value in
            if !result.contains(where: { $0.caseInsensitiveCompare(value) == .orderedSame }) {
                result.append(value)
            }
        }
    }

    private static func resolvedQuitMode(
        preference: QuitApproachPreference,
        status: QuitStatus,
        confidence: Double,
        cigarettesPerDay: Double,
        firstCigaretteTiming: FirstCigaretteTiming
    ) -> String {
        switch preference {
        case .taper:
            return status == .alreadyQuit ? "Cold turkey" : "Taper"
        case .coldTurkey:
            return "Cold turkey"
        case .notSure:
            if status == .alreadyQuit || status == .readyToQuit && confidence >= 7 && cigarettesPerDay <= 10 {
                return "Cold turkey"
            }
            if firstCigaretteTiming == .withinFiveMinutes || firstCigaretteTiming == .withinThirtyMinutes {
                return "Taper"
            }
            return status == .cuttingDown || confidence <= 6 || cigarettesPerDay > 10 ? "Taper" : "Cold turkey"
        }
    }

    private static func resolvedQuitDate(
        preference: QuitDatePreference,
        selectedDate: Date,
        status: QuitStatus,
        confidence: Double,
        now: Date,
        calendar: Calendar
    ) -> Date {
        let today = calendar.startOfDay(for: now)
        switch preference {
        case .alreadyQuit:
            return min(calendar.startOfDay(for: selectedDate), today)
        case .chooseDate:
            return max(calendar.startOfDay(for: selectedDate), today)
        case .helpMeChoose:
            let days: Int
            switch status {
            case .alreadyQuit:
                days = 0
            case .readyToQuit:
                days = confidence >= 7 ? 7 : 10
            case .cuttingDown:
                days = confidence >= 7 ? 14 : 21
            case .thinkingAboutIt, .unsure:
                days = 21
            }
            return calendar.date(byAdding: .day, value: days, to: today) ?? today
        }
    }

    private static func generatedTaperSettings(
        cigarettesPerDay: Double,
        confidence: Double,
        firstCigaretteTiming: FirstCigaretteTiming,
        previousAttempts: PreviousQuitAttemptCount,
        mainChallenge: SmokingChallenge,
        mode: String
    ) -> (target: Double, step: Double, intervalDays: Int) {
        guard mode == "Taper" else {
            return (0, 0, 3)
        }

        let needsGentlerStart = confidence <= 4 ||
            firstCigaretteTiming == .withinFiveMinutes ||
            previousAttempts == .fourOrMore ||
            mainChallenge == .withdrawal
        let step = needsGentlerStart ? 1.0 : min(max((cigarettesPerDay * 0.2).rounded(), 1), 3)
        let intervalDays = needsGentlerStart ? 4 : (confidence >= 8 ? 2 : 3)
        return (max(cigarettesPerDay, 0), step, intervalDays)
    }

    private static func generatedDailyFocus(
        status: QuitStatus,
        selectedTriggers: [String],
        mainChallenge: SmokingChallenge
    ) -> String {
        let primaryTrigger = selectedTriggers.first ?? mainChallenge.triggerLabel
        switch status {
        case .alreadyQuit:
            return "Protect \(primaryTrigger.lowercased()) with a 10-minute rescue before the urge peaks."
        case .readyToQuit:
            return "Rehearse the \(primaryTrigger.lowercased()) rule once before the quit date."
        case .cuttingDown:
            return "Delay one \(primaryTrigger.lowercased()) cigarette and use a replacement first."
        case .thinkingAboutIt:
            return "Notice the next \(primaryTrigger.lowercased()) cue and try one replacement without pressure."
        case .unsure:
            return "Log one smoking moment and what the \(mainChallenge.title.lowercased()) was asking for."
        }
    }

    private static func generatedPlanSummary(
        status: QuitStatus,
        selectedTriggers: [String],
        mainChallenge: SmokingChallenge,
        mode: String,
        dailyFocus: String,
        primaryReason: String
    ) -> String {
        let triggerSummary = selectedTriggers.prefix(3).joined(separator: ", ")
        let triggerText = triggerSummary.isEmpty ? mainChallenge.triggerLabel : triggerSummary
        return "You are in \(status.readinessStage.lowercased()) with \(mode.lowercased()) as the first strategy. The first rescue plan protects \(triggerText). \(dailyFocus) Your reason to protect is \"\(primaryReason)\"."
    }

    private static func onboardingReplacementActivities(
        for triggers: [String],
        selectedActions: [String],
        now: Date
    ) -> [ReplacementActivity] {
        let triggerActivities = triggers.prefix(4).map { trigger in
            ReplacementActivity(
                title: onboardingActivityTitle(for: trigger),
                instruction: onboardingActivityInstruction(for: trigger),
                category: onboardingActivityCategory(for: trigger),
                linkedTrigger: trigger,
                createdAt: now,
                updatedAt: now
            )
        }

        let actionActivities = selectedActions.map { action in
            ReplacementActivity(
                title: onboardingActivityTitle(forAction: action),
                instruction: onboardingActivityInstruction(forAction: action),
                category: onboardingActivityCategory(forAction: action),
                createdAt: now,
                updatedAt: now
            )
        }

        return (triggerActivities + actionActivities).uniquedByTitle().prefix(8).map { $0 }
    }

    private static func onboardingRiskySituations(
        triggers: [String],
        selectedReplacementActions: [String],
        mainChallenge: SmokingChallenge,
        now: Date
    ) -> [RiskySituation] {
        let backup = "Start the 10-minute rescue before leaving the current place."
        return triggers.prefix(3).map { trigger in
            RiskySituation(
                title: trigger,
                expectedContext: "Risk may rise when \(trigger.lowercased()) overlaps with \(mainChallenge.title.lowercased()).",
                preventionPlan: onboardingAction(
                    for: trigger,
                    selectedReplacementActions: selectedReplacementActions,
                    mainChallenge: mainChallenge
                ),
                backupAction: backup,
                createdAt: now,
                updatedAt: now
            )
        }
    }

    private static func onboardingAction(
        for trigger: String,
        selectedReplacementActions: [String] = [],
        mainChallenge: SmokingChallenge = .cravings
    ) -> String {
        let preferredAction = selectedReplacementActions.first.map { " Start with \($0.lowercased())." } ?? ""
        switch trigger {
        case "Coffee", "After coffee":
            return "Drink a full glass of water first, then wait 10 minutes before deciding.\(preferredAction)"
        case "After meals":
            return "Brush teeth or chew gum as soon as the meal ends.\(preferredAction)"
        case "Work stress", "Work breaks", "Work pressure", "Stress":
            return "Step away from the task, walk for 10 minutes, then choose the next small action."
        case "Driving", "Driving or commute":
            return "Keep cigarettes out of reach and start a short breathing reset before the trip."
        case "Alcohol":
            return "Keep a drink in hand, avoid stepping outside with smokers, and start the rescue timer if the urge spikes."
        case "Boredom":
            return "Start a five-minute reset task before making any smoking decision."
        case "Social smoking", "Friends who smoke", "Social pressure":
            return "Tell one person you are pausing for 10 minutes and stay away from the smoking spot."
        case "Morning", "Morning routine":
            return "Change the first 10 minutes: water, shower, or a short walk before coffee."
        case "Evening", "Before bed", "Evening wind-down":
            return "Put cigarettes out of sight and start the rescue timer before settling in."
        case "Anger", "Anxiety", "Loneliness":
            return "Name the feeling, slow your breathing, and wait 10 minutes before making a smoking decision."
        case "Being outside", "Phone scrolling", "Waiting":
            return "Keep your hands busy and start a replacement action before autopilot takes over."
        default:
            return "Pause for 10 minutes, name the \(mainChallenge.title.lowercased()) cue, and choose one substitute."
        }
    }

    private static func onboardingActivityTitle(for trigger: String) -> String {
        switch trigger {
        case "Coffee", "After coffee":
            return "Cold water first"
        case "After meals":
            return "Brush or chew"
        case "Work stress", "Work breaks", "Work pressure", "Stress":
            return "Walk one block"
        case "Driving", "Driving or commute":
            return "Commute breathing"
        case "Alcohol":
            return "Step back inside"
        case "Boredom":
            return "Five-minute reset"
        case "Social smoking", "Friends who smoke", "Social pressure":
            return "Stay with the room"
        case "Morning", "Morning routine":
            return "Change the first 10"
        case "Evening", "Before bed", "Evening wind-down":
            return "Hands-busy reset"
        case "Anger", "Anxiety", "Loneliness":
            return "Name the feeling"
        case "Being outside", "Phone scrolling", "Waiting":
            return "Hands-busy pause"
        default:
            return "10-minute substitute"
        }
    }

    private static func onboardingActivityInstruction(for trigger: String) -> String {
        switch trigger {
        case "Coffee", "After coffee":
            return "Finish one full glass of cold water before deciding anything."
        case "After meals":
            return "Brush teeth or chew gum until the urge drops."
        case "Work stress", "Work breaks", "Work pressure", "Stress":
            return "Walk away from the task until the timer drops below 6:00."
        case "Driving", "Driving or commute":
            return "Take five slow breaths before starting the car or leaving transit."
        case "Alcohol":
            return "Move away from the smoking cue and keep both hands busy before going outside."
        case "Boredom":
            return "Tidy one small area or start one quick errand until the urge changes."
        case "Social smoking", "Friends who smoke", "Social pressure":
            return "Stay inside for 10 minutes and choose one hands-busy reset."
        case "Morning", "Morning routine":
            return "Drink water and move for two minutes before coffee or phone checks."
        case "Evening", "Before bed", "Evening wind-down":
            return "Hold a cold drink, stretch, or keep both hands busy until the timer ends."
        case "Anger", "Anxiety", "Loneliness":
            return "Write one sentence that names the feeling, then breathe for one minute."
        case "Being outside", "Phone scrolling", "Waiting":
            return "Keep both hands busy and delay the smoking decision until the timer drops."
        default:
            return "Choose one substitute and stay with it until the timer ends."
        }
    }

    private static func onboardingActivityCategory(for trigger: String) -> ReplacementActivityCategory {
        switch trigger {
        case "Work stress", "Work breaks", "Work pressure", "Stress", "Morning", "Morning routine":
            return .movement
        case "Driving", "Driving or commute", "Anxiety":
            return .breathing
        case "Coffee", "After coffee", "After meals", "Evening", "Before bed", "Evening wind-down":
            return .sensory
        case "Alcohol":
            return .sensory
        case "Anger", "Loneliness":
            return .journaling
        case "Social smoking", "Friends who smoke", "Social pressure":
            return .distraction
        default:
            return .distraction
        }
    }

    private static func onboardingActivityTitle(forAction action: String) -> String {
        switch action {
        case "Drink water":
            return "Drink cold water"
        case "Walk":
            return "Walk for 10"
        case "Breathing":
            return "Box breathing"
        case "Chewing gum":
            return "Chew through the urge"
        case "Brush teeth":
            return "Brush teeth"
        case "Message someone":
            return "Message a person"
        case "Journal":
            return "Write one sentence"
        case "Short task":
            return "Five-minute reset"
        default:
            return action
        }
    }

    private static func onboardingActivityInstruction(forAction action: String) -> String {
        switch action {
        case "Drink water":
            return "Finish one full glass before deciding anything."
        case "Walk":
            return "Walk until the timer drops below 6:00."
        case "Breathing":
            return "Breathe in 4, hold 4, out 4, hold 4. Repeat five times."
        case "Chewing gum":
            return "Chew gum until the first wave of the urge drops."
        case "Brush teeth":
            return "Brush teeth as soon as the cue ends."
        case "Message someone":
            return "Send a short text before stepping toward the smoking cue."
        case "Journal":
            return "Name the trigger and the next right action."
        case "Short task":
            return "Tidy one small area or finish one two-minute task."
        default:
            return "Use this as the first 10-minute substitute."
        }
    }

    private static func onboardingActivityCategory(forAction action: String) -> ReplacementActivityCategory {
        switch action {
        case "Walk":
            return .movement
        case "Breathing":
            return .breathing
        case "Drink water", "Chewing gum", "Brush teeth":
            return .sensory
        case "Message someone":
            return .distraction
        case "Journal":
            return .journaling
        default:
            return .distraction
        }
    }

    private static func defaultQuitPlan() -> QuitPlan {
        let now = Date()
        let quitDate = Calendar.current.date(byAdding: .day, value: 11, to: now) ?? now
        return QuitPlan(
            quitDate: quitDate,
            quitMode: "Taper",
            triggerRules: [
                TriggerRule(trigger: "After coffee", action: "Drink water first, wait 10 minutes, log the urge."),
                TriggerRule(trigger: "Leaving work", action: "Walk one block before checking messages."),
                TriggerRule(trigger: "Alcohol", action: "Keep a drink in hand and step outside without cigarettes."),
                TriggerRule(trigger: "After meals", action: "Brush teeth or chew gum immediately.")
            ],
            medicationNote: "",
            baselineCigarettesPerDay: 10,
            costPerPack: 10,
            cigarettesPerPack: 20,
            taperTargetCigarettesPerDay: 8,
            taperReductionStep: 2,
            taperReductionIntervalDays: 3,
            attemptStartedAt: quitDate,
            createdAt: now,
            updatedAt: now
        )
    }

    private static func defaultUserReasons() -> [UserReason] {
        [
            UserReason(
                text: "I want mornings without chest tightness, and I want to keep promises I made when I was calm.",
                sortOrder: 0,
                isPrimary: true
            )
        ]
    }

    private static func defaultReplacementActivities() -> [ReplacementActivity] {
        [
            ReplacementActivity(title: "Drink cold water", instruction: "Finish one full glass before deciding anything.", category: .sensory, linkedTrigger: "Coffee"),
            ReplacementActivity(title: "Walk outside", instruction: "Move until the timer drops below 6:00.", category: .movement, linkedTrigger: "Work stress"),
            ReplacementActivity(title: "Box breathing", instruction: "Breathe in 4, hold 4, out 4, hold 4. Repeat five times.", category: .breathing),
            ReplacementActivity(title: "Hold something cold", instruction: "Keep an ice cube or cold can in your hand until the urge drops.", category: .sensory),
            ReplacementActivity(title: "Write one sentence", instruction: "Name the trigger and the next right action.", category: .journaling),
            ReplacementActivity(title: "Five-minute reset", instruction: "Tidy one small area until the urge drops.", category: .distraction)
        ]
    }

    private static func defaultCoachChats() -> [CoachChat] {
        let createdAt = Date()

        return [
            CoachChat(
                title: "New chat",
                messages: [],
                createdAt: createdAt,
                updatedAt: createdAt
            )
        ]
    }

    private static func validSelectedCoachChatID(_ chatID: UUID?, in chats: [CoachChat]) -> UUID? {
        if let chatID, chats.contains(where: { $0.id == chatID }) {
            return chatID
        }
        return chats.first?.id
    }
}

// MARK: - iCloud Backup

extension TeoPateoStore {
    private enum CloudPushReason { case automatic, manual, background }
    private enum CloudRestoreReason { case automatic, manual }

    /// Turn automatic iCloud backup on or off (device-local preference). Turning it on triggers
    /// an immediate backup so the user's data is protected right away.
    func setCloudBackupEnabled(_ enabled: Bool) {
        cloudBackupSettings.isEnabled = enabled
        isCloudBackupEnabled = enabled
        if enabled {
            backUpNow()
        } else {
            cloudPushTask?.cancel()
            cloudBackupStatus = .idle
        }
    }

    /// User-initiated "Back up now".
    func backUpNow() {
        Task { [weak self] in await self?.backUpAndWait() }
    }

    /// Awaitable backup used by `backUpNow()` and tests.
    func backUpAndWait() async {
        cloudPushTask?.cancel()
        await performCloudPush(reason: .manual)
    }

    /// User-initiated "Restore from iCloud" (overwrites local data — gate behind a confirmation).
    func requestCloudRestore() {
        Task { [weak self] in _ = await self?.restoreFromCloud() }
    }

    /// Awaitable manual restore used by `requestCloudRestore()` and tests.
    @discardableResult
    func restoreFromCloud() async -> Bool {
        await applyCloudRestore(reason: .manual)
    }

    /// Refresh the cached account availability so the UI can show the current state.
    func refreshCloudBackupAvailability() {
        Task { [weak self] in
            guard let self else { return }
            self.cloudBackupAvailability = await self.cloudBackup.accountAvailability()
        }
    }

    /// Called when the app enters the foreground.
    func onEnterForeground() {
        refreshCloudBackupAvailability()
    }

    /// Called when the app enters the background: flush a backup immediately (cancelling any
    /// pending debounce) under a background-task assertion so the upload can finish.
    func onEnterBackground() {
        guard isCloudBackupEnabled else { return }
        cloudPushTask?.cancel()
        #if canImport(UIKit)
        var backgroundTask: UIBackgroundTaskIdentifier = .invalid
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "CloudBackupFlush") {
            if backgroundTask != .invalid {
                UIApplication.shared.endBackgroundTask(backgroundTask)
                backgroundTask = .invalid
            }
        }
        Task { [weak self] in
            await self?.performCloudPush(reason: .background)
            if backgroundTask != .invalid {
                UIApplication.shared.endBackgroundTask(backgroundTask)
                backgroundTask = .invalid
            }
        }
        #else
        Task { [weak self] in await self?.performCloudPush(reason: .background) }
        #endif
    }

    /// Restores from iCloud on a fresh device. Safe to call on launch: it only overwrites local
    /// data when onboarding has NOT been completed (so there is nothing worth keeping locally)
    /// and a backup actually exists. Runs at most once per launch.
    func attemptAutomaticCloudRestoreIfEligible() {
        Task { [weak self] in _ = await self?.runAutomaticRestoreIfEligible() }
    }

    /// Awaitable automatic restore (with the fresh-device gate) used on launch and by tests.
    /// Restores only when onboarding has not been completed and a backup exists.
    @discardableResult
    func runAutomaticRestoreIfEligible() async -> Bool {
        guard !hasAttemptedCloudRestore else { return false }
        hasAttemptedCloudRestore = true
        guard isCloudBackupEnabled, !isOnboardingCompleted else { return false }
        return await applyCloudRestore(reason: .automatic)
    }

    private func scheduleCloudPushDebounced() {
        guard isCloudBackupEnabled else { return }
        cloudPushTask?.cancel()
        cloudPushTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            if Task.isCancelled { return }
            await self?.performCloudPush(reason: .automatic)
        }
    }

    private func performCloudPush(reason: CloudPushReason) async {
        guard isCloudBackupEnabled else { return }

        let availability = await cloudBackup.accountAvailability()
        cloudBackupAvailability = availability
        guard availability.canSync else {
            if reason == .manual {
                cloudBackupStatus = .failed(cloudBackupMessage(for: CloudBackupError.accountUnavailable(availability)))
            }
            return
        }

        let envelope: BackupEnvelope
        do {
            envelope = BackupEnvelope(
                schemaVersion: try repository.schemaVersion(),
                exportedAt: now(),
                deviceName: BackupEnvelope.currentDeviceName,
                snapshot: try repository.loadSnapshot()
            )
        } catch {
            if reason == .manual { cloudBackupStatus = .failed("Could not read local data to back up.") }
            return
        }

        if reason == .manual { cloudBackupStatus = .inProgress }
        do {
            try await cloudBackup.push(envelope)
            recordSuccessfulBackup(at: envelope.exportedAt, device: envelope.deviceName)
        } catch {
            // Automatic/background failures stay quiet; they retry on the next change, foreground,
            // or background. Only a user-initiated backup surfaces an error.
            if reason == .manual { cloudBackupStatus = .failed(cloudBackupMessage(for: error)) }
        }
    }

    @discardableResult
    private func applyCloudRestore(reason: CloudRestoreReason) async -> Bool {
        let availability = await cloudBackup.accountAvailability()
        cloudBackupAvailability = availability
        guard availability.canSync else {
            if reason == .manual {
                cloudBackupStatus = .failed(cloudBackupMessage(for: CloudBackupError.accountUnavailable(availability)))
            }
            return false
        }

        let fetched: BackupEnvelope?
        do {
            fetched = try await cloudBackup.fetchLatest()
        } catch {
            if reason == .manual { cloudBackupStatus = .failed(cloudBackupMessage(for: error)) }
            return false
        }

        guard let envelope = fetched else {
            if reason == .manual { cloudBackupStatus = .failed("No iCloud backup found yet.") }
            return false
        }

        let currentSchema = (try? repository.schemaVersion()) ?? 0
        guard envelope.schemaVersion <= currentSchema else {
            cloudBackupStatus = .failed(cloudBackupMessage(for: CloudBackupError.incompatibleVersion))
            return false
        }

        do {
            isApplyingCloudRestore = true
            defer { isApplyingCloudRestore = false }
            try repository.importSnapshot(envelope.snapshot)
            reloadFromPersistenceAfterRestore()
            recordSuccessfulBackup(at: envelope.exportedAt, device: envelope.deviceName)
            lastSaveStatus = .saved("Restored your data from iCloud.")
            return true
        } catch {
            recordPersistenceError(error)
            cloudBackupStatus = .failed("Could not restore from iCloud.")
            return false
        }
    }

    /// Re-applies persisted state into the published properties after a restore overwrote the
    /// database. Mirrors the safe core of `hydrateFromPersistence` without re-seeding defaults or
    /// restarting the tutorial, and wraps the apply in `isHydrating` so the property `didSet`s do
    /// not fire a write/push storm.
    private func reloadFromPersistenceAfterRestore() {
        let wasHydrating = isHydrating
        isHydrating = true
        defer { isHydrating = wasHydrating }

        do {
            applyPersistedSnapshot(try repository.loadSnapshot())
            persistenceError = nil
        } catch {
            recordPersistenceError(error)
        }
        selectedTab = .today
        syncScheduledNotifications(showSuccess: false)
    }

    private func recordSuccessfulBackup(at date: Date, device: String) {
        cloudBackupSettings.lastBackupAt = date
        cloudBackupSettings.lastBackupDevice = device
        lastCloudBackupAt = date
        lastCloudBackupDevice = device
        cloudBackupStatus = .success
    }

    private func cloudBackupMessage(for error: Error) -> String {
        guard let error = error as? CloudBackupError else { return "iCloud backup failed." }
        switch error {
        case .accountUnavailable:
            return "Sign in to iCloud in Settings to back up your quit journey."
        case .network:
            return "No connection. Your backup will retry automatically."
        case .quotaExceeded:
            return "Your iCloud storage is full, so the backup couldn't be saved."
        case .serviceUnavailable:
            return "iCloud is busy right now. Try again in a moment."
        case .incompatibleVersion:
            return "This backup was made with a newer version of TeoPateo. Update the app to restore it."
        case .corruptBackup:
            return "The iCloud backup couldn't be read."
        case .unknown:
            return "iCloud backup failed."
        }
    }
}

enum AppTab: String, CaseIterable {
    case today = "Today"
    case plan = "Plan"
    case checkIn = "Check-in"
    case insights = "Insights"
    case coach = "Coach"
}

private final class InMemoryTeoPateoRepository: TeoPateoRepository {
    private var appSettings: AppSettings?
    private var notificationSettings: NotificationSettings?
    private var privacySettings: PrivacySettings?
    private var userProfile: UserProfile?
    private var quitReadiness: QuitReadiness?
    private var smokingBackground: SmokingBackground?
    private var savingsGoal: SavingsGoal?
    private var quitPlan: QuitPlan?
    private var dailyCheckIns: [DailyCheckIn] = []
    private var cravingEvents: [CravingEvent] = []
    private var slipEvents: [SlipEvent] = []
    private var replacementActivities: [ReplacementActivity] = []
    private var riskySituations: [RiskySituation] = []
    private var supportContacts: [SupportContact] = []
    private var userReasons: [UserReason] = []
    private var coachChats: [CoachChat] = []
    private var selectedCoachChatID: UUID?

    func schemaVersion() throws -> Int { 0 }
    func tableNames() throws -> Set<String> { [] }

    func loadSnapshot() throws -> PersistedTeoPateoSnapshot {
        PersistedTeoPateoSnapshot(
            appSettings: appSettings,
            notificationSettings: notificationSettings,
            privacySettings: privacySettings,
            userProfile: userProfile,
            quitReadiness: quitReadiness,
            smokingBackground: smokingBackground,
            savingsGoal: savingsGoal,
            quitPlan: quitPlan,
            dailyCheckIns: dailyCheckIns,
            cravingEvents: cravingEvents,
            slipEvents: slipEvents,
            replacementActivities: replacementActivities,
            riskySituations: riskySituations,
            supportContacts: supportContacts,
            userReasons: userReasons,
            coachChats: coachChats,
            selectedCoachChatID: selectedCoachChatID
        )
    }

    func fetchAppSettings() throws -> AppSettings? {
        appSettings
    }

    func saveAppSettings(_ settings: AppSettings) throws {
        appSettings = settings
    }

    func fetchNotificationSettings() throws -> NotificationSettings? {
        notificationSettings
    }

    func saveNotificationSettings(_ settings: NotificationSettings) throws {
        notificationSettings = settings
    }

    func fetchPrivacySettings() throws -> PrivacySettings? {
        privacySettings
    }

    func savePrivacySettings(_ settings: PrivacySettings) throws {
        privacySettings = settings
    }

    func fetchUserProfile() throws -> UserProfile? {
        userProfile
    }

    func saveUserProfile(_ profile: UserProfile) throws {
        userProfile = profile
    }

    func fetchQuitReadiness() throws -> QuitReadiness? {
        quitReadiness
    }

    func saveQuitReadiness(_ readiness: QuitReadiness) throws {
        quitReadiness = readiness
    }

    func fetchSmokingBackground() throws -> SmokingBackground? {
        smokingBackground
    }

    func saveSmokingBackground(_ background: SmokingBackground) throws {
        smokingBackground = background
    }

    func fetchSavingsGoal() throws -> SavingsGoal? {
        savingsGoal
    }

    func saveSavingsGoal(_ goal: SavingsGoal) throws {
        savingsGoal = goal
    }

    func fetchQuitPlan() throws -> QuitPlan? {
        quitPlan
    }

    func saveQuitPlan(_ plan: QuitPlan) throws {
        quitPlan = plan
    }

    func saveDailyCheckIn(_ checkIn: DailyCheckIn) throws {
        dailyCheckIns.removeAll { $0.id == checkIn.id }
        dailyCheckIns.append(checkIn)
    }

    func recentCheckIns(limit: Int) throws -> [DailyCheckIn] {
        Array(dailyCheckIns.sorted { $0.date > $1.date }.prefix(limit))
    }

    func deleteDailyCheckIn(_ id: UUID) throws {
        dailyCheckIns.removeAll { $0.id == id }
    }

    func saveCravingEvent(_ event: CravingEvent) throws {
        cravingEvents.removeAll { $0.id == event.id }
        cravingEvents.append(event)
    }

    func saveCravingWithSlip(craving: CravingEvent, slip: SlipEvent) throws {
        let previousCravingEvents = cravingEvents
        let previousSlipEvents = slipEvents

        do {
            try saveCravingEvent(craving)
            try saveSlipEvent(slip)
        } catch {
            cravingEvents = previousCravingEvents
            slipEvents = previousSlipEvents
            throw error
        }
    }

    func recentCravingEvents(limit: Int) throws -> [CravingEvent] {
        Array(cravingEvents.sorted { $0.startedAt > $1.startedAt }.prefix(limit))
    }

    func deleteCravingEvent(_ id: UUID) throws {
        cravingEvents.removeAll { $0.id == id }
    }

    func saveSlipEvent(_ event: SlipEvent) throws {
        slipEvents.removeAll { $0.id == event.id }
        slipEvents.append(event)
    }

    func recentSlipEvents(limit: Int) throws -> [SlipEvent] {
        Array(slipEvents.sorted { $0.occurredAt > $1.occurredAt }.prefix(limit))
    }

    func deleteSlipEvent(_ id: UUID) throws {
        slipEvents.removeAll { $0.id == id }
    }

    func replaceReplacementActivities(_ activities: [ReplacementActivity]) throws {
        replacementActivities = activities
    }

    func fetchReplacementActivities() throws -> [ReplacementActivity] {
        replacementActivities
    }

    func replaceRiskySituations(_ situations: [RiskySituation]) throws {
        riskySituations = situations
    }

    func fetchRiskySituations() throws -> [RiskySituation] {
        riskySituations
    }

    func replaceSupportContacts(_ contacts: [SupportContact]) throws {
        supportContacts = contacts
    }

    func fetchSupportContacts() throws -> [SupportContact] {
        supportContacts
    }

    func replaceUserReasons(_ reasons: [UserReason]) throws {
        userReasons = reasons
    }

    func fetchUserReasons() throws -> [UserReason] {
        userReasons
    }

    func replaceCoachChats(_ chats: [CoachChat], selectedChatID: UUID?) throws {
        coachChats = chats
        selectedCoachChatID = selectedChatID
    }

    func fetchCoachChats() throws -> [CoachChat] {
        coachChats
    }

    func fetchSelectedCoachChatID() throws -> UUID? {
        selectedCoachChatID
    }

    func deleteAllUserData() throws {
        appSettings = nil
        notificationSettings = nil
        privacySettings = nil
        userProfile = nil
        quitReadiness = nil
        smokingBackground = nil
        savingsGoal = nil
        quitPlan = nil
        dailyCheckIns = []
        cravingEvents = []
        slipEvents = []
        replacementActivities = []
        riskySituations = []
        supportContacts = []
        userReasons = []
        coachChats = []
        selectedCoachChatID = nil
    }

    func importSnapshot(_ snapshot: PersistedTeoPateoSnapshot) throws {
        appSettings = snapshot.appSettings
        notificationSettings = snapshot.notificationSettings
        privacySettings = snapshot.privacySettings
        userProfile = snapshot.userProfile
        quitReadiness = snapshot.quitReadiness
        smokingBackground = snapshot.smokingBackground
        savingsGoal = snapshot.savingsGoal
        quitPlan = snapshot.quitPlan
        dailyCheckIns = snapshot.dailyCheckIns
        cravingEvents = snapshot.cravingEvents
        slipEvents = snapshot.slipEvents
        replacementActivities = snapshot.replacementActivities
        riskySituations = snapshot.riskySituations
        supportContacts = snapshot.supportContacts
        userReasons = snapshot.userReasons
        coachChats = snapshot.coachChats
        selectedCoachChatID = snapshot.selectedCoachChatID
    }
}

private extension Array where Element: Identifiable {
    func uniquedByID() -> [Element] {
        var seen: Set<Element.ID> = []
        var result: [Element] = []
        for element in self where !seen.contains(element.id) {
            seen.insert(element.id)
            result.append(element)
        }
        return result
    }
}

private extension Array where Element == ReplacementActivity {
    func uniquedByTitle() -> [ReplacementActivity] {
        reduce(into: [ReplacementActivity]()) { result, activity in
            if !result.contains(where: { $0.title.caseInsensitiveCompare(activity.title) == .orderedSame }) {
                result.append(activity)
            }
        }
    }
}

private extension Array {
    mutating func move(from sourceIndex: Int, to destinationIndex: Int) {
        let element = remove(at: sourceIndex)
        insert(element, at: destinationIndex)
    }
}
