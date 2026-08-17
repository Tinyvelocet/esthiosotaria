import SwiftUI
import RecallKit

/// Drill-down from a dashboard tile: every currently active recall
/// touching one specific store, in the same card style as before.
struct StoreRecallListView: View {
    let store: Store
    let items: [RecallListViewModel.Item]

    @EnvironmentObject var settings: UserSettingsStore
    @State private var selectedRecall: RecallListViewModel.Item?

    var body: some View {
        List {
            if items.isEmpty {
                Section {
                    Text("No active recalls for this store right now.")
                        .foregroundStyle(.secondary)
                }
            } else {
                Section {
                    ForEach(items) { item in
                        RecallRowView(item: item, stores: [store], isMuted: settings.isProductMuted(item.recall))
                            .contentShape(Rectangle())
                            .onTapGesture { selectedRecall = item }
                            .muteSwipeAction(for: item, settings: settings)
                    }
                } footer: {
                    Text("Matched by brand or recalling company. The FDA doesn't say which shelf a product was on — check the details before deciding.")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Design.Paper.background)
        .navigationTitle(store.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .listStyle(.insetGrouped)
        #endif
        .navigationDestination(item: $selectedRecall) { item in
            RecallDetailView(item: item)
        }
    }
}

#Preview("Store recall list") {
    NavigationStack {
        StoreRecallListView(
            store: MockData.costco,
            items: RecallListViewModel.designState().chainMatches
        )
    }
    .environmentObject(UserSettingsStore.designState())
}
