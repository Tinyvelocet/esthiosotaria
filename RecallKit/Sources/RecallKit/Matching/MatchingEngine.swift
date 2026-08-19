import Foundation

/// Pure, UI-free relevance engine: given a recall and the user's tracked
/// stores, decides the confidence tier. No I/O — fully unit-testable.
public struct MatchingEngine: Sendable {

    /// User's state as a USPS abbreviation, e.g. "CA".
    public let userStateAbbrev: String

    public init(userState: String) {
        self.userStateAbbrev = StateMatcher.normalizeState(userState) ?? userState.uppercased()
    }

    /// Classifies a recall against the user's tracked stores and area.
    public func relevance(for recall: Recall, stores: [Store]) -> Relevance {
        let haystack = recallText(recall)

        // Tier 1 (chain): firm/brand text matches a tracked store's chain.
        var matchedStores: [UUID] = []
        for store in stores {
            guard let chain = store.chain else { continue }
            if let triggers = ChainCatalog.triggers[chain],
               triggers.contains(where: { trigger in haystack.contains(trigger) }) {
                matchedStores.append(store.id)
            }
        }
        if !matchedStores.isEmpty {
            return Relevance(
                tier: .chain,
                matchedStoreIDs: matchedStores,
                reason: "This recall involves a brand that could be sold at \(matchedStores.count == 1 ? "your store" : "your stores").")
        }

        // Tier 2 (category): the brand isn't a chain house-brand, but the *kind
        // of product* could be carried by a tracked specialty/independent store
        // (e.g. a soft-cheese recall at your gourmet grocer). Elevates to chain
        // so it surfaces at your stores — still only "could be at your store".
        let category = CategoryCatalog.category(for: recall)
        if CategoryCatalog.specialtyCategories.contains(category) {
            var categoryMatched: [UUID] = []
            for store in stores where CategoryAffinity.plausiblyCarries(category, for: store) {
                categoryMatched.append(store.id)
            }
            if !categoryMatched.isEmpty {
                let names = categoryMatched.compactMap { id in stores.first(where: { $0.id == id })?.name }
                let reason: String
                if categoryMatched.count == 1, let name = names.first {
                    reason = "This \(category.label) recall could be at your store \(name) — the kind of product it carries."
                } else {
                    reason = "This \(category.label) recall could be at your stores, which carry this kind of product."
                }
                return Relevance(tier: .chain, matchedStoreIDs: categoryMatched, reason: reason)
            }
        }

        // Tier 3 (regional): distribution covers the user's state.
        if StateMatcher.coversState(recall.distributionPattern, stateAbbrev: userStateAbbrev) {
            return Relevance(
                tier: .regional,
                matchedStoreIDs: [],
                reason: "This recall's distribution includes your area.")
        }

        return Relevance(tier: .none, matchedStoreIDs: [], reason: "Outside your area.")
    }

    /// Lowercased concatenation of all recall text fields that may carry
    /// firm/brand identifiers. Includes `reasonForRecall` because FSIS
    /// records carry store/brand names in the description text.
    private func recallText(_ recall: Recall) -> String {
        var parts: [String] = []
        if let firm = recall.recallingFirm { parts.append(firm) }
        if let desc = recall.productDescription { parts.append(desc) }
        if let brands = recall.brandNames { parts.append(contentsOf: brands) }
        if let reason = recall.reasonForRecall { parts.append(reason) }
        return parts.joined(separator: " ").lowercased()
    }
}
