import Foundation
import XCTest
@testable import RecallKit

final class RecallCacheTests: XCTestCase {

    private func makeSnapshot() -> RecallSnapshot {
        let recall = Recall(
            id: "F-0480-2026",
            status: "Ongoing",
            classification: .classI,
            recallingFirm: "Costco Wholesale Corporation",
            productDescription: "Kirkland Signature Traditional Madeleines",
            reasonForRecall: "Possible Listeria contamination.",
            distributionPattern: "Nationwide",
            reportDate: "20260805",
            brandNames: ["Kirkland Signature"])
        let item = RecallSnapshot.Item(
            recall: recall,
            tier: .chain,
            matchedStoreNames: ["Costco Wholesale"])
        return RecallSnapshot(
            generatedAt: Date(timeIntervalSince1970: 1_786_700_000),
            stateAbbrev: "CA",
            chainItems: [item],
            regionalItems: [],
            fsisUnavailable: false)
    }

    func testSnapshotRoundTrip() throws {
        let original = makeSnapshot()
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(RecallSnapshot.self, from: data)
        XCTAssertEqual(decoded.chainItems.count, 1)
        XCTAssertEqual(decoded.chainItems[0].recall.id, "F-0480-2026")
        XCTAssertEqual(decoded.chainItems[0].tier, .chain)
        XCTAssertEqual(decoded.chainItems[0].matchedStoreNames, ["Costco Wholesale"])
        XCTAssertEqual(decoded.stateAbbrev, "CA")
    }

    func testSaveAndLoad() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("RecallCacheTests-\(UUID().uuidString)")
        let cache = RecallCache(directory: dir)

        let snapshot = makeSnapshot()
        try cache.save(snapshot)

        let loaded = try XCTUnwrap(cache.load())
        XCTAssertEqual(loaded.chainItems.first?.recall.id, "F-0480-2026")
        XCTAssertEqual(loaded.generatedAt, snapshot.generatedAt)
    }

    func testLoadReturnsNilWhenEmpty() {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("RecallCacheTests-\(UUID().uuidString)")
        let cache = RecallCache(directory: dir)
        XCTAssertNil(cache.load())
    }

    func testStaleCheck() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("RecallCacheTests-\(UUID().uuidString)")
        let cache = RecallCache(directory: dir)

        var stale = makeSnapshot()
        stale.generatedAt = Date(timeIntervalSinceNow: -25 * 3600) // 25h old
        try cache.save(stale)
        XCTAssertFalse(cache.isFresh(maxAge: 24 * 3600))

        var fresh = makeSnapshot()
        fresh.generatedAt = Date()
        try cache.save(fresh)
        XCTAssertTrue(cache.isFresh(maxAge: 24 * 3600))
    }
}
