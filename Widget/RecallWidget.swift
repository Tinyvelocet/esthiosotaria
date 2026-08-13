import SwiftUI
import WidgetKit

/// Widget bundle entry point. One widget for now — the recall board.
/// Adding more (e.g. a single-store widget) later is additive here.
@main
struct EsthioSotariaWidgetBundle: WidgetBundle {
    var body: some Widget {
        RecallWidget()
    }
}

struct RecallWidget: Widget {
    let kind = "RecallWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RecallTimelineProvider()) { entry in
            RecallWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Food recalls near you")
        .description("Shows recalls that could be at your stores — escalated matches first.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

#Preview(as: .systemMedium) {
    RecallWidget()
} timeline: {
    RecallEntry(date: Date(), snapshot: .placeholder)
}

#Preview(as: .systemSmall) {
    RecallWidget()
} timeline: {
    RecallEntry(date: Date(), snapshot: .placeholder)
}

#Preview(as: .systemLarge) {
    RecallWidget()
} timeline: {
    RecallEntry(date: Date(), snapshot: .placeholder)
}
