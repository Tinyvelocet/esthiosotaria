import Foundation

/// Pure stepping logic for widening a store-discovery search when nothing
/// is found nearby. Kept separate from `StoreDiscoveryService` (which lives
/// in the App target and talks to MapKit) so the arithmetic is unit-tested.
public enum RadiusExpansion {

    /// The next radius to try after `current` came back empty, or `nil` if
    /// `current` has already reached `ceiling` and there's nowhere left to
    /// expand to.
    public static func nextRadius(after current: Double, step: Double, ceiling: Double) -> Double? {
        guard current < ceiling else { return nil }
        return min(current + step, ceiling)
    }
}
