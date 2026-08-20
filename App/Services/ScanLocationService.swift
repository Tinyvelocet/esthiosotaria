import Foundation
import CoreLocation
import RecallKit

/// One-shot "Scan this location" — check the NEAREST grocery store to the
/// device for recalls, using the same filtering/matching as the tracked
/// favorites. Nothing is persisted: no region monitoring, no store is added.
///
/// Behavior (per product decision, 2026-08):
/// - Tap Scan → uses the device's current location, discovers the nearest
///   store that is NOT already a favorite, then fetches + matches recalls for
///   that store with the same engine the favorites use (chain / regional /
///   hidden; muting respected).
/// - Shows results transiently. The store is not added and no region is kept.
@MainActor
final class ScanLocationService: NSObject, ObservableObject {

    /// The result of a completed scan. `nil` before any scan or after dismiss.
    struct Result: Identifiable {
        let store: Store
        let chainMatches: [RecallListViewModel.Item]
        let regionalMatches: [RecallListViewModel.Item]
        let lastUpdated: Date

        var id: String { store.id.uuidString }
    }

    @Published var result: Result?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let location = LocationService()
    private let discovery = StoreDiscoveryService()

    /// Runs a scan: nearest non-favorite store around the current location,
    /// matched against fresh recalls.
    func scan(excluding favoriteIDs: Set<UUID>, stateAbbrev: String, handledIDs: Set<String>, mutedProductNames: [String]) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let coordinate = try await location.requestCurrentLocation()

            await discovery.discoverStores(near: coordinate, radiusMiles: RecallKit.defaultRadiusMiles)
            // Discovery is distance-sorted by StoreMerger; pick the nearest
            // store we are not already tracking (or not in scope for "scan a"
            // when favorites overlap).
            let candidate = discovery.discoveredStores.first(where: { !favoriteIDs.contains($0.id) }) ?? discovery.discoveredStores.first
            guard let store = candidate else {
                errorMessage = "Couldn't find a nearby store."
                return
            }

            // Match fresh recall.
            let recalls = try await fetchAllRecalls()

            let engine = MatchingEngine(userState: stateAbbrev)
            var chain: [RecallListViewModel.Item] = []
            var regional: [RecallListViewModel.Item] = []
            for recall in recalls where !handledIDs.contains(recall.id) {
                let rel = engine.relevance(for: recall, stores: [store])
                switch rel.tier {
                case .chain: chain.append(RecallListViewModel.Item(recall: recall, relevance: rel))
                case .regional: regional.append(RecallListViewModel.Item(recall: recall, relevance: rel))
                case .none: break
                }
            }
            // Respect muted products like the favorites views do.
            chain = chain.filter { !ProductKey.isMuted($0.recall, mutedNames: mutedProductNames) }
            regional = regional.filter { !ProductKey.isMuted($0.recall, mutedNames: mutedProductNames) }
            chain.sort(by: Self.sortItems)
            regional.sort(by: Self.sortItems)

            result = Result(store: store, chainMatches: chain, regionalMatches: regional, lastUpdated: Date())
        } catch let e {
            errorMessage = e.localizedDescription
            result = nil
        } catch {
            errorMessage = "Couldn't scan this location."
            result = nil
        }
    }

    private static func sortItems(_ a: RecallListViewModel.Item, _ b: RecallListViewModel.Item) -> Bool {
        let severityOrder: [Recall.Classification?: Int] = [.classI: 0, .classII: 1, .classIII: 2, .unknown: 3, nil: 4]
        let sa = severityOrder[a.recall.classification, default: 4]
        let sb = severityOrder[b.recall.classification, default: 4]
        if sa != sb { return sa < sb }
        return (a.recall.reportDate ?? "") > (b.recall.reportDate ?? "")
    }

    /// Fetches openFDA + fast FDA + FSIS (same decomposition as the app's
    /// main refresh), deduplicated.
    private func fetchAllRecalls() async throws -> [Recall] {
        async let fda = FDAService().fetchOngoing(limit: 500)
        let fsis = (try? await FSISService().fetchRecalls()) ?? []
        let fast = (try? await FDAFeedService().fetchRecalls()) ?? []
        let structuredFda = try await fda
        return RecallDeduplicator.mergeFast(fast, intoBase: structuredFda) + fsis
    }
}