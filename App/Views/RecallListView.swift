import SwiftUI
import RecallKit

/// Main screen: chain matches pinned on top under "Could be at your stores",
/// regional recalls below. The coordinator owns fetching/state; the cards are
/// `RecallRowView` (design surface in `Views/Recalls/RecallRowView.swift`).
///
/// All copy says "could be at your store" — never certainty.
struct RecallListView: View {
    @EnvironmentObject var settings: UserSettingsStore
    @StateObject private var viewModel = RecallListViewModel()
    @State private var selectedRecall: RecallListViewModel.Item?
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
        NavigationStack {
            content
                .navigationTitle("Recalls near you")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            Task { await refresh() }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
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
                .navigationDestination(item: $selectedRecall) { item in
                    RecallDetailView(item: item)
                }
        }
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
        case .loaded:
            loadedList
        }
    }

    private var loadedList: some View {
        let vm = effectiveViewModel
        return List {
            if !vm.chainMatches.isEmpty {
                Section {
                    ForEach(vm.chainMatches) { item in
                        RecallRowView(item: item, stores: settings.selectedStores)
                            .contentShape(Rectangle())
                            .onTapGesture { selectedRecall = item }
                    }
                } header: {
                    Label("Could be at your stores", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(Design.Accent.storeMatch)
                } footer: {
                    Text("Matched by brand or recalling company. The FDA doesn't say which shelf a product was on — check the details before deciding.")
                }
            }

            Section {
                if vm.regionalMatches.isEmpty && vm.chainMatches.isEmpty {
                    Text("No active recalls match your area right now.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(vm.regionalMatches) { item in
                        RecallRowView(item: item, stores: settings.selectedStores)
                            .contentShape(Rectangle())
                            .onTapGesture { selectedRecall = item }
                    }
                }
            } header: {
                Text("In your area")
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    if vm.fsisUnavailable {
                        Label("USDA meat/poultry feed unavailable — FDA recalls shown only.",
                              systemImage: "exclamationmark.circle")
                            .font(.caption)
                            .foregroundStyle(Design.Accent.warning)
                    }
                    if let lastUpdated = vm.lastUpdated {
                        Text("Updated \(lastUpdated.formatted(date: .omitted, time: .shortened)). FDA data may lag the official recall site by days.")
                    }
                }
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        .refreshable { await refresh() }
        #endif
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
