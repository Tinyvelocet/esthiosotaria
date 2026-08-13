import Foundation

/// Maps grocery chains to the firm/brand strings that appear in FDA recall
/// records. When a recall's recalling firm, product description, or brand
/// names contain one of these strings, we say the recall *could be* at a
/// store of that chain — never that it definitely is.
///
/// Keep keys lowercase-normalized; matching is case-insensitive.
/// Extend as needed — unknown stores simply fall back to regional matching.
public enum ChainCatalog {

    /// Normalized chain id -> substrings indicating that chain in recall text.
    public static let triggers: [String: [String]] = [
        "costco": ["costco", "kirkland"],
        "wholefoods": [
            "whole foods", "whole foods market",
            "365 everyday value", "365 by whole foods market",
        ],
        "traderjoes": ["trader joe", "trader joes", "trader joe's"],
        "safeway": ["safeway"],
        "albertsons": ["albertsons", "albertson's", "lucky", "andronico"],
        "kroger": ["kroger", "fred meyer", "ralphs"],
        "walmart": ["walmart", "great value", "marketside"],
        "target": ["target corporation", "good & gather", "market pantry"],
        "sprouts": ["sprouts farmers market", "sprouts"],
        "groceryoutlet": ["grocery outlet"],
        "99ranch": ["99 ranch", "tawa supermarket"],
    ]

    /// Returns the normalized chain id for a store name, if known.
    /// e.g. "Costco Wholesale (Mountain View)" -> "costco".
    public static func chainID(forStoreName name: String) -> String? {
        let lower = name.lowercased()
        for (chain, keys) in triggers where keys.contains(where: lower.contains) {
            return chain
        }
        return nil
    }

    /// Returns chain ids whose trigger strings appear anywhere in `text`.
    public static func chains(inText text: String) -> Set<String> {
        let lower = text.lowercased()
        var found = Set<String>()
        for (chain, keys) in triggers where keys.contains(where: lower.contains) {
            found.insert(chain)
        }
        return found
    }
}
