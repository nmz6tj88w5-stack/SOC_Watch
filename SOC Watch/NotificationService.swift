import UserNotifications

/// Local-only re-engagement notifications (no push/remote infrastructure
/// needed for V1). One notification "slot" is scheduled whenever the app
/// backgrounds, replacing any previously scheduled one via a fixed
/// identifier, and canceled again if the player comes back before it
/// fires. Kept out of GameEngine — permission prompts and scheduling are
/// a system/UI concern, not game logic.
enum NotificationService {
    private static let reengagementIdentifier = "com.socwatch.reengagement"

    private static let criticalAbsorptionThreshold = 0.25
    private static let postMortemFollowUpDelay: TimeInterval = 20 * 3600
    private static let criticalCapacityDelay: TimeInterval = 2 * 3600
    private static let idleReminderDelay: TimeInterval = 24 * 3600
    /// A breach only counts as "just happened" (for the follow-up
    /// notification) if it occurred shortly before backgrounding —
    /// otherwise a breach from hours ago shouldn't dominate the message.
    private static let recentBreachWindow: TimeInterval = 60

    /// Awaits the full round-trip of the system permission dialog (if one
    /// is shown) so callers can keep gameplay paused until it's gone —
    /// this dialog is native OS UI, not a SwiftUI sheet, so nothing in
    /// our view hierarchy knows about it otherwise.
    static func requestAuthorization() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
    }

    static func scheduleReengagement(theme: ThemeConfig, breachSummary: BreachSummary?, absorptionFraction: Double, now: Date) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else { return }

            let title: String
            let body: String
            let delay: TimeInterval
            let reason: String

            if let breachSummary, now.timeIntervalSince(breachSummary.occurredAt) < recentBreachWindow {
                title = theme.notifications.postMortemTitle
                body = theme.notifications.postMortemBody
                delay = postMortemFollowUpDelay
                reason = "post_mortem_follow_up"
            } else if absorptionFraction < criticalAbsorptionThreshold {
                title = theme.notifications.criticalTitle
                body = theme.notifications.criticalBody
                delay = criticalCapacityDelay
                reason = "critical_capacity"
            } else {
                title = theme.notifications.idleTitle
                body = theme.notifications.idleBody
                delay = idleReminderDelay
                reason = "idle_reminder"
            }
            AnalyticsService.reengagementScheduled(reason: reason, delaySeconds: delay)

            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
            let request = UNNotificationRequest(identifier: reengagementIdentifier, content: content, trigger: trigger)
            // Adding a request with an identifier that already exists
            // replaces the pending one, so there's never more than one
            // reengagement notification in flight at a time.
            UNUserNotificationCenter.current().add(request)
        }
    }

    static func cancelReengagement() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [reengagementIdentifier])
    }
}
