import SwiftUI
import CoreLocation
import MapKit
import RecallKit

/// Onboarding coordinator. Owns all onboarding STATE (location, discovery,
/// step machine) and delegates rendering to the isolated, design-friendly
/// screens in this folder:
///
/// - `OnboardingWelcomeView`      step: welcome
/// - `OnboardingLocatingView`     step: locating (or denied)
/// - `OnboardingManualEntryView`  step: manual entry
/// - `OnboardingStorePickerView`  step: pick stores
///
/// Design iteration should happen in those files, not here.
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
        VStack(spacing: Design.Spacing.screenPadding) {
            switch step {
            case .welcome:
                OnboardingWelcomeView(onStart: {
                    step = .locating
                    Task { await requestLocation() }
                })
            case .locating:
                OnboardingLocatingView(
                    isDenied: isLocationDenied,
                    onManualEntry: { step = .manualEntry }
                )
            case .manualEntry:
                OnboardingManualEntryView(
                    text: $manualEntry,
                    errorMessage: geocodingError,
                    onSearch: { geocodeManualEntry() },
                    onBack: { step = .welcome }
                )
            case .pickingStores:
                OnboardingStorePickerView(
                    stores: discovery.discoveredStores,
                    selectedStores: settings.selectedStores,
                    source: discovery.source,
                    isLoading: discovery.isLoading,
                    errorMessage: discovery.errorMessage,
                    searchCenter: coordinate,
                    radiusMiles: $radiusMiles,
                    onRadiusCommit: {
                        if let coordinate {
                            Task { await runDiscovery(near: coordinate) }
                        }
                    },
                    onToggle: { toggle($0) },
                    onDone: {
                        settings.payload.radiusMiles = radiusMiles
                        settings.finishOnboarding()
                    }
                )
            }
        }
        .padding(Design.Spacing.screenPadding)
        #if os(macOS)
        .frame(minWidth: 760, minHeight: 560)
        #endif
    }

    private var isLocationDenied: Bool {
        if case .denied = location.status { return true }
        return false
    }

    private func toggle(_ store: Store) {
        if settings.selectedStores.contains(store) {
            settings.removeStore(store)
        } else {
            settings.addStore(store)
        }
    }

    private func requestLocation() async {
        do {
            let coordinate = try await location.requestCurrentLocation()
            self.coordinate = coordinate
            step = .pickingStores
            await runDiscovery(near: coordinate)
        } catch {
            step = .manualEntry
        }
    }

    private func geocodeManualEntry() {
        geocodingError = nil
        let query = manualEntry.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        CLGeocoder().geocodeAddressString(query) { placemarks, error in
            Task { @MainActor in
                if let placemark = placemarks?.first, let coordinate = placemark.location?.coordinate {
                    self.coordinate = coordinate
                    if let state = placemark.administrativeArea,
                       let abbrev = StateMatcher.normalizeState(state) {
                        settings.payload.stateAbbrev = abbrev
                    }
                    step = .pickingStores
                    await runDiscovery(near: coordinate)
                } else {
                    geocodingError = "Couldn't find that place. Try a city name or ZIP code."
                }
            }
        }
    }

    /// Runs discovery at `radiusMiles`, then syncs the slider/map back to
    /// whatever radius the search actually used (it may auto-expand beyond
    /// what was requested to find a store).
    private func runDiscovery(near coordinate: CLLocationCoordinate2D) async {
        await discovery.discoverStores(near: coordinate, radiusMiles: radiusMiles)
        if let searched = discovery.searchedRadiusMiles {
            radiusMiles = searched
        }
    }
}
