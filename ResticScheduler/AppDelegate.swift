import Cocoa
import ResticSchedulerKit
@preconcurrency import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private typealias TypeLogger = ResticSchedulerKit.TypeLogger<AppDelegate>

    enum NotificationCategoryIdentifier: String {
        case backupFailure = "BACKUP_FAILURE"
    }

    enum NotificationUserInfoKey: String {
        case localizedError = "LOCALIZED_ERROR"
        case repository = "REPOSITORY"
    }

    private enum NotificationActionIdentifier: String {
        case details = "DETAILS"
    }

    private(set) static var shared: AppDelegate?

    private static let authorizationOptions: UNAuthorizationOptions = [.alert, .sound]
    private var notificationCenter: UNUserNotificationCenter?

    func applicationDidFinishLaunching(_: Notification) {
        Self.shared = self
        notificationCenter = UNUserNotificationCenter.current()
        notificationCenter!.delegate = self
        let detailsAction = UNNotificationAction(identifier: NotificationActionIdentifier.details.rawValue, title: "Details", options: [])
        let backupFailureCategory = UNNotificationCategory(
            identifier: NotificationCategoryIdentifier.backupFailure.rawValue,
            actions: [detailsAction],
            intentIdentifiers: [],
            hiddenPreviewsBodyPlaceholder: "",
            options: .hiddenPreviewsShowTitle
        )
        notificationCenter!.setNotificationCategories([backupFailureCategory])
        notificationCenter!.requestAuthorization(options: Self.authorizationOptions) { granted, error in
            guard error == nil else {
                TypeLogger.function().warning("Notification authorization request error: \(error!.localizedDescription, privacy: .public)")
                return
            }
            guard granted else {
                TypeLogger.function().warning("Notification authorization request denied")
                return
            }
        }
    }

    func userNotificationCenter(_: UNUserNotificationCenter, willPresent _: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    func userNotificationCenter(_: UNUserNotificationCenter, didReceive notification: UNNotificationResponse) async {
        DispatchQueue.main.async {
            switch notification.actionIdentifier {
            case NotificationActionIdentifier.details.rawValue, UNNotificationDefaultActionIdentifier:
                guard let repository = notification.notification.request.content.userInfo[NotificationUserInfoKey.repository.rawValue] as? String else {
                    TypeLogger.function().warning("No repository name found in notification user info")
                    return
                }
                guard let localizedError = notification.notification.request.content.userInfo[NotificationUserInfoKey.localizedError.rawValue] as? String else {
                    TypeLogger.function().warning("No localized error found in notification user info")
                    return
                }

                NSAlert.showError(.backupFailure(repository: repository), informativeText: localizedError)
            default:
                break
            }
        }
    }

    func addNotification(content: UNNotificationContent) {
        notificationCenter!.requestAuthorization(options: Self.authorizationOptions) { granted, error in
            guard error == nil else {
                TypeLogger.function().warning("Notification authorization request error: \(error!.localizedDescription, privacy: .public)")
                return
            }
            guard granted else {
                TypeLogger.function().warning("Notification authorization request denied")
                return
            }

            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            self.notificationCenter!.add(request, withCompletionHandler: { error in
                guard error == nil else {
                    TypeLogger.function().warning("Couldn't add notification request: \(error!.localizedDescription, privacy: .public)")
                    return
                }
            })
        }
    }
}
