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

final class LocalNotificationScheduler: NotificationScheduling {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func currentAuthorizationStatus(
        completion: @escaping (NotificationPermissionStatus) -> Void
    ) {
        center.getNotificationSettings { settings in
            completion(Self.permissionStatus(from: settings.authorizationStatus))
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
        var firstError: Error?
        let lock = NSLock()

        for item in items {
            group.enter()
            center.add(request(for: item)) { error in
                if let error {
                    lock.lock()
                    if firstError == nil {
                        firstError = error
                    }
                    lock.unlock()
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            if let firstError {
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
