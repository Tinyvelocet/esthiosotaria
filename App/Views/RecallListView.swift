import SwiftUI
import RecallKit

/// Main screen: chain matches pinned on top, regional recalls below.
/// All copy says "could be at your store" — never certainty.
struct RecallListView: View {
    @EnvironmentObject var settings: UserSettingsStore
    @StateObject private var viewModel = RecallListViewModel()
    @State private var selectedRecall: RecallListViewModel.Item?

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
        .task { await refresh() }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            ProgressView("Checking FDA recalls…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let message):
            VStack(spacing: 12) {
                Image(systemName: "wifi.exclamationmark")
                    .font(.largeTitle)
                    .foregroundStyle(.orange)
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
        List {
            if !viewModel.chainMatches.isEmpty {
                Section {
                    ForEach(viewModel.chainMatches) { item in
                        RecallRow(item: item, stores: settings.selectedStores)
                            .contentShape(Rectangle())
                            .onTapGesture { selectedRecall = item }
                    }
                } header: {
                    Label("Could be at your stores", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                } footer: {
                    Text("Matched by brand or recalling company. The FDA doesn't say which shelf a product was on — check the details before deciding.")
                }
            }

            Section {
                if viewModel.regionalMatches.isEmpty && viewModel.chainMatches.isEmpty {
                    Text("No active recalls match your area right now.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.regionalMatches) { item in
                        RecallRow(item: item, stores: settings.selectedStores)
                            .contentShape(Rectangle())
                            .onTapGesture { selectedRecall = item }
                    }
                }
            } header: {
                Text("In your area")
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    if viewModel.fsisUnavailable {
                        Label("USDA meat/poultry feed unavailable — FDA recalls shown only.",
                              systemImage: "exclamationmark.circle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    if let lastUpdated = viewModel.lastUpdated {
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

    /// In-memory set of recall ids already notified this session.
    /// (Persisted variant lands with the notification-settings phase.)
    @State private var notifiedIDs: Set<String> = []
}

/// One recall card. Severity dot + plain-language label, every icon paired
/// with text per the self-explanatory-UI rule.
struct RecallRow: View {
    let item: RecallListViewModel.Item
    let stores: [Store]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                severityBadge
                Text(item.recall.agency.rawValue)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())
                    .foregroundStyle(.secondary)
                Spacer()
                Text(dateLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(item.recall.shortProductName())
                .font(.headline)
                .lineLimit(2)
            Text(item.recall.reasonSummary())
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            if !item.relevance.matchedStoreIDs.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "storefront")
                        .font(.caption)
                    Text(storeNames)
                        .font(.caption.weight(.medium))
                }
                .foregroundStyle(.red)
            }
        }
        .padding(.vertical, 4)
    }

    private var severityBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(severityColor)
                .frame(width: 9, height: 9)
            Text(severityLabel)
                .font(.caption.bold())
                .foregroundStyle(severityColor)
        }
    }

    private var severityLabel: String {
        switch item.recall.classification {
        case .classI: return "Critical — Class I"
        case .classII: return "Serious — Class II"
        case .classIII: return "Minor — Class III"
        case .unknown, nil: return "Unclassified"
        }
    }

    private var severityColor: Color {
        switch item.recall.classification {
        case .classI: return .red
        case .classII: return .orange
        case .classIII: return .gray
        case .unknown, nil: return .secondary
        }
    }

    private var storeNames: String {
        item.relevance.matchedStoreIDs
            .compactMap { id in stores.first(where: { $0.id == id })?.name }
            .joined(separator: ", ")
    }

    private var dateLabel: String {
        guard let raw = item.recall.reportDate, raw.count == 8,
              let year = Int(raw.prefix(4)),
              let month = Int(raw.dropFirst(4).prefix(2)),
              let day = Int(raw.suffix(2)) else { return "" }
        var components = DateComponents()
        components.year = year; components.month = month; components.day = day
        guard let date = Calendar.current.date(from: components) else { return "" }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }
}
