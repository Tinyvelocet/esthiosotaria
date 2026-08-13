import Foundation

/// Display-facing helpers shared by the app and the widget.
/// Kept in RecallKit so every surface renders text identically.
extension Recall {
    /// Short product label for notifications, cards, and widgets.
    public func shortProductName() -> String {
        let description = productDescription ?? "A food product"
        return description.count > 80 ? String(description.prefix(80)) + "…" : description
    }

    /// One-line plain-language reason.
    public func reasonSummary() -> String {
        let reason = reasonForRecall ?? "See the FDA notice for details."
        return reason.count > 100 ? String(reason.prefix(100)) + "…" : reason
    }

    /// Human-readable date from the FDA YYYYMMDD `reportDate`.
    public var displayDate: String {
        guard let raw = reportDate, raw.count == 8,
              let year = Int(raw.prefix(4)),
              let month = Int(raw.dropFirst(4).prefix(2)),
              let day = Int(raw.suffix(2)) else { return "" }
        var components = DateComponents()
        components.year = year; components.month = month; components.day = day
        guard let date = Calendar.current.date(from: components) else { return "" }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }
}
