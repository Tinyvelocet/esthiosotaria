import Foundation

/// Merges grocery-store results from multiple discovery sources (MapKit +
/// OSM Overpass) into one de-duplicated, distance-sorted list.
///
/// Why merge: MapKit's `MKLocalSearch` is relevance-ranked and capped
/// (~25–30 results), which silently drops many real stores. OSM Overpass
/// is exhaustive within the radius but misses some mall/POI entries.
/// Together they give far better coverage than either alone.
public enum StoreMerger {

    /// Two stores closer than this with similar names are the same store.
    static let dedupeDistanceMiles: Double = 0.1

    public static func merge(
        _ primary: [Store],
        _ secondary: [Store],
        around center: (lat: Double, lon: Double)
    ) -> [Store] {
        var kept: [Store] = []

        // Primary source first so its entries win positionally; on name
        // collisions the entry with richer data (chain tag) is kept.
        for candidate in primary + secondary {
            if let index = duplicateIndex(of: candidate, in: kept) {
                if kept[index].chain == nil && candidate.chain != nil {
                    kept[index] = candidate
                }
            } else {
                kept.append(candidate)
            }
        }

        return kept.sorted {
            haversineMiles(center.lat, center.lon, $0.latitude, $0.longitude)
                < haversineMiles(center.lat, center.lon, $1.latitude, $1.longitude)
        }
    }

    private static func duplicateIndex(of candidate: Store, in stores: [Store]) -> Int? {
        for (index, existing) in stores.enumerated() {
            guard namesAreSimilar(existing.name, candidate.name) else { continue }
            let distance = haversineMiles(
                existing.latitude, existing.longitude,
                candidate.latitude, candidate.longitude)
            if distance < dedupeDistanceMiles { return index }
        }
        return nil
    }

    /// Case/punctuation-insensitive; also treats short prefixes as the same
    /// store ("Costco" vs "Costco Wholesale") to bridge source differences.
    static func namesAreSimilar(_ a: String, _ b: String) -> Bool {
        let na = normalize(a)
        let nb = normalize(b)
        guard !na.isEmpty, !nb.isEmpty else { return false }
        if na == nb { return true }
        let shorter = min(na.count, nb.count)
        guard shorter >= 4 else { return false }
        return na.hasPrefix(nb) || nb.hasPrefix(na)
    }

    private static func normalize(_ name: String) -> String {
        name.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    /// Great-circle distance in miles.
    public static func haversineMiles(
        _ lat1: Double, _ lon1: Double,
        _ lat2: Double, _ lon2: Double
    ) -> Double {
        let earthRadiusMiles = 3958.8
        let toRadians = Double.pi / 180
        let dLat = (lat2 - lat1) * toRadians
        let dLon = (lon2 - lon1) * toRadians
        let a = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1 * toRadians) * cos(lat2 * toRadians)
            * sin(dLon / 2) * sin(dLon / 2)
        return 2 * earthRadiusMiles * asin(sqrt(a))
    }
}
