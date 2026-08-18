import SwiftUI
import RecallKit

/// Root coordinator after onboarding: owns fetching/state, hands data to
/// the single-destination store dashboard. There's no separate "browse
/// everything nearby" tab — that framed a full unfiltered regional feed
/// as equally important as your own stores. Serious (Class I/II) regional
/// recalls surface as a small section on the dashboard instead; the full
/// log is one opt-in tap away, not a competing primary destination.
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
                // Re-register geofences on launch if store-entry alerts are on
                // (e.g. re-entering the app after they were enabled in Settings).
                if settings.payload.entryNotificationsEnabled {
                    StoreGeofenceService.shared.syncRegions(for: settings.selectedStores)
                }
            }
            .onChange(of: settings.payload.selectedStores) { _, _ in
                guard settings.payload.entryNotificationsEnabled else { return }
                StoreGeofenceService.shared.syncRegions(for: settings.selectedStores)
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
                    .buttonStyle(.appPrimary)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Design.Paper.background)
        case .loaded:
            NavigationStack {
                StoreDashboardView(
                    stores: settings.selectedStores,
                    chainMatches: vm.chainMatches,
                    regionalMatches: vm.regionalMatches,
                    isLoading: vm.isLoading,
                    fsisUnavailable: vm.fsisUnavailable,
                    lastUpdated: vm.lastUpdated,
                    onRefresh: { Task { await refresh() } }
                )
            }
        }
    }

    private func refresh() async {
        let handled = Set(settings.payload.handledRecallIDs)
        await viewModel.refresh(
            stores: settings.selectedStores,
            stateAbbrev: settings.payload.stateAbbrev,
            handledIDs: handled,
            mutedProductNames: settings.payload.mutedProducts)

        guard settings.payload.chainNotificationsEnabled else { return }

        // Chain matches: muted products don't notify, and neither does
        // anything below the Class I/II bar — a Class III alert every
        // time is exactly the fatigue that makes people stop reading the
        // one that's actually serious.
        let notifiableChain = viewModel.chainMatches.filter {
            !settings.isProductMuted($0.recall) && AlertPolicy.warrantsNotification($0.recall)
        }
        if !notifiableChain.isEmpty {
            let items = notifiableChain.map { item in
                let names = item.relevance.matchedStoreIDs.compactMap { id in
                    settings.selectedStores.first(where: { $0.id == id })?.name
                }
                return (recall: item.recall, storeLabel: names.joined(separator: ", "))
            }
            let notified = await NotificationScheduler.notifyNewChainMatches(
                items, seenIDs: notifiedIDs)
            notifiedIDs.formUnion(notified)
        }

        // Regional matches only notify when they clear the same severity
        // bar — this is the same threshold that puts them in the
        // dashboard's "Serious recalls in your area" section, so a
        // notification always corresponds to something visible there.
        let notifiableRegional = viewModel.regionalMatches
            .map(\.recall)
            .filter { !settings.isProductMuted($0) && AlertPolicy.warrantsNotification($0) }
        if !notifiableRegional.isEmpty {
            let notified = await NotificationScheduler.notifyNewRegionalMatches(
                notifiableRegional, seenIDs: notifiedIDs)
            notifiedIDs.formUnion(notified)
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
