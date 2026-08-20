import Foundation
import RecallKit

#if !os(iOS)
import SwiftUI

/// Build-time stand-in for `StoreGeofenceService` (the real one is iOS-only)
/// so the macOS ScreenshotGen tool can compile views that reference it
/// (RecallListView, SettingsView). It never runs — rendering only needs a type.
@MainActor
final class StoreGeofenceService: ObservableObject {
    static let shared = StoreGeofenceService()
    @Published var isMonitoring = false
    @Published var authorizationDenied = false
    func syncRegions(for stores: [Store]) {}
    func stopAll() {}
    func requestAlwaysAuthorizationIfNeeded() -> Bool { false }
}
#endif