import XCTest
@testable import RecallKit

final class FDAServiceTests: XCTestCase {

    private func fixtureData(_ name: String) throws -> Data {
        guard let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures") else {
            throw XCTSkip("fixture \(name).json missing")
        }
        return try Data(contentsOf: url)
    }

    // MARK: - Task 1.1: Recall model decoding

    func testDecodeRecallFromFixture() throws {
        let data = try fixtureData("fda_sample")
        struct Envelope: Decodable { let results: [Recall] }
        let envelope = try JSONDecoder().decode(Envelope.self, from: data)

        XCTAssertEqual(envelope.results.count, 1)
        let r = envelope.results[0]
        XCTAssertEqual(r.id, "H-1189-2026")
        XCTAssertEqual(r.status, "Ongoing")
        XCTAssertEqual(r.classification, .classI)
        XCTAssertEqual(r.recallingFirm, "Nelson & Isa Lacteos LLC")
        XCTAssertEqual(r.reasonForRecall, "Products may be contaminated with Listeria monocytogenes.")
        XCTAssertEqual(r.distributionPattern, "Only in NY.")
        XCTAssertEqual(r.reportDate, "20260805")
        XCTAssertEqual(r.brandNames, ["Nelson & Isa Lacteos"])
        XCTAssertTrue(r.productDescription?.contains("Requeson") == true)
    }

    func testDecodeRecallWithoutOpenFDASection() throws {
        // Real records sometimes lack the openfda block — must not throw.
        let json = """
        {"results":[{"recall_number":"F-0001-2026","status":"Terminated","classification":"Class III",
        "recalling_firm":"Acme Foods","product_description":"Widget 12oz",
        "reason_for_recall":"Mislabeling","distribution_pattern":"Nationwide","report_date":"20260101"}]}
        """
        struct Envelope: Decodable { let results: [Recall] }
        let envelope = try JSONDecoder().decode(Envelope.self, from: Data(json.utf8))
        XCTAssertEqual(envelope.results.count, 1)
        XCTAssertNil(envelope.results[0].brandNames)
        XCTAssertEqual(envelope.results[0].classification, .classIII)
    }

    func testUnknownClassificationDecodesAsUnknown() throws {
        let json = """
        {"results":[{"recall_number":"F-0002-2026","classification":"Class IV"}]}
        """
        struct Envelope: Decodable { let results: [Recall] }
        let envelope = try JSONDecoder().decode(Envelope.self, from: Data(json.utf8))
        XCTAssertEqual(envelope.results[0].classification, .unknown)
    }

    // MARK: - Task 1.2: FDAService

    /// Stub transport that records requested URLs and returns a canned payload.
    final class StubTransport: HTTPTransport, @unchecked Sendable {
        var requestedURLs: [URL] = []
        var payload: Data

        init(payload: Data) { self.payload = payload }

        func data(for url: URL) async throws -> (Data, URLResponse) {
            requestedURLs.append(url)
            let response = HTTPURLResponse(
                url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (payload, response)
        }
    }

    func testFDAServiceBuildsOngoingQuery() async throws {
        let data = try fixtureData("fda_sample")
        let stub = StubTransport(payload: data)
        let service = FDAService(transport: stub)

        let recalls = try await service.fetchOngoing(limit: 150)

        XCTAssertEqual(recalls.count, 1)
        XCTAssertEqual(recalls[0].id, "H-1189-2026")

        let url = try XCTUnwrap(stub.requestedURLs.first)
        XCTAssertEqual(url.scheme, "https")
        XCTAssertEqual(url.host, "api.fda.gov")
        XCTAssertTrue(url.path.contains("food/enforcement.json"))
        let query = url.query ?? ""
        XCTAssertTrue(query.contains("status"), "query should filter ongoing: \(query)")
        XCTAssertTrue(query.contains("Ongoing"), "query should filter ongoing: \(query)")
        XCTAssertTrue(query.contains("limit=150"), "query should carry limit: \(query)")
    }

    func testFDAServiceThrowsOnHTTPError() async throws {
        final class FailingTransport: HTTPTransport, @unchecked Sendable {
            func data(for url: URL) async throws -> (Data, URLResponse) {
                let response = HTTPURLResponse(
                    url: url, statusCode: 429, httpVersion: nil, headerFields: nil)!
                return (Data(), response)
            }
        }
        let service = FDAService(transport: FailingTransport())
        do {
            _ = try await service.fetchOngoing()
            XCTFail("expected error on HTTP 429")
        } catch {
            // Expected: rate-limited or error response must surface, not swallow.
        }
    }
}
