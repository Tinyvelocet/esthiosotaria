import Foundation
import UserNotifications
import RecallKit

/// Schedules local notifications for new chain-tier recall matches.
/// Local-first: no server, no account. (Cross-device sync via CloudKit
/// is a post-MVP phase — see plan.)
enum NotificationScheduler {

    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    /// Notifies about chain-tier matches the user hasn't seen yet.
    /// - Parameters:
    ///   - items: chain-tier recalls with the display label of matched stores
    ///   - seenIDs: recall ids already notified
    /// - Returns: ids newly notified (caller persists them)
    @discardableResult
    static func notifyNewChainMatches(
        _ items: [(recall: Recall, storeLabel: String)],
        seenIDs: Set<String>
    ) async -> [String] {
        guard !items.isEmpty else { return [] }
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
            return []
        }

        var notified: [String] = []
        for item in items where !seenIDs.contains(item.recall.id) {
            let content = UNMutableNotificationContent()
            content.title = "Recall could be at your store"
            content.body = "\(item.storeLabel): \(item.recall.shortProductName()) — \(item.recall.reasonSummary())"
            content.sound = .default
            content.userInfo = ["recallID": item.recall.id]

            let request = UNNotificationRequest(
                identifier: item.recall.id,
                content: content,
                trigger: nil) // deliver immediately
            try? await center.add(request)
            notified.append(item.recall.id)
        }
        return notified
    }
}

extension Recall {
    /// Short product label for notifications/cards.
    func shortProductName() -> String {
        let description = productDescription ?? "A food product"
        return description.count > 80 ? String(description.prefix(80)) + "…" : description
    }

    /// One-line plain-language reason.
    func reasonSummary() -> String {
        let reason = reasonForRecall ?? "See the FDA notice for details."
        return reason.count > 100 ? String(reason.prefix(100)) + "…" : reason
    }
}
