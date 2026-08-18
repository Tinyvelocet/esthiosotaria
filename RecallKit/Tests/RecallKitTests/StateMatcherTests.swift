import XCTest
@testable import RecallKit

final class StateMatcherTests: XCTestCase {

    /// 2-letter state abbreviations that double as common English words
    /// ("in", "or", "me", "id") must NOT match merely because the word
    /// appears in the distribution text — otherwise an Indiana user sees
    /// every recall line containing "in" as regional.

    func testWordInDoesNotMatchIndiana() {
        XCTAssertFalse(StateMatcher.coversState("Distributed to CA, OR, WA", stateAbbrev: "IN"))
        XCTAssertFalse(StateMatcher.coversState("Only in NY.", stateAbbrev: "IN"))
    }

    func testWordOrDoesNotMatchOregon() {
        XCTAssertFalse(StateMatcher.coversState("Distributed to CA and WA", stateAbbrev: "OR"))
    }

    func testAllCapsAbbreviationTokenMatches() {
        // Real FDA distributions list abbreviations in all caps.
        XCTAssertTrue(StateMatcher.coversState("CA, TX and AZ", stateAbbrev: "CA"))
        XCTAssertTrue(StateMatcher.coversState("Shipped to retail locations in IN.", stateAbbrev: "IN"))
    }

    func testFullStateNameMatchesCaseInsensitively() {
        XCTAssertTrue(StateMatcher.coversState("distributed throughout California", stateAbbrev: "CA"))
        XCTAssertTrue(StateMatcher.coversState("sold in Indiana and Ohio", stateAbbrev: "IN"))
        // ...but not an unrelated state.
        XCTAssertFalse(StateMatcher.coversState("distributed in texas", stateAbbrev: "CA"))
    }

    func testNationwideCoversEveryState() {
        XCTAssertTrue(StateMatcher.coversState("Nationwide", stateAbbrev: "AK"))
        XCTAssertTrue(StateMatcher.coversState("All 50 states", stateAbbrev: "WY"))
    }

    func testMissingOrEmptyPatternDoesNotMatch() {
        XCTAssertFalse(StateMatcher.coversState(nil, stateAbbrev: "CA"))
        XCTAssertFalse(StateMatcher.coversState("", stateAbbrev: "CA"))
    }
}