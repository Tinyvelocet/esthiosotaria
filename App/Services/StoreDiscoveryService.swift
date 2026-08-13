import Foundation
import CoreLocation
import MapKit
import RecallKit

/// Store discovery: MapKit `MKLocalSearch` first (native, rich metadata),
/// with automatic fallback to OSM Overpass when MapKit returns nothing or
/// errors (observed in headless probes; must be verified in-app).
@MainActor
final class StoreDiscoveryService: ObservableObject {

    enum DiscoverySource: String {
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

        // 1) MapKit first.
        if let mapKitResults = await mapKitSearch(near: coordinate, radiusMiles: radiusMiles),
           !mapKitResults.isEmpty {
            discoveredStores = mapKitResults
            source = .mapKit
            return
        }

        // 2) Overpass fallback (keyless OSM).
        do {
            let stores = try await overpass.stores(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                radiusMiles: radiusMiles)
            discoveredStores = stores
            source = .overpass
        } catch {
            errorMessage = "Could not find stores nearby: \(error.localizedDescription)"
            discoveredStores = []
        }
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
        request.naturalLanguageQuery = "grocery store"
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
            return stores
        } catch {
            return nil // fall through to Overpass
        }
    }
}
