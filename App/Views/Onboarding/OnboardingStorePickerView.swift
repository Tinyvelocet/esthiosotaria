import SwiftUI
import MapKit
import RecallKit

/// Onboarding step 3 — store picker. **Split layout: store list on the left,
/// MapKit map on the right** (stacked vertically on compact widths, e.g. iPhone).
///
/// **Design notes:**
/// - List and map are two views of the same data: selecting in either one
///   updates both (single source of truth: `selectedStores` + `onToggle`).
/// - The map shows the search center, the radius circle, and store markers
///   (red = selected). Marker tap toggles selection like a list row.
/// - Selection limit (4) is enforced by dimming unselectable rows/markers.
struct OnboardingStorePickerView: View {
    let stores: [Store]
    let selectedStores: [Store]
    let source: StoreDiscoveryService.DiscoverySource?
    let isLoading: Bool
    let errorMessage: String?
    /// Search origin for the map (location or geocoded city).
    var searchCenter: CLLocationCoordinate2D?
    @Binding var radiusMiles: Double
    let onRadiusCommit: () -> Void
    let onToggle: (Store) -> Void
    let onDone: () -> Void

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var hSizeClass
    private var isCompact: Bool { hSizeClass == .compact }
    #else
    private let isCompact = false
    #endif

    private var canSelectMore: Bool { selectedStores.count < RecallKit.maxSelectedStores }

    var body: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.sectionGap) {
            header

            if isLoading {
                HStack {
                    ProgressView()
                    Text("Searching for stores…").foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            } else if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(Design.Accent.warning)
            } else if stores.isEmpty {
                Text("No grocery stores found nearby. Try a wider radius.")
                    .foregroundStyle(.secondary)
            } else {
                splitContent
            }

            Spacer(minLength: 0)
            footer
        }
    }

    // MARK: - Split layout

    @ViewBuilder
    private var splitContent: some View {
        if isCompact {
            // iPhone: map on top, list below.
            VStack(spacing: Design.Spacing.sectionGap) {
                mapSection
                    .frame(height: 260)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                storeList
            }
        } else {
            // Mac / iPad: list left, map right.
            HStack(alignment: .top, spacing: Design.Spacing.sectionGap) {
                storeList
                    .frame(minWidth: 300, idealWidth: 340, maxWidth: 400)
                mapSection
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    @ViewBuilder
    private var mapSection: some View {
        if let center = searchCenter {
            StoreMapView(
                stores: stores,
                selectedStores: selectedStores,
                center: center,
                radiusMiles: radiusMiles,
                onToggle: { store in
                    guard canSelectMore || selectedStores.contains(store) else { return }
                    onToggle(store)
                }
            )
        } else {
            // No coordinate (defensive): keep the slot visible but inert.
            RoundedRectangle(cornerRadius: 12)
                .fill(.quaternary)
                .overlay(
                    Label("Map unavailable", systemImage: "map")
                        .foregroundStyle(.secondary))
        }
    }

    private var storeList: some View {
        List(stores, id: \.id) { store in
            StoreRowView(
                store: store,
                isSelected: selectedStores.contains(store),
                canSelectMore: canSelectMore
            ) {
                onToggle(store)
            }
        }
        #if os(iOS)
        .listStyle(.plain)
        #endif
    }

    // MARK: - Header & footer

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Pick up to \(RecallKit.maxSelectedStores) stores")
                .font(.title2.bold())

            if let source {
                Label("Stores found via \(source.rawValue)", systemImage: "mappin.and.ellipse")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("Search radius: \(radiusMiles, specifier: "%.0f") mi")
                    .font(.callout)
                Slider(
                    value: $radiusMiles,
                    in: RecallKit.radiusRangeMiles,
                    step: 1
                ) {
                    Text("Search radius")
                } onEditingChanged: { editing in
                    if !editing { onRadiusCommit() }
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            Text("\(selectedStores.count)/\(RecallKit.maxSelectedStores) selected")
                .foregroundStyle(.secondary)
            Spacer()
            Button("Done") { onDone() }
                .buttonStyle(.borderedProminent)
                .disabled(selectedStores.isEmpty)
        }
    }
}

/// One selectable store row. Shared by onboarding picker (and previewed here).
struct StoreRowView: View {
    let store: Store
    let isSelected: Bool
    let canSelectMore: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.name)
                        .foregroundStyle(.primary)
                    if store.chain != nil {
                        Text("Chain store — recall matches escalate to the top")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(!isSelected && !canSelectMore)
        .opacity(!isSelected && !canSelectMore ? 0.5 : 1)
    }
}

#Preview("Picker — split, 2 selected") {
    OnboardingStorePickerView(
        stores: MockData.discoveryStores,
        selectedStores: [MockData.costco, MockData.piazzas],
        source: .mapKit,
        isLoading: false,
        errorMessage: nil,
        searchCenter: CLLocationCoordinate2D(latitude: 37.4419, longitude: -122.1430),
        radiusMiles: .constant(15),
        onRadiusCommit: {},
        onToggle: { _ in },
        onDone: {}
    )
    .padding(.top)
    .frame(width: 900, height: 640)
}

#Preview("Picker — fresh") {
    OnboardingStorePickerView(
        stores: MockData.discoveryStores,
        selectedStores: [],
        source: .overpass,
        isLoading: false,
        errorMessage: nil,
        searchCenter: CLLocationCoordinate2D(latitude: 37.4419, longitude: -122.1430),
        radiusMiles: .constant(15),
        onRadiusCommit: {},
        onToggle: { _ in },
        onDone: {}
    )
    .padding(.top)
    .frame(width: 900, height: 640)
}
