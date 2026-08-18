import SwiftUI
import RecallKit

/// Full details for one recall, with actions and the official notice link.
/// Design surface: header, four labeled sections, handled toggle.
struct RecallDetailView: View {
    let item: RecallListViewModel.Item
    @EnvironmentObject var settings: UserSettingsStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                section("What to look for") {
                    Text(item.recall.productDescription ?? "No product details published.")
                }
                section("Why it was recalled") {
                    Text(item.recall.reasonForRecall ?? "No reason published.")
                }
                section("What you can do") {
                    Text(advice)
                }
                section("Official notice") {
                    Link(destination: noticeURL) {
                        Label("Open the \(item.recall.agency.rawValue) recall record", systemImage: "arrow.up.right.square")
                    }
                }
                handledToggle
                muteToggle
            }
            .padding()
            .padding(.bottom, 60) // clears the floating tab bar — the last toggle was getting obscured behind it
            .frame(maxWidth: 640, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(Design.Paper.background)
        .navigationTitle("Recall details")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            if item.isChainMatch {
                if isMuted {
                    Label("Muted — you said you don't buy this", systemImage: "bell.slash.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)
                } else {
                    Label("Could be at your store", systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(Design.Accent.storeMatch)
                }
                if !matchedStores.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(matchedStores) { store in
                            StoreBadge(store: store, size: 22)
                        }
                    }
                }
            }
            Text(item.recall.recallingFirm ?? "Unknown company")
                .font(Design.BrandFont.sized(26))
                .tracking(-0.3)
                .foregroundStyle(Design.Paper.ink)
            Text("Recall \(item.recall.id)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var matchedStores: [Store] {
        item.relevance.matchedStoreIDs
            .compactMap { id in settings.selectedStores.first(where: { $0.id == id }) }
    }

    private var isMuted: Bool { settings.isProductMuted(item.recall) }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            content()
        }
    }

    private var advice: String {
        let base = "Check the product in your pantry or fridge against the description above. If it matches, don't eat it — return it to the store for a refund or throw it away."
        switch item.recall.classification {
        case .classI:
            return base + " This is a Class I recall (serious health risk). If you ate the product and feel unwell, contact a doctor."
        default:
            return base
        }
    }

    private var noticeURL: URL {
        // FSIS records carry a direct link; FDA records use the accessdata lookup.
        if let urlString = item.recall.urlString, let url = URL(string: urlString) {
            return url
        }
        return URL(string: "https://www.accessdata.fda.gov/scripts/ires/index.cfm?event=recalls.showRecall&recallNumber=\(item.recall.id)")
            ?? URL(string: "https://www.fda.gov/safety/recalls-market-withdrawals-safety-alerts")!
    }

    private var handledToggle: some View {
        Toggle(isOn: Binding(
            get: { settings.isHandled(item.recall) },
            set: { settings.setHandled(item.recall, $0) }
        )) {
            Label("I've handled this recall", systemImage: "checkmark.circle")
        }
        .toggleStyle(.switch)
    }

    /// Only shown when the recall has an identifiable brand/firm to mute —
    /// absent for the rare synthetic record with neither field.
    @ViewBuilder
    private var muteToggle: some View {
        if let productName = ProductKey.displayName(for: item.recall) {
            Toggle(isOn: Binding(
                get: { isMuted },
                set: { newValue in
                    if newValue {
                        settings.muteProduct(productName)
                    } else {
                        settings.unmuteProduct(productName)
                    }
                }
            )) {
                Label("I don't buy \(productName)", systemImage: "bell.slash")
            }
            .toggleStyle(.switch)
        }
    }
}

#Preview("Detail — Class I chain match") {
    NavigationStack {
        RecallDetailView(item: MockData.items(for: [MockData.kirklandMadeleines], stores: MockData.fourStores)[0])
    }
    .environmentObject(UserSettingsStore.designState())
}

#Preview("Detail — muted brand") {
    NavigationStack {
        RecallDetailView(item: MockData.items(for: [MockData.wfmQuinoa], stores: MockData.fourStores)[0])
    }
    .environmentObject(UserSettingsStore.designState())
}

#Preview("Detail — USDA/FSIS regional") {
    NavigationStack {
        RecallDetailView(item: MockData.items(for: [MockData.fsisGroundBeef], stores: [])[0])
    }
    .environmentObject(UserSettingsStore.designState())
}
