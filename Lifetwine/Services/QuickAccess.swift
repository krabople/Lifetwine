import AppIntents
import UIKit
import UserNotifications

extension Notification.Name {
    static let openLifetwineLogger = Notification.Name("openLifetwineLogger")
    static let openLifetwineMetric = Notification.Name("openLifetwineMetric")
}

enum QuickAccessRequest {
    private static let key = "LifetwineOpenQuickLogger"
    private static let metricKey = "LifetwineOpenMetricID"

    static func request() {
        UserDefaults.standard.set(true, forKey: key)
        NotificationCenter.default.post(name: .openLifetwineLogger, object: nil)
    }

    static func consume() -> Bool {
        let requested = UserDefaults.standard.bool(forKey: key)
        if requested { UserDefaults.standard.removeObject(forKey: key) }
        return requested
    }

    static func request(metricID: String) {
        UserDefaults.standard.set(metricID, forKey: metricKey)
        NotificationCenter.default.post(name: .openLifetwineMetric, object: metricID)
    }

    static func consumeMetricID() -> UUID? {
        guard let value = UserDefaults.standard.string(forKey: metricKey) else { return nil }
        UserDefaults.standard.removeObject(forKey: metricKey)
        return UUID(uuidString: value)
    }
}

struct OpenLifetwineLoggerIntent: AppIntent {
    static var title: LocalizedStringResource = "Log anything"
    static var description = IntentDescription("Open Lifetwine directly at the searchable quick logger.")
    static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        QuickAccessRequest.request()
        return .result()
    }
}

struct LifetwineShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenLifetwineLoggerIntent(),
            phrases: [
                "Log something in \(.applicationName)",
                "Quick log with \(.applicationName)",
                "Record something in \(.applicationName)"
            ],
            shortTitle: "Log anything",
            systemImageName: "plus.circle.fill"
        )
    }
}

final class LifetwineAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        if let shortcut = launchOptions?[.shortcutItem] as? UIApplicationShortcutItem,
           shortcut.type == "com.krabople.lifetwine.quicklog" {
            UserDefaults.standard.set(true, forKey: "LifetwineOpenQuickLogger")
            return false
        }
        return true
    }

    func application(
        _ application: UIApplication,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        guard shortcutItem.type == "com.krabople.lifetwine.quicklog" else {
            completionHandler(false)
            return
        }
        QuickAccessRequest.request()
        completionHandler(true)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard let metricID = response.notification.request.content.userInfo["metricID"] as? String else { return }
        QuickAccessRequest.request(metricID: metricID)
    }
}
