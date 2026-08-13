import Foundation
import XCTest
@testable import RecallKit

final class OverpassPOIServiceTests: XCTestCase {

    // MARK: - Parsing

    func testParseOverpassFixture() throws {
        let json = """
        {"version":0.6,"generator":"Overpass API","elements":[
          {"type":"node","id":1,"lat":37.4299,"lon":-122.1381,
           "tags":{"name":"Piazza's Fine Foods","shop":"supermarket","addr:city":"Palo Alto"}},
          {"type":"way","id":2,"center":{"lat":37.4019,"lon":-122.0800},
           "tags":{"name":"Costco Wholesale","shop":"wholesale","addr:city":"Mountain View"}},
          {"type":"node","id":3,"lat":37.44,"lon":-122.14,
           "tags":{"shop":"supermarket"}}
        ]}
        """
        let stores = try OverpassPOIService.parseStores(from: Data(json.utf8))

        XCTAssertEqual(stores.count, 3)
        XCTAssertEqual(stores[0].name, "Piazza's Fine Foods")
        XCTAssertNil(stores[0].chain)   // independent store: not in ChainCatalog
        XCTAssertEqual(stores[1].name, "Costco Wholesale")
        XCTAssertEqual(stores[1].chain, "costco")
        XCTAssertEqual(stores[2].name, "(Unnamed store)")
        XCTAssertNil(stores[2].chain)
    }

    func testParseEmptyElements() throws {
        let json = """
        {"version":0.6,"elements":[]}
        """
        let stores = try OverpassPOIService.parseStores(from: Data(json.utf8))
        XCTAssertTrue(stores.isEmpty)
    }

    // MARK: - Query building

    func testBuildQueryContainsShopTypesAndAround() {
        let query = OverpassPOIService.buildQuery(
            latitude: 37.4419, longitude: -122.1430, radiusMeters: 24000)
        XCTAssertTrue(query.contains("[out:json]"))
        XCTAssertTrue(query.contains("around:24000,37.4419,-122.143"))
        XCTAssertTrue(query.contains("supermarket"))
        XCTAssertTrue(query.contains("grocery"))
        XCTAssertTrue(query.contains("wholesale"))
        XCTAssertTrue(query.contains("out center tags"))
    }

    // MARK: - Service with stub transport

    func testFetchStoresHitsOverpassEndpoint() async throws {
        final class Stub: HTTPTransport, @unchecked Sendable {
            var requested: [URL] = []
            func data(for url: URL) async throws -> (Data, URLResponse) {
                requested.append(url)
                let payload = Data("{\"version\":0.6,\"elements\":[]}".utf8)
                let resp = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (payload, resp)
            }
        }
        let stub = Stub()
        let service = OverpassPOIService(transport: stub)
        let stores = try await service.stores(
            latitude: 37.4419, longitude: -122.1430, radiusMiles: 15)
        XCTAssertTrue(stores.isEmpty)
        let url = try XCTUnwrap(stub.requested.first)
        XCTAssertEqual(url.host, "overpass-api.de")
        XCTAssertTrue(url.path.contains("/api/interpreter"))
        // 15 mi ≈ 24140 m — verify radius conversion.
        let body = url.query.flatMap { _ in url.query } ?? ""
        XCTAssertTrue(body.contains("24140") || body.contains("around"), "query should encode radius: \(body)")
    }

    func testHTTPErrorThrows() async throws {
        final class Failing: HTTPTransport, @unchecked Sendable {
            func data(for url: URL) async throws -> (Data, URLResponse) {
                let resp = HTTPURLResponse(url: url, statusCode: 504, httpVersion: nil, headerFields: nil)!
                return (Data(), resp)
            }
        }
        let service = OverpassPOIService(transport: Failing())
        do {
            _ = try await service.stores(latitude: 0, longitude: 0, radiusMiles: 15)
            XCTFail("expected error")
        } catch {
            // expected
        }
    }
}
