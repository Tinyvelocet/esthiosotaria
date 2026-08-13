import Foundation

/// A grocery store the user tracks recalls for.
public struct Store: Codable, Identifiable, Equatable, Hashable, Sendable {
    public let id: UUID
    /// Display name, e.g. "Costco Wholesale (Mountain View)".
    public var name: String
    /// Normalized chain identifier from `ChainCatalog` (e.g. "costco"),
    /// nil for independents — they fall back to regional matching.
    public var chain: String?
    public var latitude: Double
    public var longitude: Double

    public init(id: UUID = UUID(), name: String, chain: String?, latitude: Double, longitude: Double) {
        self.id = id
        self.name = name
        self.chain = chain
        self.latitude = latitude
        self.longitude = longitude
    }
}
