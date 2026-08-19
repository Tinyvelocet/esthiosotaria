import Foundation

/// A coarse product category inferred from a recall's free-text fields.
///
/// Powers **Tier-2 matching**: when the recalling brand doesn't match a tracked
/// store's chain, the *kind of product* can still be relevant to a store that
/// plausibly carries it — e.g. a soft-cheese recall **could be** at the gourmet
/// independent grocer you track, even though no house brand names it.
///
/// Always a heuristic — inferred from keywords, never from structured data the
/// FDA publishes. The UI must keep saying "could be at your store".
public enum ProductCategory: String, Sendable, CaseIterable {
    case cheese
    case deli
    case bakery
    case seafood
    case produce
    case dairy
    case meat
    case prepared   // prepared/fresh meals, rotisserie, deli-prepared foods
    case confectionery
    case nuts
    case pantry
    case beverage
    case frozen
    case baby
    case other

    /// A human, plural-ish label for reasons/copy.
    public var label: String {
        switch self {
        case .cheese: return "cheese (soft & aged)"
        case .deli: return "deli meats & sandwiches"
        case .bakery: return "bakery goods"
        case .seafood: return "seafood"
        case .produce: return "fresh produce"
        case .dairy: return "dairy"
        case .meat: return "meat & poultry"
        case .prepared: return "prepared foods"
        case .confectionery: return "confectionery"
        case .nuts: return "nuts & nut butters"
        case .pantry: return "pantry staples"
        case .beverage: return "beverages"
        case .frozen: return "frozen foods"
        case .baby: return "infant & baby food"
        case .other: return "food products"
        }
    }
}