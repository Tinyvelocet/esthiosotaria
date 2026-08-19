import XCTest
@testable import RecallKit

final class CategoryCatalogTests: XCTestCase {

    func testSoftCheeseIsCheese() {
        XCTAssertEqual(CategoryCatalog.category(for: "Soft ripened cheese wheels"), .cheese)
        XCTAssertEqual(CategoryCatalog.category(for: "Cream cheese spread"), .cheese)
    }

    func testProduceVsBakeryVsMeat() {
        XCTAssertEqual(CategoryCatalog.category(for: "Fresh romaine lettuce hearts"), .produce)
        XCTAssertEqual(CategoryCatalog.category(for: "Multigrain bread 20 oz"), .bakery)
        XCTAssertEqual(CategoryCatalog.category(for: "ground beef 12,000 lbs"), .meat)
    }

    func testPreparedBeatsGenericMeat() {
        // "chicken salad" is a prepared food, not plain chicken.
        XCTAssertEqual(CategoryCatalog.category(for: "Ready-to-eat chicken salad"), .prepared)
    }

    func testNutsAndSeafood() {
        XCTAssertEqual(CategoryCatalog.category(for: "Roasted peanut butter 16 oz"), .nuts)
        XCTAssertEqual(CategoryCatalog.category(for: "Smoked salmon fillets"), .seafood)
    }

    func testUnknownFallsBackToOther() {
        XCTAssertEqual(CategoryCatalog.category(for: "Widget cleaning cloth"), .other)
    }

    func testClassifiesFromRecallFields() {
        let recall = Recall(
            id: "R1", classification: .classII,
            recallingFirm: "Northwest Creamery",
            productDescription: "Mozzarella balls in brine",
            reasonForRecall: "Possible Listeria contamination.",
            distributionPattern: "CA")
        XCTAssertEqual(CategoryCatalog.category(for: recall), .cheese)
    }
}