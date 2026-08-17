import SwiftUI
import CoreLocation
import RecallKit

/// Settings: stores, radius, notification toggle, manual location override.
struct SettingsView: View {
    @EnvironmentObject var settings: UserSettingsStore
    @StateObject private var discovery = StoreDiscoveryService()
    @State private var manualCity = ""
    @State private var geocodeError: String?
    @State private var newMutedProduct = ""

    var body: some View {
        Form {
            Section("Your stores") {
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
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.borderless)
                        .help("Remove store")
                    }
                }
                if settings.selectedStores.isEmpty {
                    Text("No stores selected. Add one below.")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Add a store") {
                HStack {
                    TextField("City or ZIP to search", text: $manualCity)
                        .textFieldStyle(.roundedBorder)
                    Button("Search") { searchNearCity() }
                        .buttonStyle(.bordered)
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
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.borderless)
                        .help("Remove from muted products")
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
                    .buttonStyle(.bordered)
                    .disabled(newMutedProduct.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            } header: {
                Text("Products you don't buy")
            } footer: {
                Text("Muted products won't trigger notifications or the red \"could be at your store\" alert, but their recalls still show up in your store's list.")
            }

            Section("Notifications") {
                Toggle("Notify me about store matches", isOn: Binding(
                    get: { settings.payload.chainNotificationsEnabled },
                    set: { newValue in
                        settings.payload.chainNotificationsEnabled = newValue
                        if newValue {
                            Task { _ = await NotificationScheduler.requestAuthorization() }
                        }
                    }
                ))
            }

            Section("About") {
                LabeledContent("Data source", value: "openFDA (FDA enforcement reports)")
                LabeledContent("Matching", value: "Brand-based — could be, not certainty")
                Text("Recall data can lag the official FDA site by days to weeks.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Design.Paper.background)
        .navigationTitle("Settings")
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
