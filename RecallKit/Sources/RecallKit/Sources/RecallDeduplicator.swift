import Foundation

/// Combines the structured openFDA feed with the fresher, sparser FDA RSS feed.
///
/// The fast feed's whole point is catching recalls openFDA hasn't indexed yet.
/// Once openFDA catches up, the same notice would otherwise appear twice — so
/// we deduplicate by the FDA notice URL's trailing slug and let the structured
/// (classified) record win, while fast-only notices (freshest) are appended.
public enum RecallDeduplicator {

    /// Returns `base` plus any `fast` notices that aren't already represented.
    public static func mergeFast(_ fast: [Recall], intoBase base: [Recall]) -> [Recall] {
        let baseSlugs = Set(base.compactMap { noticeSlug($0.urlString) })
        var kept = base
        var seenIDs = Set(kept.map(\.id))
        for record in fast {
            if let slug = noticeSlug(record.urlString), baseSlugs.contains(slug) {
                continue // the structured base already has this notice
            }
            if seenIDs.contains(record.id) { continue }
            seenIDs.insert(record.id)
            kept.append(record)
        }
        return kept
    }

    /// The trailing, non-empty path segment of an FDA notice URL, normalized.
    /// e.g. ".../recalls-market-withdrawals-safety-alerts/hy-vee-..." -> "hy-vee-...".
    static func noticeSlug(_ url: String?) -> String? {
        guard let url else { return nil }
        let withoutQuery = url.split(separator: "?").first.map(String.init) ?? url
        guard let last = withoutQuery.split(separator: "/").last, !last.isEmpty else { return nil }
        return String(last).lowercased()
    }
}