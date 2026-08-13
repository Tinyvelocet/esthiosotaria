// RecallKit — UI-free core for food recall tracking.
// All data logic (fetching, parsing, store↔recall matching) lives here,
// fully unit-testable and shared between iOS and macOS targets.

import Foundation

public enum RecallKit {
    /// Semantic version of the package.
    public static let version = "0.1.0"

    /// Maximum number of stores a user can track.
    public static let maxSelectedStores = 4

    /// Default search radius for store discovery, in miles.
    public static let defaultRadiusMiles: Double = 15

    /// Allowed radius range for store discovery, in miles.
    public static let radiusRangeMiles: ClosedRange<Double> = 5...50
}
