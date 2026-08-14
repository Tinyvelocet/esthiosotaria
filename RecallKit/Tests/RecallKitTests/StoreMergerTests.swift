import Foundation
import XCTest
@testable import RecallKit

final class StoreMergerTests: XCTestCase {

    private let center = (lat: 37.4419, lon: -122.1430) // Palo Alto

    func testDedupesNearDuplicates() {
        let a = Store(name: "Piazza's Fine Foods", chain: nil, latitude: 37.4299, longitude: -122.1381)
        let b = Store(name: "Piazzas Fine Foods", chain: nil, latitude: 37.42995, longitude: -122.13815)
        let merged = StoreMerger.merge([a], [b], around: center)
        XCTAssertEqual(merged.count, 1)
    }

    func testKeepsDistantSameChainLocations() {
        // Two real Costcos ~16 mi apart — both must survive.
        let costcoMV = Store(name: "Costco Wholesale", chain: "costco", latitude: 37.4007, longitude: -122.1126)
        let costcoSJV = Store(name: "Costco Wholesale", chain: "costco", latitude: 37.3382, longitude: -121.8863)
        let merged = StoreMerger.merge([costcoMV], [costcoSJV], around: center)
        XCTAssertEqual(merged.count, 2)
    }

    func testPrefixNamesDedupeWhenClose() {
        let a = Store(name: "Costco Wholesale", chain: "costco", latitude: 37.4007, longitude: -122.1126)
        let b = Store(name: "Costco", chain: "costco", latitude: 37.4008, longitude: -122.1127)
        let merged = StoreMerger.merge([a], [b], around: center)
        XCTAssertEqual(merged.count, 1)
    }

    func testSortsByDistanceFromCenter() {
        let near = Store(name: "Near Market", chain: nil, latitude: 37.4420, longitude: -122.1431)
        let far = Store(name: "Far Market", chain: nil, latitude: 37.35, longitude: -122.05)
        let merged = StoreMerger.merge([far], [near], around: center)
        XCTAssertEqual(merged.first?.name, "Near Market")
    }

    func testPrefersChainTaggedEntryOnDuplicate() {
        let plain = Store(name: "99 Ranch Market", chain: nil, latitude: 37.4019, longitude: -122.0800)
        let tagged = Store(name: "99 Ranch Market", chain: "99ranch", latitude: 37.4019, longitude: -122.0800)
        let merged = StoreMerger.merge([plain], [tagged], around: center)
        XCTAssertEqual(merged.count, 1)
        XCTAssertEqual(merged[0].chain, "99ranch")
    }

    func testEmptyInputs() {
        XCTAssertTrue(StoreMerger.merge([], [], around: center).isEmpty)
        let only = Store(name: "Solo Market", chain: nil, latitude: 37.44, longitude: -122.14)
        XCTAssertEqual(StoreMerger.merge([only], [], around: center).count, 1)
    }
}
