import Foundation

/// A widget-friendly snapshot of the user's matched recalls.
///
/// The main app writes one after every successful refresh; widgets (iOS +
/// macOS) read it from the shared App Group container. Kept deliberately
/// small — widgets get a handful of top items, not the full feed.
public struct RecallSnapshot: Codable, Equatable, Sendable {

    /// One matched recall, pre-scored for display.
    public struct Item: Codable, Equatable, Hashable, Sendable {
        public let recall: Recall
        /// Why this item surfaced: chain match or regional coverage.
        public let tier: Relevance.Tier
        /// Display names of matched stores (chain tier), empty for regional.
        public let matchedStoreNames: [String]

        public init(recall: Recall, tier: Relevance.Tier, matchedStoreNames: [String]) {
            self.recall = recall
            self.tier = tier
            self.matchedStoreNames = matchedStoreNames
        }
    }

    public var generatedAt: Date
    public var stateAbbrev: String
    public var chainItems: [Item]
    public var regionalItems: [Item]
    public var fsisUnavailable: Bool

    public init(
        generatedAt: Date,
        stateAbbrev: String,
        chainItems: [Item],
        regionalItems: [Item],
        fsisUnavailable: Bool
    ) {
        self.generatedAt = generatedAt
        self.stateAbbrev = stateAbbrev
        self.chainItems = chainItems
        self.regionalItems = regionalItems
        self.fsisUnavailable = fsisUnavailable
    }

    /// Top items for widget display: chain matches first, then regional,
    /// capped at `limit`.
    public func topItems(limit: Int) -> [Item] {
        Array((chainItems + regionalItems).prefix(limit))
    }

    /// True when at least one chain-tier (store) match exists.
    public var hasStoreMatch: Bool { !chainItems.isEmpty }
}

/// Reads/writes `RecallSnapshot` to a shared directory (the App Group
/// container in production, a temp dir in tests).
public struct RecallCache: Sendable {

    public static let fileName = "recall-snapshot.json"
    /// Shared App Group identifier (must match the entitlements).
    public static let appGroupID = "group.dev.tinyvelocet.esthiosotaria"

    private let directory: URL
    private var fileURL: URL { directory.appendingPathComponent(Self.fileName) }

    /// Production init: the App Group container (nil if the entitlement
    /// is missing — callers should degrade gracefully).
    public init?() {
        guard let dir = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: Self.appGroupID) else {
            return nil
        }
        self.directory = dir
    }

    /// Test/custom-directory init.
    public init(directory: URL) {
        self.directory = directory
    }

    public func save(_ snapshot: RecallSnapshot) throws {
        try FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(snapshot).write(to: fileURL, options: .atomic)
    }

    public func load() -> RecallSnapshot? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(RecallSnapshot.self, from: data)
    }

    /// True when a snapshot exists and is newer than `maxAge`.
    public func isFresh(maxAge: TimeInterval) -> Bool {
        guard let snapshot = load() else { return false }
        return Date().timeIntervalSince(snapshot.generatedAt) < maxAge
    }
}
