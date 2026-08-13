import SwiftUI
import WidgetKit
import RecallKit

/// The recall widget UI — shared verbatim between iOS and macOS.
/// Design surfaces are the three widget families; restyle here.
struct RecallWidgetEntryView: View {
    @Environment(\.widgetFamily) private var environmentFamily
    let entry: RecallEntry
    /// Override the widget family (tests / design renders); nil = use environment.
    var familyOverride: WidgetFamily?

    private var family: WidgetFamily { familyOverride ?? environmentFamily }

    init(entry: RecallEntry, familyOverride: WidgetFamily? = nil) {
        self.entry = entry
        self.familyOverride = familyOverride
    }

    var body: some View {
        switch family {
        case .systemSmall:
            smallView
        case .systemMedium:
            mediumView
        case .systemLarge:
            largeView
        default:
            mediumView
        }
    }

    // MARK: - Small: headline signal

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 6) {
            headerBadge
            if let top = entry.snapshot.topItems(limit: 1).first {
                Text(top.recall.shortProductName())
                    .font(.caption.bold())
                    .lineLimit(3)
                    .minimumScaleFactor(0.85)
                if !top.matchedStoreNames.isEmpty {
                    Text(top.matchedStoreNames.joined(separator: ", "))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            } else {
                Text("No recalls match your stores")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            staleFooter
        }
        .containerBackgroundCompat()
    }

    // MARK: - Medium: top 2 with tier badges

    private var mediumView: some View {
        VStack(alignment: .leading, spacing: 6) {
            headerBadge
            let items = entry.snapshot.topItems(limit: 2)
            if items.isEmpty {
                Spacer(minLength: 4)
                Text("No active recalls match your area.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                ForEach(items, id: \.recall.id) { item in
                    widgetRow(item)
                }
                Spacer(minLength: 0)
            }
            staleFooter
        }
        .containerBackgroundCompat()
    }

    // MARK: - Large: more items

    private var largeView: some View {
        VStack(alignment: .leading, spacing: 8) {
            headerBadge
            let items = entry.snapshot.topItems(limit: 5)
            if items.isEmpty {
                Text("No active recalls match your area.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                ForEach(items, id: \.recall.id) { item in
                    widgetRow(item)
                    if item.recall.id != items.last?.recall.id {
                        Divider()
                    }
                }
                Spacer(minLength: 0)
            }
            staleFooter
        }
        .containerBackgroundCompat()
    }

    // MARK: - Pieces

    private func widgetRow(_ item: RecallSnapshot.Item) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(color(for: item.recall.classification))
                .frame(width: 8, height: 8)
                .padding(.top, 5)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.recall.shortProductName())
                    .font(.caption.bold())
                    .lineLimit(2)
                HStack(spacing: 4) {
                    Text(severityLabel(item.recall.classification))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(color(for: item.recall.classification))
                    if item.tier == .chain, !item.matchedStoreNames.isEmpty {
                        Text("• \(item.matchedStoreNames.joined(separator: ", "))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
    }

    private var headerBadge: some View {
        HStack(spacing: 5) {
            Image(systemName: entry.snapshot.hasStoreMatch
                  ? "exclamationmark.triangle.fill"
                  : "checkmark.seal.fill")
                .font(.caption)
                .foregroundStyle(entry.snapshot.hasStoreMatch ? Color.red : Color.green)
            Text(entry.snapshot.hasStoreMatch ? "Could be at your store" : "Recalls near you")
                .font(.caption.bold())
            Spacer()
        }
    }

    private var staleFooter: some View {
        Group {
            if entry.snapshot.generatedAt == .distantPast {
                Text("Open EsthioSotaria to set up")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            } else {
                Text("Updated \(entry.snapshot.generatedAt.formatted(date: .omitted, time: .shortened))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func severityLabel(_ classification: Recall.Classification?) -> String {
        switch classification {
        case .classI: return "Critical — Class I"
        case .classII: return "Serious — Class II"
        case .classIII: return "Minor — Class III"
        case .unknown, nil: return "Unclassified"
        }
    }

    private func color(for classification: Recall.Classification?) -> Color {
        switch classification {
        case .classI: return .red
        case .classII: return .orange
        case .classIII: return .gray
        case .unknown, nil: return .secondary
        }
    }
}

extension View {
    /// containerBackground(for: .widget) exists on iOS 17+/macOS 14+ only.
    /// Both deployment targets qualify, but keep the call in one place.
    @ViewBuilder
    func containerBackgroundCompat() -> some View {
        self.containerBackground(.background, for: .widget)
    }
}
