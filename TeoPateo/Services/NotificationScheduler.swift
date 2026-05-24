import Foundation
import UserNotifications

protocol NotificationScheduling {
    func currentAuthorizationStatus(
        completion: @escaping (NotificationPermissionStatus) -> Void
    )
    func requestAuthorization(
        completion: @escaping (Result<NotificationPermissionStatus, Error>) -> Void
    )
    func replaceScheduledNotifications(
        with items: [NotificationScheduleItem],
        completion: @escaping (Result<Void, Error>) -> Void
    )
    func cancelScheduledNotifications(
        completion: @escaping (Result<Void, Error>) -> Void
    )
}

protocol UserNotificationCentering {
    func authorizationStatus(
        completion: @escaping @Sendable (UNAuthorizationStatus) -> Void
    )
    func requestAuthorization(
        options: UNAuthorizationOptions,
        completionHandler: @escaping @Sendable (Bool, Error?) -> Void
    )
    func add(
        _ request: UNNotificationRequest,
        withCompletionHandler completionHandler: (@Sendable (Error?) -> Void)?
    )
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
}

extension UNUserNotificationCenter: UserNotificationCentering {
    func authorizationStatus(
        completion: @escaping @Sendable (UNAuthorizationStatus) -> Void
    ) {
        getNotificationSettings { settings in
            completion(settings.authorizationStatus)
        }
    }
}

final class LocalNotificationScheduler: NotificationScheduling {
    private let center: UserNotificationCentering

    init(center: UserNotificationCentering = UNUserNotificationCenter.current()) {
        self.center = center
    }

    func currentAuthorizationStatus(
        completion: @escaping (NotificationPermissionStatus) -> Void
    ) {
        center.authorizationStatus { status in
            completion(Self.permissionStatus(from: status))
        }
    }

    func requestAuthorization(
        completion: @escaping (Result<NotificationPermissionStatus, Error>) -> Void
    ) {
        center.requestAuthorization(options: [.alert, .badge, .sound]) { _, error in
            if let error {
                completion(.failure(error))
                return
            }

            self.currentAuthorizationStatus { status in
                completion(.success(status))
            }
        }
    }

    func replaceScheduledNotifications(
        with items: [NotificationScheduleItem],
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        center.removePendingNotificationRequests(
            withIdentifiers: NotificationPlanner.allManagedIdentifiers
        )

        guard !items.isEmpty else {
            completion(.success(()))
            return
        }

        let group = DispatchGroup()
        let errorRecorder = NotificationSchedulingErrorRecorder()

        for item in items {
            group.enter()
            center.add(request(for: item)) { error in
                if let error {
                    errorRecorder.record(error)
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            if let firstError = errorRecorder.firstError {
                completion(.failure(firstError))
            } else {
                completion(.success(()))
            }
        }
    }

    func cancelScheduledNotifications(
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        center.removePendingNotificationRequests(
            withIdentifiers: NotificationPlanner.allManagedIdentifiers
        )
        completion(.success(()))
    }

    private func request(for item: NotificationScheduleItem) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = item.title
        content.body = item.body
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = item.time.hour
        dateComponents.minute = item.time.minute

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents,
            repeats: true
        )
        return UNNotificationRequest(
            identifier: item.identifier,
            content: content,
            trigger: trigger
        )
    }

    private static func permissionStatus(
        from status: UNAuthorizationStatus
    ) -> NotificationPermissionStatus {
        switch status {
        case .notDetermined:
            return .notDetermined
        case .denied:
            return .denied
        case .authorized:
            return .authorized
        case .provisional:
            return .provisional
        case .ephemeral:
            return .ephemeral
        @unknown default:
            return .unknown
        }
    }
}

private final class NotificationSchedulingErrorRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storedError: Error?

    var firstError: Error? {
        lock.lock()
        defer { lock.unlock() }
        return storedError
    }

    func record(_ error: Error) {
        lock.lock()
        defer { lock.unlock() }
        if storedError == nil {
            storedError = error
        }
    }
}
