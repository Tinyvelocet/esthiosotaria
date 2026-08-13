import Foundation
import XCTest
@testable import RecallKit

final class MatchingEngineTests: XCTestCase {

    private let costco = Store(name: "Costco Wholesale", chain: "costco", latitude: 37.4, longitude: -122.1)
    private let piazza = Store(name: "Piazza's Fine Foods", chain: nil, latitude: 37.42, longitude: -122.13)

    private func engine(state: String = "CA") -> MatchingEngine {
        MatchingEngine(userState: state)
    }

    // MARK: - Chain tier

    func testKirklandRecallMatchesSelectedCostco() {
        let recall = Recall(
            id: "F-1", classification: .classI,
            recallingFirm: "Costco Wholesale Corporation",
            productDescription: "Kirkland Signature Traditional Madeleines 12 Count",
            distributionPattern: "Nationwide")
        let rel = engine().relevance(for: recall, stores: [costco, piazza])
        XCTAssertEqual(rel.tier, .chain)
        XCTAssertEqual(rel.matchedStoreIDs, [costco.id])
    }

    func testWholeFoodsBrandMatchesWholeFoodsStore() {
        let wholeFoods = Store(name: "Whole Foods Market", chain: "wholefoods", latitude: 37.4, longitude: -122.1)
        let recall = Recall(
            id: "F-2", classification: .classII,
            recallingFirm: "Whole Foods Market",
            productDescription: "365 Everyday Value Organic Quinoa",
            distributionPattern: "CA, OR, WA")
        let rel = engine().relevance(for: recall, stores: [wholeFoods])
        XCTAssertEqual(rel.tier, .chain)
        XCTAssertEqual(rel.matchedStoreIDs, [wholeFoods.id])
    }

    func testChainMatchViaBrandNamesArray() {
        let recall = Recall(
            id: "F-3", classification: .classI,
            recallingFirm: "Some Dairy LLC",
            productDescription: "Vanilla ice cream pints",
            distributionPattern: "Nationwide",
            brandNames: ["Kirkland Signature"])
        let rel = engine().relevance(for: recall, stores: [costco])
        XCTAssertEqual(rel.tier, .chain)
        XCTAssertEqual(rel.matchedStoreIDs, [costco.id])
    }

    func testIndependentStoreFallsBackToRegional() {
        // Piazza's has no chain id: even a local-ish recall is regional-only.
        let recall = Recall(
            id: "F-4", classification: .classI,
            recallingFirm: "Artisan Cheese Co",
            productDescription: "Soft ripened cheese wheels",
            distributionPattern: "CA")
        let rel = engine().relevance(for: recall, stores: [piazza])
        XCTAssertEqual(rel.tier, .regional)
        XCTAssertTrue(rel.matchedStoreIDs.isEmpty)
    }

    // MARK: - Regional tier

    func testNationwideRecallIsRegionalForCAUser() {
        let recall = Recall(
            id: "F-5", classification: .classII,
            recallingFirm: "Snack Corp",
            productDescription: "Granola bars",
            distributionPattern: "Nationwide")
        let rel = engine().relevance(for: recall, stores: [piazza])
        XCTAssertEqual(rel.tier, .regional)
    }

    func testStateListIncludingCAIsRegional() {
        let recall = Recall(
            id: "F-6", classification: .classI,
            recallingFirm: "Greens Inc",
            productDescription: "Romaine lettuce",
            distributionPattern: "Distributed to CA, OR, WA")
        let rel = engine().relevance(for: recall, stores: [piazza])
        XCTAssertEqual(rel.tier, .regional)
    }

    // MARK: - None tier

    func testOtherStateOnlyRecallIsNone() {
        let recall = Recall(
            id: "F-7", classification: .classI,
            recallingFirm: "East Coast Dairy",
            productDescription: "Requeson cheese",
            distributionPattern: "Only in NY.")
        let rel = engine().relevance(for: recall, stores: [costco])
        XCTAssertEqual(rel.tier, .none)
    }

    func testMissingDistributionPatternIsNone() {
        let recall = Recall(id: "F-8", recallingFirm: "Mystery Foods")
        let rel = engine().relevance(for: recall, stores: [costco])
        XCTAssertEqual(rel.tier, .none)
    }

    // MARK: - Case-insensitivity

    func testMatchingIsCaseInsensitive() {
        let recall = Recall(
            id: "F-9", classification: .classII,
            recallingFirm: "COSTCO WHOLESALE",
            productDescription: "KIRKLAND SIGNATURE chicken sandwich",
            distributionPattern: "nationwide")
        let rel = engine().relevance(for: recall, stores: [costco])
        XCTAssertEqual(rel.tier, .chain)
    }
}
