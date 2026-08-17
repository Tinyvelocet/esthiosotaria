import SwiftUI
import RecallKit

/// The recall card — the single most repeated element in the app.
/// Pure design surface: pass an item + stores, get a card.
///
/// **Design notes:** severity must read at a glance (dot + words, never
/// icon-only) and carries real type weight so it's the first thing scanned.
/// Chain matches carry red store chips — the escalation signal. Agency pill
/// (FDA/USDA) distinguishes sources. Every icon is paired with text.
/// Spacing is deliberately uneven: tight within the title/reason pair,
/// looser between the card's three groups (meta, content, chips).
struct RecallRowView: View {
    let item: RecallListViewModel.Item
    let stores: [Store]

    var body: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.cardGroupGap) {
            HStack(spacing: 8) {
                severityBadge
                agencyPill
                Spacer()
                Text(item.recall.displayDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: Design.Spacing.cardTightGap) {
                Text(item.recall.shortProductName())
                    .font(.title3.weight(.semibold))
                    .lineLimit(2)
                Text(item.recall.reasonSummary())
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if !item.relevance.matchedStoreIDs.isEmpty {
                storeChips
            }
        }
        .padding(.vertical, Design.Spacing.cardVertical)
    }

    private var severityBadge: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(severityColor)
                .frame(width: 10, height: 10)
            Text(severityLabel)
                .font(.subheadline.weight(.bold))
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

    /// Matched stores as individual red capsules (the escalation signal),
    /// each carrying that store's own identity badge so it's recognizable
    /// at a glance — wrapping onto multiple lines rather than one
    /// truncated, comma-joined caption, since up to 4 stores can match
    /// and names run long.
    private var storeChips: some View {
        FlowLayout(spacing: 6) {
            ForEach(matchedStores) { store in
                HStack(spacing: 5) {
                    StoreBadge(store: store, size: 14)
                    Text(store.name)
                        .font(.caption.weight(.semibold))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Design.Accent.storeMatch.opacity(0.15), in: Capsule())
                .foregroundStyle(Design.Accent.storeMatch)
            }
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
        case .classI: return Design.Severity.critical
        case .classII: return Design.Severity.serious
        case .classIII: return Design.Severity.minor
        case .unknown, nil: return Design.Severity.unclassified
        }
    }

    private var matchedStores: [Store] {
        item.relevance.matchedStoreIDs
            .compactMap { id in stores.first(where: { $0.id == id }) }
    }
}

/// Left-to-right, top-to-bottom wrapping layout for chip-style content that
/// can't predict how many items it holds.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var totalHeight: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth > 0, rowWidth + spacing + size.width > maxWidth {
                totalHeight += rowHeight + spacing
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += (rowWidth > 0 ? spacing : 0) + size.width
            rowHeight = max(rowHeight, size.height)
        }
        totalHeight += rowHeight
        return CGSize(width: maxWidth.isFinite ? maxWidth : rowWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
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
