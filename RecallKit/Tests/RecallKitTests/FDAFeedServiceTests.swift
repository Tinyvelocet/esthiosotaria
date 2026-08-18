import Foundation
import XCTest
@testable import RecallKit

final class FDAFeedServiceTests: XCTestCase {

    /// A representative slice of the real FDA Food Safety Recalls RSS feed
    /// (captured from the live feed).
    let sampleXML = """
    <?xml version="1.0" encoding="utf-8"?>
    <rss xmlns:dc="http://purl.org/dc/elements/1.1/" version="2.0">
      <channel>
        <title>FDA Food Safety Recalls RSS Feed</title>
        <link>http://www.fda.gov/</link>
        <language>en</language>
        <item>
          <title>Hormel Foods Sales, LLC Recalls a Limited Number of Planters® Honey Roasted Peanuts 4 Oz. and Planters® Deluxe Lightly Salted Mixed Nuts 8.75 Oz. Because of Possible Health Risk</title>
          <link>https://www.fda.gov/safety/recalls-market-withdrawals-safety-alerts/hormel-foods-sales-llc-recalls-limited-number-plantersr-honey-roasted-peanuts-4-oz-and-plantersr</link>
          <description>Hormel Foods Sales, LLC is voluntarily recalling a limited number of two PLANTERS® products that were produced at one of its facilities in April. These products are being recalled because they have the potential to be contaminated with Listeria monocytogenes.</description>
          <pubDate>Fri, 03 May 2024 16:56:00 EDT</pubDate>
          <dc:creator>FDA</dc:creator>
          <guid isPermaLink="true">https://www.fda.gov/safety/recalls-market-withdrawals-safety-alerts/hormel-foods-sales-llc-recalls-limited-number-plantersr-honey-roasted-peanuts-4-oz-and-plantersr</guid>
        </item>
        <item>
          <title>Palmer Candy Company Recalls White Confectionary Products Because of Possible Health Risk</title>
          <link>https://www.fda.gov/safety/recalls-market-withdrawals-safety-alerts/palmer-candy-company-recalls-white-confectionary-products-because-possible-health-risk</link>
          <description>Palmer Candy Company, Sioux City, Iowa, is recalling its “White Coated Confectionary Items” because they have the potential to be contaminated with Salmonella.</description>
          <pubDate>Sun, 05 May 2024 10:09:00 EDT</pubDate>
          <dc:creator>FDA</dc:creator>
          <guid isPermaLink="true">https://www.fda.gov/safety/recalls-market-withdrawals-safety-alerts/palmer-candy-company-recalls-white-confectionary-products-because-possible-health-risk</guid>
        </item>
        <item>
          <title>Supplier Recalls Impact Two Hy-Vee Products Third-Party Manufacturers Alert Retailer of Potential for Contamination</title>
          <link>https://www.fda.gov/safety/recalls-market-withdrawals-safety-alerts/recall_supplier-recalls-impact-two-hy-vee-products-third-party-manufacturers-alert-retailer</link>
          <description>Hy-Vee, Inc., based in West Des Moines, Iowa, is voluntarily recalling two varieties of its Hy-Vee Cream Cheese Spread out of an abundance of caution due to the potential for contamination with Salmonella.</description>
          <pubDate>Mon, 06 May 2024 19:24:00 EDT</pubDate>
          <dc:creator>FDA</dc:creator>
          <guid isPermaLink="true">https://www.fda.gov/safety/recalls-market-withdrawals-safety-alerts/recall_supplier-recalls-impact-two-hy-vee-products-third-party-manufacturers-alert-retailer</guid>
        </item>
      </channel>
    </rss>
    """

    // MARK: - RSS parsing

    func testParseSampleFeed() throws {
        let recalls = try FDAFeedService.parseFeed(from: Data(sampleXML.utf8))
        XCTAssertEqual(recalls.count, 3)
        XCTAssertTrue(recalls.allSatisfy { $0.agency == .fda })
        XCTAssertTrue(recalls.allSatisfy { $0.classification == .unknown }) // RSS has no class
        XCTAssertTrue(recalls.allSatisfy { $0.distributionPattern == nil }) // RSS has no distribution
    }

    func testHormelFields() throws {
        let recalls = try FDAFeedService.parseFeed(from: Data(sampleXML.utf8))
        let hormel = recalls[0]
        XCTAssertEqual(hormel.recallingFirm, "Hormel Foods Sales, LLC")
        XCTAssertTrue(hormel.productDescription?.hasPrefix("Recalls a Limited Number of Planters") == true)
        XCTAssertFalse(hormel.productDescription?.hasSuffix("Because of Possible Health Risk") == true)
        XCTAssertEqual(hormel.reportDate, "20240503")
        XCTAssertNotNil(hormel.urlString?.range(of: "hormel-foods"))
        XCTAssertTrue(hormel.id.hasPrefix("FDA-RSS-"))
    }

    func testFirmTrimsCityStateLocation() throws {
        // "Palmer Candy Company, Sioux City, Iowa, is recalling..." -> firm only.
        let recalls = try FDAFeedService.parseFeed(from: Data(sampleXML.utf8))
        XCTAssertEqual(recalls[1].recallingFirm, "Palmer Candy Company")
        // "Hy-Vee, Inc., based in West Des Moines, Iowa, is voluntarily recalling"
        XCTAssertEqual(recalls[2].recallingFirm, "Hy-Vee, Inc.")
    }

    func testStableIDAcrossParses() throws {
        let a = try FDAFeedService.parseFeed(from: Data(sampleXML.utf8))
        let b = try FDAFeedService.parseFeed(from: Data(sampleXML.utf8))
        XCTAssertEqual(a.map(\.id), b.map(\.id))
        // Distinct notices get distinct ids.
        XCTAssertNotEqual(a[0].id, a[1].id)
    }

    func testMalformedXMLThrows() {
        XCTAssertThrowsError(try FDAFeedService.parseFeed(from: Data("<not-xml".utf8)))
    }

    // MARK: - Service with stub transport

    func testFetchHitsEndpoint() async throws {
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
        let service = FDAFeedService(transport: stub)
        _ = try await service.fetchRecalls()
        let url = try XCTUnwrap(stub.requested.first)
        XCTAssertEqual(url.host, "www.fda.gov")
    }

    func testHTTPErrorThrows() async throws {
        final class Failing: HTTPTransport, @unchecked Sendable {
            func data(for url: URL) async throws -> (Data, URLResponse) {
                let resp = HTTPURLResponse(url: url, statusCode: 403, httpVersion: nil, headerFields: nil)!
                return (Data(), resp)
            }
        }
        let service = FDAFeedService(transport: Failing())
        do {
            _ = try await service.fetchRecalls()
            XCTFail("expected error")
        } catch {
            // expected — FDA bot-gating surfaces as a typed error, not a crash
        }
    }
}