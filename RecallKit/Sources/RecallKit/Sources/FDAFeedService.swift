import Foundation

/// Client for the FDA *Food Safety Recalls* RSS feed — the FDA's own, fresher
/// announcement feed.
///
/// This is the "faster feed" that closes two gap sources:
/// - openFDA is batch-indexed and can lag the live FDA recall site by days–weeks.
/// - The FDA RSS reflects announcements as they are published.
///
/// ⚠️ Trade-off: the RSS carries **no `classification` and no
/// `distribution_pattern`** (structurally it's just title/link/description/
/// pubDate/guid), so records parse with `.unknown` classification and nil
/// distribution. The app therefore treats this feed as a *freshness
/// supplement*: it is merged with the structured openFDA feed and openFDA's
/// richer record wins on a duplicate. See `RecallDeduplicator`.
///
/// ⚠️ fda.gov bot-gates datacenter/CI IPs (403 observed from probes), so this
/// feed — like the FSIS feed — is expected to work from real devices on
/// residential networks. A 403 surfaces as `RecallServiceError.httpError`,
/// which the app treats as "fast feed unavailable" and continues with openFDA.
public struct FDAFeedService: Sendable {

    public static let defaultEndpoint = URL(
        string: "https://www.fda.gov/about-fda/contact-fda/stay-informed/rss-feeds/food-safety-recalls/rss.xml")!

    private let transport: HTTPTransport
    private let endpoint: URL

    public init(
        transport: HTTPTransport = URLSessionTransport(),
        endpoint: URL = FDAFeedService.defaultEndpoint
    ) {
        self.transport = transport
        self.endpoint = endpoint
    }

    /// Fetches current FDA food safety recalls from the RSS feed.
    public func fetchRecalls() async throws -> [Recall] {
        let (data, response) = try await transport.data(for: endpoint)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw RecallServiceError.httpError(statusCode: http.statusCode)
        }
        return try Self.parseFeed(from: data)
    }

    // MARK: - RSS parsing (Foundation XMLParser, no dependencies)

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
        return Recall(
            id: "FDA-RSS-" + slugID(from: item.link.isEmpty ? item.title : item.link),
            status: "Ongoing", // the feed carries active announcements only
            classification: .unknown, // RSS carries no class
            recallingFirm: firm(fromTitle: item.title, description: item.description),
            productDescription: product(fromTitle: item.title, firm: firm(fromTitle: item.title, description: item.description)),
            reasonForRecall: item.description.isEmpty ? nil : item.description,
            distributionPattern: nil, // RSS carries no distribution
            reportDate: reportDate(fromPubDate: item.pubDate),
            brandNames: nil,
            agency: .fda,
            urlString: item.link.isEmpty ? nil : item.link
        )
    }

    /// Stable id from the notice URL (or title) — the URL is stable across
    /// refreshes, unlike `String.hashValue`.
    static func slugID(from urlOrTitle: String) -> String {
        let sum = urlOrTitle.lowercased().unicodeScalars.reduce(UInt64(5381)) { ($0 &* 33) ^ UInt64($1.value) }
        return String(sum, radix: 16, uppercase: true)
    }

    /// Best-effort recalling firm. Prefers the description's "X ... is
    /// voluntarily recalling / is recalling / issued" phrase; falls back to the
    /// title's leading firm before a recall verb ("X Recalls ...").
    static func firm(fromTitle title: String, description: String) -> String? {
        let markers = [" is voluntarily recalling", " is recalling", " is issuing",
                       " issues voluntary recall", " announced", " is announcing"]
        for marker in markers {
            guard let r = description.range(of: marker, options: .caseInsensitive) else { continue }
            var firm = description[description.startIndex..<r.lowerBound]
                .trimmingCharacters(in: .whitespacesAndNewlines)
            // Drop a trailing address/descriptor: "X, Inc., based in Des Moines, Iowa,".
            for cut in [", based in", ", of ", ", a ", ", eliminates"] {
                if let i = firm.range(of: cut) {
                    firm = String(firm[..<i.lowerBound]).trimmingCharacters(in: .whitespaces)
                    break
                }
            }
            // Also cut at a leading comma when everything after it reads like a
            // location ("Palmer Candy Company, Sioux City, Iowa, is recalling").
            if let comma = firm.firstIndex(of: ","),
               Self.looksLikeAddress(String(firm[firm.index(after: comma)...])) {
                firm = String(firm[..<comma]).trimmingCharacters(in: .whitespaces)
            }
            return firm.isEmpty ? nil : firm
        }
        // Fallback: title leads with the firm, e.g. "Palmer Candy Company Recalls ..."
        let verbs = [" Recalls ", " Issues ", " Announces ", " Expands Recall "]
        for v in verbs {
            if let r = title.range(of: v, options: [.caseInsensitive]) {
                let firm = title[title.startIndex..<r.lowerBound].trimmingCharacters(in: .whitespaces)
                if !firm.isEmpty { return firm }
            }
        }
        return nil
    }

    /// A display label for the product: the title with the leading firm
    /// phrase and any trailing boilerplate ("Because of Possible Health Risk")
    /// trimmed, so the card doesn't read "Hormel... Because of Possible Health Risk".
    static func product(fromTitle title: String, firm: String?) -> String {
        var product = title
        if let firm, let r = product.range(of: firm) {
            product = String(product[r.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        for tail in [" Because of Possible Health Risk", " for Possible Health Risk",
                     " Due to Possible Health Risk", " because of possible health risk",
                     " due to possible health risk", "for possible health risk"] {
            if product.hasSuffix(tail) {
                product = String(product.dropLast(tail.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return product.isEmpty ? title : product
    }

    /// True when `text` looks like a US location reference (a state name or a
    /// two-letter state abbreviation), used to trim address suffixes from firm
    /// names. Best-effort.
    static func looksLikeAddress(_ text: String) -> Bool {
        let lower = text.lowercased()
        if StateMatcher.abbreviations.keys.contains(where: { lower.contains($0) }) {
            return true
        }
        let tokens = text.split(whereSeparator: { !$0.isLetter }).map(String.init)
        return tokens.contains {
            $0.count == 2 && StateMatcher.abbreviations.values.contains($0.uppercased())
        }
    }

    /// "Mon, 06 May 2024 19:24:00 EDT" -> "20240506" (matches FDA's YYYYMMDD).
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