import SwiftUI
import CoreLocation
import RecallKit

/// Settings: stores, radius, notification toggle, manual location override.
struct SettingsView: View {
    @EnvironmentObject var settings: UserSettingsStore
    @StateObject private var discovery = StoreDiscoveryService()
    @StateObject private var location = LocationService()
    @State private var manualCity = ""
    @State private var geocodeError: String?
    @State private var newMutedProduct = ""

    var body: some View {
        Form {
            Section {
                ForEach(settings.selectedStores) { store in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(store.name)
                            if let chain = store.chain {
                                Text(chain.capitalized)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Button {
                            settings.removeStore(store)
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(Design.Severity.critical)
                                .frame(minWidth: 44, minHeight: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.borderless)
                        .help("Remove store")
                        .accessibilityLabel("Remove \(store.name)")
                    }
                }
                if settings.selectedStores.isEmpty {
                    Text("No stores selected. Add one below.")
                        .foregroundStyle(.secondary)
                }
            } header: {
                sectionHeader("Your stores")
            }

            Section {
                Button {
                    Task { await scanAtCurrentLocation() }
                } label: {
                    Label(location.status == .requesting ? "Locating…" : "Use my current location",
                          systemImage: "location.fill")
                }
                .buttonStyle(.appSecondary)
                .disabled(location.status == .requesting)
                HStack {
                    TextField("City or ZIP to search", text: $manualCity)
                        .textFieldStyle(.roundedBorder)
                    Button("Search") { searchNearCity() }
                        .buttonStyle(.appSecondary)
                        .disabled(manualCity.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                if let geocodeError {
                    Text(geocodeError).font(.caption).foregroundStyle(.red)
                }
                if discovery.isLoading {
                    ProgressView()
                } else if !discovery.discoveredStores.isEmpty {
                    ForEach(discovery.discoveredStores.prefix(10)) { store in
                        Button {
                            settings.addStore(store)
                        } label: {
                            HStack {
                                Text(store.name).foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "plus.circle.fill")
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(settings.selectedStores.count >= RecallKit.maxSelectedStores)
                    }
                }
            } header: {
                sectionHeader("Add a store")
            }

            Section {
                ForEach(settings.payload.mutedProducts, id: \.self) { product in
                    HStack {
                        Text(product)
                        Spacer()
                        Button {
                            settings.unmuteProduct(product)
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(Design.Severity.critical)
                                .frame(minWidth: 44, minHeight: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.borderless)
                        .help("Remove from muted products")
                        .accessibilityLabel("Unmute \(product)")
                    }
                }
                if settings.payload.mutedProducts.isEmpty {
                    Text("Nothing muted yet. Swipe a recall card, or use its detail page, to mark a brand \"not something I buy.\"")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    TextField("Brand or company name", text: $newMutedProduct)
                        .textFieldStyle(.roundedBorder)
                    Button("Mute") {
                        settings.muteProduct(newMutedProduct)
                        newMutedProduct = ""
                    }
                    .buttonStyle(.appSecondary)
                    .disabled(newMutedProduct.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            } header: {
                sectionHeader("Products you don't buy")
            } footer: {
                Text("Muted products won't trigger notifications or the red \"could be at your store\" alert, but their recalls still show up in your store's list.")
            }

            Section {
                Toggle("Notify me about recall matches", isOn: Binding(
                    get: { settings.payload.chainNotificationsEnabled },
                    set: { newValue in
                        settings.payload.chainNotificationsEnabled = newValue
                        if newValue {
                            Task { _ = await NotificationScheduler.requestAuthorization() }
                        }
                    }
                ))
                Toggle("Notify me when I enter a store", isOn: Binding(
                    get: { settings.payload.entryNotificationsEnabled },
                    set: { setEntryNotifications($0) }
                ))
                Text("Fires when you're near one of your tracked stores. Needs “Always” location access and a real device (the Simulator can't monitor regions).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                sectionHeader("Notifications")
            }

            Section {
                LabeledContent("Data source", value: "openFDA (FDA enforcement reports)")
                LabeledContent("Matching", value: "Brand-based — could be, not certainty")
                Text("Recall data can lag the official FDA site by days to weeks.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                sectionHeader("About")
            }
        }
        .onChange(of: settings.payload.selectedStores) { _, _ in
            guard settings.payload.entryNotificationsEnabled else { return }
            StoreGeofenceService.shared.syncRegions(for: settings.selectedStores)
        }
        .scrollContentBackground(.hidden)
        .background(Design.Paper.background)
        .navigationTitle("Settings")
    }

    /// Replaces the default uppercase-gray Form section header with the
    /// app's own token so Settings stops reading as a stock system screen.
    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.caption.weight(.bold))
            .tracking(0.6)
            .foregroundStyle(Design.Accent.brand)
    }

    private func searchNearCity() {
        geocodeError = nil
        CLGeocoder().geocodeAddressString(manualCity) { placemarks, error in
            Task { @MainActor in
                if let coordinate = placemarks?.first?.location?.coordinate {
                    await discovery.discoverStores(
                        near: coordinate, radiusMiles: settings.radiusMiles)
                } else {
                    geocodeError = "Couldn't find that place."
                }
            }
        }
    }

    /// Discovers stores around the device's current location ("scan a store".
    private func scanAtCurrentLocation() async {
        geocodeError = nil
        do {
            let coordinate = try await location.requestCurrentLocation()
            await discovery.discoverStores(near: coordinate, radiusMiles: settings.radiusMiles)
        } catch {
            geocodeError = error.localizedDescription
        }
    }

    /// Toggles CoreLocation geofencing; asks for "Always" access on first enable.
    private func setEntryNotifications(_ on: Bool) {
        settings.payload.entryNotificationsEnabled = on
        let geofence = StoreGeofenceService.shared
        if on {
            // Ask for Always auth (region monitoring needs it for background
            // delivery). syncRegions registers immediately — regions work in
            // the foreground on WhenInUse and upgrade to background delivery
            // once the user grants Always, so no re-sync is required later.
            geofence.requestAlwaysAuthorizationIfNeeded()
            geofence.syncRegions(for: settings.selectedStores)
        } else {
            geofence.stopAll()
        }
    }
}

#Preview("Settings — populated") {
    NavigationStack {
        SettingsView()
    }
    .environmentObject(UserSettingsStore.designState())
}

#Preview("Settings — empty") {
    NavigationStack {
        SettingsView()
    }
    .environmentObject(UserSettingsStore())
}
