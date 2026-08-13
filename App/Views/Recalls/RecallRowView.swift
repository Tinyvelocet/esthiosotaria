import SwiftUI
import RecallKit

/// The recall card — the single most repeated element in the app.
/// Pure design surface: pass an item + stores, get a card.
///
/// **Design notes:** severity must read at a glance (dot + words, never
/// icon-only). Chain matches carry red store chips. Agency pill (FDA/USDA)
/// distinguishes sources. Every icon is paired with text.
struct RecallRowView: View {
    let item: RecallListViewModel.Item
    let stores: [Store]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                severityBadge
                agencyPill
                Spacer()
                Text(item.recall.displayDate)
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
                .foregroundStyle(Design.Accent.storeMatch)
            }
        }
        .padding(.vertical, Design.Spacing.cardVertical)
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

    private var agencyPill: some View {
        Text(item.recall.agency.rawValue)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(.quaternary, in: Capsule())
            .foregroundStyle(.secondary)
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
        case .classI: return Design.Severity.critical
        case .classII: return Design.Severity.serious
        case .classIII: return Design.Severity.minor
        case .unknown, nil: return Design.Severity.unclassified
        }
    }

    private var storeNames: String {
        item.relevance.matchedStoreIDs
            .compactMap { id in stores.first(where: { $0.id == id })?.name }
            .joined(separator: ", ")
    }
}

#Preview("Card — Class I chain match (Costco)") {
    List(MockData.items(for: [MockData.kirklandMadeleines], stores: MockData.fourStores)) { item in
        RecallRowView(item: item, stores: MockData.fourStores)
    }
    .listStyle(.plain)
}

#Preview("Card — all severities") {
    List(MockData.items(for: MockData.chainMatchRecalls + MockData.regionalRecalls, stores: MockData.fourStores)) { item in
        RecallRowView(item: item, stores: MockData.fourStores)
    }
    .listStyle(.plain)
}
