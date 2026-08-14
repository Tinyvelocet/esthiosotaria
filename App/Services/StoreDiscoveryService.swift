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

    private let overpass = OverpassPOIService()

    /// Discovers grocery stores within `radiusMiles` of the coordinate.
    func discoverStores(near coordinate: CLLocationCoordinate2D, radiusMiles: Double) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        // Query both sources concurrently — neither blocks the other.
        async let mapKitResults = mapKitSearch(near: coordinate, radiusMiles: radiusMiles)
        async let overpassResults = overpassSearch(near: coordinate, radiusMiles: radiusMiles)

        let mapKitStores = await mapKitResults
        let osmStores = await overpassResults

        switch (mapKitStores, osmStores) {
        case let (mk?, osm?):
            let center = (lat: coordinate.latitude, lon: coordinate.longitude)
            discoveredStores = StoreMerger.merge(mk, osm, around: center)
            source = .merged
        case let (mk?, nil):
            discoveredStores = mk
            source = .mapKit
        case let (nil, osm?):
            discoveredStores = osm
            source = .overpass
        case (nil, nil):
            errorMessage = "Could not find stores nearby. Check your connection and try again."
            discoveredStores = []
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
