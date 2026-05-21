import Foundation
import GRDB

protocol TeoPateoRepository {
    func schemaVersion() throws -> Int
    func tableNames() throws -> Set<String>
    func loadSnapshot() throws -> PersistedTeoPateoSnapshot

    func fetchQuitPlan() throws -> QuitPlan?
    func saveQuitPlan(_ plan: QuitPlan) throws

    func saveDailyCheckIn(_ checkIn: DailyCheckIn) throws
    func recentCheckIns(limit: Int) throws -> [DailyCheckIn]

    func saveCravingEvent(_ event: CravingEvent) throws
    func recentCravingEvents(limit: Int) throws -> [CravingEvent]

    func replaceSupportContacts(_ contacts: [SupportContact]) throws
    func fetchSupportContacts() throws -> [SupportContact]

    func replaceUserReasons(_ reasons: [UserReason]) throws
    func fetchUserReasons() throws -> [UserReason]

    func replaceCoachMessages(_ messages: [CoachMessage]) throws
    func fetchCoachMessages() throws -> [CoachMessage]
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
            quitPlan: try fetchQuitPlan(),
            dailyCheckIns: try recentCheckIns(limit: 10_000),
            cravingEvents: try recentCravingEvents(limit: 10_000),
            supportContacts: try fetchSupportContacts(),
            userReasons: try fetchUserReasons(),
            coachMessages: try fetchCoachMessages()
        )
    }

    func fetchQuitPlan() throws -> QuitPlan? {
        try dbQueue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT id, quit_date, quit_mode, medication_note, created_at, updated_at
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
                triggerRules: try fetchTriggerRules(db: db, quitPlanID: id),
                medicationNote: row["medication_note"],
                createdAt: date(row, "created_at"),
                updatedAt: date(row, "updated_at")
            )
        }
    }

    func saveQuitPlan(_ plan: QuitPlan) throws {
        try dbQueue.write { db in
            try db.execute(literal: """
                INSERT INTO quit_plans (
                    id, quit_date, quit_mode, medication_note, created_at, updated_at
                )
                VALUES (
                    \(plan.id.uuidString),
                    \(plan.quitDate.timeIntervalSince1970),
                    \(plan.quitMode),
                    \(plan.medicationNote),
                    \(plan.createdAt.timeIntervalSince1970),
                    \(plan.updatedAt.timeIntervalSince1970)
                )
                ON CONFLICT(id) DO UPDATE SET
                    quit_date = excluded.quit_date,
                    quit_mode = excluded.quit_mode,
                    medication_note = excluded.medication_note,
                    updated_at = excluded.updated_at;
                """)

            try db.execute(
                sql: "DELETE FROM trigger_rules WHERE quit_plan_id = ?;",
                arguments: [plan.id.uuidString]
            )

            for (position, rule) in plan.triggerRules.enumerated() {
                try db.execute(literal: """
                    INSERT INTO trigger_rules (
                        id, quit_plan_id, trigger, action, is_enabled, position
                    )
                    VALUES (
                        \(rule.id.uuidString),
                        \(plan.id.uuidString),
                        \(rule.trigger),
                        \(rule.action),
                        \(rule.isEnabled ? 1 : 0),
                        \(position)
                    );
                    """)
            }
        }
    }

    func saveDailyCheckIn(_ checkIn: DailyCheckIn) throws {
        let smokedToday = checkIn.smokedToday.map { $0 ? 1 : 0 }
        try dbQueue.write { db in
            try db.execute(literal: """
                INSERT INTO daily_check_ins (
                    id, date, mood, stress, confidence, smoked_today,
                    focus_note, slip_note, created_at, updated_at
                )
                VALUES (
                    \(checkIn.id.uuidString),
                    \(checkIn.date.timeIntervalSince1970),
                    \(checkIn.mood),
                    \(checkIn.stress),
                    \(checkIn.confidence),
                    \(smokedToday),
                    \(checkIn.focusNote),
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
                SELECT id, date, mood, stress, confidence, smoked_today,
                       focus_note, slip_note, created_at, updated_at
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
                    focusNote: row["focus_note"],
                    slipNote: row["slip_note"],
                    createdAt: date(row, "created_at"),
                    updatedAt: date(row, "updated_at")
                )
            }
        }
    }

    func saveCravingEvent(_ event: CravingEvent) throws {
        let completedAt = event.completedAt.map(\.timeIntervalSince1970)
        try dbQueue.write { db in
            try db.execute(literal: """
                INSERT INTO craving_events (
                    id, started_at, completed_at, duration_seconds,
                    completed_without_smoking, created_at, updated_at
                )
                VALUES (
                    \(event.id.uuidString),
                    \(event.startedAt.timeIntervalSince1970),
                    \(completedAt),
                    \(event.durationSeconds),
                    \(event.completedWithoutSmoking ? 1 : 0),
                    \(event.createdAt.timeIntervalSince1970),
                    \(event.updatedAt.timeIntervalSince1970)
                )
                ON CONFLICT(id) DO UPDATE SET
                    started_at = excluded.started_at,
                    completed_at = excluded.completed_at,
                    duration_seconds = excluded.duration_seconds,
                    completed_without_smoking = excluded.completed_without_smoking,
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
    }

    func recentCravingEvents(limit: Int) throws -> [CravingEvent] {
        try dbQueue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT id, started_at, completed_at, duration_seconds,
                       completed_without_smoking, created_at, updated_at
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
                    completedWithoutSmoking: bool(row, "completed_without_smoking"),
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
                        id, name, detail, created_at, updated_at
                    )
                    VALUES (
                        \(contact.id.uuidString),
                        \(contact.name),
                        \(contact.detail),
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
                SELECT id, name, detail, created_at, updated_at
                FROM support_contacts
                ORDER BY created_at ASC, name ASC;
                """
            )

            return try rows.map { row in
                SupportContact(
                    id: try uuid(row, "id"),
                    name: row["name"],
                    detail: row["detail"],
                    createdAt: date(row, "created_at"),
                    updatedAt: date(row, "updated_at")
                )
            }
        }
    }

    func replaceUserReasons(_ reasons: [UserReason]) throws {
        try dbQueue.write { db in
            try db.execute(sql: "DELETE FROM user_reasons;")
            for reason in reasons {
                try db.execute(literal: """
                    INSERT INTO user_reasons (
                        id, text, created_at, updated_at
                    )
                    VALUES (
                        \(reason.id.uuidString),
                        \(reason.text),
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
                SELECT id, text, created_at, updated_at
                FROM user_reasons
                ORDER BY created_at ASC;
                """
            )

            return try rows.map { row in
                UserReason(
                    id: try uuid(row, "id"),
                    text: row["text"],
                    createdAt: date(row, "created_at"),
                    updatedAt: date(row, "updated_at")
                )
            }
        }
    }

    func replaceCoachMessages(_ messages: [CoachMessage]) throws {
        try dbQueue.write { db in
            try db.execute(sql: "DELETE FROM coach_messages;")
            for (position, message) in messages.enumerated() {
                try db.execute(literal: """
                    INSERT INTO coach_messages (
                        id, text, is_user, created_at, position
                    )
                    VALUES (
                        \(message.id.uuidString),
                        \(message.text),
                        \(message.isUser ? 1 : 0),
                        \(message.createdAt.timeIntervalSince1970),
                        \(position)
                    );
                    """)
            }
        }
    }

    func fetchCoachMessages() throws -> [CoachMessage] {
        try dbQueue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT id, text, is_user, created_at
                FROM coach_messages
                ORDER BY position ASC, created_at ASC;
                """
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

        return migrator
    }

    private func fetchTriggerRules(db: Database, quitPlanID: UUID) throws -> [TriggerRule] {
        let rows = try Row.fetchAll(
            db,
            sql: """
            SELECT id, trigger, action, is_enabled
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
                isEnabled: bool(row, "is_enabled")
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

    private func uuid(_ row: Row, _ column: String) throws -> UUID {
        let value: String = row[column]
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
}
