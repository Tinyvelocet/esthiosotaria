import Foundation
import RecallKit
#if os(iOS)
import CloudKit
#endif

/// CloudKit sync for the user's settings state — so one iPhone's handled /
/// muted / store selection reliably reaches the user's other iOS devices
/// (iPhone + iPad) via iCloud, and each device can be woken by a CloudKit
/// silent push ("remote-notification") to re-pull.
///
/// What syncs (the UI-state the user actually owns and edits everywhere):
/// - handledRecallIDs (recalls marked "I've handled this")
/// - mutedProducts (brands muted anywhere)
/// - selectedStores, radius, state abbreviation, notification toggles
///
/// What does NOT sync: the recall feed itself — that's public data each
/// device fetches fresh from FDA/USDA, so there's nothing to mirror.
///
/// The service is **state-free**: callers pass the live payload in (`pull`)
/// and hand back the pulled payload (`pull`), so it never holds a stale copy
/// of the app's own `UserSettingsStore`.
///
/// NOTE: activation REQUIRES the iCloud capability enabled in the Xcode GUI
/// (register the container id + generate the entitlement). This file is the
/// code half; the entitlement half is a one-time Xcode step, and runtime
/// testing needs a real iCloud account + two devices. The service degrades
/// to local-only when CloudKit isn't available (simulator / unsigned), so the
/// app never breaks without it.
@MainActor
final class CloudKitSyncService: ObservableObject {

    /// A single zone keeps all user-sync records in one place.
    static let zoneID = CKRecordZone.ID(zoneName: "EsthioSotariaSync", ownerName: CKCurrentUserDefaultName)
    static let recordType = "Settings"
    static let recordName = "settings"

    @Published var lastSyncStatus: String?
    @Published var isSupported = false

    #if os(iOS)
    private var activated = false
    #endif

    /// The app's iCloud container. Must be registered in Xcode's iCloud
    /// capabilities + an entitlement generated — a one-time GUI step.
    private var container: CKContainer {
        #if os(iOS)
        CKContainer.default()
        #else
        preconditionFailure("CloudKit is iOS-only")
        #endif
    }

    /// Prime the zone + silent-push subscription. Idempotent. Safe to call
    /// once at app launch; returns without error if CloudKit is unavailable.
    func activate() async {
        #if os(iOS)
        guard !activated else { return }
        activated = true
        let db = container.privateCloudDatabase
        do {
            // Ensure the zone exists (create on first run).
            let zones = try await db.recordZones(for: [Self.zoneID])
            if zones[Self.zoneID] == nil {
                _ = try await db.modifyRecordZones(saving: [CKRecordZone(zoneID: Self.zoneID)], deleting: [])
            }

            // Register the silent-push subscription so another device's write
            // wakes this device to re-pull.
            let sub = CKQuerySubscription(
                recordType: Self.recordType,
                predicate: NSPredicate(value: true),
                subscriptionID: "sync-settings",
                options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion])
            var info: CKSubscription.NotificationInfo = sub.notificationInfo ?? CKSubscription.NotificationInfo()
            info.shouldSendContentAvailable = true // background delivery
            sub.notificationInfo = info
            _ = try await db.modifySubscriptions(saving: [sub], deleting: [])

            isSupported = true
        } catch {
            isSupported = false
            lastSyncStatus = "CloudKit unavailable — staying local-only."
        }
        #endif
    }

    /// Push the given payload to iCloud (last-writer-wins).
    func push(_ snapshot: UserSettingsStore.Payload) async -> String? {
        #if os(iOS)
        guard isSupported else { return nil }
        let db = container.privateCloudDatabase
        let record = CKRecord(recordType: Self.recordType,
                              recordID: CKRecord.ID(__recordName: Self.recordName, zoneID: Self.zoneID))
        record["payload"] = Self.encode(snapshot)
        do {
            _ = try await db.modifyRecords(saving: [record], deleting: [],
                                           savePolicy: .ifServerRecordUnchanged, atomically: false)
            lastSyncStatus = "Synced."
            return nil
        } catch {
            lastSyncStatus = "Sync failed — won't reach other devices."
            return error.localizedDescription
        }
        #else
        return nil
        #endif
    }

    /// Pull the remote payload and apply it to `target` (last writer wins).
    /// Returns true if a remote payload was found and applied.
    func pull(_ target: inout UserSettingsStore.Payload) async -> Bool {
        #if os(iOS)
        guard isSupported else { return false }
        let db = container.privateCloudDatabase
        let q = CKQuery(recordType: Self.recordType, predicate: NSPredicate(value: true))
        do {
            let (matchResults, _) = try await db.records(matching: q, inZoneWith: Self.zoneID)
            var applied = false
            for (_, outcome) in matchResults {
                if case .success(let record) = outcome,
                   let payload = record["payload"] as? String {
                    if let decoded = Self.decode(payload) {
                        target = decoded
                        applied = true
                    }
                }
            }
            lastSyncStatus = applied ? "Synced latest from iCloud." : "No remote settings yet."
            return applied
        } catch {
            lastSyncStatus = nil
            return false
        }
        #else
        return false
        #endif
    }
}

/// Self-contained settings <-> JSON (no coupling between App and CloudKit).
extension CloudKitSyncService {
    static func encode(_ snapshot: UserSettingsStore.Payload) -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try? encoder.encode(snapshot)
        return data.map { String(decoding: $0, as: UTF8.self) } ?? "{}"
    }

    static func decode(_ json: String) -> UserSettingsStore.Payload? {
        if let data = try? Data(json.utf8),
           let decoded = try? JSONDecoder().decode(UserSettingsStore.Payload.self, from: data) {
            return decoded
        }
        return nil
    }
}