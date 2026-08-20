import Foundation
import Combine
import RecallKit

/// User selections persisted as JSON in Application Support.
/// Kept deliberately simple (no Core Data) — see plan §6.
@MainActor
final class UserSettingsStore: ObservableObject {

    struct Payload: Codable, Equatable {
        var selectedStores: [Store] = []
        var radiusMiles: Double = RecallKit.defaultRadiusMiles
        var stateAbbrev: String = "CA"
        var handledRecallIDs: [String] = []
        var onboardingComplete: Bool = false
        var chainNotificationsEnabled: Bool = true
        /// "Notify me when I enter one of my stores" — CoreLocation geofencing.
        var entryNotificationsEnabled: Bool = false
        /// Brand/firm display names the user has marked "not something I
        /// buy" — see `ProductKey`. Global, not per-store.
        var mutedProducts: [String] = []

        /// Defaults for a brand-new install.
        init() {}

        enum CodingKeys: String, CodingKey {
            case selectedStores, radiusMiles, stateAbbrev, handledRecallIDs
            case onboardingComplete, chainNotificationsEnabled, entryNotificationsEnabled, mutedProducts
        }

        /// Backward-compatible decode: every key is optional and falls back
        /// to the default, so a settings file written by an OLDER build
        /// (one that predates, say, `mutedProducts`) still decodes cleanly.
        /// The synthesized `Decodable` would instead throw on a missing key
        /// and ignore these default values, which — combined with the
        /// trailing `try?` in `init()` — silently reset the user's stores,
        /// onboarding, and handled recalls on upgrade.
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            selectedStores = try c.decodeIfPresent([Store].self, forKey: .selectedStores) ?? []
            radiusMiles = try c.decodeIfPresent(Double.self, forKey: .radiusMiles) ?? RecallKit.defaultRadiusMiles
            stateAbbrev = try c.decodeIfPresent(String.self, forKey: .stateAbbrev) ?? "CA"
            handledRecallIDs = try c.decodeIfPresent([String].self, forKey: .handledRecallIDs) ?? []
            onboardingComplete = try c.decodeIfPresent(Bool.self, forKey: .onboardingComplete) ?? false
            chainNotificationsEnabled = try c.decodeIfPresent(Bool.self, forKey: .chainNotificationsEnabled) ?? true
            entryNotificationsEnabled = try c.decodeIfPresent(Bool.self, forKey: .entryNotificationsEnabled) ?? false
            mutedProducts = try c.decodeIfPresent([String].self, forKey: .mutedProducts) ?? []
        }
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

    func isProductMuted(_ recall: Recall) -> Bool {
        ProductKey.isMuted(recall, mutedNames: payload.mutedProducts)
    }

    /// Mutes a brand/firm by display name (deduped case/whitespace-insensitively).
    func muteProduct(_ displayName: String) {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let key = ProductKey.normalize(trimmed)
        guard !payload.mutedProducts.contains(where: { ProductKey.normalize($0) == key }) else { return }
        payload.mutedProducts.append(trimmed)
    }

    /// Mutes the brand/firm behind a specific recall, if one can be determined.
    func muteProduct(from recall: Recall) {
        guard let name = ProductKey.displayName(for: recall) else { return }
        muteProduct(name)
    }

    func unmuteProduct(_ displayName: String) {
        let key = ProductKey.normalize(displayName)
        payload.mutedProducts.removeAll { ProductKey.normalize($0) == key }
    }

    // MARK: - Design support

    /// Pre-populated store for previews / design gallery (no file I/O).
    static func designState() -> UserSettingsStore {
        let store = UserSettingsStore()
        store.payload.selectedStores = MockData.fourStores
        store.payload.stateAbbrev = "CA"
        store.payload.onboardingComplete = true
        store.payload.mutedProducts = ["365 Everyday Value"]
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
