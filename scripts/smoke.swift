// End-to-end smoke test: live FDA data through the real matching engine,
// simulating a Bay Area user's setup (Costco, Whole Foods, Piazza's, Trader Joe's).
import Foundation

// Load RecallKit sources directly for the smoke run.
let stores = [
    Store(name: "Costco Wholesale", chain: "costco", latitude: 37.40, longitude: -122.11),
    Store(name: "Whole Foods Market", chain: "wholefoods", latitude: 37.44, longitude: -122.17),
    Store(name: "Piazza's Fine Foods", chain: nil, latitude: 37.42, longitude: -122.13),
    Store(name: "Trader Joe's", chain: "traderjoes", latitude: 37.42, longitude: -122.16),
]
let engine = MatchingEngine(userState: "CA")
let service = FDAService()

Task {
    do {
        let recalls = try await service.fetchOngoing(limit: 500)
        print("Fetched \(recalls.count) ongoing recalls from openFDA (live)")

        var chain: [Recall] = [], regional: [Recall] = []
        for recall in recalls {
            let rel = engine.relevance(for: recall, stores: stores)
            switch rel.tier {
            case .chain: chain.append(recall)
            case .regional: regional.append(recall)
            case .none: break
            }
        }
        print("Chain-tier matches (escalated): \(chain.count)")
        for r in chain.prefix(6) {
            print("  🔴 \(r.classification?.rawValue ?? "?") | \(r.recallingFirm ?? "?") | \(r.productDescription?.prefix(70) ?? "")")
        }
        print("Regional (CA) matches: \(regional.count)")
        for r in regional.prefix(4) {
            print("  🟠 \(r.classification?.rawValue ?? "?") | \(r.productDescription?.prefix(70) ?? "")")
        }
        print("Hidden (out of area): \(recalls.count - chain.count - regional.count)")
        exit(0)
    } catch {
        print("ERROR:", error)
        exit(1)
    }
}
RunLoop.main.run(until: Date(timeIntervalSinceNow: 30))
exit(1)
