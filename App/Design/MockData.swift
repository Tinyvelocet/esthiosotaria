import Foundation
import RecallKit

/// Deterministic sample data for previews, the design gallery, and future
/// snapshot tests. No network required — all screens render offline.
enum MockData {

    // MARK: - Stores (sample set)

    static let costco = Store(id: UUID(uuidString: "00000000-0000-0000-0000-0000000000C1")!,
                              name: "Costco Wholesale (Mountain View)", chain: "costco",
                              latitude: 37.4007, longitude: -122.1126)
    static let wholeFoods = Store(id: UUID(uuidString: "00000000-0000-0000-0000-0000000000C2")!,
                                  name: "Whole Foods Market (Palo Alto)", chain: "wholefoods",
                                  latitude: 37.4440, longitude: -122.1630)
    static let piazzas = Store(id: UUID(uuidString: "00000000-0000-0000-0000-0000000000C3")!,
                               name: "Piazza's Fine Foods", chain: nil,
                               latitude: 37.4299, longitude: -122.1381)
    static let traderJoes = Store(id: UUID(uuidString: "00000000-0000-0000-0000-0000000000C4")!,
                                  name: "Trader Joe's (Palo Alto)", chain: "traderjoes",
                                  latitude: 37.4213, longitude: -122.1590)

    static let fourStores: [Store] = [costco, wholeFoods, piazzas, traderJoes]

    /// Stores as they appear in discovery results (before selection).
    static let discoveryStores: [Store] = fourStores + [
        Store(name: "Grocery Outlet", chain: "groceryoutlet", latitude: 37.4310, longitude: -122.1400),
        Store(name: "99 Ranch Market", chain: "99ranch", latitude: 37.4019, longitude: -122.0800),
        Store(name: "Nob Hill Foods", chain: nil, latitude: 37.3890, longitude: -122.0819),
        Store(name: "Sprouts Farmers Market", chain: "sprouts", latitude: 37.3720, longitude: -122.0360),
    ]

    // MARK: - Recalls

    /// Class I — chain match for Costco (Kirkland brand).
    static let kirklandMadeleines = Recall(
        id: "F-0480-2026",
        status: "Ongoing",
        classification: .classI,
        recallingFirm: "Costco Wholesale Corporation",
        productDescription: "Kirkland Signature Traditional Madeleines, 12 count, net wt. 18 oz, Item #2471197, best-by dates 10/01/2026 through 10/15/2026.",
        reasonForRecall: "Product may be contaminated with Listeria monocytogenes.",
        distributionPattern: "Nationwide",
        reportDate: "20260805",
        brandNames: ["Kirkland Signature"])

    /// Class I — USDA FSIS recall naming Costco warehouses (chain match).
    static let fsisGroundBeef = Recall(
        id: "FSIS-015-2026",
        status: "Ongoing",
        classification: .classI,
        recallingFirm: "Grandview Meat Company",
        productDescription: "Ground Beef Product",
        reasonForRecall: "Approximately 12,000 pounds of ground beef that may be contaminated with E. coli O157:H7. Sold at warehouse clubs including Costco in CA, TX and AZ.",
        distributionPattern: "CA, TX and AZ",
        reportDate: "20260804",
        agency: .fsis,
        urlString: "https://www.fsis.usda.gov/recalls-alerts/ground-beef-recall-015-2026")

    /// Class II — chain match for Whole Foods (365 brand).
    static let wfmQuinoa = Recall(
        id: "F-0455-2026",
        status: "Ongoing",
        classification: .classII,
        recallingFirm: "Whole Foods Market",
        productDescription: "365 Everyday Value Organic Quinoa, 16 oz bags, all lot codes.",
        reasonForRecall: "Undeclared tree nut allergen (cashew) discovered during routine testing.",
        distributionPattern: "CA, OR, WA",
        reportDate: "20260802",
        brandNames: ["365 Everyday Value"])

    /// Class II — chain match for Trader Joe's (FSIS frozen meal).
    static let tjsFriedRice = Recall(
        id: "FSIS-021-2026",
        status: "Ongoing",
        classification: .classII,
        recallingFirm: "Ajinomoto Foods North America Inc.",
        productDescription: "Trader Joe's Vegetable Fried Rice, net wt. 1 lb per bag.",
        reasonForRecall: "Foreign material (pieces of plastic) in product.",
        distributionPattern: "Nationwide",
        reportDate: "20260731",
        agency: .fsis,
        urlString: "https://www.fsis.usda.gov/recalls-alerts/trader-joes-fried-rice-021-2026")

    /// Class II — regional only (distribution covers CA, no chain match).
    static let wontonWrappers = Recall(
        id: "F-0441-2026",
        status: "Ongoing",
        classification: .classII,
        recallingFirm: "Man Fon Inc.",
        productDescription: "Won Ton Wrappers Extra Thin, Net Wt. 10 oz, UPC# 757168 001234.",
        reasonForRecall: "Undeclared egg allergen.",
        distributionPattern: "Distributed to retail stores in CA and NV.",
        reportDate: "20260728")

    /// Class I — regional (leafy greens, no chain match).
    static let romaineLettuce = Recall(
        id: "F-0432-2026",
        status: "Ongoing",
        classification: .classI,
        recallingFirm: "Salinas Greens LLC",
        productDescription: "Fresh romaine lettuce hearts, 3-count packs, harvest dates 07/15–07/25/2026.",
        reasonForRecall: "Potential contamination with E. coli O157:H7 linked to an ongoing outbreak.",
        distributionPattern: "Distributed to CA, OR, WA",
        reportDate: "20260725")

    /// Class III — minor, regional.
    static let mislabeledJam = Recall(
        id: "F-0410-2026",
        status: "Ongoing",
        classification: .classIII,
        recallingFirm: "Orchard Preserves Co.",
        productDescription: "Strawberry Jam 12 oz jars, lot 2026-07.",
        reasonForRecall: "Net weight statement below labeled amount; no safety risk.",
        distributionPattern: "CA",
        reportDate: "20260720")

    // MARK: - Curated sets

    static let chainMatchRecalls: [Recall] = [kirklandMadeleines, fsisGroundBeef, wfmQuinoa, tjsFriedRice]
    static let regionalRecalls: [Recall] = [romaineLettuce, wontonWrappers, mislabeledJam]

    /// Builds `RecallListViewModel.Item`s with plausible relevance metadata.
    static func items(for recalls: [Recall], stores: [Store]) -> [RecallListViewModel.Item] {
        let engine = MatchingEngine(userState: "CA")
        return recalls.map { recall in
            RecallListViewModel.Item(recall: recall, relevance: engine.relevance(for: recall, stores: stores))
        }
    }
}
