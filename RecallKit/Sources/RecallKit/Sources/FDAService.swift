import Foundation

/// Errors thrown by data source clients.
public enum RecallServiceError: Error, Equatable, LocalizedError {
    /// Non-2xx HTTP status from the API.
    case httpError(statusCode: Int)
    /// The API returned a well-formed error payload (e.g. openFDA error envelope).
    case apiError(message: String)
    /// Response body could not be decoded.
    case decodingFailed(underlying: String)

    public var errorDescription: String? {
        switch self {
        case .httpError(let code):
            return "The recall service returned HTTP \(code)."
        case .apiError(let message):
            return "The recall service returned an error: \(message)"
        case .decodingFailed(let detail):
            return "Could not read the recall data (\(detail))."
        }
    }
}

/// Abstracts network I/O so services are testable without touching the wire.
public protocol HTTPTransport: Sendable {
    func data(for url: URL) async throws -> (Data, URLResponse)
}

/// Production transport backed by URLSession.
public struct URLSessionTransport: HTTPTransport {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func data(for url: URL) async throws -> (Data, URLResponse) {
        try await session.data(from: url)
    }
}

/// Client for the openFDA food enforcement (recall) API.
///
/// Source: `api.fda.gov/food/enforcement.json` — docs at
/// https://open.fda.gov/apis/food/enforcement/ . No API key required for
/// modest usage (keyless tier: 240 requests/minute/IP); the app polls a few
/// times per day at most.
///
/// Note: openFDA is batch-indexed and can lag the live FDA recall site
/// by days to weeks — the UI must state data freshness honestly.
public struct FDAService: Sendable {

    private let transport: HTTPTransport
    private let baseURL: URL

    public init(
        transport: HTTPTransport = URLSessionTransport(),
        baseURL: URL = URL(string: "https://api.fda.gov/food/enforcement.json")!
    ) {
        self.transport = transport
        self.baseURL = baseURL
    }

    /// Fetches ongoing recalls, newest first.
    /// - Parameter limit: page size (openFDA caps at 1000).
    public func fetchOngoing(limit: Int = 200) async throws -> [Recall] {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "search", value: "status:Ongoing"),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "sort", value: "report_date:desc"),
        ]
        guard let url = components.url else {
            throw RecallServiceError.apiError(message: "could not build request URL")
        }

        let (data, response) = try await transport.data(for: url)

        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw RecallServiceError.httpError(statusCode: http.statusCode)
        }

        struct Envelope: Decodable {
            struct ErrorPayload: Decodable { let message: String? }
            let results: [Recall]?
            let error: ErrorPayload?
        }

        let envelope: Envelope
        do {
            envelope = try JSONDecoder().decode(Envelope.self, from: data)
        } catch {
            throw RecallServiceError.decodingFailed(underlying: error.localizedDescription)
        }

        if let apiError = envelope.error {
            throw RecallServiceError.apiError(message: apiError.message ?? "unknown API error")
        }
        return envelope.results ?? []
    }
}
