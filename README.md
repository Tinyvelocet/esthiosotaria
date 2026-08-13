# EsthioSotaria

A local food recall tracker for **iOS + macOS**. It finds the grocery stores near you, watches FDA food recalls, and escalates the ones that **could be at your stores** to the top.

> ⚠️ Matching is brand-based confidence, not certainty: FDA recall data never names a specific store shelf. This app always says *"could be at your store"* — verify against the linked FDA notice before deciding.

## Why

Food recalls are published constantly (~1,400 FDA recalls/year), but only a fraction reach your state and only a handful touch stores you actually shop at. EsthioSotaria filters to what matters to you:

1. **Locate** — your position (never leaves the device) or a city you type.
2. **Discover** — grocery stores within a radius you choose (5–50 mi, default 15), via Apple Maps with OpenStreetMap fallback.
3. **Track** — pick up to 4 stores.
4. **Match** — every ongoing FDA recall is scored:
   - 🔴 **Chain match** (escalated to the top + local notification): the recalling firm/brand matches one of your stores — e.g. a Kirkland Signature recall for Costco shoppers.
   - 🟠 **Regional**: the recall's distribution covers your state or is nationwide.
   - ⚪ Out-of-area recalls are hidden.

## Privacy

- No server, no account, no telemetry.
- Your location is used only to query store databases and is never transmitted.
- Data sources: [openFDA enforcement API](https://open.fda.gov/apis/food/enforcement/), [OSM Overpass](https://overpass-api.de), Apple MapKit — all public, keyless at this usage level.

## Known limitations (by design, stated honestly)

- **openFDA lags** the live FDA recall site by days–weeks (it is batch-indexed).
- **Meat/poultry/egg (USDA FSIS)** recalls are not ingested yet (their API is bot-gated; tracked as the next data-source phase).
- Independent stores (no chain brand) match only at the regional tier — there is no public feed saying which items an independent store stocks.

## Build

Requirements: macOS 14+, Xcode 15+, [xcodegen](https://github.com/yonaskolb/XcodeGen).

```bash
git clone https://github.com/Tinyvelocet/esthiosotaria.git
cd esthiosotaria
xcodegen generate          # -> EsthioSotaria.xcodeproj
open EsthioSotaria.xcodeproj
# Schemes: EsthioSotaria_iOS, EsthioSotaria_macOS
```

The core logic lives in the UI-free **RecallKit** Swift package:

```bash
cd RecallKit
swift test                 # 21 tests — models, FDA client, matching, POI parsing
```

## Architecture

```
RecallKit/            UI-free Swift package (the brain, fully unit-tested)
├── Models/           Recall, Store, Relevance
├── Sources/          FDAService (openFDA client, injectable transport)
├── Matching/         ChainCatalog, StateMatcher, MatchingEngine
└── Geo/              OverpassPOIService (OSM store discovery)

App/                  Shared SwiftUI layer (iOS + macOS targets)
├── Views/            Onboarding, RecallList, RecallDetail, Settings
├── ViewModels/       RecallListViewModel (fetch + match + sort)
└── Services/         Location, StoreDiscovery (MapKit→OSM), Notifications
```

## Roadmap

- [ ] USDA FSIS (meat/poultry/egg) ingestion
- [ ] Faster feeds (FDA listing page / RSS) to close the openFDA lag
- [ ] CloudKit sync + cross-device notification delivery (iOS silent push; macOS polls)
- [ ] Tier-2 brand→category matching (e.g. soft cheese → gourmet grocers)

## License

MIT — see [LICENSE](LICENSE).
