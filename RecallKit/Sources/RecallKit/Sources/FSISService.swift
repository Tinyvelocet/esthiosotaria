import Foundation

/// Client for USDA FSIS recall announcements (meat, poultry, processed egg
/// products — the categories the FDA does not regulate).
///
/// Source: FSIS recalls RSS feed at `fsis.usda.gov/rss/recalls.xml`.
/// ⚠️ fsis.usda.gov bot-gates datacenter IPs (Akamai 403 observed from CI
/// and cloud probes). The feed is expected to work from real devices on
/// residential networks; a 403 surfaces as `RecallServiceError.httpError`,
/// which the app treats as "FSIS source unavailable" and continues with
/// FDA data only. Verify on a real device before relying on this source.
public struct FSISService: Sendable {

    private let transport: HTTPTransport
    private let endpoint: URL

    public init(
        transport: HTTPTransport = URLSessionTransport(),
        endpoint: URL = URL(string: "https://www.fsis.usda.gov/rss/recalls.xml")!
    ) {
        self.transport = transport
        self.endpoint = endpoint
    }

    /// Fetches current FSIS recalls and public health alerts.
    public func fetchRecalls() async throws -> [Recall] {
        let (data, response) = try await transport.data(for: endpoint)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw RecallServiceError.httpError(statusCode: http.statusCode)
        }
        return try Self.parseFeed(from: data)
    }

    // MARK: - RSS parsing (Foundation XMLParser, no dependencies)

    /// Parses an FSIS recalls RSS feed into `Recall` values.
    public static func parseFeed(from data: Data) throws -> [Recall] {
        let delegate = FeedDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        guard parser.parse() else {
            throw RecallServiceError.decodingFailed(
                underlying: parser.parserError?.localizedDescription ?? "invalid RSS")
        }
        return delegate.items.map(makeRecall)
    }

    private struct FeedItem {
        var title = ""
        var link = ""
        var description = ""
        var pubDate = ""
    }

    private final class FeedDelegate: NSObject, XMLParserDelegate {
        var items: [FeedItem] = []
        private var current: FeedItem?
        private var currentElement = ""
        private var buffer = ""

        func parser(_ parser: XMLParser, didStartElement elementName: String,
                    namespaceURI: String?, qualifiedName: String?,
                    attributes: [String: String] = [:]) {
            currentElement = elementName
            if elementName == "item" { current = FeedItem() }
            buffer = ""
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            buffer += string
        }

        func parser(_ parser: XMLParser, didEndElement elementName: String,
                    namespaceURI: String?, qualifiedName: String?) {
            guard var item = current else { return }
            let text = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
            switch elementName {
            case "title": item.title = text
            case "link": item.link = text
            case "description": item.description = text
            case "pubDate": item.pubDate = text
            case "item":
                items.append(item)
                current = nil
            default: break
            }
            current = item
        }
    }

    private static func makeRecall(_ item: FeedItem) -> Recall {
        let number = recallNumber(fromTitle: item.title)
        let id = number.map { "FSIS-\($0)" } ?? "FSIS-\(abs(item.title.hashValue))"
        return Recall(
            id: id,
            status: "Ongoing", // FSIS RSS carries active announcements only
            classification: classification(fromTitle: item.title),
            recallingFirm: firm(fromDescription: item.description),
            productDescription: product(fromTitle: item.title),
            reasonForRecall: item.description,
            distributionPattern: distribution(fromDescription: item.description),
            reportDate: reportDate(fromPubDate: item.pubDate),
            brandNames: nil,
            agency: .fsis,
            urlString: item.link.isEmpty ? nil : item.link
        )
    }

    // MARK: - Field extractors (internal for tests)

    /// "Class I Recall: Ground Beef (Recall 015-2026)" -> .classI
    static func classification(fromTitle title: String) -> Recall.Classification {
        let lower = title.lowercased()
        // Check most specific first: "class iii" contains "class i" as a substring.
        if lower.contains("class iii") { return .classIII }
        if lower.contains("class ii") { return .classII }
        if lower.contains("class i") { return .classI }
        return .unknown // e.g. Public Health Alerts
    }

    /// Extracts "015-2026" from "(Recall 015-2026)" or "Recall Number 042-2025".
    static func recallNumber(fromTitle title: String) -> String? {
        guard let regex = try? NSRegularExpression(
            pattern: #"Recall(?:\s+Number)?[:\s]+([0-9]{3}-[0-9]{4})"#,
            options: [.caseInsensitive]
        ) else { return nil }
        let range = NSRange(title.startIndex..., in: title)
        guard let match = regex.firstMatch(in: title, range: range),
              let r = Range(match.range(at: 1), in: title) else { return nil }
        return String(title[r])
    }

    /// FSIS titles follow "Class X Recall: <product>" or "Public Health Alert: <product>".
    static func product(fromTitle title: String) -> String {
        guard let colonIndex = title.firstIndex(of: ":") else { return title }
        return String(title[title.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
    }

    /// Best-effort recalling firm: first sentence of the description when it
    /// names an establishment ("X Company ... is recalling ..."). Returns nil
    /// when the pattern isn't present (public health alerts often lack one).
    static func firm(fromDescription description: String) -> String? {
        let lower = description.lowercased()
        guard lower.contains("is recalling") || lower.contains("recalled approximately") else {
            return nil
        }
        let firstSentence = description.split(separator: ".").first.map(String.init) ?? description
        let words = firstSentence.split(separator: " ")
        guard words.count >= 2 else { return nil }
        return words.prefix(3).joined(separator: " ").trimmingCharacters(in: .punctuationCharacters)
    }

    /// Extracts a distribution summary: "nationwide", or the state list after
    /// "in"/"to" (e.g. "shipped to retail locations in CA, TX and AZ").
    static func distribution(fromDescription description: String) -> String? {
        let lower = description.lowercased()
        if let _ = lower.range(of: #"\bnationwide\b"#, options: .regularExpression) {
            return "nationwide"
        }
        guard let regex = try? NSRegularExpression(
            pattern: #"(?:in|to)\s+((?:[A-Z]{2}\s*,\s*)*(?:and\s+)?[A-Z]{2}\s*(?:and\s+[A-Z]{2})?)\b"#
        ) else { return nil }
        let range = NSRange(description.startIndex..., in: description)
        guard let match = regex.firstMatch(in: description, range: range),
              let r = Range(match.range(at: 1), in: description) else { return nil }
        return String(description[r]).trimmingCharacters(in: .whitespaces)
    }

    /// "Tue, 04 Aug 2026 12:00:00 EDT" -> "20260804" (matches FDA's YYYYMMDD).
    static func reportDate(fromPubDate pubDate: String) -> String? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        guard let date = formatter.date(from: pubDate) else { return nil }
        let output = DateFormatter()
        output.locale = Locale(identifier: "en_US_POSIX")
        output.dateFormat = "yyyyMMdd"
        output.timeZone = TimeZone(identifier: "UTC")
        return output.string(from: date)
    }
}
