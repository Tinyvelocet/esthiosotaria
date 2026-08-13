import Foundation
import RecallKit

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

    func refresh(stores: [Store], stateAbbrev: String, handledIDs: Set<String>) async {
        state = .loading
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
}
