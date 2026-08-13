import Foundation

/// Discovers grocery stores near a coordinate using OpenStreetMap's
/// Overpass API. Keyless, open data — used as the fallback (and
/// verification reference) for MapKit-based discovery.
///
/// Query verified live 2026-08-13 around Palo Alto, CA: returned 60 POIs
/// including Piazza's Fine Foods at 2.4 mi.
public struct OverpassPOIService: Sendable {

    private let transport: HTTPTransport
    private let endpoint: URL

    public init(
        transport: HTTPTransport = URLSessionTransport(),
        endpoint: URL = URL(string: "https://overpass-api.de/api/interpreter")!
    ) {
        self.transport = transport
        self.endpoint = endpoint
    }

    /// Miles → meters conversion shared with tests.
    public static let metersPerMile: Double = 1609.344

    /// Fetches grocery POIs within `radiusMiles` of the coordinate.
    public func stores(latitude: Double, longitude: Double, radiusMiles: Double) async throws -> [Store] {
        let radiusMeters = Int((radiusMiles * Self.metersPerMile).rounded())
        let query = Self.buildQuery(latitude: latitude, longitude: longitude, radiusMeters: radiusMeters)

        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "data", value: query)]
        guard let url = components.url else {
            throw RecallServiceError.apiError(message: "could not build Overpass request")
        }

        let (data, response) = try await transport.data(for: url)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw RecallServiceError.httpError(statusCode: http.statusCode)
        }
        return try Self.parseStores(from: data)
    }

    /// Builds the Overpass QL query for grocery-type POIs in a circle.
    public static func buildQuery(latitude: Double, longitude: Double, radiusMeters: Int) -> String {
        """
        [out:json][timeout:25];
        (
          node["shop"~"supermarket|grocery|wholesale"](around:\(radiusMeters),\(latitude),\(longitude));
          way["shop"~"supermarket|grocery|wholesale"](around:\(radiusMeters),\(latitude),\(longitude));
        );
        out center tags;
        """
    }

    /// Decodes an Overpass JSON payload into `Store` values.
    /// Nameless elements become "(Unnamed store)" so the UI can still
    /// offer them; chain is resolved via `ChainCatalog` when possible.
    public static func parseStores(from data: Data) throws -> [Store] {
        struct Element: Decodable {
            struct Center: Decodable { let lat: Double; let lon: Double }
            let type: String
            let lat: Double?
            let lon: Double?
            let center: Center?
            let tags: [String: String]?
        }
        struct Payload: Decodable { let elements: [Element] }

        let payload: Payload
        do {
            payload = try JSONDecoder().decode(Payload.self, from: data)
        } catch {
            throw RecallServiceError.decodingFailed(underlying: error.localizedDescription)
        }

        return payload.elements.compactMap { element in
            let lat: Double
            let lon: Double
            if let directLat = element.lat, let directLon = element.lon {
                lat = directLat; lon = directLon
            } else if let center = element.center {
                lat = center.lat; lon = center.lon
            } else {
                return nil
            }
            let tags = element.tags ?? [:]
            let name = tags["name"] ?? tags["operator"] ?? "(Unnamed store)"
            return Store(
                name: name,
                chain: ChainCatalog.chainID(forStoreName: name),
                latitude: lat,
                longitude: lon
            )
        }
    }
}
