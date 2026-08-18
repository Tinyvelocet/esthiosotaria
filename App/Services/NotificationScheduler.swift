import Foundation
import UserNotifications
import RecallKit

/// Schedules local notifications for new chain-tier and severe-regional
/// recall matches. Local-first: no server, no account. (Cross-device sync
/// via CloudKit is a post-MVP phase — see plan.)
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
        await notify(items.map { item in
            (recall: item.recall,
             title: "Recall could be at your store",
             body: "\(item.storeLabel): \(item.recall.shortProductName()) — \(item.recall.reasonSummary())")
        }, seenIDs: seenIDs)
    }

    /// Notifies about serious (Class I/II) regional matches the user hasn't
    /// seen yet — not claimed to be at any specific store, so the copy
    /// stays honest about that.
    /// - Returns: ids newly notified (caller persists them)
    @discardableResult
    static func notifyNewRegionalMatches(
        _ recalls: [Recall],
        seenIDs: Set<String>
    ) async -> [String] {
        await notify(recalls.map { recall in
            (recall: recall,
             title: "Serious recall in your area",
             body: "\(recall.shortProductName()) — \(recall.reasonSummary())")
        }, seenIDs: seenIDs)
    }

    private static func notify(
        _ items: [(recall: Recall, title: String, body: String)],
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
            content.title = item.title
            content.body = item.body
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
