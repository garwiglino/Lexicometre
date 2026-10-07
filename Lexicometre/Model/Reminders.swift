import Foundation
#if canImport(UserNotifications)
import UserNotifications
#endif

/// Daily local notification that keeps the streak alive.
enum Reminders {
    static let identifier = "lexicometre.rappel-quotidien"

    /// Asks the permission if needed, then schedules the reminder. Returns false when refused.
    static func schedule(hour: Int, minute: Int) async -> Bool {
        #if canImport(UserNotifications)
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        guard granted else { return false }
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        let content = UNMutableNotificationContent()
        content.title = "Lexicomètre"
        content.body = "🔥 Garde ta série ! Le défi du jour t'attend : 10 mots, une minute."
        content.sound = .default
        var time = DateComponents()
        time.hour = hour
        time.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: time, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        do {
            try await center.add(request)
            return true
        } catch {
            return false
        }
        #else
        return false
        #endif
    }

    static func cancel() {
        #if canImport(UserNotifications)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        #endif
    }
}
