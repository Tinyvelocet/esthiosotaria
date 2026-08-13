import Foundation
import WidgetKit
import RecallKit

/// Timeline provider: the widget is a *reader* of the snapshot the main app
/// maintains. No network calls from the widget itself — that keeps widget
/// behavior predictable under WidgetKit's refresh budget and makes the app
/// the single owner of matching logic.
struct RecallTimelineProvider: TimelineProvider {

    func placeholder(in context: Context) -> RecallEntry {
        RecallEntry(date: Date(), snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (RecallEntry) -> Void) {
        completion(RecallEntry(date: Date(), snapshot: loadSnapshot()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RecallEntry>) -> Void) {
        let snapshot = loadSnapshot()
        let entry = RecallEntry(date: Date(), snapshot: snapshot)
        // Ask WidgetKit to consider a refresh in ~2 hours; the system
        // decides based on its budget. Fresh data also lands whenever the
        // app refreshes (it reloads the timeline).
        let refresh = Calendar.current.date(byAdding: .hour, value: 2, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }

    private func loadSnapshot() -> RecallSnapshot {
        RecallCache()?.load() ?? .empty
    }
}

struct RecallEntry: TimelineEntry {
    let date: Date
    let snapshot: RecallSnapshot
}

extension RecallSnapshot {
    static let empty = RecallSnapshot(
        generatedAt: .distantPast, stateAbbrev: "", chainItems: [], regionalItems: [], fsisUnavailable: false)

    /// Placeholder content for the widget gallery / redacted rendering.
    static let placeholder = RecallSnapshot(
        generatedAt: Date(),
        stateAbbrev: "CA",
        chainItems: [
            Item(
                recall: Recall(
                    id: "PLACEHOLDER-1",
                    classification: .classI,
                    recallingFirm: "Costco Wholesale",
                    productDescription: "Kirkland Signature Madeleines 12 count",
                    reasonForRecall: "Possible Listeria contamination.",
                    reportDate: "20260805"),
                tier: .chain,
                matchedStoreNames: ["Costco"]),
        ],
        regionalItems: [],
        fsisUnavailable: false)
}
