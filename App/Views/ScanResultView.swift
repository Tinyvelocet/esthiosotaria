import SwiftUI
import RecallKit

/// The transient result of a "Scan this location" check — shows the nearest
/// store's recall status using the same severity/category cards as the
/// favorites. Not persisted: a stale/dismissed result goes away.
struct ScanResultView: View {
    let result: ScanLocationService.Result
    let onClose: () -> Void

    @EnvironmentObject var settings: UserSettingsStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Design.Spacing.sectionGap) {
                    header
                    if result.chainMatches.isEmpty && result.regionalMatches.isEmpty {
                        allSafeCard
                    } else {
                        if !result.chainMatches.isEmpty { matchesSection("Match at \(result.store.name)", result.chainMatches) }
                        if !result.regionalMatches.isEmpty { matchesSection("Also in your area", result.regionalMatches) }
                    }
                }
                .padding(Design.Spacing.screenPadding)
            }
            .background(Design.Paper.background)
            .scrollContentBackground(.hidden)
            .navigationTitle("Scan — \(result.store.name)")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { onClose() }
                }
            }
        }
        .environmentObject(settings)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                StoreBadge(store: result.store, size: 22)
                Text(result.store.name)
                    .font(.headline)
            }
            Text("Checked against the latest FDA & USDA recalls.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var allSafeCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("All safe at \(result.store.name)", systemImage: "checkmark.circle.fill")
                .font(.headline)
                .foregroundStyle(Design.Accent.brand)
            Text("No recall matches right now for the kind of products this store carries.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Design.Paper.surface, in: RoundedRectangle(cornerRadius: Design.Radius.card))
    }

    private func matchesSection(_ title: String, _ items: [RecallListViewModel.Item]) -> some View {
        VStack(alignment: .leading, spacing: Design.Spacing.cardGroupGap) {
            Text(title.uppercased())
                .font(.caption.weight(.bold))
                .tracking(0.6)
                .foregroundStyle(Design.Accent.brand)
            ForEach(items) { item in
                RecallRowView(item: item, stores: settings.selectedStores + [result.store], isMuted: settings.isProductMuted(item.recall))
            }
        }
    }
}