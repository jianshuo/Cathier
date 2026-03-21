import Foundation
import UserNotifications

struct ReminderTime: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var hour: Int
    var minute: Int
    var isEnabled: Bool

    var displayString: String {
        String(format: "%02d:%02d", hour, minute)
    }
}

final class NotificationService {
    static let shared = NotificationService()

    private let reminderMessages = [
        "现在，停一秒，感受一下身体。",
        "此刻，你的身体在说什么？",
        "花30秒，和自己的感受相遇。",
        "深呼吸，注意一下此刻的感觉。",
    ]

    private init() {}

    func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional: return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        default: return false
        }
    }

    func checkAuthorizationStatus() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus == .authorized
    }

    func scheduleReminders(_ times: [ReminderTime]) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        let enabledTimes = times.filter { $0.isEnabled }
        for (i, time) in enabledTimes.enumerated() {
            let content = UNMutableNotificationContent()
            content.title = "体感签到"
            content.body = reminderMessages[i % reminderMessages.count]
            content.sound = .default

            var comps = DateComponents()
            comps.hour = time.hour
            comps.minute = time.minute

            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
            let request = UNNotificationRequest(
                identifier: "reminder_\(i)",
                content: content,
                trigger: trigger
            )
            center.add(request)
        }
    }

    func removeAllReminders() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    /// One-time nudge delivered when the user reaches 30 check-ins.
    /// Guards against re-delivery via UserDefaults flag "insightNudgeSent".
    func scheduleInsightNudge() {
        guard !UserDefaults.standard.bool(forKey: "insightNudgeSent") else { return }
        UserDefaults.standard.set(true, forKey: "insightNudgeSent")

        let content = UNMutableNotificationContent()
        content.title = LanguageManager.shared.notifMilestoneTitle
        content.body = LanguageManager.shared.notifMilestoneBody
        content.sound = .default

        // Deliver 2 seconds from now (app is in background or user may have just locked)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let request = UNNotificationRequest(
            identifier: "insightMilestone30",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Persistence

    static let defaultTimes: [ReminderTime] = [
        ReminderTime(hour: 9, minute: 0, isEnabled: true),
        ReminderTime(hour: 13, minute: 0, isEnabled: true),
        ReminderTime(hour: 17, minute: 0, isEnabled: true),
        ReminderTime(hour: 21, minute: 0, isEnabled: true),
    ]

    func loadTimes() -> [ReminderTime] {
        guard let data = UserDefaults.standard.data(forKey: "reminderTimes"),
              let times = try? JSONDecoder().decode([ReminderTime].self, from: data)
        else { return Self.defaultTimes }
        return times
    }

    func saveTimes(_ times: [ReminderTime]) {
        guard let data = try? JSONEncoder().encode(times) else { return }
        UserDefaults.standard.set(data, forKey: "reminderTimes")
    }
}
