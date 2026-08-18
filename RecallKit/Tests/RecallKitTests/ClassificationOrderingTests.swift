import XCTest
@testable import RecallKit

final class ClassificationOrderingTests: XCTestCase {

    func testClassIIsWorst() {
        XCTAssertLessThan(Recall.Classification.classI, .classII)
        XCTAssertLessThan(Recall.Classification.classI, .classIII)
        XCTAssertLessThan(Recall.Classification.classI, .unknown)
    }

    func testUnknownIsLeastSevere() {
        XCTAssertLessThan(Recall.Classification.classIII, .unknown)
    }

    func testMinFindsWorstAcrossASet() {
        let classifications: [Recall.Classification] = [.classIII, .unknown, .classII, .classIII]
        XCTAssertEqual(classifications.min(), .classII)
    }

    func testMinOfEmptySetIsNil() {
        let classifications: [Recall.Classification] = []
        XCTAssertNil(classifications.min())
    }
}
