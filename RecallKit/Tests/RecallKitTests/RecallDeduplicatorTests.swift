import XCTest
@testable import RecallKit

final class RecallDeduplicatorTests: XCTestCase {

    private func fdaRecall(id: String, slug: String, classification: Recall.Classification?) -> Recall {
        Recall(id: id,
               classification: classification,
               recallingFirm: "Firm \(id)",
               distributionPattern: "Nationwide",
               urlString: "https://www.fda.gov/safety/recalls-market-withdrawals-safety-alerts/\(slug)")
    }

    private func fastRecall(id: String, slug: String, title: String) -> Recall {
        Recall(id: id,
               productDescription: title,
               reasonForRecall: "Possible contamination.",
               urlString: "https://www.fda.gov/safety/recalls-market-withdrawals-safety-alerts/\(slug)")
    }

    func testFastDuplicateDroppedInFavorOfStructured() {
        // Same notice, once structured (classified) and once fresh-fast.
        let base = [fdaRecall(id: "F-0001-2026", slug: "palmer-candy-recalls", classification: .classI)]
        let fast = [fastRecall(id: "FDA-RSS-ABC", slug: "palmer-candy-recalls", title: "Palmer Candy Company Recalls")]
        let merged = RecallDeduplicator.mergeFast(fast, intoBase: base)
        XCTAssertEqual(merged.count, 1)
        XCTAssertEqual(merged.first?.id, "F-0001-2026") // structured wins
    }

    func testFastOnlyNoticeIsAppended() {
        // openFDA hasn't indexed this notice yet — the fast feed surfaces it.
        let base = [fdaRecall(id: "F-0002-2026", slug: "some-other-recall", classification: .classII)]
        let fast = [fastRecall(id: "FDA-RSS-ABC", slug: "brand-new-recall-today", title: "Fresh Recall")]
        let merged = RecallDeduplicator.mergeFast(fast, intoBase: base)
        XCTAssertEqual(merged.count, 2)
        XCTAssertEqual(merged.last?.id, "FDA-RSS-ABC")
    }

    func testDistinctNoticesBothKept() {
        let base = [fdaRecall(id: "F-0003-2026", slug: "recall-a", classification: .classI)]
        let fast = [fastRecall(id: "FDA-RSS-B", slug: "recall-b", title: "Recall B")]
        XCTAssertEqual(RecallDeduplicator.mergeFast(fast, intoBase: base).count, 2)
    }

    func testNoticesWithoutURLAreKept() {
        let base = [Recall(id: "F-0004-2026", classification: .classI)]
        let fast = [Recall(id: "FDA-RSS-C", productDescription: "No url")]
        XCTAssertEqual(RecallDeduplicator.mergeFast(fast, intoBase: base).count, 2)
    }

    func testSlugIgnoresQueryAndPathPrefix() {
        XCTAssertEqual(
            RecallDeduplicator.noticeSlug("https://www.fda.gov/safety/recalls-market-withdrawals-safety-alerts/my-recall"),
            "my-recall")
        XCTAssertEqual(
            RecallDeduplicator.noticeSlug("http://www.fda.gov/safety/.../my-recall?utm=1"),
            "my-recall")
        XCTAssertNil(RecallDeduplicator.noticeSlug(nil))
    }
}