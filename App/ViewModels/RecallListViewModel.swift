import Foundation
import RecallKit
import WidgetKit

/// Fetches ongoing recalls, matches them against the user's stores,
/// and exposes sorted, filtered results. Pure app-layer glue over RecallKit.
@MainActor
final class RecallListViewModel: ObservableObject {

    struct Item: Identifiable, Hashable {
        let recall: Recall
        let relevance: Relevance
        var id: String { recall.id }

        var isChainMatch: Bool { relevance.tier == .chain }
    }

    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    @Published var chainMatches: [Item] = []
    @Published var regionalMatches: [Item] = []
    @Published var state: LoadState = .idle
    @Published var lastUpdated: Date?
    /// True when the FSIS (USDA meat/poultry) feed was unavailable this run
    /// — FDA data still shown, but meat coverage may be incomplete.
    @Published var fsisUnavailable = false

    private let service: FDAService
    private let fsisService: FSISService

    init(service: FDAService = FDAService(), fsisService: FSISService = FSISService()) {
        self.service = service
        self.fsisService = fsisService
    }

    func refresh(stores: [Store], stateAbbrev: String, handledIDs: Set<String>, mutedProductNames: [String] = []) async {
        state = .loading
        self.stores = stores
        do {
            // Fetch both sources in parallel; FSIS failure is non-fatal
            // (its site bot-gates some networks — degrade to FDA-only).
            async let fdaRecalls = service.fetchOngoing(limit: 500)
            let fsisRecalls = (try? await fsisService.fetchRecalls()) ?? []
            fsisUnavailable = fsisRecalls.isEmpty
            let recalls = try await fdaRecalls + fsisRecalls

            let engine = MatchingEngine(userState: stateAbbrev)

            var chain: [Item] = []
            var regional: [Item] = []
            for recall in recalls where !handledIDs.contains(recall.id) {
                let relevance = engine.relevance(for: recall, stores: stores)
                switch relevance.tier {
                case .chain: chain.append(Item(recall: recall, relevance: relevance))
                case .regional: regional.append(Item(recall: recall, relevance: relevance))
                case .none: continue
                }
            }
            // Sort: severity (Class I first), then newest report date.
            chain.sort(by: Self.sortItems)
            regional.sort(by: Self.sortItems)

            chainMatches = chain
            regionalMatches = regional
            lastUpdated = Date()
            state = .loaded

            // Publish the matched results for the widget (App Group cache).
            publishSnapshot(chain: chain, regional: regional, stateAbbrev: stateAbbrev, mutedProductNames: mutedProductNames)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private static func sortItems(_ a: Item, _ b: Item) -> Bool {
        let severityOrder: [Recall.Classification?: Int] = [.classI: 0, .classII: 1, .classIII: 2, .unknown: 3, nil: 4]
        let sa = severityOrder[a.recall.classification, default: 4]
        let sb = severityOrder[b.recall.classification, default: 4]
        if sa != sb { return sa < sb }
        return (a.recall.reportDate ?? "") > (b.recall.reportDate ?? "")
    }

    // MARK: - Widget cache

    /// Writes the matched recalls to the shared App Group cache so the
    /// widget can render without doing its own network calls. Muted
    /// products are left out entirely — the widget is a glance surface
    /// with no way to review/unmute, so it should only ever show what's
    /// actually urgent.
    private func publishSnapshot(chain: [Item], regional: [Item], stateAbbrev: String, mutedProductNames: [String]) {
        guard let cache = RecallCache() else { return } // entitlement missing — degrade silently
        let storeNames: [UUID: String] = Dictionary(uniqueKeysWithValues: stores.map { ($0.id, $0.name) })
        let activeChain = chain.filter { !ProductKey.isMuted($0.recall, mutedNames: mutedProductNames) }
        let activeRegional = regional.filter { !ProductKey.isMuted($0.recall, mutedNames: mutedProductNames) }
        let snapshot = RecallSnapshot(
            generatedAt: Date(),
            stateAbbrev: stateAbbrev,
            chainItems: activeChain.map { item in
                RecallSnapshot.Item(
                    recall: item.recall,
                    tier: .chain,
                    matchedStoreNames: item.relevance.matchedStoreIDs.compactMap { storeNames[$0] })
            },
            regionalItems: activeRegional.map { item in
                RecallSnapshot.Item(recall: item.recall, tier: .regional, matchedStoreNames: [])
            },
            fsisUnavailable: fsisUnavailable)
        try? cache.save(snapshot)
        // Ask WidgetKit to redraw with the fresh snapshot.
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// The stores used for the most recent refresh (kept for snapshot names).
    private var stores: [Store] = []

    // MARK: - Design support

    /// Builds a view model pre-populated with mock data for previews and
    /// the design gallery. No network access.
    static func designState() -> RecallListViewModel {
        let vm = RecallListViewModel()
        let stores = MockData.fourStores
        vm.chainMatches = items(for: MockData.chainMatchRecalls, stores: stores)
        vm.regionalMatches = items(for: MockData.regionalRecalls, stores: stores)
        vm.lastUpdated = Date()
        vm.state = .loaded
        vm.fsisUnavailable = false
        return vm
    }

    private static func items(for recalls: [Recall], stores: [Store]) -> [Item] {
        let engine = MatchingEngine(userState: "CA")
        return recalls.map { Item(recall: $0, relevance: engine.relevance(for: $0, stores: stores)) }
    }
}
