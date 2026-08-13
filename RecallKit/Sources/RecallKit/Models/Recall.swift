import Foundation

/// A single food recall event, as reported by the FDA enforcement dataset.
///
/// Field names mirror openFDA's `food/enforcement.json` records.
/// `distribution_pattern` and `brand_names` drive local relevance matching;
/// they are free-form text and must never be presented as certainty
/// (the UI must say "could be at your store", never "is").
public struct Recall: Codable, Identifiable, Equatable, Hashable, Sendable {

    /// FDA classification of a recall's health risk.
    public enum Classification: String, Codable, Sendable {
        case classI = "Class I"
        case classII = "Class II"
        case classIII = "Class III"
        case unknown

        /// Decodes known classes; anything else becomes `.unknown` instead of throwing.
        public init(from decoder: Decoder) throws {
            let raw = try decoder.singleValueContainer().decode(String.self)
            self = Classification(rawValue: raw) ?? .unknown
        }
    }

    /// Unique FDA recall number, e.g. `F-0480-2026`. Used as the stable ID.
    public let id: String

    /// "Ongoing" or "Terminated".
    public let status: String?

    /// Class I (serious harm/death) → Class III (unlikely harm).
    public let classification: Classification?

    /// The firm initiating the recall.
    public let recallingFirm: String?

    /// Free-text product description (brand, package size, codes).
    public let productDescription: String?

    /// Why the product is being recalled.
    public let reasonForRecall: String?

    /// Free-text distribution area, e.g. "Nationwide" or "CA, OR, WA".
    public let distributionPattern: String?

    /// Date the FDA received the report, YYYYMMDD.
    public let reportDate: String?

    /// Brand names from the `openfda.brand_name` array, when present.
    public let brandNames: [String]?

    enum CodingKeys: String, CodingKey {
        case id = "recall_number"
        case status
        case classification
        case recallingFirm = "recalling_firm"
        case productDescription = "product_description"
        case reasonForRecall = "reason_for_recall"
        case distributionPattern = "distribution_pattern"
        case reportDate = "report_date"
        case openfda
    }

    private enum OpenFDACodingKeys: String, CodingKey {
        case brandName = "brand_name"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        status = try c.decodeIfPresent(String.self, forKey: .status)
        classification = try c.decodeIfPresent(Classification.self, forKey: .classification)
        recallingFirm = try c.decodeIfPresent(String.self, forKey: .recallingFirm)
        productDescription = try c.decodeIfPresent(String.self, forKey: .productDescription)
        reasonForRecall = try c.decodeIfPresent(String.self, forKey: .reasonForRecall)
        distributionPattern = try c.decodeIfPresent(String.self, forKey: .distributionPattern)
        reportDate = try c.decodeIfPresent(String.self, forKey: .reportDate)
        if let openfda = try? c.nestedContainer(keyedBy: OpenFDACodingKeys.self, forKey: .openfda) {
            brandNames = try openfda.decodeIfPresent([String].self, forKey: .brandName)
        } else {
            brandNames = nil
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encodeIfPresent(status, forKey: .status)
        try c.encodeIfPresent(classification, forKey: .classification)
        try c.encodeIfPresent(recallingFirm, forKey: .recallingFirm)
        try c.encodeIfPresent(productDescription, forKey: .productDescription)
        try c.encodeIfPresent(reasonForRecall, forKey: .reasonForRecall)
        try c.encodeIfPresent(distributionPattern, forKey: .distributionPattern)
        try c.encodeIfPresent(reportDate, forKey: .reportDate)
        if let brandNames {
            var openfda = c.nestedContainer(keyedBy: OpenFDACodingKeys.self, forKey: .openfda)
            try openfda.encode(brandNames, forKey: .brandName)
        }
    }

    /// Designated memberwise init for tests and future synthetic records.
    public init(
        id: String,
        status: String? = nil,
        classification: Classification? = nil,
        recallingFirm: String? = nil,
        productDescription: String? = nil,
        reasonForRecall: String? = nil,
        distributionPattern: String? = nil,
        reportDate: String? = nil,
        brandNames: [String]? = nil
    ) {
        self.id = id
        self.status = status
        self.classification = classification
        self.recallingFirm = recallingFirm
        self.productDescription = productDescription
        self.reasonForRecall = reasonForRecall
        self.distributionPattern = distributionPattern
        self.reportDate = reportDate
        self.brandNames = brandNames
    }
}
