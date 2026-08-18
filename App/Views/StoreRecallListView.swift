import SwiftUI
import RecallKit

/// Drill-down from a dashboard tile: every currently active recall
/// touching one specific store, in the same card style as before.
struct StoreRecallListView: View {
    let store: Store
    let items: [RecallListViewModel.Item]

    @EnvironmentObject var settings: UserSettingsStore

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
                        NavigationLink {
                            RecallDetailView(item: item)
                        } label: {
                            RecallRowView(item: item, stores: [store], isMuted: settings.isProductMuted(item.recall))
                        }
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
