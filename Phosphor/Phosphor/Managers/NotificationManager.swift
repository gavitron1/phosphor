import Foundation
import UserNotifications

@MainActor
class NotificationManager: ObservableObject {
    static let shared = NotificationManager()

    @Published var isAuthorized = false
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private init() {
        Task {
            await checkAuthorizationStatus()
        }
    }

    // MARK: - Authorization

    func checkAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
        isAuthorized = settings.authorizationStatus == .authorized
    }

    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            await checkAuthorizationStatus()
            return granted
        } catch {
            print("Notification authorization error: \(error)")
            return false
        }
    }

    // MARK: - Cooldown Notifications

    /// Schedule notifications for muscle groups approaching full cooldown
    func scheduleCooldownNotifications(muscleData: [MuscleGroup: MuscleGroupData], cooldownDays: Double) {
        guard isAuthorized else { return }

        // Cancel existing cooldown notifications
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers:
            MuscleGroup.allCases.map { "cooldown-\($0.rawValue)" }
        )

        let cooldownSeconds = cooldownDays * 86400
        // Notify when 90% of cooldown has elapsed (10% remaining)
        let notifyAtPercent = 0.9

        for (group, data) in muscleData {
            guard let lastTapped = data.lastTappedDate else { continue }

            let elapsed = Date().timeIntervalSince(lastTapped)
            let notifyAfter = cooldownSeconds * notifyAtPercent

            // Only schedule if the notification time is in the future
            if elapsed < notifyAfter {
                let remainingTime = notifyAfter - elapsed

                let content = UNMutableNotificationContent()
                content.title = "Muscle Cooldown"
                content.body = "\(group.rawValue) is almost fully recovered!"
                content.sound = .default

                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: remainingTime, repeats: false)
                let request = UNNotificationRequest(
                    identifier: "cooldown-\(group.rawValue)",
                    content: content,
                    trigger: trigger
                )

                UNUserNotificationCenter.current().add(request) { error in
                    if let error = error {
                        print("Failed to schedule notification: \(error)")
                    }
                }
            }
        }
    }

    /// Cancel all cooldown notifications
    func cancelAllCooldownNotifications() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers:
            MuscleGroup.allCases.map { "cooldown-\($0.rawValue)" }
        )
    }
}
