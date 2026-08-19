import Foundation

/// Classifies a recall into a `ProductCategory` from its free-text fields.
///
/// Ordered most-specific-first so "soft cheese" wins over "cheese", and
/// "chicken salad" (prepared) wins over "chicken" (meat). Heuristic only.
public enum CategoryCatalog {

    /// Ordered keyword buckets: the first category any keyword hits wins, so
    /// keep the most specific/disambiguating terms earlier in each array and
    /// put whole-bucket priority where overlaps matter (e.g. prepared before meat).
    static let keywordMap: [(ProductCategory, [String])] = [
        (.prepared, ["chicken salad", "potato salad", "rotisserie", "prepared meal",
                     "entrée", "entree", "burrito", "ready-to-eat meal", "frozen dinner"]),
        (.cheese, ["soft cheese", "cream cheese", "brie", "camembert", "ricotta",
                   "mozzarella", "cheddar", "parmesan", "feta", "queso",
                   "cheese spread", "goat's milk cheese", "goat milk cheese",
                   "cheese wheels", "cheese wedges", "cheese"]),
        (.deli, ["deli", "cold cuts", "lunch meat", "salami", "prosciutto",
                 "bologna", "ham", "sandwich meat"]),
        (.seafood, ["seafood", "salmon", "shrimp", "tuna", "tilapia", "shellfish",
                    "oyster", "crab", "lobster", "fish fillet", "smoked fish"]),
        (.frozen, ["frozen pizza", "frozen meal", "ice cream"]),
        (.bakery, ["bagel", "bread", "croissant", "bakery", "muffin", "pita",
                   "tortilla", "rolls", "buns", "flour tortilla"]),
        (.produce, ["romaine", "lettuce", "spinach", "basil", "cucumber", "broccoli",
                    "produce", "herbs", "strawberr", "apple", "tomato", "green onion"]),
        (.nuts, ["peanut", "almond", "walnut", "cashew", "pecan", "hazelnut",
                 "peanut butter", "nut butter", "mixed nuts"]),
        (.meat, ["ground beef", "beef", "pork", "chicken", "turkey", "sausage",
                 "bacon", "meat", "poultry", "lamb"]),
        (.dairy, ["milk", "yogurt", "butter", "cream", "custard", "gelato",
                  "half-and-half"]),
        (.beverage, ["juice", "soda", "iced tea", "coffee", "water", "beverage",
                     "energy drink", "smoothie"]),
        (.confectionery, ["candy", "chocolate", "cookie", "brownie", "confectionary",
                          "donut", "pastry", "snack bar", "granola bar"]),
        (.baby, ["formula", "infant", "baby food", "toddler"]),
        (.pantry, ["rice", "pasta", "flour", "sugar", "oil", "sauce", "spice",
                   "seasoning", "cereal", "quinoa", "oats", "jelly", "jam",
                   "crackers", "pancake mix"]),
    ]

    /// Categories distinctive enough that a store "plausibly carries it" is a
    /// meaningful, non-trivial signal (soft cheese at the gourmet store — not
    /// "pantry staples at Costco"). Only these escalate at Tier-2.
    public static let specialtyCategories: Set<ProductCategory> =
        [.cheese, .deli, .seafood, .prepared, .nuts, .bakery]

    /// Classifies a recall's text into a category (`.other` if nothing matches).
    public static func category(for recall: Recall) -> ProductCategory {
        var text = ""
        if let p = recall.productDescription { text += " \(p)" }
        if let r = recall.reasonForRecall { text += " \(r)" }
        if let f = recall.recallingFirm { text += " \(f)" }
        for b in recall.brandNames ?? [] { text += " \(b)" }
        return category(for: text)
    }

    /// Classifies arbitrary lowercased text into a category.
    public static func category(for text: String) -> ProductCategory {
        let lower = text.lowercased()
        for (category, keywords) in keywordMap {
            if keywords.contains(where: { lower.contains($0) }) {
                return category
            }
        }
        return .other
    }
}