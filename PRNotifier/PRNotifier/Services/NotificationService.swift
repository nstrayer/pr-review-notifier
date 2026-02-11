import Foundation
import UserNotifications
import AppKit

@MainActor
final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationService()

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    // MARK: - Permission

    func requestPermission() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }

        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            print("Notification permission granted: \(granted)")
        } catch {
            print("Notification permission error: \(error.localizedDescription)")
        }
    }

    // MARK: - Send Notifications

    func sendNewPRNotification(pr: PR) async {
        let content = UNMutableNotificationContent()
        content.title = "PR Review Requested: \(pr.repo)"
        content.body = pr.title
        content.sound = .default
        content.userInfo = ["url": pr.htmlURL]

        let request = UNNotificationRequest(
            identifier: "pr-\(pr.id)",
            content: content,
            trigger: nil
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            print("Failed to schedule notification: \(error.localizedDescription)")
        }
    }

    func sendSummaryNotification(count: Int) async {
        let content = UNMutableNotificationContent()
        content.title = "PR Reviews Pending"
        content.body = "You have \(count) pull request(s) waiting for your review."

        let request = UNNotificationRequest(
            identifier: "pr-summary",
            content: content,
            trigger: nil
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            print("Failed to schedule summary notification: \(error.localizedDescription)")
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        if let urlString = userInfo["url"] as? String,
           let url = URL(string: urlString) {
            DispatchQueue.main.async {
                NSWorkspace.shared.open(url)
            }
        }
        completionHandler()
    }
}
