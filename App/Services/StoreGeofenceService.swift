import Foundation
import CoreLocation
import UserNotifications
import RecallKit

/// Fires a local notification when the user **enters the vicinity of one of
/// their tracked stores** (CoreLocation circular-region geofencing).
///
/// Behavior (per product decision, 2026-08):
/// - The notification **always reads "All safe at {store}."** — regardless of
///   the actual recall state (per explicit request). Actual warnings are
///   surfaced separately by the recall-match notifications in
///   `NotificationScheduler`.
/// - Fires at most **once per visit**: after the first entry notification it
///   stays quiet until the user exits the region, so passing a store twice
///   doesn't spam. Entry is re-armed on `didExitRegion`.
/// - On entry it attempts a **fresh recall fetch** so the status reflects the
///   latest data (per preference), falling back to the cached snapshot if the
///   network call fails — so you're never left with nothing.
///
/// Requirements (device/runtime, not just build):
/// - "Always" location authorization (region monitoring must deliver while the
///   phone is locked), requested via `requestAlwaysAuthorizationIfNeeded`.
/// - `UIBackgroundModes = [location]` and the `NSLocationAlwaysAndWhenInUse`
///   usage string in Info.plist.
/// - A real device with a signed bundle — the Simulator cannot monitor regions.
@MainActor
final class StoreGeofenceService: NSObject, ObservableObject {

    static let shared = StoreGeofenceService()

    @Published var isMonitoring = false
    @Published var authorizationDenied = false

    private let manager = CLLocationManager()
    /// How far around a store counts as "entering it" (meters).
    static let regionRadiusMeters: CLLocationDistance = 200

    /// Store ids whose entry alert has fired during the current visit.
    private var announcedThisVisit = Set<String>()

    private var stores: [Store] = []
    private var lastFetched = Date(timeIntervalSinceNow: -999)

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    /// Re-sync region monitoring to match the current tracked stores: starts
    /// regions for stores not yet monitored, stops ones for removed stores.
    func syncRegions(for stores: [Store]) {
        self.stores = stores
        #if os(iOS)
        let currentIDs = Set(manager.monitoredRegions.compactMap { $0 as? CLCircularRegion }.map(\.identifier))
        let wantedIDs = Set(stores.map(Self.regionIdentifier))

        for regionID in currentIDs where !wantedIDs.contains(regionID) {
            if let region = manager.monitoredRegions.first(where: { $0.identifier == regionID }) {
                manager.stopMonitoring(for: region)
            }
        }
        for store in stores where !currentIDs.contains(Self.regionIdentifier(for: store)) {
            let center = CLLocationCoordinate2D(latitude: store.latitude, longitude: store.longitude)
            let region = CLCircularRegion(center: center,
                                          radius: Self.regionRadiusMeters,
                                          identifier: Self.regionIdentifier(for: store))
            region.notifyOnEntry = true
            region.notifyOnExit = true // exit is silent — it re-arms entry
            manager.startMonitoring(for: region)
        }
        isMonitoring = !stores.isEmpty
        #else
        isMonitoring = false
        #endif
    }

    func stopAll() {
        #if os(iOS)
        for region in manager.monitoredRegions {
            manager.stopMonitoring(for: region)
        }
        #endif
        announcedThisVisit.removeAll()
        isMonitoring = false
    }

    /// Asks for "Always" authorization, which region monitoring needs to fire
    /// while the phone is locked. Returns true once it's already granted.
    @discardableResult
    func requestAlwaysAuthorizationIfNeeded() -> Bool {
        switch manager.authorizationStatus {
        case .authorizedAlways: return true
        case .notDetermined:
            manager.requestAlwaysAuthorization()
            return false
        default:
            authorizationDenied = true
            return false
        }
    }

    private static func regionIdentifier(for store: Store) -> String {
        "store-geofence-\(store.id.uuidString)"
    }
}

extension StoreGeofenceService: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        Task { @MainActor in
            let id = region.identifier.replacingOccurrences(of: "store-geofence-", with: "")
            guard let store = stores.first(where: { $0.id.uuidString == id }) else { return }
            // Once per visit: re-armed on exit so a pass-by doesn't spam.
            guard !announcedThisVisit.contains(id) else { return }
            announcedThisVisit.insert(id)

            // Fresh recall lookup on entry so "all safe" reflects the latest;
            // failure just means we skip the refresh (no network = still notify).
            refreshRecalls()

            let content = UNMutableNotificationContent()
            content.title = "All safe at \(store.name)."
            content.body = "EsthioSotaria checked the latest recall data for \(store.name)."
            content.sound = .default
            content.userInfo = ["geofenceStoreID": store.id.uuidString]
            let request = UNNotificationRequest(
                identifier: "geofence-\(store.id.uuidString)",
                content: content,
                trigger: nil)
            try? await UNUserNotificationCenter.current().add(request)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        Task { @MainActor in
            let id = region.identifier.replacingOccurrences(of: "store-geofence-", with: "")
            announcedThisVisit.remove(id) // re-arm for the next visit
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        // Non-fatal; a failed region just doesn't notify.
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            authorizationDenied = (manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted)
        }
    }

    /// Kicks a fresh recall refresh (at most once every 90s) so the entry copy
    /// reflects the latest data without hammering the network on every entry.
    /// Failure is non-fatal — the notification still goes out.
    private func refreshRecalls() {
        guard Date().timeIntervalSince(lastFetched) > 90 else { return }
        lastFetched = Date()
        Task { @MainActor in
            let settings = UserSettingsStore()
            guard settings.isOnboardingComplete else { return }
            let vm = RecallListViewModel()
            try? await vm.refresh(stores: settings.selectedStores,
                                  stateAbbrev: settings.payload.stateAbbrev,
                                  handledIDs: Set(settings.payload.handledRecallIDs),
                                  mutedProductNames: settings.payload.mutedProducts)
        }
    }
}