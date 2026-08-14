import XCTest
@testable import RecallKit

final class RadiusExpansionTests: XCTestCase {

    func testStepsByIncrementWhenRoomRemains() {
        let next = RadiusExpansion.nextRadius(after: 10, step: 5, ceiling: 50)
        XCTAssertEqual(next, 15)
    }

    func testClampsToCeilingOnFinalStep() {
        let next = RadiusExpansion.nextRadius(after: 48, step: 5, ceiling: 50)
        XCTAssertEqual(next, 50)
    }

    func testReturnsNilAtCeiling() {
        let next = RadiusExpansion.nextRadius(after: 50, step: 5, ceiling: 50)
        XCTAssertNil(next)
    }

    func testReturnsNilPastCeiling() {
        let next = RadiusExpansion.nextRadius(after: 55, step: 5, ceiling: 50)
        XCTAssertNil(next)
    }

    func testFullSequenceFromDefaultReachesCeiling() {
        var radius = RecallKit.defaultRadiusMiles
        var steps = [radius]
        while let next = RadiusExpansion.nextRadius(
            after: radius, step: RecallKit.radiusExpansionStepMiles,
            ceiling: RecallKit.radiusRangeMiles.upperBound
        ) {
            radius = next
            steps.append(radius)
        }
        XCTAssertEqual(steps, [10, 15, 20, 25, 30, 35, 40, 45, 50])
    }
}
