import Foundation
import UserNotifications

enum ReminderScheduler {
    private static let identifierPrefix = "lifetwine.reminder."
    private static let maximumScheduledReminders = 60

    @discardableResult
    static func rebuild(for metrics: [MetricDefinition]) async -> Int {
        let center = UNUserNotificationCenter.current()
        let existing = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: existing)

        let enabledMetrics = metrics
            .filter { !$0.isArchived && $0.hasReminders && !$0.reminderMinutes.isEmpty }
            .sorted { $0.sortOrder < $1.sortOrder }
        guard !enabledMetrics.isEmpty else { return 0 }

        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            do {
                guard try await center.requestAuthorization(options: [.alert, .sound, .badge]) else { return 0 }
            } catch {
                return 0
            }
        } else if settings.authorizationStatus == .denied {
            return 0
        }

        var scheduled = 0
        for metric in enabledMetrics {
            for minutes in metric.reminderMinutes.sorted() {
                let weekdays: [Int?] = metric.reminderWeekdays.isEmpty
                    ? [nil]
                    : metric.reminderWeekdays.sorted().map(Optional.some)
                for weekday in weekdays {
                    guard scheduled < maximumScheduledReminders else { return scheduled }
                    let content = UNMutableNotificationContent()
                    content.title = metric.name
                    let customMessage = metric.reminderMessage.trimmingCharacters(in: .whitespacesAndNewlines)
                    content.body = customMessage.isEmpty ? "A quick moment to log \(metric.name.lowercased())." : customMessage
                    content.sound = .default
                    content.userInfo = ["metricID": metric.id.uuidString]

                    var components = DateComponents()
                    components.hour = minutes / 60
                    components.minute = minutes % 60
                    components.weekday = weekday
                    let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                    let weekdayKey = weekday.map(String.init) ?? "daily"
                    let identifier = "\(identifierPrefix)\(metric.id.uuidString).\(minutes).\(weekdayKey)"
                    do {
                        try await center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
                        scheduled += 1
                    } catch {
                        continue
                    }
                }
            }
        }
        return scheduled
    }
}
