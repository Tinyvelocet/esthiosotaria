import Foundation
import Combine
import RecallKit

/// User selections persisted as JSON in Application Support.
/// Kept deliberately simple (no Core Data) — see plan §6.
@MainActor
final class UserSettingsStore: ObservableObject {

    struct Payload: Codable {
        var selectedStores: [Store] = []
        var radiusMiles: Double = RecallKit.defaultRadiusMiles
        var stateAbbrev: String = "CA"
        var handledRecallIDs: [String] = []
        var onboardingComplete: Bool = false
        var chainNotificationsEnabled: Bool = true
    }

    @Published var payload: Payload {
        didSet { scheduleSave() }
    }

    private var saveTask: Task<Void, Never>?

    private static var fileURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("EsthioSotaria", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("settings.json")
    }

    init() {
        if let data = try? Data(contentsOf: Self.fileURL),
           let decoded = try? JSONDecoder().decode(Payload.self, from: data) {
            payload = decoded
        } else {
            payload = Payload()
        }
    }

    // Convenience accessors

    var selectedStores: [Store] { payload.selectedStores }
    var radiusMiles: Double { payload.radiusMiles }
    var isOnboardingComplete: Bool { payload.onboardingComplete }

    func addStore(_ store: Store) {
        guard payload.selectedStores.count < RecallKit.maxSelectedStores else { return }
        guard !payload.selectedStores.contains(where: { $0.id == store.id }) else { return }
        payload.selectedStores.append(store)
    }

    func removeStore(_ store: Store) {
        payload.selectedStores.removeAll { $0.id == store.id }
    }

    func isHandled(_ recall: Recall) -> Bool {
        payload.handledRecallIDs.contains(recall.id)
    }

    func setHandled(_ recall: Recall, _ handled: Bool) {
        if handled {
            payload.handledRecallIDs.append(recall.id)
        } else {
            payload.handledRecallIDs.removeAll { $0 == recall.id }
        }
    }

    func finishOnboarding() {
        payload.onboardingComplete = true
    }

    // MARK: - Design support

    /// Pre-populated store for previews / design gallery (no file I/O).
    static func designState() -> UserSettingsStore {
        let store = UserSettingsStore()
        store.payload.selectedStores = MockData.fourStores
        store.payload.stateAbbrev = "CA"
        store.payload.onboardingComplete = true
        return store
    }

    // MARK: - Persistence

    private func scheduleSave() {
        saveTask?.cancel()
        let snapshot = payload
        saveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            if let data = try? JSONEncoder().encode(snapshot) {
                try? data.write(to: Self.fileURL, options: .atomic)
            }
            _ = self
        }
    }
}
