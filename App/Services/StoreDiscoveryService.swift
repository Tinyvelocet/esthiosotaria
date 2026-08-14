import Foundation
import CoreLocation
import MapKit
import RecallKit

/// Store discovery: queries **both** MapKit and OSM Overpass and merges the
/// results, because each source alone misses stores:
///
/// - MapKit `MKLocalSearch` is relevance-ranked and capped (~25–30 results),
///   silently dropping many real stores in dense areas.
/// - OSM Overpass is exhaustive within the radius but misses some entries.
///
/// `StoreMerger` de-duplicates (distance + fuzzy name) and sorts by distance.
/// MapKit remains the primary source for name/quality; Overpass fills gaps.
@MainActor
final class StoreDiscoveryService: ObservableObject {

    enum DiscoverySource: String {
        case merged = "Apple Maps + OpenStreetMap"
        case mapKit = "Apple Maps"
        case overpass = "OpenStreetMap"
    }

    @Published var discoveredStores: [Store] = []
    @Published var source: DiscoverySource?
    @Published var isLoading = false
    @Published var errorMessage: String?
    /// Radius actually used for `discoveredStores` — wider than the
    /// requested radius if the search had to auto-expand to find a store.
    @Published var searchedRadiusMiles: Double?

    private let overpass = OverpassPOIService()

    /// Discovers grocery stores near a coordinate, starting at `radiusMiles`
    /// and expanding in `RecallKit.radiusExpansionStepMiles` steps (up to
    /// `RecallKit.radiusRangeMiles`'s upper bound) until at least one store
    /// is found, so a sparse area doesn't dead-end the search.
    func discoverStores(near coordinate: CLLocationCoordinate2D, radiusMiles: Double) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        var currentRadius = radiusMiles
        while true {
            let (stores, foundSource) = await search(near: coordinate, radiusMiles: currentRadius)

            if let stores, !stores.isEmpty {
                discoveredStores = stores
                source = foundSource
                searchedRadiusMiles = currentRadius
                return
            }

            guard let nextRadius = RadiusExpansion.nextRadius(
                after: currentRadius,
                step: RecallKit.radiusExpansionStepMiles,
                ceiling: RecallKit.radiusRangeMiles.upperBound
            ) else {
                errorMessage = "Could not find stores nearby. Check your connection and try again."
                discoveredStores = []
                source = nil
                searchedRadiusMiles = currentRadius
                return
            }
            currentRadius = nextRadius
        }
    }

    /// Queries both sources concurrently — neither blocks the other — and
    /// merges them.
    private func search(
        near coordinate: CLLocationCoordinate2D, radiusMiles: Double
    ) async -> (stores: [Store]?, source: DiscoverySource?) {
        async let mapKitResults = mapKitSearch(near: coordinate, radiusMiles: radiusMiles)
        async let overpassResults = overpassSearch(near: coordinate, radiusMiles: radiusMiles)

        let mapKitStores = await mapKitResults
        let osmStores = await overpassResults

        switch (mapKitStores, osmStores) {
        case let (mk?, osm?):
            let center = (lat: coordinate.latitude, lon: coordinate.longitude)
            return (StoreMerger.merge(mk, osm, around: center), .merged)
        case let (mk?, nil):
            return (mk, .mapKit)
        case let (nil, osm?):
            return (osm, .overpass)
        case (nil, nil):
            return (nil, nil)
        }
    }

    private func overpassSearch(
        near coordinate: CLLocationCoordinate2D, radiusMiles: Double
    ) async -> [Store]? {
        try? await overpass.stores(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            radiusMiles: radiusMiles)
    }

    private func mapKitSearch(
        near coordinate: CLLocationCoordinate2D,
        radiusMiles: Double
    ) async -> [Store]? {
        let region = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: radiusMiles * OverpassPOIService.metersPerMile * 2,
            longitudinalMeters: radiusMiles * OverpassPOIService.metersPerMile * 2)

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "grocery store supermarket"
        request.region = region
        request.resultTypes = .pointOfInterest

        do {
            let response = try await MKLocalSearch(request: request).start()
            let origin = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            let stores: [Store] = response.mapItems.compactMap { item in
                let coordinate = item.placemark.coordinate
                // Filter to the requested radius (MapKit may return items outside).
                let distanceMiles = origin.distance(from: CLLocation(
                    latitude: coordinate.latitude, longitude: coordinate.longitude
                )) / OverpassPOIService.metersPerMile
                guard distanceMiles <= radiusMiles else { return nil }
                let name = item.name ?? "Grocery store"
                return Store(
                    name: name,
                    chain: ChainCatalog.chainID(forStoreName: name),
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude)
            }
            return stores.isEmpty ? nil : stores
        } catch {
            return nil // fall through to Overpass-only
        }
    }
}
