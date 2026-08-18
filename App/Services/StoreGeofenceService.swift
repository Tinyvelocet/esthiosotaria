import Foundation
import CoreLocation
import UserNotifications
import RecallKit

/// Fires a local notification when the user **enters the vicinity of one of
/// their tracked stores** (CoreLocation circular-region geofencing).
///
/// This is a *proximity* notification — entirely separate from the
/// recall-data notifications in `NotificationScheduler`. It exists so you can
/// get a tap on the shoulder when you're physically at one of your 4 stores.
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
    private var stores: [Store] = []

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
            region.notifyOnExit = true // exit is a silent no-op; it re-arms entry for the next visit
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
        isMonitoring = false
    }

    /// Asks for "Always" authorization, which region monitoring needs to fire
    /// while the phone is locked. Returns true once it's already granted.
    @discardableResult
    func requestAlwaysAuthorizationIfNeeded() -> Bool {
        switch manager.authorizationStatus {
        case .authorizedAlways:
            return true
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
            let content = UNMutableNotificationContent()
            content.title = "You're near \(store.name)"
            content.body = "Tap to check the current recalls at this store."
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
        // Silent — the network exists only so a later re-entry can notify again.
    }

    nonisolated func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        // Non-fatal; a failed region just doesn't notify.
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            authorizationDenied = (manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted)
        }
    }
}