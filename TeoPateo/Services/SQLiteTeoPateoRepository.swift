import Foundation
import GRDB

protocol TeoPateoRepository {
    func schemaVersion() throws -> Int
    func tableNames() throws -> Set<String>
    func loadSnapshot() throws -> PersistedTeoPateoSnapshot

    func fetchAppSettings() throws -> AppSettings?
    func saveAppSettings(_ settings: AppSettings) throws

    func fetchNotificationSettings() throws -> NotificationSettings?
    func saveNotificationSettings(_ settings: NotificationSettings) throws

    func fetchUserProfile() throws -> UserProfile?
    func saveUserProfile(_ profile: UserProfile) throws

    func fetchQuitReadiness() throws -> QuitReadiness?
    func saveQuitReadiness(_ readiness: QuitReadiness) throws

    func fetchSmokingBackground() throws -> SmokingBackground?
    func saveSmokingBackground(_ background: SmokingBackground) throws

    func fetchSavingsGoal() throws -> SavingsGoal?
    func saveSavingsGoal(_ goal: SavingsGoal) throws

    func fetchQuitPlan() throws -> QuitPlan?
    func saveQuitPlan(_ plan: QuitPlan) throws

    func saveDailyCheckIn(_ checkIn: DailyCheckIn) throws
    func recentCheckIns(limit: Int) throws -> [DailyCheckIn]
    func deleteDailyCheckIn(_ id: UUID) throws

    func saveCravingEvent(_ event: CravingEvent) throws
    func saveCravingWithSlip(craving: CravingEvent, slip: SlipEvent) throws
    func recentCravingEvents(limit: Int) throws -> [CravingEvent]
    func deleteCravingEvent(_ id: UUID) throws

    func saveSlipEvent(_ event: SlipEvent) throws
    func recentSlipEvents(limit: Int) throws -> [SlipEvent]
    func deleteSlipEvent(_ id: UUID) throws

    func replaceReplacementActivities(_ activities: [ReplacementActivity]) throws
    func fetchReplacementActivities() throws -> [ReplacementActivity]

    func replaceRiskySituations(_ situations: [RiskySituation]) throws
    func fetchRiskySituations() throws -> [RiskySituation]

    func replaceSupportContacts(_ contacts: [SupportContact]) throws
    func fetchSupportContacts() throws -> [SupportContact]

    func replaceUserReasons(_ reasons: [UserReason]) throws
    func fetchUserReasons() throws -> [UserReason]

    func replaceCoachChats(_ chats: [CoachChat], selectedChatID: UUID?) throws
    func fetchCoachChats() throws -> [CoachChat]
    func fetchSelectedCoachChatID() throws -> UUID?
}

enum TeoPateoRepositoryError: Error, LocalizedError {
    case invalidUUID(String)

    var errorDescription: String? {
        switch self {
        case .invalidUUID(let value):
            return "Invalid UUID stored in database: \(value)"
        }
    }
}

final class SQLiteTeoPateoRepository: TeoPateoRepository {
    private let dbQueue: DatabaseQueue

