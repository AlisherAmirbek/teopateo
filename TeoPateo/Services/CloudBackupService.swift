import CloudKit
import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Whether the device can currently reach the user's private iCloud database.
enum CloudBackupAvailability: Equatable {
    /// Signed in and reachable — backup and restore can proceed.
    case available
    /// No iCloud account is signed in on the device.
    case noAccount
    /// iCloud is blocked by parental controls or an MDM profile.
    case restricted
    /// Signed in, but the account needs attention (e.g. re-auth) before CloudKit works.
    case temporarilyUnavailable
    /// Status could not be read (often a flaky simulator or transient error).
    case couldNotDetermine

    /// Only `.available` should allow a push/fetch attempt.
    var canSync: Bool { self == .available }
}

/// A friendly, UI-mappable error for backup failures. Raw `CKError`s are translated here so
/// the store and views never have to reason about CloudKit error codes.
enum CloudBackupError: Error, Equatable {
    /// iCloud was not usable; carries the specific availability for messaging.
    case accountUnavailable(CloudBackupAvailability)
    /// A transient connectivity failure — safe to retry later.
    case network
    /// The user's iCloud storage is full. User-fixable; do not auto-retry.
    case quotaExceeded
    /// CloudKit is busy / rate limiting. Retry after a short delay.
    case serviceUnavailable
    /// The stored backup was written by a newer app version and cannot be imported.
    case incompatibleVersion
    /// The backup payload exists but could not be read/decoded.
    case corruptBackup
    /// Anything not specifically classified above.
    case unknown(String)
}

/// Transient, user-visible state for the most recent backup or restore action.
enum CloudBackupStatus: Equatable {
    case idle
    case inProgress
    case success
    case failed(String)
}

/// Abstraction over the iCloud backup store so the app can swap in a no-op (UI tests) or a
/// fake (unit tests) without touching CloudKit.
protocol CloudBackupService {
    /// Current iCloud account reachability. Never throws — returns `.couldNotDetermine` on error.
    func accountAvailability() async -> CloudBackupAvailability
    /// Overwrites the single cloud backup with `envelope` (last-writer-wins).
    func push(_ envelope: BackupEnvelope) async throws
    /// Returns the latest cloud backup, or `nil` if none exists yet.
    func fetchLatest() async throws -> BackupEnvelope?
    /// Removes the cloud backup entirely (used when the user deletes their local data, so the
    /// deletion is honored across devices and the data cannot be restored later).
    func deleteBackup() async throws
}

/// CloudKit-backed implementation. Mirrors the whole data snapshot as a single record in the
/// user's **private** database, with the JSON payload stored as a `CKAsset` (the snapshot can
/// exceed the 1 MB per-field limit once coach history grows). One fixed record in one custom
/// zone means every push overwrites the previous backup — there is exactly one to restore.
final class CloudKitBackupService: CloudBackupService {
    private let container: CKContainer
    private let recordType = "Backup"
    private let zoneID: CKRecordZone.ID
    private let recordID: CKRecord.ID
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private var didEnsureZone = false

    private var database: CKDatabase { container.privateCloudDatabase }

    init(containerIdentifier: String = "iCloud.com.teopateo.TeoPateo") {
        container = CKContainer(identifier: containerIdentifier)
        zoneID = CKRecordZone.ID(zoneName: "TeoPateoBackup", ownerName: CKCurrentUserDefaultName)
        recordID = CKRecord.ID(recordName: "backup-singleton", zoneID: zoneID)
        encoder = JSONEncoder()
        decoder = JSONDecoder()
    }

    func accountAvailability() async -> CloudBackupAvailability {
        do {
            switch try await container.accountStatus() {
            case .available: return .available
            case .noAccount: return .noAccount
            case .restricted: return .restricted
            case .temporarilyUnavailable: return .temporarilyUnavailable
            case .couldNotDetermine: return .couldNotDetermine
            @unknown default: return .couldNotDetermine
            }
        } catch {
            return .couldNotDetermine
        }
    }

    func push(_ envelope: BackupEnvelope) async throws {
        let availability = await accountAvailability()
        guard availability.canSync else { throw CloudBackupError.accountUnavailable(availability) }

        do {
            try await ensureZoneExists()

            let data = try encoder.encode(envelope)
            let fileURL = try writeTemporaryPayload(data)
            defer { try? FileManager.default.removeItem(at: fileURL) }

            try await saveRecord(for: envelope, payloadFile: fileURL, retryOnConflict: true)
        } catch let error as CKError {
            throw Self.map(error)
        } catch let error as CloudBackupError {
            throw error
        } catch {
            throw CloudBackupError.unknown(error.localizedDescription)
        }
    }

