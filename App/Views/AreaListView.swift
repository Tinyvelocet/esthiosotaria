import SwiftUI
import RecallKit

/// The "Area" tab — recalls distributed to the user's state/nationwide,
/// not tied to any specific tracked store. Split out from the dashboard
/// because a store-quadrant grid has no natural home for data that isn't
/// about a store.
struct AreaListView: View {
    let items: [RecallListViewModel.Item]
    let isLoading: Bool
    let fsisUnavailable: Bool
    let lastUpdated: Date?
    let onRefresh: () -> Void

    @EnvironmentObject var settings: UserSettingsStore

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Checking FDA recalls…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Design.Paper.background)
            } else {
                List {
                    Section {
                        if items.isEmpty {
                            Text("No active recalls match your area right now.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(items) { item in
                                NavigationLink {
                                    RecallDetailView(item: item)
                                } label: {
                                    RecallRowView(item: item, stores: [], isMuted: settings.isProductMuted(item.recall))
                                }
                                .muteSwipeAction(for: item, settings: settings)
                            }
                        }
                    } footer: {
                        VStack(alignment: .leading, spacing: 4) {
                            if fsisUnavailable {
                                Label("USDA meat/poultry feed unavailable — FDA recalls shown only.",
                                      systemImage: "exclamationmark.circle")
                                    .font(.caption)
                                    .foregroundStyle(Design.Accent.warning)
                            }
                            if let lastUpdated {
                                Text("Updated \(lastUpdated.formatted(date: .omitted, time: .shortened)). FDA data may lag the official recall site by days.")
                            }
                        }
                    }
                }
                #if os(iOS)
                .listStyle(.insetGrouped)
                .refreshable { onRefresh() }
                #endif
                .scrollContentBackground(.hidden)
                .background(Design.Paper.background)
            }
        }
        .navigationTitle("In your area")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { onRefresh() } label: { Image(systemName: "arrow.clockwise") }
                    .help("Refresh recalls")
                    .accessibilityLabel("Refresh recalls")
            }
        }
    }
}

#Preview("Area list") {
    NavigationStack {
        AreaListView(
            items: RecallListViewModel.designState().regionalMatches,
            isLoading: false,
            fsisUnavailable: false,
            lastUpdated: Date(),
            onRefresh: {}
        )
    }
    .environmentObject(UserSettingsStore.designState())
}
