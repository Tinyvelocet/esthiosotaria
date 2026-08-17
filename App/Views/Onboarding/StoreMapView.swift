import SwiftUI
import MapKit
import RecallKit

/// MapKit companion for the store picker. Shows discovered stores as their
/// identity badges (red ring = selected), the search center pin, and the
/// radius circle.
///
/// Design notes:
/// - Marker tap toggles selection (same affordance as the list rows).
/// - The radius circle is drawn as a map-space annotation so it resizes
///   correctly with zoom via `context.convert(UnitLength, to: .points)`.
/// - Restyle here; the picker owns layout.
struct StoreMapView: View {
    let stores: [Store]
    let selectedStores: [Store]
    let center: CLLocationCoordinate2D
    let radiusMiles: Double
    /// nil disables selection (e.g. limit reached or read-only contexts).
    var onToggle: ((Store) -> Void)?

    @State private var position: MapCameraPosition

    init(
        stores: [Store],
        selectedStores: [Store],
        center: CLLocationCoordinate2D,
        radiusMiles: Double,
        onToggle: ((Store) -> Void)? = nil
    ) {
        self.stores = stores
        self.selectedStores = selectedStores
        self.center = center
        self.radiusMiles = radiusMiles
        self.onToggle = onToggle
        let meters = radiusMiles * OverpassPOIService.metersPerMile
        _position = State(initialValue: .region(MKCoordinateRegion(
            center: center,
            latitudinalMeters: meters * 2.4,
            longitudinalMeters: meters * 2.4)))
    }

    var body: some View {
        Map(position: $position, interactionModes: .all) {
            radiusCircle
            storeMarkers
            centerPin
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
    }

    // MARK: - Content

    private var radiusCircle: some MapContent {
        MapCircle(center: center, radius: radiusMiles * OverpassPOIService.metersPerMile)
            .foregroundStyle(Color.blue.opacity(0.10))
            .stroke(Color.blue.opacity(0.55), lineWidth: 1.5)
    }

    private var storeMarkers: some MapContent {
        ForEach(stores) { store in
            Annotation(store.name, coordinate: CLLocationCoordinate2D(
                latitude: store.latitude, longitude: store.longitude
            ), anchor: .bottom) {
                Button {
                    onToggle?(store)
                } label: {
                    StoreBadge(store: store, size: 28, isEmphasized: isSelected(store))
                        .shadow(radius: 2)
                }
                .buttonStyle(.plain)
                .disabled(onToggle == nil || (!isSelected(store) && selectionFull))
                .opacity(onToggle != nil && !isSelected(store) && selectionFull ? 0.5 : 1)
            }
        }
    }

    // "You are here" stays the system Maps blue-dot convention rather than
    // the app's store-identity system — it isn't a store, and blue is what
    // every Maps-based app already trains users to read as "my location".
    private var centerPin: some MapContent {
        Annotation("You", coordinate: center, anchor: .center) {
            Circle()
                .fill(Color.blue)
                .frame(width: 14, height: 14)
                .overlay(Circle().stroke(.white, lineWidth: 3))
                .shadow(radius: 2)
        }
    }

    // MARK: - Helpers

    private func isSelected(_ store: Store) -> Bool {
        selectedStores.contains(where: { $0.id == store.id })
    }

    private var selectionFull: Bool {
        selectedStores.count >= RecallKit.maxSelectedStores
    }
}

#Preview("Store map") {
    StoreMapView(
        stores: MockData.discoveryStores,
        selectedStores: [MockData.costco, MockData.piazzas],
        center: CLLocationCoordinate2D(latitude: 37.4419, longitude: -122.1430),
        radiusMiles: 15,
        onToggle: { _ in }
    )
    .frame(width: 600, height: 500)
}
