import XCTest
@testable import RecallKit

final class DangerScoreTests: XCTestCase {

    private func recall(_ classification: Recall.Classification?, id: String = UUID().uuidString) -> Recall {
        Recall(id: id, classification: classification)
    }

    func testEmptyIsZero() {
        XCTAssertEqual(DangerScore.score(for: []), 0)
    }

    func testSingleClassIIsHighestSingleWeight() {
        XCTAssertEqual(DangerScore.score(for: [recall(.classI)]), 1.0, accuracy: 0.001)
    }

    func testWorstRecallDominatesOverMultipleMinor() {
        let manyMinor = (0..<5).map { _ in recall(.classIII) }
        let oneCritical = [recall(.classI)]
        XCTAssertGreaterThan(DangerScore.score(for: oneCritical), DangerScore.score(for: manyMinor))
    }

    func testMultipleActiveRecallsScoreHigherThanOneAtSameSeverity() {
        let one = [recall(.classII)]
        let two = [recall(.classII), recall(.classII)]
        XCTAssertGreaterThan(DangerScore.score(for: two), DangerScore.score(for: one))
    }

    func testScoreNeverExceedsOne() {
        let manyCritical = (0..<10).map { _ in recall(.classI) }
        XCTAssertEqual(DangerScore.score(for: manyCritical), 1.0, accuracy: 0.001)
    }

    func testUnknownClassificationScoresLow() {
        let score = DangerScore.score(for: [recall(nil)])
        XCTAssertLessThan(score, DangerScore.score(for: [recall(.classIII)]))
    }
}
