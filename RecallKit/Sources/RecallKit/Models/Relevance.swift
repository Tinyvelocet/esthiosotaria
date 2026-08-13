import Foundation

/// How relevant a recall is to the user's tracked stores and area.
///
/// The tier is a confidence signal, not a certainty: recall data never
/// names a specific store shelf. UI copy must say "could be at your
/// store", never "is at your store".
public struct Relevance: Equatable, Sendable {
    public enum Tier: Int, Comparable, Sendable {
        /// Recalling firm or brand matches a tracked store's chain.
        case chain = 0
        /// Distribution pattern covers the user's state (or nationwide).
        case regional = 1
        /// Outside the user's area — filtered out by default.
        case none = 2

        public static func < (lhs: Tier, rhs: Tier) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    public let tier: Tier
    /// IDs of tracked stores matched at chain tier (empty for regional).
    public let matchedStoreIDs: [UUID]
    /// Plain-language explanation, safe to show verbatim in the UI.
    public let reason: String

    public init(tier: Tier, matchedStoreIDs: [UUID], reason: String) {
        self.tier = tier
        self.matchedStoreIDs = matchedStoreIDs
        self.reason = reason
    }
}
