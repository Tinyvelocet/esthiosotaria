import XCTest
@testable import RecallKit

final class AlertPolicyTests: XCTestCase {

    func testClassIWarrantsNotification() {
        let recall = Recall(id: "1", classification: .classI)
        XCTAssertTrue(AlertPolicy.warrantsNotification(recall))
    }

    func testClassIIWarrantsNotification() {
        let recall = Recall(id: "1", classification: .classII)
        XCTAssertTrue(AlertPolicy.warrantsNotification(recall))
    }

    func testClassIIIDoesNotWarrantNotification() {
        let recall = Recall(id: "1", classification: .classIII)
        XCTAssertFalse(AlertPolicy.warrantsNotification(recall))
    }

    func testUnknownClassificationDoesNotWarrantNotification() {
        let recall = Recall(id: "1", classification: .unknown)
        XCTAssertFalse(AlertPolicy.warrantsNotification(recall))
    }

    func testNilClassificationDoesNotWarrantNotification() {
        let recall = Recall(id: "1", classification: nil)
        XCTAssertFalse(AlertPolicy.warrantsNotification(recall))
    }
}
