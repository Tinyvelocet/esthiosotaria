import Foundation
#if os(iOS)
import BackgroundTasks
import WidgetKit

/// Keeps the widget cache fresh without the user opening the app (iOS only).
///
/// Registers a BGAppRefreshTask that re-runs the match pipeline and
/// republishes the shared snapshot. The system decides when it runs
/// (typically every few hours when the device is idle); each run also
/// reschedules the next one.
///
/// macOS has no equivalent background API — the Mac widget refreshes
/// whenever the Mac app runs (and on its own 2-hour timeline ask).
enum BackgroundRefresh {

    static let taskID = "dev.tinyvelocet.esthiosotaria.refresh"

    private static var currentTask: Task<Void, Never>?

    /// Call once at app launch.
    static func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskID, using: nil) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            // The scheduler callback runs on a background queue; hop to main
            // before calling the @MainActor handle().
            Task { @MainActor in handle(refreshTask) }
        }
    }

    /// Call whenever the app moves to the background.
    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: taskID)
        // No earlier than 1 hour from now; the system may delay further.
        request.earliestBeginDate = Date(timeIntervalSinceNow: 3600)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            // Non-fatal: the widget still updates whenever the app is opened.
        }
    }

    @MainActor
    private static func handle(_ task: BGAppRefreshTask) {
        schedule() // always chain the next refresh

        currentTask?.cancel()
        currentTask = Task {
            task.expirationHandler = { currentTask?.cancel() }
            defer { task.setTaskCompleted(success: true) }

            let settings = UserSettingsStore()
            guard settings.isOnboardingComplete, !settings.selectedStores.isEmpty else { return }
            let viewModel = RecallListViewModel()
            await viewModel.refresh(
                stores: settings.selectedStores,
                stateAbbrev: settings.payload.stateAbbrev,
                handledIDs: Set(settings.payload.handledRecallIDs),
                // Pass muted products so the widget snapshot respects mutes:
                // otherwise a background refresh (the common path on a phone)
                // republishes silenced products back into the widget.
                mutedProductNames: settings.payload.mutedProducts)
            // refresh() republishes the snapshot and reloads widget timelines.
        }
    }
}
#endif
