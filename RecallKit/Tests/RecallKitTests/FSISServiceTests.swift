import Foundation
import XCTest
@testable import RecallKit

final class FSISServiceTests: XCTestCase {

    // MARK: - RSS parsing (fixture = FSIS recall RSS format)

    func testParseFSISFeed() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0">
          <channel>
            <title>FSIS Recalls</title>
            <item>
              <title>Class I Recall: Ground Beef Product (Recall 015-2026)</title>
              <link>https://www.fsis.usda.gov/recalls-alerts/ground-beef-recall-015-2026</link>
              <description>Grandview Meat Company, a Texas establishment, is recalling approximately 12,000 pounds of ground beef that may be contaminated with E. coli O157:H7. The product was shipped to retail locations in CA, TX and AZ.</description>
              <pubDate>Tue, 04 Aug 2026 12:00:00 EDT</pubDate>
            </item>
            <item>
              <title>Public Health Alert: Ready-to-Eat Chicken Salad</title>
              <link>https://www.fsis.usda.gov/recalls-alerts/chicken-salad-pha-2026</link>
              <description>FSIS is issuing a public health alert due to concerns of undeclared allergens (soy) in a ready-to-eat chicken salad sold at Costco warehouses nationwide.</description>
              <pubDate>Mon, 03 Aug 2026 09:30:00 EDT</pubDate>
            </item>
          </channel>
        </rss>
        """
        let recalls = try FSISService.parseFeed(from: Data(xml.utf8))

        XCTAssertEqual(recalls.count, 2)

        let beef = recalls[0]
        XCTAssertEqual(beef.id, "FSIS-015-2026")
        XCTAssertEqual(beef.agency, .fsis)
        XCTAssertEqual(beef.classification, .classI)
        XCTAssertEqual(beef.status, "Ongoing")
        XCTAssertEqual(beef.agency, .fsis)
        XCTAssertTrue(beef.productDescription?.contains("Ground Beef") == true)
        XCTAssertEqual(beef.distributionPattern, "CA, TX and AZ")
        XCTAssertTrue(beef.recallingFirm?.contains("Grandview Meat") == true)
        XCTAssertTrue(beef.urlString?.hasSuffix("ground-beef-recall-015-2026") == true)

        let alert = recalls[1]
        XCTAssertEqual(alert.agency, .fsis)
        XCTAssertEqual(alert.classification, .unknown) // public health alerts have no class
        XCTAssertTrue(alert.productDescription?.lowercased().contains("chicken salad") == true)
        XCTAssertNil(alert.recallingFirm) // PHA descriptions name no establishment
        XCTAssertTrue(alert.reasonForRecall?.lowercased().contains("costco") == true)
    }

    func testParseEmptyFeed() throws {
        let xml = """
        <?xml version="1.0"?><rss version="2.0"><channel><title>FSIS Recalls</title></channel></rss>
        """
        let recalls = try FSISService.parseFeed(from: Data(xml.utf8))
        XCTAssertTrue(recalls.isEmpty)
    }

    func testMalformedXMLThrows() {
        XCTAssertThrowsError(try FSISService.parseFeed(from: Data("<not-xml".utf8)))
    }

    // MARK: - Classification extraction

    func testClassificationFromTitle() {
        XCTAssertEqual(FSISService.classification(fromTitle: "Class I Recall: X"), .classI)
        XCTAssertEqual(FSISService.classification(fromTitle: "Class II Recall (Expanded): Y"), .classII)
        XCTAssertEqual(FSISService.classification(fromTitle: "Class III Recall: Z"), .classIII)
        XCTAssertEqual(FSISService.classification(fromTitle: "Public Health Alert: W"), .unknown)
    }

    // MARK: - Recall number extraction

    func testRecallNumberExtraction() {
        XCTAssertEqual(FSISService.recallNumber(fromTitle: "Class I Recall: Ground Beef (Recall 015-2026)"), "015-2026")
        XCTAssertEqual(FSISService.recallNumber(fromTitle: "FSIS Recalls Frozen Pizza (Recall Number 042-2025)"), "042-2025")
        XCTAssertNil(FSISService.recallNumber(fromTitle: "No number here"))
    }

    // MARK: - State extraction from description

    func testDistributionExtraction() {
        let desc = "shipped to retail locations in CA, TX and AZ."
        XCTAssertEqual(FSISService.distribution(fromDescription: desc), "CA, TX and AZ")
        let nationwide = "The product was sold nationwide at warehouse clubs."
        XCTAssertEqual(FSISService.distribution(fromDescription: nationwide), "nationwide")
        XCTAssertNil(FSISService.distribution(fromDescription: "No location info at all."))
    }

    // MARK: - Service with stub transport

    func testFetchHitsFSISEndpoint() async throws {
        final class Stub: HTTPTransport, @unchecked Sendable {
            var requested: [URL] = []
            func data(for url: URL) async throws -> (Data, URLResponse) {
                requested.append(url)
                let payload = Data("<rss version=\"2.0\"><channel></channel></rss>".utf8)
                let resp = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (payload, resp)
            }
        }
        let stub = Stub()
        let service = FSISService(transport: stub)
        let recalls = try await service.fetchRecalls()
        XCTAssertTrue(recalls.isEmpty)
        let url = try XCTUnwrap(stub.requested.first)
        XCTAssertEqual(url.host, "www.fsis.usda.gov")
        XCTAssertTrue(url.path.contains("rss"))
    }

    func testHTTPErrorThrows() async throws {
        final class Failing: HTTPTransport, @unchecked Sendable {
            func data(for url: URL) async throws -> (Data, URLResponse) {
                let resp = HTTPURLResponse(url: url, statusCode: 403, httpVersion: nil, headerFields: nil)!
                return (Data(), resp)
            }
        }
        let service = FSISService(transport: Failing())
        do {
            _ = try await service.fetchRecalls()
            XCTFail("expected error")
        } catch {
            // expected — FSIS bot-gating surfaces as a typed error, not a crash
        }
    }

    // MARK: - Firm extraction (dateline handling)

    func testFirmExtractionStripsDateline() {
        let desc = "WASHINGTON, Aug. 6, 2026 – Grandview Meat Company, a Texas establishment, is recalling approximately 12,000 pounds of ground beef."
        XCTAssertEqual(FSISService.firm(fromDescription: desc), "Grandview Meat Company")
        // The dateline must never be reported as the firm name.
        XCTAssertFalse(FSISService.firm(fromDescription: desc)?.hasPrefix("WASHINGTON") == true)
    }

    func testFirmReturnsNilWhenNoMarkingFirm() {
        let desc = "FSIS is issuing a public health alert due to concerns of undeclared allergens in ready-to-eat chicken salad."
        XCTAssertNil(FSISService.firm(fromDescription: desc))
    }

    // MARK: - Fallback id (must be stable across launches)

    func testFallbackIDIsStable() {
        let title = "Public Health Alert: Ready-to-Eat Chicken Salad"
        XCTAssertEqual(FSISService.fallbackID(fromTitle: title), FSISService.fallbackID(fromTitle: title))
        // Distinct titles must not collide.
        XCTAssertNotEqual(
            FSISService.fallbackID(fromTitle: title),
            FSISService.fallbackID(fromTitle: "Public Health Alert: Frozen Beef Patties"))
        XCTAssertTrue(FSISService.fallbackID(fromTitle: title).hasPrefix("FSIS-"))
    }
}
