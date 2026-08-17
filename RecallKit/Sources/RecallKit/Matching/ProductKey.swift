import Foundation

/// Identifies the recurring brand behind a recall, for muting products a
/// user doesn't buy. Recall *events* never repeat (each has a unique id
/// and product description), but the brand/firm text often does — so
/// muting keys off that instead of `Recall.id`.
public enum ProductKey {
    /// The label to show/mute for a recall — prefers the first non-empty
    /// brand name from openFDA's `brand_name` array, falls back to the
    /// recalling firm. `nil` only when a synthetic/malformed record has
    /// neither.
    public static func displayName(for recall: Recall) -> String? {
        if let brand = recall.brandNames?.first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) {
            return brand
        }
        return recall.recallingFirm
    }

    public static func normalize(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// Whether `recall`'s brand/firm matches any of the user's muted names
    /// (case- and whitespace-insensitive).
    public static func isMuted(_ recall: Recall, mutedNames: [String]) -> Bool {
        guard let name = displayName(for: recall) else { return false }
        let key = normalize(name)
        return mutedNames.contains { normalize($0) == key }
    }
}
