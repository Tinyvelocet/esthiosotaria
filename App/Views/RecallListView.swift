import SwiftUI
import RecallKit

/// Root coordinator after onboarding: owns fetching/state, hands data to
/// two tabs — the store dashboard (quadrant grid) and the area list
/// (regional matches, not tied to any specific store).
struct RecallListView: View {
    @EnvironmentObject var settings: UserSettingsStore
    @StateObject private var viewModel = RecallListViewModel()
    @State private var notifiedIDs: Set<String> = []

    /// Design/preview injection point (nil = live view model).
    private let designViewModel: RecallListViewModel?

    init(viewModel: RecallListViewModel? = nil) {
        designViewModel = viewModel
    }

    private var effectiveViewModel: RecallListViewModel {
        designViewModel ?? viewModel
    }

    var body: some View {
        content
            .task {
                guard designViewModel == nil else { return }
                await refresh()
            }
    }

    @ViewBuilder
    private var content: some View {
        let vm = effectiveViewModel
        switch vm.state {
        case .idle, .loading:
            ProgressView("Checking FDA recalls…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Design.Paper.background)
        case .failed(let message):
            VStack(spacing: 12) {
                Image(systemName: "wifi.exclamationmark")
                    .font(.largeTitle)
                    .foregroundStyle(Design.Accent.warning)
                Text("Couldn't load recalls")
                    .font(.headline)
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Try again") { Task { await refresh() } }
                    .buttonStyle(.borderedProminent)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Design.Paper.background)
        case .loaded:
            tabs
        }
    }

    private var tabs: some View {
        let vm = effectiveViewModel
        return TabView {
            NavigationStack {
                StoreDashboardView(
                    stores: settings.selectedStores,
                    chainMatches: vm.chainMatches,
                    isLoading: vm.isLoading,
                    lastUpdated: vm.lastUpdated,
                    onRefresh: { Task { await refresh() } }
                )
            }
            .tabItem { Label("Stores", systemImage: "square.grid.2x2.fill") }

            NavigationStack {
                AreaListView(
                    items: vm.regionalMatches,
                    isLoading: vm.isLoading,
                    fsisUnavailable: vm.fsisUnavailable,
                    lastUpdated: vm.lastUpdated,
                    onRefresh: { Task { await refresh() } }
                )
            }
            .tabItem { Label("Area", systemImage: "map.fill") }
        }
    }

    private func refresh() async {
        let handled = Set(settings.payload.handledRecallIDs)
        await viewModel.refresh(
            stores: settings.selectedStores,
            stateAbbrev: settings.payload.stateAbbrev,
            handledIDs: handled)

        // Local notification for brand-new chain matches.
        if settings.payload.chainNotificationsEnabled, !viewModel.chainMatches.isEmpty {
            let items = viewModel.chainMatches.map { item in
                let names = item.relevance.matchedStoreIDs.compactMap { id in
                    settings.selectedStores.first(where: { $0.id == id })?.name
                }
                return (recall: item.recall, storeLabel: names.joined(separator: ", "))
            }
            let notified = await NotificationScheduler.notifyNewChainMatches(
                items, seenIDs: notifiedIDs)
            if !notified.isEmpty {
                notifiedIDs.formUnion(notified)
            }
        }
    }
}

private extension RecallListViewModel {
    var isLoading: Bool { state == .loading }
}

#Preview("Recall list — populated") {
    RecallListView(viewModel: .designState())
        .environmentObject(UserSettingsStore.designState())
}

#Preview("Recall list — FSIS unavailable") {
    let vm = RecallListViewModel.designState()
    vm.fsisUnavailable = true
    return RecallListView(viewModel: vm)
        .environmentObject(UserSettingsStore.designState())
}
