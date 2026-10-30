import BackgroundTasks
import Foundation
import UserNotifications

/// Posts local notifications when a catalog update adds cards for talents the user follows.
@MainActor
final class NewCardNotifier: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NewCardNotifier()
    static let refreshTaskID = "com.julianmanaois.holowish.catalog-refresh"
    private static let refreshInterval: TimeInterval = 12 * 60 * 60
    private static let maxTalentNotifications = 4

    private var center: UNUserNotificationCenter { .current() }

    func activate() {
        center.delegate = self
    }

    /// Asks for permission; returns whether alerts can be shown.
    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    func notify(about addedCards: [Card], following talents: [AppTheme]) {
        let matches = talents.compactMap { theme -> (AppTheme, [Card])? in
            let cards = addedCards.filter { $0.belongs(to: theme) }
            return cards.isEmpty ? nil : (theme, cards)
        }
        for (theme, cards) in matches.prefix(Self.maxTalentNotifications) {
            let content = UNMutableNotificationContent()
            content.title = "New \(theme.rawValue) cards"
            let firstName = cards[0].displayEnglishName ?? cards[0].name
            content.body = cards.count == 1
                ? "\(firstName) (\(cards[0].number.uppercased())) was added to the catalog."
                : "\(cards.count) new cards were added, including \(firstName)."
            content.sound = .default
            content.threadIdentifier = "new-cards"
            let request = UNNotificationRequest(
                identifier: "new-cards-\(theme.rawValue)-\(cards.map(\.id).max() ?? 0)",
                content: content,
                trigger: nil
            )
            center.add(request)
        }
    }

    /// Schedules the next background catalog check so alerts can arrive while the app is closed.
    func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.refreshTaskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: Self.refreshInterval)
        try? BGTaskScheduler.shared.submit(request)
    }

    func cancelBackgroundRefresh() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.refreshTaskID)
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}
