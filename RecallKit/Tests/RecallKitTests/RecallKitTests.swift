import XCTest
@testable import RecallKit

final class RecallKitTests: XCTestCase {
    func testVersionIsSet() {
        XCTAssertEqual(RecallKit.version, "0.1.0")
    }

    func testStoreLimits() {
        XCTAssertEqual(RecallKit.maxSelectedStores, 4)
        XCTAssertEqual(RecallKit.defaultRadiusMiles, 10)
        XCTAssertEqual(RecallKit.radiusRangeMiles, 5...50)
        XCTAssertEqual(RecallKit.radiusExpansionStepMiles, 5)
    }
}
