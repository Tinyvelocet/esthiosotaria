import SwiftUI
import RecallKit

/// The app's home screen — a quadrant grid, one tile per tracked store,
/// each showing that store's aggregate danger score as a filled
/// `DangerMark` circle. Replaces the old scrolling list-of-cards home
/// screen; tapping a tile drills into that store's actual recalls.
struct StoreDashboardView: View {
    let stores: [Store]
    let chainMatches: [RecallListViewModel.Item]
    let isLoading: Bool
    let lastUpdated: Date?
    let onRefresh: () -> Void

    @EnvironmentObject var settings: UserSettingsStore
    @State private var selectedStore: Store?

    private let columns = [
        GridItem(.flexible(), spacing: Design.Spacing.sectionGap),
        GridItem(.flexible(), spacing: Design.Spacing.sectionGap),
    ]

    var body: some View {
        ZStack {
            Design.Paper.background.ignoresSafeArea()
            PatternBackground(intensity: overallIntensity)

            if stores.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: Design.Spacing.sectionGap) {
                        header
                        LazyVGrid(columns: columns, spacing: Design.Spacing.sectionGap) {
                            ForEach(stores) { store in
                                let active = activeMatchedItems(for: store)
                                StoreTile(
                                    store: store,
                                    score: DangerScore.score(for: active.map(\.recall)),
                                    activeCount: active.count
                                ) {
                                    selectedStore = store
                                }
                            }
                        }
                    }
                    .padding(Design.Spacing.screenPadding)
                }
            }
        }
        .navigationTitle("Your stores")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { onRefresh() } label: { Image(systemName: "arrow.clockwise") }
                    .help("Refresh recalls")
            }
            ToolbarItem(placement: .secondaryAction) {
                NavigationLink {
                    SettingsView()
                } label: {
                    Image(systemName: "gearshape")
                }
            }
        }
        .navigationDestination(item: $selectedStore) { store in
            StoreRecallListView(store: store, items: matchedItems(for: store))
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            if isLoading {
                Label("Checking FDA and USDA recalls…", systemImage: "ellipsis")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if let lastUpdated {
                Text("Updated \(lastUpdated.formatted(date: .omitted, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "storefront")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No stores tracked yet")
                .font(.headline)
            Text("Add a store in Settings to start seeing danger scores here.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: 320)
    }

    /// Every chain match for a store, muted ones included — this is what
    /// the drill-down list shows, since muting downgrades urgency without
    /// hiding the recall.
    private func matchedItems(for store: Store) -> [RecallListViewModel.Item] {
        chainMatches.filter { $0.relevance.matchedStoreIDs.contains(store.id) }
    }

    /// Muted products excluded — this is what the tile's score and count
    /// reflect, since a muted product isn't something to be alarmed about.
    private func activeMatchedItems(for store: Store) -> [RecallListViewModel.Item] {
        matchedItems(for: store).filter { !settings.isProductMuted($0.recall) }
    }

    /// Feeds the background pattern's density — busier when the worst
    /// tracked store is more dangerous, not just a flat constant.
    private var overallIntensity: Double {
        stores
            .map { DangerScore.score(for: activeMatchedItems(for: $0).map(\.recall)) }
            .max() ?? 0
    }
}

/// One dashboard quadrant: store identity + its aggregate danger fill.
private struct StoreTile: View {
    let store: Store
    let score: Double
    let activeCount: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Design.Spacing.cardGroupGap) {
                DangerMark(score: score, size: 72, showsLabel: true)
                VStack(spacing: 4) {
                    StoreBadge(store: store, size: 20)
                    Text(store.name)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Design.Paper.ink)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                    Text(activeCount == 0 ? "Nothing active" : "\(activeCount) active recall\(activeCount == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(Design.Spacing.screenPadding)
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fill)
            .background(Design.Paper.surface, in: RoundedRectangle(cornerRadius: Design.Radius.card))
            .overlay(
                RoundedRectangle(cornerRadius: Design.Radius.card)
                    .strokeBorder(Design.Paper.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

#Preview("Store dashboard") {
    NavigationStack {
        StoreDashboardView(
            stores: MockData.fourStores,
            chainMatches: RecallListViewModel.designState().chainMatches,
            isLoading: false,
            lastUpdated: Date(),
            onRefresh: {}
        )
    }
    .environmentObject(UserSettingsStore.designState())
}

#Preview("Store dashboard — empty") {
    NavigationStack {
        StoreDashboardView(stores: [], chainMatches: [], isLoading: false, lastUpdated: nil, onRefresh: {})
    }
    .environmentObject(UserSettingsStore.designState())
}
