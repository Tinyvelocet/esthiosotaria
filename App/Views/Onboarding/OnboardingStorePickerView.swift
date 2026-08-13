import SwiftUI
import RecallKit

/// Onboarding step 3 — store picker. The most design-heavy onboarding screen:
/// radius slider, discovery source label, selectable store list, selection
/// counter + Done.
///
/// **Design notes:** the list must make chain-vs-independent visible at a
/// glance (chain stores get escalated recall matches). Selection limit (4)
/// is enforced by dimming unselectable rows — keep that affordance obvious.
struct OnboardingStorePickerView: View {
    let stores: [Store]
    let selectedStores: [Store]
    let source: StoreDiscoveryService.DiscoverySource?
    let isLoading: Bool
    let errorMessage: String?
    @Binding var radiusMiles: Double
    let onRadiusCommit: () -> Void
    let onToggle: (Store) -> Void
    let onDone: () -> Void

    private var canSelectMore: Bool { selectedStores.count < RecallKit.maxSelectedStores }

    var body: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.sectionGap) {
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

            if isLoading {
                HStack {
                    ProgressView()
                    Text("Searching for stores…").foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            } else if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            } else if stores.isEmpty {
                Text("No grocery stores found nearby. Try a wider radius.")
                    .foregroundStyle(.secondary)
            } else {
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

            Spacer(minLength: 0)

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

#Preview("Picker — fresh") {
    OnboardingStorePickerView(
        stores: MockData.discoveryStores,
        selectedStores: [],
        source: .overpass,
        isLoading: false,
        errorMessage: nil,
        radiusMiles: .constant(15),
        onRadiusCommit: {},
        onToggle: { _ in },
        onDone: {}
    )
    .padding(.top)
}

#Preview("Picker — 2 selected") {
    OnboardingStorePickerView(
        stores: MockData.discoveryStores,
        selectedStores: [MockData.costco, MockData.piazzas],
        source: .mapKit,
        isLoading: false,
        errorMessage: nil,
        radiusMiles: .constant(20),
        onRadiusCommit: {},
        onToggle: { _ in },
        onDone: {}
    )
    .padding(.top)
}