    func fetchLatest() async throws -> BackupEnvelope? {
        let availability = await accountAvailability()
        guard availability.canSync else { throw CloudBackupError.accountUnavailable(availability) }

        do {
            let record = try await database.record(for: recordID)
            guard let asset = record["payload"] as? CKAsset, let fileURL = asset.fileURL else {
                return nil
            }
            let data = try Data(contentsOf: fileURL)
            do {
                return try decoder.decode(BackupEnvelope.self, from: data)
            } catch {
                throw CloudBackupError.corruptBackup
            }
        } catch let error as CKError where error.code == .unknownItem || error.code == .zoneNotFound {
            return nil
        } catch let error as CKError {
            throw Self.map(error)
        }
    }

    func deleteBackup() async throws {
        guard await accountAvailability().canSync else { return }
        do {
            _ = try await database.deleteRecord(withID: recordID)
        } catch let error as CKError where error.code == .unknownItem || error.code == .zoneNotFound {
            // Already gone — nothing to delete.
        } catch let error as CKError {
            throw Self.map(error)
        }
    }

    // MARK: - Internals

    private func ensureZoneExists() async throws {
        if didEnsureZone { return }
        // Saving a zone that already exists is idempotent in CloudKit, so this is safe to repeat.
        _ = try await database.modifyRecordZones(saving: [CKRecordZone(zoneID: zoneID)], deleting: [])
        didEnsureZone = true
    }

    /// Fetches the existing backup record (so we save with its current change tag) or creates a
    /// fresh one, then overwrites the payload. On a `serverRecordChanged` conflict we refetch and
    /// save once more so the latest writer wins.
    private func saveRecord(
        for envelope: BackupEnvelope,
        payloadFile: URL,
        retryOnConflict: Bool
    ) async throws {
        let record: CKRecord
        do {
            record = try await database.record(for: recordID)
        } catch let error as CKError where error.code == .unknownItem {
            record = CKRecord(recordType: recordType, recordID: recordID)
        }

        record["payload"] = CKAsset(fileURL: payloadFile)
        record["modifiedAt"] = envelope.exportedAt as NSDate
        record["schemaVersion"] = envelope.schemaVersion as NSNumber
        record["deviceName"] = envelope.deviceName as NSString

        do {
            _ = try await database.save(record)
        } catch let error as CKError where error.code == .serverRecordChanged && retryOnConflict {
            try await saveRecord(for: envelope, payloadFile: payloadFile, retryOnConflict: false)
        }
    }

    private func writeTemporaryPayload(_ data: Data) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("teopateo-backup-\(UUID().uuidString)")
            .appendingPathExtension("json")
        try data.write(to: url, options: .atomic)
        return url
    }

    private static func map(_ error: CKError) -> CloudBackupError {
        switch error.code {
        case .networkUnavailable, .networkFailure, .serverResponseLost:
            return .network
        case .quotaExceeded:
            return .quotaExceeded
        case .serviceUnavailable, .requestRateLimited, .zoneBusy:
            return .serviceUnavailable
        case .notAuthenticated:
            return .accountUnavailable(.noAccount)
        default:
            return .unknown(error.localizedDescription)
        }
    }
}

/// No-op backup service for unit/UI tests and any build without iCloud configured. Reports the
/// account as unavailable so the store treats backup as off and never touches the network.
final class NoopCloudBackupService: CloudBackupService {
    func accountAvailability() async -> CloudBackupAvailability { .noAccount }
    func push(_ envelope: BackupEnvelope) async throws {}
    func fetchLatest() async throws -> BackupEnvelope? { nil }
    func deleteBackup() async throws {}
}

/// Device-local backup preferences and status, kept in `UserDefaults` (NOT in the synced
/// snapshot, so toggling backup off on one device can never propagate and disable it elsewhere).
struct CloudBackupSettings {
    private let defaults: UserDefaults

    private enum Key {
        static let enabled = "cloudBackup.enabled"
        static let lastBackupAt = "cloudBackup.lastBackupAt"
        static let lastBackupDevice = "cloudBackup.lastBackupDevice"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Defaults to `true`: backup is on by default and only takes effect when an iCloud account
    /// is actually available (checked at sync time).
    var isEnabled: Bool {
        get { defaults.object(forKey: Key.enabled) as? Bool ?? true }
        nonmutating set { defaults.set(newValue, forKey: Key.enabled) }
    }

    var lastBackupAt: Date? {
        get {
            let value = defaults.double(forKey: Key.lastBackupAt)
            return value > 0 ? Date(timeIntervalSince1970: value) : nil
        }
        nonmutating set {
            defaults.set(newValue?.timeIntervalSince1970 ?? 0, forKey: Key.lastBackupAt)
        }
    }

    var lastBackupDevice: String? {
        get { defaults.string(forKey: Key.lastBackupDevice) }
        nonmutating set { defaults.set(newValue, forKey: Key.lastBackupDevice) }
    }
}

extension BackupEnvelope {
    /// The current device's display name (e.g. "iPhone"), used for "Last backed up from …" copy.
    static var currentDeviceName: String {
        #if canImport(UIKit)
        return UIDevice.current.name
        #else
        return ProcessInfo.processInfo.hostName
        #endif
    }
}
