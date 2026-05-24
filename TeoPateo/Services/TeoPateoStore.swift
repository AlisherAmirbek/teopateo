import Foundation

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
    @Published private(set) var notificationSettings = NotificationSettings()
    @Published private(set) var notificationPermissionStatus: NotificationPermissionStatus = .unknown
    @Published private(set) var isOnboardingCompleted = false
    @Published private(set) var persistenceError: String?
    @Published private(set) var lastSaveStatus: SaveStatus = .idle
    @Published private(set) var supportMessageDraft = ""

    private let repository: TeoPateoRepository
    private let notificationScheduler: NotificationScheduling
    private let coachClient: CoachResponding
    private let now: () -> Date
    private let calendar: Calendar
    private var quitPlan = TeoPateoStore.defaultQuitPlan()
    private var isHydrating = false

    convenience init() {
        do {
            try self.init(repository: SQLiteTeoPateoRepository.live())
        } catch {
            self.init(repository: InMemoryTeoPateoRepository())
            persistenceError = error.localizedDescription
            lastSaveStatus = .failed("Local storage is unavailable. Changes may not persist.")
        }
    }

    init(
        repository: TeoPateoRepository,
        notificationScheduler: NotificationScheduling = LocalNotificationScheduler(),
        coachClient: CoachResponding = LiveCoachClient(),
        now: @escaping () -> Date = Date.init,
        calendar: Calendar = .current
    ) {
        self.repository = repository
        self.notificationScheduler = notificationScheduler
        self.coachClient = coachClient
        self.now = now
        self.calendar = calendar
        hydrateFromPersistence()
    }

    var currentQuitPlan: QuitPlan {
        quitPlan
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

    var todayTaperTarget: Double? {
        taperTarget(on: now())
    }

    var todayCheckIn: DailyCheckIn? {
        latestCheckIn(on: now())
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
        date: Date = Date(),
        slipNote: String
    ) -> Bool {
        guard smokedToday != nil else {
            lastSaveStatus = .failed("Choose whether you smoked today before saving.")
            return false
        }

        let now = now()
        let existing = latestCheckIn(on: date)
        let cigarettesSmoked = smokedToday == true ? max(cigarettesSmoked, 1) : 0
        let taperTarget = taperTarget(on: date)
        let checkIn = DailyCheckIn(
            id: existing?.id ?? UUID(),
            date: date,
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
            persistenceError = nil
            lastSaveStatus = .saved(existing == nil ? "Check-in saved." : "Today check-in updated.")
            return true
        } catch {
            persistenceError = error.localizedDescription
            lastSaveStatus = .failed("Check-in could not be saved.")
            return false
        }
    }

    @discardableResult
    func completeCraving(
        startedAt: Date,
        completedAt: Date = Date(),
        durationSeconds: Int,
        completedWithoutSmoking: Bool
    ) -> Bool {
        if completedWithoutSmoking {
            return completeCravingWithoutSmoking(
                startedAt: startedAt,
                completedAt: completedAt,
                durationSeconds: durationSeconds
            )
        }

        return completeCravingWithSlip(
            startedAt: startedAt,
            completedAt: completedAt,
            durationSeconds: durationSeconds,
            cigarettesSmoked: 1,
            slipNote: "Smoked during a craving.",
            recoveryAction: "Return to the next planned 10-minute pause."
        )
    }

    @discardableResult
    func completeCravingWithoutSmoking(
        startedAt: Date,
        completedAt: Date = Date(),
        durationSeconds: Int,
        initialIntensity: Double? = nil,
        finalIntensity: Double? = nil,
        helpedActivityID: UUID? = nil,
        supportContactID: UUID? = nil,
        reflectionNote: String = ""
    ) -> Bool {
        let event = makeCravingEvent(
            startedAt: startedAt,
            completedAt: completedAt,
            durationSeconds: durationSeconds,
            outcome: .completedWithoutSmoking,
            initialIntensity: initialIntensity,
            finalIntensity: finalIntensity,
            helpedActivityID: helpedActivityID,
            supportContactID: supportContactID,
            reflectionNote: reflectionNote,
            dismissedAt: nil
        )

        return persistCravingEvent(event, successMessage: "Craving saved as handled.")
    }

    @discardableResult
    func completeCravingWithSlip(
        startedAt: Date,
        completedAt: Date = Date(),
        durationSeconds: Int,
        initialIntensity: Double? = nil,
        finalIntensity: Double? = nil,
        helpedActivityID: UUID? = nil,
        supportContactID: UUID? = nil,
        cigarettesSmoked: Int,
        slipNote: String,
        recoveryAction: String
    ) -> Bool {
        let event = makeCravingEvent(
            startedAt: startedAt,
            completedAt: completedAt,
            durationSeconds: durationSeconds,
            outcome: .smokedAfterCraving,
            initialIntensity: initialIntensity,
            finalIntensity: finalIntensity,
            helpedActivityID: helpedActivityID,
            supportContactID: supportContactID,
            reflectionNote: slipNote,
            dismissedAt: nil
        )

        guard persistCravingEvent(event, successMessage: "Craving and slip saved.") else {
            return false
        }

        return saveSlipEvent(
            occurredAt: completedAt,
            cigarettesSmoked: cigarettesSmoked,
            triggers: selectedTriggers,
            mood: mood,
            stress: stress,
            context: "Craving mode",
            note: slipNote,
            recoveryAction: recoveryAction
        )
    }

    @discardableResult
    func dismissCravingSession(
        startedAt: Date,
        dismissedAt: Date = Date(),
        durationSeconds: Int,
        initialIntensity: Double? = nil
    ) -> Bool {
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
            dismissedAt: dismissedAt
        )

        return persistCravingEvent(event, successMessage: "Craving saved for later review.")
    }

    @discardableResult
    func saveSlipEvent(
        occurredAt: Date = Date(),
        cigarettesSmoked: Int,
        triggers: Set<String>,
        mood: Double? = nil,
        stress: Double? = nil,
        context: String,
        note: String,
        recoveryAction: String
    ) -> Bool {
        let now = now()
        let event = SlipEvent(
            occurredAt: occurredAt,
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
            persistenceError = nil
            lastSaveStatus = .saved("Slip saved as plan data.")
            return true
        } catch {
            persistenceError = error.localizedDescription
            lastSaveStatus = .failed("Slip could not be saved.")
            return false
        }
    }

    func startCravingSession() {
        selectedTriggers = []
        supportMessageDraft = ""
        lastSaveStatus = .idle
    }

    func draftSupportMessage(for contact: SupportContact? = nil) {
        guard let contact = contact ?? supportContactForCraving() else {
            supportMessageDraft = "Add a support contact in your plan first."
            return
        }
        supportMessageDraft = supportMessageTemplate(for: contact)
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

        let chatID = ensureSelectedCoachChat()
        appendCoachMessage(
            CoachMessage(text: trimmed, isUser: true, createdAt: now()),
            to: chatID,
            updateTitleFromUserText: trimmed
        )
        coachResponseState = .sending
        persistCoachChats()

        do {
            let coachRequest = makeCoachRequest(for: chatID)
            let assistantMessageID = UUID()
            appendCoachMessage(
                CoachMessage(id: assistantMessageID, text: "", isUser: false, createdAt: now()),
                to: chatID
            )

            var reply = ""
            for try await chunk in coachClient.reply(to: coachRequest) {
                reply += chunk
                updateCoachMessage(assistantMessageID, in: chatID, text: reply)
            }

            let trimmedReply = reply.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedReply.isEmpty else {
                deleteCoachMessage(assistantMessageID, from: chatID)
                throw CoachClientError.emptyResponse
            }
            updateCoachMessage(assistantMessageID, in: chatID, text: trimmedReply)
            coachResponseState = .ready
            persistCoachChats()
        } catch {
            coachResponseState = .failed(Self.coachErrorMessage(for: error))
        }
    }

    func updateQuitDate(_ date: Date) {
        quitPlan.quitDate = date
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
        quitPlan.taperReductionStep = max(reductionStep, 0)
        quitPlan.taperReductionIntervalDays = max(reductionIntervalDays, 1)
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
        let reduction = Double(completedIntervals) * max(quitPlan.taperReductionStep, 0)
        return max(quitPlan.taperTargetCigarettesPerDay - reduction, 0)
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

    @discardableResult
    func completeOnboarding(_ input: OnboardingPlanInput) -> Bool {
        let now = now()
        let normalizedMode = input.quitMode == "Cold turkey" ? "Cold turkey" : "Taper"
        let selectedTriggers = Self.normalizedOnboardingTriggers(input.selectedTriggers)
        let nextTriggerRules = selectedTriggers.map { trigger in
            TriggerRule(
                trigger: trigger,
                action: Self.onboardingAction(for: trigger)
            )
        }
        let primaryReason = input.primaryReason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !primaryReason.isEmpty else {
            lastSaveStatus = .failed("Add one reason before creating the plan.")
            return false
        }
        let nextReasons = [
            UserReason(
                text: primaryReason,
                sortOrder: 0,
                isPrimary: true,
                createdAt: now,
                updatedAt: now
            )
        ]
        let nextActivities = Self.onboardingReplacementActivities(
            for: selectedTriggers,
            now: now
        )

        var nextPlan = quitPlan
        nextPlan.quitDate = input.quitDate
        nextPlan.quitMode = normalizedMode
        nextPlan.triggerRules = nextTriggerRules
        nextPlan.medicationNote = ""
        nextPlan.baselineCigarettesPerDay = max(input.cigarettesPerDay, 0)
        nextPlan.costPerPack = max(input.costPerPack, 0)
        nextPlan.cigarettesPerPack = 20
        nextPlan.taperTargetCigarettesPerDay = normalizedMode == "Taper"
            ? max(input.cigarettesPerDay - 2, 0)
            : 0
        nextPlan.taperReductionStep = 2
        nextPlan.taperReductionIntervalDays = 3
        nextPlan.attemptStartedAt = input.quitDate
        nextPlan.updatedAt = now

        let nextSettings = AppSettings(onboardingCompleted: true, updatedAt: now)

        do {
            try repository.saveQuitPlan(nextPlan)
            try repository.replaceSupportContacts([])
            try repository.replaceUserReasons(nextReasons)
            try repository.replaceReplacementActivities(nextActivities)
            try repository.replaceRiskySituations([])
            try repository.saveAppSettings(nextSettings)

            isHydrating = true
            quitPlan = nextPlan
            quitMode = normalizedMode
            triggerRules = nextTriggerRules
            supportContacts = []
            userReasons = nextReasons
            replacementActivities = nextActivities
            riskySituations = []
            self.selectedTriggers = Set(selectedTriggers)
            isOnboardingCompleted = true
            isOnboardingPresented = false
            selectedTab = .today
            isHydrating = false

            persistenceError = nil
            lastSaveStatus = .saved("Your quit plan is ready.")
            return true
        } catch {
            isHydrating = false
            persistenceError = error.localizedDescription
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

    func addSupportContact(
        name: String,
        detail: String,
        phoneNumber: String = "",
        preferredRole: SupportRole = .cravingAlert,
        defaultMessage: String = ""
    ) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            lastSaveStatus = .failed("Support contact needs a name.")
            return
        }
        supportContacts.append(
            SupportContact(
                name: trimmedName,
                detail: detail,
                phoneNumber: phoneNumber,
                preferredRole: preferredRole,
                defaultMessage: defaultMessage
            )
        )
        persistSupportContacts(successMessage: "Support contact saved.")
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
        let enabled = replacementActivities.filter(\.isEnabled)
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

        let categoryFallbacks = ReplacementActivityCategory.allCases.compactMap { category in
            enabled.first { $0.category == category }
        }

        return Array((matched + categoryFallbacks).uniquedByID().prefix(4))
    }

    func supportContactForCraving() -> SupportContact? {
        supportContacts.first { $0.preferredRole == .cravingAlert } ?? supportContacts.first
    }

    func supportMessageTemplate(for contact: SupportContact) -> String {
        let trimmed = contact.defaultMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }

        return "I am having a craving. Can you stay with me for 10 minutes?"
    }

    func reasonsForCravingMode() -> [UserReason] {
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
        let insights = calculatedInsights
        if let topTrigger = (insights.topSlipTriggers.first ?? insights.topTriggers.first) {
            return matchingTriggerRule(for: topTrigger.name) == nil
        }
        return false
    }

    @discardableResult
    func applyPlanAdjustmentSuggestion() -> Bool {
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

    func deleteCravingEvent(_ id: UUID) {
        do {
            try repository.deleteCravingEvent(id)
            cravingEvents = try repository.recentCravingEvents(limit: 10_000)
            lastSaveStatus = .saved("Craving record deleted.")
            syncScheduledNotifications(showSuccess: false)
        } catch {
            persistenceError = error.localizedDescription
            lastSaveStatus = .failed("Craving record could not be deleted.")
        }
    }

    func deleteDailyCheckIn(_ id: UUID) {
        do {
            try repository.deleteDailyCheckIn(id)
            dailyCheckIns = try repository.recentCheckIns(limit: 10_000)
            lastSaveStatus = .saved("Check-in deleted.")
        } catch {
            persistenceError = error.localizedDescription
            lastSaveStatus = .failed("Check-in could not be deleted.")
        }
    }

    func deleteSlipEvent(_ id: UUID) {
        do {
            try repository.deleteSlipEvent(id)
            slipEvents = try repository.recentSlipEvents(limit: 10_000)
            lastSaveStatus = .saved("Slip record deleted.")
        } catch {
            persistenceError = error.localizedDescription
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
            persistenceError = error.localizedDescription
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
            persistenceError = error.localizedDescription
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

            isOnboardingCompleted = snapshot.appSettings?.onboardingCompleted ?? false
            isOnboardingPresented = !isOnboardingCompleted
            notificationSettings = snapshot.notificationSettings ?? NotificationSettings()

            let loadedPlan = snapshot.quitPlan ?? Self.defaultQuitPlan()
            quitPlan = loadedPlan
            quitMode = loadedPlan.quitMode
            triggerRules = loadedPlan.triggerRules

            supportContacts = snapshot.supportContacts.isEmpty && !isOnboardingCompleted
                ? Self.defaultSupportContacts()
                : snapshot.supportContacts
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

            try persistDefaultsIfNeeded(snapshot: snapshot)
            persistenceError = nil
        } catch {
            persistenceError = error.localizedDescription
            lastSaveStatus = .failed("Local data could not be loaded.")
            applyDefaultState()
        }
    }

    private func applyDefaultState() {
        let plan = Self.defaultQuitPlan()
        quitPlan = plan
        quitMode = plan.quitMode
        triggerRules = plan.triggerRules
        supportContacts = Self.defaultSupportContacts()
        userReasons = Self.defaultUserReasons()
        replacementActivities = Self.defaultReplacementActivities()
        riskySituations = []
        coachChats = Self.defaultCoachChats()
        selectedCoachChatID = coachChats.first?.id
        notificationSettings = NotificationSettings()
        isOnboardingCompleted = false
        isOnboardingPresented = true
        dailyCheckIns = []
        cravingEvents = []
        slipEvents = []
    }

    private func persistDefaultsIfNeeded(snapshot: PersistedTeoPateoSnapshot) throws {
        let shouldSeedDefaultData = Self.shouldSeedDefaultData(appSettings: snapshot.appSettings)
        if shouldSeedDefaultData {
            try repository.saveAppSettings(AppSettings(onboardingCompleted: isOnboardingCompleted))
        }
        if snapshot.notificationSettings == nil {
            try repository.saveNotificationSettings(notificationSettings)
        }
        if snapshot.quitPlan == nil {
            try repository.saveQuitPlan(quitPlan)
        }
        if snapshot.supportContacts.isEmpty && !isOnboardingCompleted {
            try repository.replaceSupportContacts(supportContacts)
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
            persistenceError = error.localizedDescription
            lastSaveStatus = .failed("Quit plan could not be saved.")
        }
    }

    private func persistSupportContacts(successMessage: String) {
        do {
            try repository.replaceSupportContacts(supportContacts)
            persistenceError = nil
            lastSaveStatus = .saved(successMessage)
        } catch {
            persistenceError = error.localizedDescription
            lastSaveStatus = .failed("Support contacts could not be saved.")
        }
    }

    private func persistUserReasons(successMessage: String) {
        do {
            try repository.replaceUserReasons(userReasons)
            persistenceError = nil
            lastSaveStatus = .saved(successMessage)
        } catch {
            persistenceError = error.localizedDescription
            lastSaveStatus = .failed("Reasons could not be saved.")
        }
    }

    private func persistReplacementActivities(successMessage: String) {
        do {
            try repository.replaceReplacementActivities(replacementActivities)
            persistenceError = nil
            lastSaveStatus = .saved(successMessage)
        } catch {
            persistenceError = error.localizedDescription
            lastSaveStatus = .failed("Replacement activities could not be saved.")
        }
    }

    private func persistRiskySituations(successMessage: String) {
        do {
            try repository.replaceRiskySituations(riskySituations)
            persistenceError = nil
            lastSaveStatus = .saved(successMessage)
        } catch {
            persistenceError = error.localizedDescription
            lastSaveStatus = .failed("Risky situations could not be saved.")
        }
    }

    private func persistCoachChats() {
        do {
            try repository.replaceCoachChats(coachChats, selectedChatID: selectedCoachChatID)
            persistenceError = nil
        } catch {
            persistenceError = error.localizedDescription
            lastSaveStatus = .failed("Coach chats could not be saved.")
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
            "Quit mode: \(quitPlan.quitMode)",
            "Quit date: \(Self.coachDateLabel(quitPlan.quitDate))",
            "Primary reason: \(reasonForCravingMode())",
            "Today risk: \(insights.todayRisk.level.rawValue) - \(insights.todayRisk.summary)",
            "Progress: \(insights.smokeFreeSummary), \(insights.cravingsHandled) cravings handled, \(insights.moneySavedSummary) saved."
        ]

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

        if let supportContact = supportContactForCraving() {
            lines.append(
                "Support contact: \(supportContact.name) (\(supportContact.preferredRole.title)); default message: \(supportMessageTemplate(for: supportContact))"
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
        if
            let coachError = error as? CoachClientError,
            let description = coachError.errorDescription
        {
            return description
        }

        return "The coach could not respond. Check your connection and try again."
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
            persistenceError = error.localizedDescription
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
        dismissedAt: Date?
    ) -> CravingEvent {
        let now = now()
        return CravingEvent(
            startedAt: startedAt,
            completedAt: completedAt,
            durationSeconds: max(durationSeconds, 0),
            selectedTriggers: selectedTriggers.sorted(),
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
            persistenceError = nil
            lastSaveStatus = .saved(successMessage)
            syncScheduledNotifications(showSuccess: false)
            return true
        } catch {
            persistenceError = error.localizedDescription
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
        if let interval = calendar.dateInterval(of: .weekOfYear, for: date) {
            return interval.start...interval.end.addingTimeInterval(-1)
        }

        let start = calendar.startOfDay(for: date)
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
        let validTriggers = Set(QuitTriggerCatalog.onboardingTriggers)
        let normalized = triggers
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { validTriggers.contains($0) }

        let uniqueTriggers = normalized.reduce(into: [String]()) { result, trigger in
            if !result.contains(trigger) {
                result.append(trigger)
            }
        }

        return uniqueTriggers.isEmpty
            ? Array(QuitTriggerCatalog.onboardingTriggers.prefix(3))
            : uniqueTriggers
    }

    private static func onboardingReplacementActivities(
        for triggers: [String],
        now: Date
    ) -> [ReplacementActivity] {
        var activities = triggers.map { trigger in
            ReplacementActivity(
                title: onboardingActivityTitle(for: trigger),
                instruction: onboardingActivityInstruction(for: trigger),
                category: onboardingActivityCategory(for: trigger),
                linkedTrigger: trigger,
                createdAt: now,
                updatedAt: now
            )
        }

        activities.append(
            ReplacementActivity(
                title: "Box breathing",
                instruction: "Breathe in 4, hold 4, out 4, hold 4. Repeat five times.",
                category: .breathing,
                createdAt: now,
                updatedAt: now
            )
        )
        activities.append(
            ReplacementActivity(
                title: "Write one sentence",
                instruction: "Name the trigger and the next right action.",
                category: .journaling,
                createdAt: now,
                updatedAt: now
            )
        )

        return activities
    }

    private static func onboardingAction(for trigger: String) -> String {
        switch trigger {
        case "Coffee":
            return "Drink a full glass of water first, then wait 10 minutes before deciding."
        case "After meals":
            return "Brush teeth or chew gum as soon as the meal ends."
        case "Work stress":
            return "Step away from the task, walk for 10 minutes, then choose the next small action."
        case "Driving or commute":
            return "Keep cigarettes out of reach and start a short breathing reset before the trip."
        case "Alcohol":
            return "Keep a drink in hand, avoid stepping outside with smokers, and text support if the urge spikes."
        case "Boredom":
            return "Start a five-minute reset task before making any smoking decision."
        case "Social smoking":
            return "Tell one person you are pausing for 10 minutes and stay away from the smoking spot."
        case "Morning routine":
            return "Change the first 10 minutes: water, shower, or a short walk before coffee."
        case "Evening wind-down":
            return "Put cigarettes out of sight and start the rescue timer before settling in."
        default:
            return "Pause for 10 minutes, name the trigger, and choose one substitute."
        }
    }

    private static func onboardingActivityTitle(for trigger: String) -> String {
        switch trigger {
        case "Coffee":
            return "Cold water first"
        case "After meals":
            return "Brush or chew"
        case "Work stress":
            return "Walk one block"
        case "Driving or commute":
            return "Commute breathing"
        case "Alcohol":
            return "Step back inside"
        case "Boredom":
            return "Five-minute reset"
        case "Social smoking":
            return "Text before stepping out"
        case "Morning routine":
            return "Change the first 10"
        case "Evening wind-down":
            return "Hands-busy reset"
        default:
            return "10-minute substitute"
        }
    }

    private static func onboardingActivityInstruction(for trigger: String) -> String {
        switch trigger {
        case "Coffee":
            return "Finish one full glass of cold water before deciding anything."
        case "After meals":
            return "Brush teeth or chew gum until the urge drops."
        case "Work stress":
            return "Walk away from the task until the timer drops below 6:00."
        case "Driving or commute":
            return "Take five slow breaths before starting the car or leaving transit."
        case "Alcohol":
            return "Move away from the smoking cue and text support before going outside."
        case "Boredom":
            return "Tidy one small area or start one quick errand until the urge changes."
        case "Social smoking":
            return "Send the craving message before following anyone to smoke."
        case "Morning routine":
            return "Drink water and move for two minutes before coffee or phone checks."
        case "Evening wind-down":
            return "Hold a cold drink, stretch, or keep both hands busy until the timer ends."
        default:
            return "Choose one substitute and stay with it until the timer ends."
        }
    }

    private static func onboardingActivityCategory(for trigger: String) -> ReplacementActivityCategory {
        switch trigger {
        case "Work stress", "Morning routine":
            return .movement
        case "Driving or commute":
            return .breathing
        case "Coffee", "After meals", "Evening wind-down":
            return .sensory
        case "Social smoking", "Alcohol":
            return .support
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

    private static func defaultSupportContacts() -> [SupportContact] {
        [
            SupportContact(
                name: "Maya",
                detail: "Craving alert and evening check-in",
                preferredRole: .cravingAlert,
                defaultMessage: "I am having a craving. Can you stay with me for 10 minutes?"
            ),
            SupportContact(
                name: "1-800-QUIT-NOW",
                detail: "US quitline support",
                phoneNumber: "18007848669",
                preferredRole: .quitline
            )
        ]
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

private extension Array {
    mutating func move(from sourceIndex: Int, to destinationIndex: Int) {
        let element = remove(at: sourceIndex)
        insert(element, at: destinationIndex)
    }
}