    init(databaseURL: URL) throws {
        try FileManager.default.createDirectory(
            at: databaseURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        var configuration = Configuration()
        configuration.foreignKeysEnabled = true
        dbQueue = try DatabaseQueue(path: databaseURL.path, configuration: configuration)
        try migrator.migrate(dbQueue)
    }

    static func live() throws -> SQLiteTeoPateoRepository {
        let baseURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
            .appendingPathComponent("TeoPateo", isDirectory: true)
        return try SQLiteTeoPateoRepository(
            databaseURL: baseURL.appendingPathComponent("teopateo.sqlite")
        )
    }

    func schemaVersion() throws -> Int {
        try dbQueue.read { db in
            try Int.fetchOne(db, sql: "PRAGMA user_version;") ?? 0
        }
    }

    func tableNames() throws -> Set<String> {
        try dbQueue.read { db in
            let names = try String.fetchAll(
                db,
                sql: """
                SELECT name
                FROM sqlite_master
                WHERE type = 'table'
                ORDER BY name;
                """
            )
            return Set(names)
        }
    }

    func loadSnapshot() throws -> PersistedTeoPateoSnapshot {
        PersistedTeoPateoSnapshot(
            appSettings: try fetchAppSettings(),
            notificationSettings: try fetchNotificationSettings(),
            userProfile: try fetchUserProfile(),
            quitReadiness: try fetchQuitReadiness(),
            smokingBackground: try fetchSmokingBackground(),
            savingsGoal: try fetchSavingsGoal(),
            quitPlan: try fetchQuitPlan(),
            dailyCheckIns: try recentCheckIns(limit: 10_000),
            cravingEvents: try recentCravingEvents(limit: 10_000),
            slipEvents: try recentSlipEvents(limit: 10_000),
            replacementActivities: try fetchReplacementActivities(),
            riskySituations: try fetchRiskySituations(),
            supportContacts: try fetchSupportContacts(),
            userReasons: try fetchUserReasons(),
            coachChats: try fetchCoachChats(),
            selectedCoachChatID: try fetchSelectedCoachChatID()
        )
    }

    func fetchAppSettings() throws -> AppSettings? {
        try dbQueue.read { db in
            let row = try Row.fetchOne(
                db,
                sql: """
                SELECT onboarding_completed, updated_at
                FROM app_settings
                WHERE id = 0;
                """
            )

            guard let row else {
                return nil
            }

            return AppSettings(
                onboardingCompleted: bool(row, "onboarding_completed"),
                updatedAt: date(row, "updated_at")
            )
        }
    }

    func saveAppSettings(_ settings: AppSettings) throws {
        try dbQueue.write { db in
            try db.execute(literal: """
                INSERT INTO app_settings (
                    id, onboarding_completed, updated_at
                )
                VALUES (
                    0,
                    \(settings.onboardingCompleted ? 1 : 0),
                    \(settings.updatedAt.timeIntervalSince1970)
                )
                ON CONFLICT(id) DO UPDATE SET
                    onboarding_completed = excluded.onboarding_completed,
                    updated_at = excluded.updated_at;
                """)
        }
    }

    func fetchNotificationSettings() throws -> NotificationSettings? {
        try dbQueue.read { db in
            let row = try Row.fetchOne(
                db,
                sql: """
                SELECT morning_plan_enabled, risky_window_enabled,
                       post_meal_enabled, evening_check_in_enabled,
                       medication_enabled, morning_plan_hour,
                       morning_plan_minute, post_meal_hour,
                       post_meal_minute, evening_check_in_hour,
                       evening_check_in_minute, medication_hour,
                       medication_minute, updated_at
                FROM notification_settings
                WHERE id = 0;
                """
            )

            guard let row else {
                return nil
            }

            return NotificationSettings(
                morningPlanEnabled: bool(row, "morning_plan_enabled"),
                riskyWindowEnabled: bool(row, "risky_window_enabled"),
                postMealEnabled: bool(row, "post_meal_enabled"),
                eveningCheckInEnabled: bool(row, "evening_check_in_enabled"),
                medicationEnabled: bool(row, "medication_enabled"),
                morningPlanTime: ReminderTime(
                    hour: row["morning_plan_hour"],
                    minute: row["morning_plan_minute"]
                ),
                postMealTime: ReminderTime(
                    hour: row["post_meal_hour"],
                    minute: row["post_meal_minute"]
                ),
                eveningCheckInTime: ReminderTime(
                    hour: row["evening_check_in_hour"],
                    minute: row["evening_check_in_minute"]
                ),
                medicationTime: ReminderTime(
                    hour: row["medication_hour"],
                    minute: row["medication_minute"]
                ),
                updatedAt: date(row, "updated_at")
            )
        }
    }

    func saveNotificationSettings(_ settings: NotificationSettings) throws {
        try dbQueue.write { db in
            try db.execute(literal: """
                INSERT INTO notification_settings (
                    id, morning_plan_enabled, risky_window_enabled,
                    post_meal_enabled, evening_check_in_enabled,
                    medication_enabled, morning_plan_hour, morning_plan_minute,
                    post_meal_hour, post_meal_minute, evening_check_in_hour,
                    evening_check_in_minute, medication_hour, medication_minute,
                    updated_at
                )
                VALUES (
                    0,
                    \(settings.morningPlanEnabled ? 1 : 0),
                    \(settings.riskyWindowEnabled ? 1 : 0),
                    \(settings.postMealEnabled ? 1 : 0),
                    \(settings.eveningCheckInEnabled ? 1 : 0),
                    \(settings.medicationEnabled ? 1 : 0),
                    \(settings.morningPlanTime.hour),
                    \(settings.morningPlanTime.minute),
                    \(settings.postMealTime.hour),
                    \(settings.postMealTime.minute),
                    \(settings.eveningCheckInTime.hour),
                    \(settings.eveningCheckInTime.minute),
                    \(settings.medicationTime.hour),
                    \(settings.medicationTime.minute),
                    \(settings.updatedAt.timeIntervalSince1970)
                )
                ON CONFLICT(id) DO UPDATE SET
                    morning_plan_enabled = excluded.morning_plan_enabled,
                    risky_window_enabled = excluded.risky_window_enabled,
                    post_meal_enabled = excluded.post_meal_enabled,
                    evening_check_in_enabled = excluded.evening_check_in_enabled,
                    medication_enabled = excluded.medication_enabled,
                    morning_plan_hour = excluded.morning_plan_hour,
                    morning_plan_minute = excluded.morning_plan_minute,
                    post_meal_hour = excluded.post_meal_hour,
                    post_meal_minute = excluded.post_meal_minute,
                    evening_check_in_hour = excluded.evening_check_in_hour,
                    evening_check_in_minute = excluded.evening_check_in_minute,
                    medication_hour = excluded.medication_hour,
                    medication_minute = excluded.medication_minute,
                    updated_at = excluded.updated_at;
                """)
        }
    }

    func fetchUserProfile() throws -> UserProfile? {
        try dbQueue.read { db in
            let row = try Row.fetchOne(
                db,
                sql: """
                SELECT nickname, age, created_at, updated_at
                FROM user_profile
                WHERE id = 0;
                """
            )

            guard let row else { return nil }
            return UserProfile(
                nickname: row["nickname"],
                age: row["age"],
                createdAt: date(row, "created_at"),
                updatedAt: date(row, "updated_at")
            )
        }
    }

    func saveUserProfile(_ profile: UserProfile) throws {
        try dbQueue.write { db in
            try db.execute(literal: """
                INSERT INTO user_profile (
                    id, nickname, age, created_at, updated_at
                )
                VALUES (
                    0,
                    \(profile.nickname),
                    \(profile.age),
                    \(profile.createdAt.timeIntervalSince1970),
                    \(profile.updatedAt.timeIntervalSince1970)
                )
                ON CONFLICT(id) DO UPDATE SET
                    nickname = excluded.nickname,
                    age = excluded.age,
                    updated_at = excluded.updated_at;
                """)
        }
    }

    func fetchQuitReadiness() throws -> QuitReadiness? {
        try dbQueue.read { db in
            let row = try Row.fetchOne(
                db,
                sql: """
                SELECT status, confidence, opened_app_reason, created_at, updated_at
                FROM quit_readiness
                WHERE id = 0;
                """
            )

            guard let row else { return nil }
            return QuitReadiness(
                status: QuitStatus(rawValue: row["status"]) ?? .readyToQuit,
                confidence: row["confidence"],
                openedAppReason: row["opened_app_reason"],
                createdAt: date(row, "created_at"),
                updatedAt: date(row, "updated_at")
            )
        }
    }

    func saveQuitReadiness(_ readiness: QuitReadiness) throws {
        try dbQueue.write { db in
            try db.execute(literal: """
                INSERT INTO quit_readiness (
                    id, status, confidence, opened_app_reason, created_at, updated_at
                )
                VALUES (
                    0,
                    \(readiness.status.rawValue),
                    \(readiness.confidence),
                    \(readiness.openedAppReason),
                    \(readiness.createdAt.timeIntervalSince1970),
                    \(readiness.updatedAt.timeIntervalSince1970)
                )
                ON CONFLICT(id) DO UPDATE SET
                    status = excluded.status,
                    confidence = excluded.confidence,
                    opened_app_reason = excluded.opened_app_reason,
                    updated_at = excluded.updated_at;
                """)
        }
    }

    func fetchSmokingBackground() throws -> SmokingBackground? {
        try dbQueue.read { db in
            let row = try Row.fetchOne(
                db,
                sql: """
                SELECT age_started_smoking, years_smoking, first_cigarette_timing,
                       previous_quit_attempt_count, longest_quit_attempt,
                       main_challenge, created_at, updated_at
                FROM smoking_background
                WHERE id = 0;
                """
            )

            guard let row else { return nil }
            return SmokingBackground(
                ageStartedSmoking: row["age_started_smoking"],
                yearsSmoking: row["years_smoking"],
                firstCigaretteTiming: FirstCigaretteTiming(rawValue: row["first_cigarette_timing"]) ?? .withinThirtyMinutes,
                previousQuitAttemptCount: PreviousQuitAttemptCount(rawValue: row["previous_quit_attempt_count"]) ?? .none,
                longestQuitAttempt: LongestQuitAttempt(rawValue: row["longest_quit_attempt"]) ?? .lessThanDay,
                mainChallenge: SmokingChallenge(rawValue: row["main_challenge"]) ?? .cravings,
                createdAt: date(row, "created_at"),
                updatedAt: date(row, "updated_at")
            )
        }
    }

    func saveSmokingBackground(_ background: SmokingBackground) throws {
        try dbQueue.write { db in
            try db.execute(literal: """
                INSERT INTO smoking_background (
                    id, age_started_smoking, years_smoking, first_cigarette_timing,
                    previous_quit_attempt_count, longest_quit_attempt,
                    main_challenge, created_at, updated_at
                )
                VALUES (
                    0,
                    \(background.ageStartedSmoking),
                    \(background.yearsSmoking),
                    \(background.firstCigaretteTiming.rawValue),
                    \(background.previousQuitAttemptCount.rawValue),
                    \(background.longestQuitAttempt.rawValue),
                    \(background.mainChallenge.rawValue),
                    \(background.createdAt.timeIntervalSince1970),
                    \(background.updatedAt.timeIntervalSince1970)
                )
                ON CONFLICT(id) DO UPDATE SET
                    age_started_smoking = excluded.age_started_smoking,
                    years_smoking = excluded.years_smoking,
                    first_cigarette_timing = excluded.first_cigarette_timing,
                    previous_quit_attempt_count = excluded.previous_quit_attempt_count,
                    longest_quit_attempt = excluded.longest_quit_attempt,
                    main_challenge = excluded.main_challenge,
                    updated_at = excluded.updated_at;
                """)
        }
    }

    func fetchSavingsGoal() throws -> SavingsGoal? {
        try dbQueue.read { db in
            let row = try Row.fetchOne(
                db,
                sql: """
                SELECT title, custom_text, created_at, updated_at
                FROM savings_goal
                WHERE id = 0;
                """
            )

            guard let row else { return nil }
            return SavingsGoal(
                title: row["title"],
                customText: row["custom_text"],
                createdAt: date(row, "created_at"),
                updatedAt: date(row, "updated_at")
            )
        }
    }

    func saveSavingsGoal(_ goal: SavingsGoal) throws {
        try dbQueue.write { db in
            try db.execute(literal: """
                INSERT INTO savings_goal (
                    id, title, custom_text, created_at, updated_at
                )
                VALUES (
                    0,
                    \(goal.title),
                    \(goal.customText),
                    \(goal.createdAt.timeIntervalSince1970),
                    \(goal.updatedAt.timeIntervalSince1970)
                )
                ON CONFLICT(id) DO UPDATE SET
                    title = excluded.title,
                    custom_text = excluded.custom_text,
                    updated_at = excluded.updated_at;
                """)
        }
    }

    func fetchQuitPlan() throws -> QuitPlan? {
        try dbQueue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT id, quit_date, quit_mode, medication_note,
                       quit_status, readiness_stage, generated_daily_focus,
                       generated_plan_summary, plan_summary_json,
                       first_week_goal, next_best_action, strategy_plan_json,
                       generated_trigger_rules_json, craving_rescue_plan_json,
                       slip_recovery_plan_json, daily_focus_plan_json,
                       savings_plan_json, pending_plan_suggestions_json,
                       baseline_cigarettes_per_day, cost_per_pack, cigarettes_per_pack,
                       taper_target_cigarettes_per_day, taper_reduction_step,
                       taper_reduction_interval_days, attempt_started_at,
                       created_at, updated_at
                FROM quit_plans
                ORDER BY updated_at DESC
                LIMIT 1;
                """
            )

            guard let row = rows.first else {
                return nil
            }

            let id = try uuid(row, "id")
            return QuitPlan(
                id: id,
                quitDate: date(row, "quit_date"),
                quitMode: row["quit_mode"],
                quitStatus: QuitStatus(rawValue: row["quit_status"]) ?? .readyToQuit,
                readinessStage: row["readiness_stage"],
                planSummary: decodeJSON(
                    PlanSummary.self,
                    from: row,
                    column: "plan_summary_json",
                    fallback: PlanSummary(
                        summary: row["generated_plan_summary"],
                        quitDate: date(row, "quit_date"),
                        quitStatus: QuitStatus(rawValue: row["quit_status"]) ?? .readyToQuit,
                        readinessStage: row["readiness_stage"]
                    )
                ),
                firstWeekGoal: row["first_week_goal"],
                nextBestAction: row["next_best_action"],
                generatedDailyFocus: row["generated_daily_focus"],
                generatedPlanSummary: row["generated_plan_summary"],
                strategyPlan: decodeJSON(
                    QuitStrategyPlan.self,
                    from: row,
                    column: "strategy_plan_json",
                    fallback: QuitStrategyPlan(
                        strategyType: row["quit_mode"] == "Cold turkey" ? .coldTurkey : .taper,
                        quitDate: date(row, "quit_date"),
                        taperTarget: row["taper_target_cigarettes_per_day"],
                        taperStep: row["taper_reduction_step"],
                        taperIntervalDays: row["taper_reduction_interval_days"]
                    )
                ),
                generatedTriggerRules: decodeJSON([GeneratedTriggerRule].self, from: row, column: "generated_trigger_rules_json", fallback: []),
                cravingRescuePlan: decodeJSON(CravingRescuePlan.self, from: row, column: "craving_rescue_plan_json", fallback: CravingRescuePlan()),
                slipRecoveryPlan: decodeJSON(SlipRecoveryPlan.self, from: row, column: "slip_recovery_plan_json", fallback: SlipRecoveryPlan()),
                dailyFocusPlan: decodeJSON([DailyFocusPlan].self, from: row, column: "daily_focus_plan_json", fallback: []),
                savingsPlan: decodeJSON(SavingsPlan.self, from: row, column: "savings_plan_json", fallback: SavingsPlan()),
                pendingPlanSuggestions: decodeJSON([PlanAdjustmentSuggestion].self, from: row, column: "pending_plan_suggestions_json", fallback: []),
                triggerRules: try fetchTriggerRules(db: db, quitPlanID: id),
                medicationNote: row["medication_note"],
                baselineCigarettesPerDay: row["baseline_cigarettes_per_day"],
                costPerPack: row["cost_per_pack"],
                cigarettesPerPack: row["cigarettes_per_pack"],
                taperTargetCigarettesPerDay: row["taper_target_cigarettes_per_day"],
                taperReductionStep: row["taper_reduction_step"],
                taperReductionIntervalDays: row["taper_reduction_interval_days"],
                attemptStartedAt: date(row, "attempt_started_at"),
                createdAt: date(row, "created_at"),
                updatedAt: date(row, "updated_at")
            )
        }
    }

    func saveQuitPlan(_ plan: QuitPlan) throws {
        let planSummaryJSON = try encodeJSON(plan.planSummary)
        let strategyPlanJSON = try encodeJSON(plan.strategyPlan)
        let generatedTriggerRulesJSON = try encodeJSON(plan.generatedTriggerRules)
        let cravingRescuePlanJSON = try encodeJSON(plan.cravingRescuePlan)
        let slipRecoveryPlanJSON = try encodeJSON(plan.slipRecoveryPlan)
        let dailyFocusPlanJSON = try encodeJSON(plan.dailyFocusPlan)
        let savingsPlanJSON = try encodeJSON(plan.savingsPlan)
        let pendingPlanSuggestionsJSON = try encodeJSON(plan.pendingPlanSuggestions)

        try dbQueue.write { db in
            try db.execute(literal: """
                INSERT INTO quit_plans (
                    id, quit_date, quit_mode, medication_note,
                    quit_status, readiness_stage, generated_daily_focus,
                    generated_plan_summary, plan_summary_json,
                    first_week_goal, next_best_action, strategy_plan_json,
                    generated_trigger_rules_json, craving_rescue_plan_json,
                    slip_recovery_plan_json, daily_focus_plan_json,
                    savings_plan_json, pending_plan_suggestions_json,
                    baseline_cigarettes_per_day, cost_per_pack, cigarettes_per_pack,
                    taper_target_cigarettes_per_day, taper_reduction_step,
                    taper_reduction_interval_days, attempt_started_at,
                    created_at, updated_at
                )
                VALUES (
                    \(plan.id.uuidString),
                    \(plan.quitDate.timeIntervalSince1970),
                    \(plan.quitMode),
                    \(plan.medicationNote),
                    \(plan.quitStatus.rawValue),
                    \(plan.readinessStage),
                    \(plan.generatedDailyFocus),
                    \(plan.generatedPlanSummary),
                    \(planSummaryJSON),
                    \(plan.firstWeekGoal),
                    \(plan.nextBestAction),
                    \(strategyPlanJSON),
                    \(generatedTriggerRulesJSON),
                    \(cravingRescuePlanJSON),
                    \(slipRecoveryPlanJSON),
                    \(dailyFocusPlanJSON),
                    \(savingsPlanJSON),
                    \(pendingPlanSuggestionsJSON),
                    \(plan.baselineCigarettesPerDay),
                    \(plan.costPerPack),
                    \(plan.cigarettesPerPack),
                    \(plan.taperTargetCigarettesPerDay),
                    \(plan.taperReductionStep),
                    \(plan.taperReductionIntervalDays),
                    \(plan.attemptStartedAt.timeIntervalSince1970),
                    \(plan.createdAt.timeIntervalSince1970),
                    \(plan.updatedAt.timeIntervalSince1970)
                )
                ON CONFLICT(id) DO UPDATE SET
                    quit_date = excluded.quit_date,
                    quit_mode = excluded.quit_mode,
                    medication_note = excluded.medication_note,
                    quit_status = excluded.quit_status,
                    readiness_stage = excluded.readiness_stage,
                    generated_daily_focus = excluded.generated_daily_focus,
                    generated_plan_summary = excluded.generated_plan_summary,
                    plan_summary_json = excluded.plan_summary_json,
                    first_week_goal = excluded.first_week_goal,
                    next_best_action = excluded.next_best_action,
                    strategy_plan_json = excluded.strategy_plan_json,
                    generated_trigger_rules_json = excluded.generated_trigger_rules_json,
                    craving_rescue_plan_json = excluded.craving_rescue_plan_json,
                    slip_recovery_plan_json = excluded.slip_recovery_plan_json,
                    daily_focus_plan_json = excluded.daily_focus_plan_json,
                    savings_plan_json = excluded.savings_plan_json,
                    pending_plan_suggestions_json = excluded.pending_plan_suggestions_json,
                    baseline_cigarettes_per_day = excluded.baseline_cigarettes_per_day,
                    cost_per_pack = excluded.cost_per_pack,
                    cigarettes_per_pack = excluded.cigarettes_per_pack,
                    taper_target_cigarettes_per_day = excluded.taper_target_cigarettes_per_day,
                    taper_reduction_step = excluded.taper_reduction_step,
                    taper_reduction_interval_days = excluded.taper_reduction_interval_days,
                    attempt_started_at = excluded.attempt_started_at,
                    updated_at = excluded.updated_at;
                """)

            try db.execute(
                sql: "DELETE FROM trigger_rules WHERE quit_plan_id = ?;",
                arguments: [plan.id.uuidString]
            )

            for (position, rule) in plan.triggerRules.enumerated() {
                let supportContactID = rule.supportContactID?.uuidString
                try db.execute(literal: """
                    INSERT INTO trigger_rules (
                        id, quit_plan_id, trigger, action, is_enabled,
                        support_contact_id, position
                    )
                    VALUES (
                        \(rule.id.uuidString),
                        \(plan.id.uuidString),
                        \(rule.trigger),
                        \(rule.action),
                        \(rule.isEnabled ? 1 : 0),
                        \(supportContactID),
                        \(position)
                    );
                    """)
            }
        }
    }

    func saveDailyCheckIn(_ checkIn: DailyCheckIn) throws {
        let smokedToday = checkIn.smokedToday.map { $0 ? 1 : 0 }
        let stayedWithinTaperTarget = checkIn.stayedWithinTaperTarget.map { $0 ? 1 : 0 }
        let emptyFocusNote = ""
        try dbQueue.write { db in
            try db.execute(literal: """
                INSERT INTO daily_check_ins (
                    id, date, mood, stress, confidence, smoked_today, cigarettes_smoked,
                    taper_target_cigarettes, stayed_within_taper_target,
                    focus_note, slip_note, created_at, updated_at
                )
                VALUES (
                    \(checkIn.id.uuidString),
                    \(checkIn.date.timeIntervalSince1970),
                    \(checkIn.mood),
                    \(checkIn.stress),
                    \(checkIn.confidence),
                    \(smokedToday),
                    \(checkIn.cigarettesSmoked),
                    \(checkIn.taperTargetCigarettes),
                    \(stayedWithinTaperTarget),
                    \(emptyFocusNote),
                    \(checkIn.slipNote),
                    \(checkIn.createdAt.timeIntervalSince1970),
                    \(checkIn.updatedAt.timeIntervalSince1970)
                )
                ON CONFLICT(id) DO UPDATE SET
                    date = excluded.date,
                    mood = excluded.mood,
                    stress = excluded.stress,
                    confidence = excluded.confidence,
                    smoked_today = excluded.smoked_today,
                    cigarettes_smoked = excluded.cigarettes_smoked,
                    taper_target_cigarettes = excluded.taper_target_cigarettes,
                    stayed_within_taper_target = excluded.stayed_within_taper_target,
                    focus_note = excluded.focus_note,
                    slip_note = excluded.slip_note,
                    updated_at = excluded.updated_at;
                """)
        }
    }

    func recentCheckIns(limit: Int) throws -> [DailyCheckIn] {
        try dbQueue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT id, date, mood, stress, confidence, smoked_today, cigarettes_smoked,
                       taper_target_cigarettes, stayed_within_taper_target,
                       slip_note, created_at, updated_at
                FROM daily_check_ins
                ORDER BY date DESC, created_at DESC
                LIMIT ?;
                """,
                arguments: [limit]
            )

            return try rows.map { row in
                DailyCheckIn(
                    id: try uuid(row, "id"),
                    date: date(row, "date"),
                    mood: row["mood"],
                    stress: row["stress"],
                    confidence: row["confidence"],
                    smokedToday: optionalBool(row, "smoked_today"),
                    cigarettesSmoked: row["cigarettes_smoked"],
                    taperTargetCigarettes: row["taper_target_cigarettes"],
                    stayedWithinTaperTarget: optionalBool(row, "stayed_within_taper_target"),
                    slipNote: row["slip_note"],
                    createdAt: date(row, "created_at"),
                    updatedAt: date(row, "updated_at")
                )
            }
        }
    }

    func deleteDailyCheckIn(_ id: UUID) throws {
        try dbQueue.write { db in
            try db.execute(sql: "DELETE FROM daily_check_ins WHERE id = ?;", arguments: [id.uuidString])
        }
    }

    func saveCravingEvent(_ event: CravingEvent) throws {
        try dbQueue.write { db in
            try writeCravingEvent(event, in: db)
        }
    }

    func saveCravingWithSlip(craving: CravingEvent, slip: SlipEvent) throws {
        try dbQueue.write { db in
            try writeCravingEvent(craving, in: db)
            try writeSlipEvent(slip, in: db)
        }
    }

    private func writeCravingEvent(_ event: CravingEvent, in db: Database) throws {
        let completedAt = event.completedAt.map(\.timeIntervalSince1970)
        let dismissedAt = event.dismissedAt.map(\.timeIntervalSince1970)
        let helpedActivityID = event.helpedActivityID?.uuidString
        let supportContactID = event.supportContactID?.uuidString

        try db.execute(literal: """
            INSERT INTO craving_events (
                id, started_at, completed_at, duration_seconds,
                completed_without_smoking, outcome, initial_intensity,
                final_intensity, helped_activity_id, support_contact_id,
                reflection_note, dismissed_at, created_at, updated_at
            )
            VALUES (
                \(event.id.uuidString),
                \(event.startedAt.timeIntervalSince1970),
                \(completedAt),
                \(event.durationSeconds),
                \(event.completedWithoutSmoking ? 1 : 0),
                \(event.outcome.rawValue),
                \(event.initialIntensity),
                \(event.finalIntensity),
                \(helpedActivityID),
                \(supportContactID),
                \(event.reflectionNote),
                \(dismissedAt),
                \(event.createdAt.timeIntervalSince1970),
                \(event.updatedAt.timeIntervalSince1970)
            )
            ON CONFLICT(id) DO UPDATE SET
                started_at = excluded.started_at,
                completed_at = excluded.completed_at,
                duration_seconds = excluded.duration_seconds,
                completed_without_smoking = excluded.completed_without_smoking,
                outcome = excluded.outcome,
                initial_intensity = excluded.initial_intensity,
                final_intensity = excluded.final_intensity,
                helped_activity_id = excluded.helped_activity_id,
                support_contact_id = excluded.support_contact_id,
                reflection_note = excluded.reflection_note,
                dismissed_at = excluded.dismissed_at,
                updated_at = excluded.updated_at;
            """)

        try db.execute(
            sql: "DELETE FROM craving_event_triggers WHERE craving_event_id = ?;",
            arguments: [event.id.uuidString]
        )

        for (position, trigger) in event.selectedTriggers.enumerated() {
            try db.execute(literal: """
                INSERT INTO craving_event_triggers (
                    craving_event_id, trigger, position
                )
                VALUES (
                    \(event.id.uuidString),
                    \(trigger),
                    \(position)
                );
                """)
        }
    }

    func recentCravingEvents(limit: Int) throws -> [CravingEvent] {
        try dbQueue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT id, started_at, completed_at, duration_seconds,
                       completed_without_smoking, outcome, initial_intensity,
                       final_intensity, helped_activity_id, support_contact_id,
                       reflection_note, dismissed_at, created_at, updated_at
                FROM craving_events
                ORDER BY started_at DESC, created_at DESC
                LIMIT ?;
                """,
                arguments: [limit]
            )

            return try rows.map { row in
                let id = try uuid(row, "id")
                return CravingEvent(
                    id: id,
                    startedAt: date(row, "started_at"),
                    completedAt: optionalDate(row, "completed_at"),
                    durationSeconds: row["duration_seconds"],
                    selectedTriggers: try fetchCravingTriggers(db: db, eventID: id),
                    outcome: CravingOutcome(rawValue: row["outcome"]) ?? (bool(row, "completed_without_smoking") ? .completedWithoutSmoking : .smokedAfterCraving),
                    initialIntensity: row["initial_intensity"],
                    finalIntensity: row["final_intensity"],
                    helpedActivityID: try optionalUUID(row, "helped_activity_id"),
                    supportContactID: try optionalUUID(row, "support_contact_id"),
                    reflectionNote: row["reflection_note"],
                    dismissedAt: optionalDate(row, "dismissed_at"),
                    createdAt: date(row, "created_at"),
                    updatedAt: date(row, "updated_at")
                )
            }
        }
    }

    func deleteCravingEvent(_ id: UUID) throws {
        try dbQueue.write { db in
            try db.execute(sql: "DELETE FROM craving_events WHERE id = ?;", arguments: [id.uuidString])
        }
    }

    func saveSlipEvent(_ event: SlipEvent) throws {
        try dbQueue.write { db in
            try writeSlipEvent(event, in: db)
        }
    }

    private func writeSlipEvent(_ event: SlipEvent, in db: Database) throws {
        try db.execute(literal: """
            INSERT INTO slip_events (
                id, occurred_at, cigarettes_smoked, mood, stress,
                context, note, recovery_action, created_at, updated_at
            )
            VALUES (
                \(event.id.uuidString),
                \(event.occurredAt.timeIntervalSince1970),
                \(event.cigarettesSmoked),
                \(event.mood),
                \(event.stress),
                \(event.context),
                \(event.note),
                \(event.recoveryAction),
                \(event.createdAt.timeIntervalSince1970),
                \(event.updatedAt.timeIntervalSince1970)
            )
            ON CONFLICT(id) DO UPDATE SET
                occurred_at = excluded.occurred_at,
                cigarettes_smoked = excluded.cigarettes_smoked,
                mood = excluded.mood,
                stress = excluded.stress,
                context = excluded.context,
                note = excluded.note,
                recovery_action = excluded.recovery_action,
                updated_at = excluded.updated_at;
            """)

        try db.execute(
            sql: "DELETE FROM slip_event_triggers WHERE slip_event_id = ?;",
            arguments: [event.id.uuidString]
        )

        for (position, trigger) in event.selectedTriggers.enumerated() {
            try db.execute(literal: """
                INSERT INTO slip_event_triggers (
                    slip_event_id, trigger, position
                )
                VALUES (
                    \(event.id.uuidString),
                    \(trigger),
                    \(position)
                );
                """)
        }
    }

    func recentSlipEvents(limit: Int) throws -> [SlipEvent] {
        try dbQueue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT id, occurred_at, cigarettes_smoked, mood, stress,
                       context, note, recovery_action, created_at, updated_at
                FROM slip_events
                ORDER BY occurred_at DESC, created_at DESC
                LIMIT ?;
                """,
                arguments: [limit]
            )

            return try rows.map { row in
                let id = try uuid(row, "id")
                return SlipEvent(
                    id: id,
                    occurredAt: date(row, "occurred_at"),
                    cigarettesSmoked: row["cigarettes_smoked"],
                    selectedTriggers: try fetchSlipTriggers(db: db, eventID: id),
                    mood: row["mood"],
                    stress: row["stress"],
                    context: row["context"],
                    note: row["note"],
                    recoveryAction: row["recovery_action"],
                    createdAt: date(row, "created_at"),
                    updatedAt: date(row, "updated_at")
                )
            }
        }
    }

    func deleteSlipEvent(_ id: UUID) throws {
        try dbQueue.write { db in
            try db.execute(sql: "DELETE FROM slip_events WHERE id = ?;", arguments: [id.uuidString])
        }
    }

    func replaceReplacementActivities(_ activities: [ReplacementActivity]) throws {
        try dbQueue.write { db in
            try db.execute(sql: "DELETE FROM replacement_activities;")
            for (position, activity) in activities.enumerated() {
                try db.execute(literal: """
                    INSERT INTO replacement_activities (
                        id, title, instruction, category, duration_seconds,
                        linked_trigger, is_enabled, position, created_at, updated_at
                    )
                    VALUES (
                        \(activity.id.uuidString),
                        \(activity.title),
                        \(activity.instruction),
                        \(activity.category.rawValue),
                        \(activity.durationSeconds),
                        \(activity.linkedTrigger),
                        \(activity.isEnabled ? 1 : 0),
                        \(position),
                        \(activity.createdAt.timeIntervalSince1970),
                        \(activity.updatedAt.timeIntervalSince1970)
                    );
                    """)
            }
        }
    }

    func fetchReplacementActivities() throws -> [ReplacementActivity] {
        try dbQueue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT id, title, instruction, category, duration_seconds,
                       linked_trigger, is_enabled, created_at, updated_at
                FROM replacement_activities
                ORDER BY position ASC, created_at ASC;
                """
            )

            return try rows.map { row in
                ReplacementActivity(
                    id: try uuid(row, "id"),
                    title: row["title"],
                    instruction: row["instruction"],
                    category: ReplacementActivityCategory(rawValue: row["category"]) ?? .distraction,
                    durationSeconds: row["duration_seconds"],
                    linkedTrigger: row["linked_trigger"],
                    isEnabled: bool(row, "is_enabled"),
                    createdAt: date(row, "created_at"),
                    updatedAt: date(row, "updated_at")
                )
            }
        }
    }

    func replaceRiskySituations(_ situations: [RiskySituation]) throws {
        try dbQueue.write { db in
            try db.execute(sql: "DELETE FROM risky_situations;")
            for (position, situation) in situations.enumerated() {
                try db.execute(literal: """
                    INSERT INTO risky_situations (
                        id, title, expected_context, prevention_plan,
                        backup_action, is_enabled, position, created_at, updated_at
                    )
                    VALUES (
                        \(situation.id.uuidString),
                        \(situation.title),
                        \(situation.expectedContext),
                        \(situation.preventionPlan),
                        \(situation.backupAction),
                        \(situation.isEnabled ? 1 : 0),
                        \(position),
                        \(situation.createdAt.timeIntervalSince1970),
                        \(situation.updatedAt.timeIntervalSince1970)
                    );
                    """)
            }
        }
    }

    func fetchRiskySituations() throws -> [RiskySituation] {
        try dbQueue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT id, title, expected_context, prevention_plan,
                       backup_action, is_enabled, created_at, updated_at
                FROM risky_situations
                ORDER BY position ASC, created_at ASC;
                """
            )

            return try rows.map { row in
                RiskySituation(
                    id: try uuid(row, "id"),
                    title: row["title"],
                    expectedContext: row["expected_context"],
                    preventionPlan: row["prevention_plan"],
                    backupAction: row["backup_action"],
                    isEnabled: bool(row, "is_enabled"),
                    createdAt: date(row, "created_at"),
                    updatedAt: date(row, "updated_at")
                )
            }
        }
    }

    func replaceSupportContacts(_ contacts: [SupportContact]) throws {
        try dbQueue.write { db in
            try db.execute(sql: "DELETE FROM support_contacts;")
            for contact in contacts {
                try db.execute(literal: """
                    INSERT INTO support_contacts (
                        id, name, detail, phone_number, preferred_role,
                        default_message, created_at, updated_at
                    )
                    VALUES (
                        \(contact.id.uuidString),
                        \(contact.name),
                        \(contact.detail),
                        \(contact.phoneNumber),
                        \(contact.preferredRole.rawValue),
                        \(contact.defaultMessage),
                        \(contact.createdAt.timeIntervalSince1970),
                        \(contact.updatedAt.timeIntervalSince1970)
                    );
                    """)
            }
        }
    }

    func fetchSupportContacts() throws -> [SupportContact] {
        try dbQueue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT id, name, detail, phone_number, preferred_role,
                       default_message, created_at, updated_at
                FROM support_contacts
                ORDER BY created_at ASC, name ASC;
                """
            )

            return try rows.map { row in
                SupportContact(
                    id: try uuid(row, "id"),
                    name: row["name"],
                    detail: row["detail"],
                    phoneNumber: row["phone_number"],
                    preferredRole: SupportRole(rawValue: row["preferred_role"]) ?? .cravingAlert,
                    defaultMessage: row["default_message"],
                    createdAt: date(row, "created_at"),
                    updatedAt: date(row, "updated_at")
                )
            }
        }
    }

    func replaceUserReasons(_ reasons: [UserReason]) throws {
        try dbQueue.write { db in
            try db.execute(sql: "DELETE FROM user_reasons;")
            for (position, reason) in reasons.enumerated() {
                try db.execute(literal: """
                    INSERT INTO user_reasons (
                        id, text, sort_order, is_primary, category,
                        created_at, updated_at
                    )
                    VALUES (
                        \(reason.id.uuidString),
                        \(reason.text),
                        \(reason.sortOrder == 0 ? position : reason.sortOrder),
                        \(reason.isPrimary ? 1 : 0),
                        \(reason.category),
                        \(reason.createdAt.timeIntervalSince1970),
                        \(reason.updatedAt.timeIntervalSince1970)
                    );
                    """)
            }
        }
    }

    func fetchUserReasons() throws -> [UserReason] {
        try dbQueue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT id, text, sort_order, is_primary, category, created_at, updated_at
                FROM user_reasons
                ORDER BY sort_order ASC, created_at ASC;
                """
            )

            return try rows.map { row in
                UserReason(
                    id: try uuid(row, "id"),
                    text: row["text"],
                    sortOrder: row["sort_order"],
                    isPrimary: bool(row, "is_primary"),
                    category: row["category"],
                    createdAt: date(row, "created_at"),
                    updatedAt: date(row, "updated_at")
                )
            }
        }
    }

    func replaceCoachChats(_ chats: [CoachChat], selectedChatID: UUID?) throws {
        try dbQueue.write { db in
            try db.execute(sql: "DELETE FROM coach_messages;")
            try db.execute(sql: "DELETE FROM coach_chats;")

            for (chatPosition, chat) in chats.enumerated() {
                try db.execute(literal: """
                    INSERT INTO coach_chats (
                        id, title, is_selected, created_at, updated_at, position
                    )
                    VALUES (
                        \(chat.id.uuidString),
                        \(chat.title),
                        \(chat.id == selectedChatID ? 1 : 0),
                        \(chat.createdAt.timeIntervalSince1970),
                        \(chat.updatedAt.timeIntervalSince1970),
                        \(chatPosition)
                    );
                    """)

                for (messagePosition, message) in chat.messages.enumerated() {
                    try db.execute(literal: """
                        INSERT INTO coach_messages (
                            id, chat_id, text, is_user, created_at, position
                        )
                        VALUES (
                            \(message.id.uuidString),
                            \(chat.id.uuidString),
                            \(message.text),
                            \(message.isUser ? 1 : 0),
                            \(message.createdAt.timeIntervalSince1970),
                            \(messagePosition)
                        );
                        """)
                }
            }
        }
    }

    func fetchCoachChats() throws -> [CoachChat] {
        try dbQueue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT id, title, created_at, updated_at
                FROM coach_chats
                ORDER BY position ASC, updated_at DESC;
                """
            )

            return try rows.map { row in
                let chatID = try uuid(row, "id")
                return CoachChat(
                    id: chatID,
                    title: row["title"],
                    messages: try fetchCoachMessages(db: db, chatID: chatID),
                    createdAt: date(row, "created_at"),
                    updatedAt: date(row, "updated_at")
                )
            }
        }
    }

    func fetchSelectedCoachChatID() throws -> UUID? {
        try dbQueue.read { db in
            let row = try Row.fetchOne(
                db,
                sql: """
                SELECT id
                FROM coach_chats
                WHERE is_selected = 1
                ORDER BY position ASC
                LIMIT 1;
                """
            )
            return try row.map { try uuid($0, "id") }
        }
    }

    private func fetchCoachMessages(db: Database, chatID: UUID) throws -> [CoachMessage] {
        let rows = try Row.fetchAll(
            db,
            sql: """
            SELECT id, text, is_user, created_at
            FROM coach_messages
            WHERE chat_id = ?
            ORDER BY position ASC, created_at ASC;
            """,
            arguments: [chatID.uuidString]
        )

        return try rows.map { row in
            CoachMessage(
                id: try uuid(row, "id"),
                text: row["text"],
                isUser: bool(row, "is_user"),
                createdAt: date(row, "created_at")
            )
        }
    }

    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1") { db in
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS quit_plans (
                    id TEXT PRIMARY KEY NOT NULL,
                    quit_date REAL NOT NULL,
                    quit_mode TEXT NOT NULL,
                    medication_note TEXT NOT NULL,
                    created_at REAL NOT NULL,
                    updated_at REAL NOT NULL
                );

                CREATE TABLE IF NOT EXISTS trigger_rules (
                    id TEXT PRIMARY KEY NOT NULL,
                    quit_plan_id TEXT NOT NULL,
                    trigger TEXT NOT NULL,
                    action TEXT NOT NULL,
                    is_enabled INTEGER NOT NULL,
                    position INTEGER NOT NULL,
                    FOREIGN KEY(quit_plan_id) REFERENCES quit_plans(id) ON DELETE CASCADE
                );

                CREATE TABLE IF NOT EXISTS daily_check_ins (
                    id TEXT PRIMARY KEY NOT NULL,
                    date REAL NOT NULL,
                    mood REAL NOT NULL,
                    stress REAL NOT NULL,
                    confidence REAL NOT NULL,
                    smoked_today INTEGER,
                    focus_note TEXT NOT NULL,
                    slip_note TEXT NOT NULL,
                    created_at REAL NOT NULL,
                    updated_at REAL NOT NULL
                );

                CREATE TABLE IF NOT EXISTS craving_events (
                    id TEXT PRIMARY KEY NOT NULL,
                    started_at REAL NOT NULL,
                    completed_at REAL,
                    duration_seconds INTEGER NOT NULL,
                    completed_without_smoking INTEGER NOT NULL,
                    created_at REAL NOT NULL,
                    updated_at REAL NOT NULL
                );

                CREATE TABLE IF NOT EXISTS craving_event_triggers (
                    craving_event_id TEXT NOT NULL,
                    trigger TEXT NOT NULL,
                    position INTEGER NOT NULL,
                    PRIMARY KEY(craving_event_id, trigger),
                    FOREIGN KEY(craving_event_id) REFERENCES craving_events(id) ON DELETE CASCADE
                );

                CREATE TABLE IF NOT EXISTS support_contacts (
                    id TEXT PRIMARY KEY NOT NULL,
                    name TEXT NOT NULL,
                    detail TEXT NOT NULL,
                    created_at REAL NOT NULL,
                    updated_at REAL NOT NULL
                );

                CREATE TABLE IF NOT EXISTS user_reasons (
                    id TEXT PRIMARY KEY NOT NULL,
                    text TEXT NOT NULL,
                    created_at REAL NOT NULL,
                    updated_at REAL NOT NULL
                );

                CREATE TABLE IF NOT EXISTS coach_messages (
                    id TEXT PRIMARY KEY NOT NULL,
                    text TEXT NOT NULL,
                    is_user INTEGER NOT NULL,
                    created_at REAL NOT NULL,
                    position INTEGER NOT NULL
                );

                CREATE INDEX IF NOT EXISTS daily_check_ins_date_index
                    ON daily_check_ins(date);
                CREATE INDEX IF NOT EXISTS craving_events_started_at_index
                    ON craving_events(started_at);
                CREATE INDEX IF NOT EXISTS craving_event_triggers_trigger_index
                    ON craving_event_triggers(trigger);

                PRAGMA user_version = 1;
                """)
        }

        migrator.registerMigration("v2") { db in
            try db.execute(sql: """
                ALTER TABLE quit_plans ADD COLUMN baseline_cigarettes_per_day REAL NOT NULL DEFAULT 10;
                ALTER TABLE quit_plans ADD COLUMN cost_per_pack REAL NOT NULL DEFAULT 10;
                ALTER TABLE quit_plans ADD COLUMN cigarettes_per_pack INTEGER NOT NULL DEFAULT 20;
                ALTER TABLE quit_plans ADD COLUMN taper_target_cigarettes_per_day REAL NOT NULL DEFAULT 0;
                ALTER TABLE quit_plans ADD COLUMN taper_reduction_step REAL NOT NULL DEFAULT 2;
                ALTER TABLE quit_plans ADD COLUMN taper_reduction_interval_days INTEGER NOT NULL DEFAULT 3;
                ALTER TABLE quit_plans ADD COLUMN attempt_started_at REAL NOT NULL DEFAULT 0;
                UPDATE quit_plans SET attempt_started_at = quit_date WHERE attempt_started_at = 0;

                ALTER TABLE trigger_rules ADD COLUMN support_contact_id TEXT;

                ALTER TABLE daily_check_ins ADD COLUMN cigarettes_smoked INTEGER NOT NULL DEFAULT 0;

                ALTER TABLE craving_events ADD COLUMN outcome TEXT NOT NULL DEFAULT 'completed_without_smoking';
                ALTER TABLE craving_events ADD COLUMN initial_intensity REAL;
                ALTER TABLE craving_events ADD COLUMN final_intensity REAL;
                ALTER TABLE craving_events ADD COLUMN helped_activity_id TEXT;
                ALTER TABLE craving_events ADD COLUMN support_contact_id TEXT;
                ALTER TABLE craving_events ADD COLUMN reflection_note TEXT NOT NULL DEFAULT '';
                ALTER TABLE craving_events ADD COLUMN dismissed_at REAL;
                UPDATE craving_events
                SET outcome = CASE
                    WHEN completed_without_smoking = 1 THEN 'completed_without_smoking'
                    ELSE 'smoked_after_craving'
                END;

                ALTER TABLE support_contacts ADD COLUMN phone_number TEXT NOT NULL DEFAULT '';
                ALTER TABLE support_contacts ADD COLUMN preferred_role TEXT NOT NULL DEFAULT 'craving_alert';
                ALTER TABLE support_contacts ADD COLUMN default_message TEXT NOT NULL DEFAULT '';

                ALTER TABLE user_reasons ADD COLUMN sort_order INTEGER NOT NULL DEFAULT 0;
                ALTER TABLE user_reasons ADD COLUMN is_primary INTEGER NOT NULL DEFAULT 0;
                ALTER TABLE user_reasons ADD COLUMN category TEXT NOT NULL DEFAULT 'personal';

                CREATE TABLE IF NOT EXISTS slip_events (
                    id TEXT PRIMARY KEY NOT NULL,
                    occurred_at REAL NOT NULL,
                    cigarettes_smoked INTEGER NOT NULL,
                    mood REAL,
                    stress REAL,
                    context TEXT NOT NULL,
                    note TEXT NOT NULL,
                    recovery_action TEXT NOT NULL,
                    created_at REAL NOT NULL,
                    updated_at REAL NOT NULL
                );

                CREATE TABLE IF NOT EXISTS slip_event_triggers (
                    slip_event_id TEXT NOT NULL,
                    trigger TEXT NOT NULL,
                    position INTEGER NOT NULL,
                    PRIMARY KEY(slip_event_id, trigger),
                    FOREIGN KEY(slip_event_id) REFERENCES slip_events(id) ON DELETE CASCADE
                );

                CREATE TABLE IF NOT EXISTS replacement_activities (
                    id TEXT PRIMARY KEY NOT NULL,
                    title TEXT NOT NULL,
                    instruction TEXT NOT NULL,
                    category TEXT NOT NULL,
                    duration_seconds INTEGER NOT NULL,
                    linked_trigger TEXT NOT NULL,
                    is_enabled INTEGER NOT NULL,
                    position INTEGER NOT NULL,
                    created_at REAL NOT NULL,
                    updated_at REAL NOT NULL
                );

                CREATE INDEX IF NOT EXISTS slip_events_occurred_at_index
                    ON slip_events(occurred_at);
                CREATE INDEX IF NOT EXISTS slip_event_triggers_trigger_index
                    ON slip_event_triggers(trigger);
                CREATE INDEX IF NOT EXISTS replacement_activities_enabled_index
                    ON replacement_activities(is_enabled);

                PRAGMA user_version = 2;
                """)
        }

        migrator.registerMigration("v3") { db in
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS app_settings (
                    id INTEGER PRIMARY KEY CHECK (id = 0),
                    onboarding_completed INTEGER NOT NULL DEFAULT 0,
                    updated_at REAL NOT NULL
                );

                INSERT OR IGNORE INTO app_settings (
                    id, onboarding_completed, updated_at
                )
                VALUES (0, 0, 0);

                PRAGMA user_version = 3;
                """)
        }

        migrator.registerMigration("v4") { db in
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS notification_settings (
                    id INTEGER PRIMARY KEY CHECK (id = 0),
                    morning_plan_enabled INTEGER NOT NULL DEFAULT 0,
                    risky_window_enabled INTEGER NOT NULL DEFAULT 0,
                    post_meal_enabled INTEGER NOT NULL DEFAULT 0,
                    evening_check_in_enabled INTEGER NOT NULL DEFAULT 0,
                    medication_enabled INTEGER NOT NULL DEFAULT 0,
                    morning_plan_hour INTEGER NOT NULL DEFAULT 8,
                    morning_plan_minute INTEGER NOT NULL DEFAULT 30,
                    post_meal_hour INTEGER NOT NULL DEFAULT 13,
                    post_meal_minute INTEGER NOT NULL DEFAULT 30,
                    evening_check_in_hour INTEGER NOT NULL DEFAULT 20,
                    evening_check_in_minute INTEGER NOT NULL DEFAULT 30,
                    medication_hour INTEGER NOT NULL DEFAULT 9,
                    medication_minute INTEGER NOT NULL DEFAULT 0,
                    updated_at REAL NOT NULL
                );

                INSERT OR IGNORE INTO notification_settings (
                    id, updated_at
                )
                VALUES (0, 0);

                PRAGMA user_version = 4;
                """)
        }

        migrator.registerMigration("v5") { db in
            try db.execute(sql: """
                ALTER TABLE daily_check_ins ADD COLUMN taper_target_cigarettes REAL;
                ALTER TABLE daily_check_ins ADD COLUMN stayed_within_taper_target INTEGER;

                CREATE TABLE IF NOT EXISTS risky_situations (
                    id TEXT PRIMARY KEY NOT NULL,
                    title TEXT NOT NULL,
                    expected_context TEXT NOT NULL,
                    prevention_plan TEXT NOT NULL,
                    backup_action TEXT NOT NULL,
                    is_enabled INTEGER NOT NULL,
                    position INTEGER NOT NULL,
                    created_at REAL NOT NULL,
                    updated_at REAL NOT NULL
                );

                CREATE INDEX IF NOT EXISTS risky_situations_enabled_index
                    ON risky_situations(is_enabled);

                PRAGMA user_version = 5;
                """)
        }

        migrator.registerMigration("v6") { db in
            let migratedChatID = UUID().uuidString
            try db.execute(literal: """
                CREATE TABLE IF NOT EXISTS coach_chats (
                    id TEXT PRIMARY KEY NOT NULL,
                    title TEXT NOT NULL,
                    is_selected INTEGER NOT NULL,
                    created_at REAL NOT NULL,
                    updated_at REAL NOT NULL,
                    position INTEGER NOT NULL
                );

                ALTER TABLE coach_messages ADD COLUMN chat_id TEXT NOT NULL DEFAULT '';

                INSERT INTO coach_chats (
                    id, title, is_selected, created_at, updated_at, position
                )
                SELECT
                    \(migratedChatID),
                    'First chat',
                    1,
                    COALESCE(MIN(created_at), 0),
                    COALESCE(MAX(created_at), 0),
                    0
                FROM coach_messages
                HAVING COUNT(*) > 0;

                UPDATE coach_messages
                SET chat_id = \(migratedChatID)
                WHERE chat_id = '';

                CREATE INDEX IF NOT EXISTS coach_chats_selected_index
                    ON coach_chats(is_selected);
                CREATE INDEX IF NOT EXISTS coach_messages_chat_index
                    ON coach_messages(chat_id, position);

                PRAGMA user_version = 6;
                """)
        }

        migrator.registerMigration("v7") { db in
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS user_profile (
                    id INTEGER PRIMARY KEY CHECK (id = 0),
                    nickname TEXT NOT NULL,
                    age INTEGER NOT NULL,
                    created_at REAL NOT NULL,
                    updated_at REAL NOT NULL
                );

                CREATE TABLE IF NOT EXISTS quit_readiness (
                    id INTEGER PRIMARY KEY CHECK (id = 0),
                    status TEXT NOT NULL,
                    confidence REAL NOT NULL,
                    opened_app_reason TEXT NOT NULL,
                    created_at REAL NOT NULL,
                    updated_at REAL NOT NULL
                );

                CREATE TABLE IF NOT EXISTS smoking_background (
                    id INTEGER PRIMARY KEY CHECK (id = 0),
                    age_started_smoking INTEGER,
                    years_smoking INTEGER,
                    first_cigarette_timing TEXT NOT NULL,
                    previous_quit_attempt_count TEXT NOT NULL,
                    longest_quit_attempt TEXT NOT NULL,
                    main_challenge TEXT NOT NULL,
                    created_at REAL NOT NULL,
                    updated_at REAL NOT NULL
                );

                CREATE TABLE IF NOT EXISTS savings_goal (
                    id INTEGER PRIMARY KEY CHECK (id = 0),
                    title TEXT NOT NULL,
                    custom_text TEXT NOT NULL,
                    created_at REAL NOT NULL,
                    updated_at REAL NOT NULL
                );

                ALTER TABLE quit_plans ADD COLUMN quit_status TEXT NOT NULL DEFAULT 'ready_to_quit';
                ALTER TABLE quit_plans ADD COLUMN readiness_stage TEXT NOT NULL DEFAULT 'Quit-date preparation';
                ALTER TABLE quit_plans ADD COLUMN generated_daily_focus TEXT NOT NULL DEFAULT 'Rehearse the 10-minute rescue before the quit date.';
                ALTER TABLE quit_plans ADD COLUMN generated_plan_summary TEXT NOT NULL DEFAULT '';

                PRAGMA user_version = 7;
                """)
        }

        migrator.registerMigration("v8") { db in
            try db.execute(sql: """
                ALTER TABLE quit_plans ADD COLUMN plan_summary_json TEXT NOT NULL DEFAULT '';
                ALTER TABLE quit_plans ADD COLUMN first_week_goal TEXT NOT NULL DEFAULT '';
                ALTER TABLE quit_plans ADD COLUMN next_best_action TEXT NOT NULL DEFAULT '';
                ALTER TABLE quit_plans ADD COLUMN strategy_plan_json TEXT NOT NULL DEFAULT '';
                ALTER TABLE quit_plans ADD COLUMN generated_trigger_rules_json TEXT NOT NULL DEFAULT '[]';
                ALTER TABLE quit_plans ADD COLUMN craving_rescue_plan_json TEXT NOT NULL DEFAULT '';
                ALTER TABLE quit_plans ADD COLUMN slip_recovery_plan_json TEXT NOT NULL DEFAULT '';
                ALTER TABLE quit_plans ADD COLUMN daily_focus_plan_json TEXT NOT NULL DEFAULT '[]';
                ALTER TABLE quit_plans ADD COLUMN savings_plan_json TEXT NOT NULL DEFAULT '';
                ALTER TABLE quit_plans ADD COLUMN pending_plan_suggestions_json TEXT NOT NULL DEFAULT '[]';

                PRAGMA user_version = 8;
                """)
        }

        return migrator
    }

    private func fetchTriggerRules(db: Database, quitPlanID: UUID) throws -> [TriggerRule] {
        let rows = try Row.fetchAll(
            db,
            sql: """
            SELECT id, trigger, action, is_enabled, support_contact_id
            FROM trigger_rules
            WHERE quit_plan_id = ?
            ORDER BY position ASC;
            """,
            arguments: [quitPlanID.uuidString]
        )

        return try rows.map { row in
            TriggerRule(
                id: try uuid(row, "id"),
                trigger: row["trigger"],
                action: row["action"],
                isEnabled: bool(row, "is_enabled"),
                supportContactID: try optionalUUID(row, "support_contact_id")
            )
        }
    }

    private func fetchCravingTriggers(db: Database, eventID: UUID) throws -> [String] {
        try String.fetchAll(
            db,
            sql: """
            SELECT trigger
            FROM craving_event_triggers
            WHERE craving_event_id = ?
            ORDER BY position ASC;
            """,
            arguments: [eventID.uuidString]
        )
    }

    private func fetchSlipTriggers(db: Database, eventID: UUID) throws -> [String] {
        try String.fetchAll(
            db,
            sql: """
            SELECT trigger
            FROM slip_event_triggers
            WHERE slip_event_id = ?
            ORDER BY position ASC;
            """,
            arguments: [eventID.uuidString]
        )
    }

    private func uuid(_ row: Row, _ column: String) throws -> UUID {
        let value: String = row[column]
        guard let uuid = UUID(uuidString: value) else {
            throw TeoPateoRepositoryError.invalidUUID(value)
        }
        return uuid
    }

    private func optionalUUID(_ row: Row, _ column: String) throws -> UUID? {
        let value: String? = row[column]
        guard let value, !value.isEmpty else {
            return nil
        }
        guard let uuid = UUID(uuidString: value) else {
            throw TeoPateoRepositoryError.invalidUUID(value)
        }
        return uuid
    }

    private func date(_ row: Row, _ column: String) -> Date {
        let value: Double = row[column]
        return Date(timeIntervalSince1970: value)
    }

    private func optionalDate(_ row: Row, _ column: String) -> Date? {
        let value: Double? = row[column]
        return value.map { Date(timeIntervalSince1970: $0) }
    }

    private func bool(_ row: Row, _ column: String) -> Bool {
        let value: Int = row[column]
        return value != 0
    }

    private func optionalBool(_ row: Row, _ column: String) -> Bool? {
        let value: Int? = row[column]
        return value.map { $0 != 0 }
    }

    private func encodeJSON<T: Encodable>(_ value: T) throws -> String {
        let data = try JSONEncoder.teoPateo.encode(value)
        return String(data: data, encoding: .utf8) ?? ""
    }

    private func decodeJSON<T: Decodable>(
        _ type: T.Type,
        from row: Row,
        column: String,
        fallback: T
    ) -> T {
        let value: String? = row[column]
        guard
            let value,
            !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            let data = value.data(using: .utf8),
            let decoded = try? JSONDecoder.teoPateo.decode(type, from: data)
        else {
            return fallback
        }
        return decoded
    }
}

private extension JSONEncoder {
    static var teoPateo: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        return encoder
    }
}

private extension JSONDecoder {
    static var teoPateo: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return decoder
    }
}
