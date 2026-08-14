import Foundation
import CryptoKit

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

    /// `id` defaults to a deterministic hash of name + coordinates rather
    /// than a random UUID, so the same physical store gets the same id
    /// across separate discovery calls (MapKit/Overpass re-queries, radius
    /// changes, app relaunches). Selection state is matched by id — a
    /// random id would silently desync a store's selected/checked state
    /// from a freshly re-fetched list even though it's the same store.
    public init(id: UUID? = nil, name: String, chain: String?, latitude: Double, longitude: Double) {
        self.id = id ?? Self.stableID(name: name, latitude: latitude, longitude: longitude)
        self.name = name
        self.chain = chain
        self.latitude = latitude
        self.longitude = longitude
    }

    private static func stableID(name: String, latitude: Double, longitude: Double) -> UUID {
        let normalizedName = name.lowercased().filter { $0.isLetter || $0.isNumber }
        // Round coordinates so trivial floating-point/geocoding jitter
        // between calls to the same source doesn't change the id.
        let key = "\(normalizedName)|\(String(format: "%.4f", latitude))|\(String(format: "%.4f", longitude))"
        let digest = Array(SHA256.hash(data: Data(key.utf8)))
        let bytes: uuid_t = (
            digest[0], digest[1], digest[2], digest[3],
            digest[4], digest[5], digest[6], digest[7],
            digest[8], digest[9], digest[10], digest[11],
            digest[12], digest[13], digest[14], digest[15]
        )
        return UUID(uuid: bytes)
    }
}
