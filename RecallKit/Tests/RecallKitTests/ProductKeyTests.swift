import XCTest
@testable import RecallKit

final class ProductKeyTests: XCTestCase {

    func testPrefersBrandNameOverRecallingFirm() {
        let recall = Recall(id: "1", recallingFirm: "Costco Wholesale Corporation", brandNames: ["Kirkland Signature"])
        XCTAssertEqual(ProductKey.displayName(for: recall), "Kirkland Signature")
    }

    func testFallsBackToRecallingFirmWhenNoBrand() {
        let recall = Recall(id: "1", recallingFirm: "Grandview Meat Company", brandNames: nil)
        XCTAssertEqual(ProductKey.displayName(for: recall), "Grandview Meat Company")
    }

    func testFallsBackToRecallingFirmWhenBrandNamesEmpty() {
        let recall = Recall(id: "1", recallingFirm: "Grandview Meat Company", brandNames: ["", "   "])
        XCTAssertEqual(ProductKey.displayName(for: recall), "Grandview Meat Company")
    }

    func testNilWhenNeitherPresent() {
        let recall = Recall(id: "1", recallingFirm: nil, brandNames: nil)
        XCTAssertNil(ProductKey.displayName(for: recall))
    }

    func testIsMutedCaseAndWhitespaceInsensitive() {
        let recall = Recall(id: "1", brandNames: ["Kirkland Signature"])
        XCTAssertTrue(ProductKey.isMuted(recall, mutedNames: ["  kirkland signature  "]))
    }

    func testIsMutedFalseWhenNotInList() {
        let recall = Recall(id: "1", brandNames: ["Kirkland Signature"])
        XCTAssertFalse(ProductKey.isMuted(recall, mutedNames: ["365 Everyday Value"]))
    }

    func testIsMutedFalseWhenNoDisplayName() {
        let recall = Recall(id: "1", recallingFirm: nil, brandNames: nil)
        XCTAssertFalse(ProductKey.isMuted(recall, mutedNames: ["Anything"]))
    }
}
