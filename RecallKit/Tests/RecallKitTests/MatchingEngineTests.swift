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
        // Piazza's has no chain id and a pantry product gives no category
        // signal either, so a local recall stays regional-only.
        let recall = Recall(
            id: "F-4", classification: .classI,
            recallingFirm: "Granola Mill Co",
            productDescription: "Toasted granola bars",
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

    // MARK: - Tier 2 (product-category matching)

    func testSoftCheeseEscalatesForIndependentGrocer() {
        let recall = Recall(id: "F-20", classification: .classII,
                            recallingFirm: "Artisan Dairy",
                            productDescription: "Soft ripened cheese wheels",
                            reasonForRecall: "Possible Listeria contamination.",
                            distributionPattern: "CA")
        let rel = engine().relevance(for: recall, stores: [piazza]) // independent (gourmet) grocer
        XCTAssertEqual(rel.tier, .chain)
        XCTAssertEqual(rel.matchedStoreIDs, [piazza.id])
    }

    func testSoftCheeseDoesNotEscalateForGenericChain() {
        let recall = Recall(id: "F-21", classification: .classII,
                            recallingFirm: "Artisan Dairy",
                            productDescription: "Soft ripened cheese wheels",
                            distributionPattern: "CA")
        let rel = engine().relevance(for: recall, stores: [costco]) // generic chain
        XCTAssertEqual(rel.tier, .regional) // a category match is no signal for Costco
    }

    func testSoftCheeseEscalatesForSpecialtyChain() {
        let wholeFoods = Store(name: "Whole Foods Market", chain: "wholefoods", latitude: 37.4, longitude: -122.1)
        let recall = Recall(id: "F-22", classification: .classII,
                            recallingFirm: "Artisan Dairy",
                            productDescription: "Soft ripened cheese wheels",
                            distributionPattern: "CA")
        let rel = engine().relevance(for: recall, stores: [wholeFoods])
        XCTAssertEqual(rel.tier, .chain)
        XCTAssertEqual(rel.matchedStoreIDs, [wholeFoods.id])
    }

    func testNonSpecialtyCategoryDoesNotEscalate() {
        // Ground beef (meat) isn't a distinctive Tier-2 category -> stays regional.
        let recall = Recall(id: "F-23", classification: .classII,
                            recallingFirm: "Ranch Co",
                            productDescription: "Ground beef patties",
                            reasonForRecall: "E. coli risk.",
                            distributionPattern: "CA")
        let rel = engine().relevance(for: recall, stores: [piazza])
        XCTAssertEqual(rel.tier, .regional)
    }

    func testBrandChainMatchStillBeatsCategory() {
        // A Kirkland cheese recall matches Costco by brand even though cheese
        // isn't a Costco Tier-2 category — brand is Tier-1 and wins.
        let recall = Recall(id: "F-24", classification: .classII,
                            recallingFirm: "Costco Wholesale",
                            productDescription: "Kirkland Signature cheese wedges",
                            distributionPattern: "CA")
        let rel = engine().relevance(for: recall, stores: [costco])
        XCTAssertEqual(rel.tier, .chain)
        XCTAssertEqual(rel.matchedStoreIDs, [costco.id])
    }

    func testCategoryMatchReasonStaysHonest() {
        let recall = Recall(id: "F-25", classification: .classII,
                            recallingFirm: "Artisan Dairy",
                            productDescription: "Soft ripened cheese wheels",
                            distributionPattern: "CA")
        let rel = engine().relevance(for: recall, stores: [piazza])
        XCTAssertTrue(rel.reason.lowercased().contains("could be"))
    }
}
