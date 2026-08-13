import SwiftUI
import CoreLocation
import RecallKit

/// First-run flow: explain → locate → discover stores → pick up to 4.
/// Designed to survive a denied location permission via manual entry.
struct OnboardingView: View {
    @EnvironmentObject var settings: UserSettingsStore
    @StateObject private var location = LocationService()
    @StateObject private var discovery = StoreDiscoveryService()

    @State private var step: Step = .welcome
    @State private var coordinate: CLLocationCoordinate2D?
    @State private var radiusMiles: Double = RecallKit.defaultRadiusMiles
    @State private var manualEntry = ""
    @State private var geocodingError: String?

    enum Step { case welcome, locating, pickingStores, manualEntry }

    var body: some View {
        VStack(spacing: 24) {
            switch step {
            case .welcome:
                welcomeView
            case .locating:
                locatingView
            case .pickingStores:
                storePickerView
            case .manualEntry:
                manualEntryView
            }
        }
        .padding(24)
        #if os(macOS)
        .frame(minWidth: 480, minHeight: 560)
        #endif
    }

    // MARK: - Welcome

    private var welcomeView: some View {
        VStack(spacing: 16) {
            Image(systemName: "cart.badge.exclamationmark")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
            Text("Food recalls for your stores")
                .font(.title.bold())
                .multilineTextAlignment(.center)
            Text("EsthioSotaria watches FDA food recalls and flags the ones that could be on the shelves of up to \(RecallKit.maxSelectedStores) grocery stores near you. Your location never leaves this device.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Get started") {
                step = .locating
                Task { await requestLocation() }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: 420)
    }

    // MARK: - Locating

    private var locatingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("Finding your location…")
                .font(.title3)
            if case .denied = location.status {
                Text("Location access was denied. You can type your city instead — nothing is sent anywhere.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Enter my city manually") { step = .manualEntry }
                    .buttonStyle(.bordered)
            }
        }
    }

    private var manualEntryView: some View {
        VStack(spacing: 16) {
            Text("Where do you shop?")
                .font(.title2.bold())
            TextField("City or ZIP code", text: $manualEntry)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 320)
                .onSubmit { geocodeManualEntry() }
            if let geocodingError {
                Text(geocodingError)
                    .foregroundStyle(.red)
                    .font(.callout)
            }
            Button("Find stores near me") { geocodeManualEntry() }
                .buttonStyle(.borderedProminent)
            Button("Back") { step = .welcome }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Store picker

    private var storePickerView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pick up to \(RecallKit.maxSelectedStores) stores")
                .font(.title2.bold())
            if let source = discovery.source {
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
                    if !editing, let coordinate {
                        Task { await discovery.discoverStores(near: coordinate, radiusMiles: radiusMiles) }
                    }
                }
            }

            if discovery.isLoading {
                HStack {
                    ProgressView()
                    Text("Searching for stores…").foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            } else if let errorMessage = discovery.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            } else if discovery.discoveredStores.isEmpty {
                Text("No grocery stores found nearby. Try a wider radius.")
                    .foregroundStyle(.secondary)
            } else {
                List(discovery.discoveredStores, id: \.id) { store in
                    StoreRow(
                        store: store,
                        isSelected: settings.selectedStores.contains(store),
                        canSelectMore: settings.selectedStores.count < RecallKit.maxSelectedStores
                    ) {
                        toggle(store)
                    }
                }
                #if os(iOS)
                .listStyle(.plain)
                #endif
            }

            Spacer(minLength: 0)

            HStack {
                Text("\(settings.selectedStores.count)/\(RecallKit.maxSelectedStores) selected")
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Done") {
                    settings.payload.radiusMiles = radiusMiles
                    settings.finishOnboarding()
                }
                .buttonStyle(.borderedProminent)
                .disabled(settings.selectedStores.isEmpty)
            }
        }
    }

    private func toggle(_ store: Store) {
        if settings.selectedStores.contains(store) {
            settings.removeStore(store)
        } else {
            settings.addStore(store)
        }
    }

    // MARK: - Actions

    private func requestLocation() async {
        do {
            let coordinate = try await location.requestCurrentLocation()
            self.coordinate = coordinate
            step = .pickingStores
            await discovery.discoverStores(near: coordinate, radiusMiles: radiusMiles)
        } catch {
            step = .manualEntry
        }
    }

    private func geocodeManualEntry() {
        geocodingError = nil
        let query = manualEntry.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(query) { placemarks, error in
            Task { @MainActor in
                if let placemark = placemarks?.first, let coordinate = placemark.location?.coordinate {
                    self.coordinate = coordinate
                    if let state = placemark.administrativeArea,
                       let abbrev = StateMatcher.normalizeState(state) {
                        settings.payload.stateAbbrev = abbrev
                    }
                    step = .pickingStores
                    await discovery.discoverStores(near: coordinate, radiusMiles: radiusMiles)
                } else {
                    geocodingError = "Couldn't find that place. Try a city name or ZIP code."
                }
            }
        }
    }
}

/// One row in the discovery list.
struct StoreRow: View {
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
                    if let chain = store.chain {
                        Text(chainLabel(chain))
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

    private func chainLabel(_ chain: String) -> String {
        switch chain {
        case "costco": return "Chain store — recall matches escalate to the top"
        default: return "Chain store"
        }
    }
}
