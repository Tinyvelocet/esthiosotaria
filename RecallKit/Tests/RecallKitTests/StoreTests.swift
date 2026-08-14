import XCTest
@testable import RecallKit

final class StoreTests: XCTestCase {

    func testSameNameAndCoordinateProduceSameID() {
        let a = Store(name: "Safeway", chain: "safeway", latitude: 37.4419, longitude: -122.1430)
        let b = Store(name: "Safeway", chain: "safeway", latitude: 37.4419, longitude: -122.1430)
        XCTAssertEqual(a.id, b.id)
    }

    func testIDIsStableAcrossCaseAndTrivialCoordinateJitter() {
        let a = Store(name: "Safeway", chain: nil, latitude: 37.44190001, longitude: -122.14300001)
        let b = Store(name: "SAFEWAY", chain: nil, latitude: 37.44189999, longitude: -122.14299999)
        XCTAssertEqual(a.id, b.id)
    }

    func testDifferentCoordinatesProduceDifferentIDs() {
        let a = Store(name: "Safeway", chain: nil, latitude: 37.4419, longitude: -122.1430)
        let b = Store(name: "Safeway", chain: nil, latitude: 37.5, longitude: -122.2)
        XCTAssertNotEqual(a.id, b.id)
    }

    func testDifferentNamesAtSameCoordinateProduceDifferentIDs() {
        let a = Store(name: "Safeway", chain: nil, latitude: 37.4419, longitude: -122.1430)
        let b = Store(name: "Costco", chain: nil, latitude: 37.4419, longitude: -122.1430)
        XCTAssertNotEqual(a.id, b.id)
    }

    func testExplicitIDOverridesDerivedOne() {
        let fixed = UUID()
        let store = Store(id: fixed, name: "Safeway", chain: nil, latitude: 37.4419, longitude: -122.1430)
        XCTAssertEqual(store.id, fixed)
    }
}
