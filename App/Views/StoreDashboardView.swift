import SwiftUI
import RecallKit

/// The app's home screen — a severity-ranked stack, one row per tracked
/// store, ordered worst-first. Earlier drafts used a uniform 2×2 card
/// grid where every tile was the same size regardless of how dangerous a
/// store was and half the screen sat empty with fewer than 4 stores —
/// here urgency reshapes the layout itself: a store with something
/// serious active gets a large hero row, a quiet store collapses to a
/// single compact line. Tapping a row drills into that store's recalls.
struct StoreDashboardView: View {
    let stores: [Store]
    let chainMatches: [RecallListViewModel.Item]
    let isLoading: Bool
    let lastUpdated: Date?
    let onRefresh: () -> Void

    @EnvironmentObject var settings: UserSettingsStore
    @State private var selectedStore: Store?

    var body: some View {
        ZStack {
            Design.Paper.background.ignoresSafeArea()
            PatternBackground(intensity: overallIntensity)

            if stores.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: Design.Spacing.cardGroupGap) {
                        header
                        ForEach(rankedStores, id: \.store.id) { entry in
                            StoreRow(store: entry.store, score: entry.score, activeCount: entry.count) {
                                selectedStore = entry.store
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
                    .accessibilityLabel("Refresh recalls")
            }
            ToolbarItem(placement: .secondaryAction) {
                NavigationLink {
                    SettingsView()
                } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("Settings")
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

    /// Muted products excluded — this is what a row's score and count
    /// reflect, since a muted product isn't something to be alarmed about.
    private func activeMatchedItems(for store: Store) -> [RecallListViewModel.Item] {
        matchedItems(for: store).filter { !settings.isProductMuted($0.recall) }
    }

    /// Stores paired with their score/count, worst first — the order the
    /// layout itself expresses through row size, not just tint.
    private var rankedStores: [(store: Store, score: Double, count: Int)] {
        stores
            .map { store -> (Store, Double, Int) in
                let active = activeMatchedItems(for: store)
                return (store, DangerScore.score(for: active.map(\.recall)), active.count)
            }
            .sorted { $0.1 > $1.1 }
            .map { (store: $0.0, score: $0.1, count: $0.2) }
    }

    /// Feeds the background pattern's density — busier when the worst
    /// tracked store is more dangerous, not just a flat constant.
    private var overallIntensity: Double {
        rankedStores.first?.score ?? 0
    }
}

/// One severity-ranked dashboard row. Three tiers, chosen by score, not a
/// fixed template: a hero row for real danger, a compact card for a minor
/// match, and a single line for a quiet store — so the layout itself
/// carries urgency instead of only a recolored fill.
private struct StoreRow: View {
    let store: Store
    let score: Double
    let activeCount: Int
    let action: () -> Void

    private enum Tier { case hero, moderate, quiet }

    private var tier: Tier {
        if score >= 0.7 { return .hero }
        if score > 0 { return .moderate }
        return .quiet
    }

    var body: some View {
        Button(action: action) {
            switch tier {
            case .hero: heroContent
            case .moderate: moderateContent
            case .quiet: quietContent
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens recalls for this store")
    }

    private var heroContent: some View {
        HStack(spacing: Design.Spacing.screenPadding) {
            DangerMark(score: score, size: 100, showsLabel: true)
            VStack(alignment: .leading, spacing: 4) {
                StoreBadge(store: store, size: 22)
                Text(store.name)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Design.Paper.ink)
                    .lineLimit(2)
                Text(countLabel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Design.Accent.storeMatch)
            }
            Spacer(minLength: 0)
        }
        .padding(Design.Spacing.screenPadding)
        .frame(maxWidth: .infinity)
        .background(Design.Paper.surface, in: RoundedRectangle(cornerRadius: Design.Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: Design.Radius.card)
                .strokeBorder(Design.Danger.color(for: score), lineWidth: 1.5))
    }

    private var moderateContent: some View {
        HStack(spacing: Design.Spacing.cardGroupGap) {
            DangerMark(score: score, size: 56, showsLabel: true)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    StoreBadge(store: store, size: 16)
                    Text(store.name)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Design.Paper.ink)
                        .lineLimit(1)
                }
                Text(countLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, Design.Spacing.cardGroupGap)
        .padding(.horizontal, Design.Spacing.screenPadding)
        .frame(maxWidth: .infinity)
        .background(Design.Paper.surface, in: RoundedRectangle(cornerRadius: Design.Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: Design.Radius.card)
                .strokeBorder(Design.Paper.line, lineWidth: 1))
    }

    private var quietContent: some View {
        HStack(spacing: 10) {
            StoreBadge(store: store, size: 20)
            Text(store.name)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Design.Paper.ink)
                .lineLimit(1)
            Spacer(minLength: 0)
            Text("Nothing active")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, Design.Spacing.screenPadding)
        .frame(maxWidth: .infinity)
        .background(Design.Paper.surface.opacity(0.6), in: RoundedRectangle(cornerRadius: Design.Radius.card))
    }

    private var countLabel: String {
        activeCount == 0 ? "Nothing active" : "\(activeCount) active recall\(activeCount == 1 ? "" : "s")"
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
