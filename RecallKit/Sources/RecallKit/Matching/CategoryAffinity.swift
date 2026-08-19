import Foundation

/// Which categories a tracked store is known/specialized enough to *plausibly
/// carry* — the Tier-2 matching signal.
///
/// A generic chain (Costco, Safeway, Kroger, …) carries everything, so for it
/// a category match is a non-signal and returns nothing. A **specialty** store
/// (Whole Foods, Trader Joe's, Sprouts) or an **independent** grocer — the
/// app's "gourmet grocers" — narrows the plausible set enough that matching
/// recall's product category is real signal (soft cheese → that grocer).
public enum CategoryAffinity {

    /// The categories a given store is *distinctively* likely to carry.
    public static func plausibleCategories(for store: Store) -> Set<ProductCategory> {
        switch store.chain {
        case "wholefoods":
            return [.produce, .cheese, .deli, .bakery, .seafood, .prepared,
                    .nuts, .dairy, .pantry, .confectionery]
        case "traderjoes":
            return [.produce, .cheese, .deli, .bakery, .seafood, .prepared,
                    .nuts, .frozen, .pantry, .confectionery]
        case "sprouts":
            return [.produce, .nuts, .prepared, .pantry, .dairy, .seafood, .confectionery]
        case "groceryoutlet", "99ranch", "tawa":
            return [.pantry, .produce, .seafood, .frozen, .nuts, .beverage]
        case .some:
            // Generic big-box / conventional chains carry essentially everything,
            // so a category match carries no Tier-2 signal for them.
            return [.produce, .pantry, .dairy, .frozen, .beverage, .meat, .confectionery]
        case .none:
            // An independent store = the app's "gourmet / specialty grocer".
            return [.cheese, .deli, .seafood, .prepared, .nuts, .bakery,
                    .produce, .dairy, .confectionery]
        }
    }

    /// True when a recall of `category` is a meaningful Tier-2 match for `store`:
    /// the category must be distinctive (see `CategoryCatalog.specialtyCategories`)
    /// AND one the store specifically carries.
    public static func plausiblyCarries(_ category: ProductCategory, for store: Store) -> Bool {
        CategoryCatalog.specialtyCategories.contains(category)
            && plausibleCategories(for: store).contains(category)
    }
}