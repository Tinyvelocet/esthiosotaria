# EsthioSotaria

<p align="center">
  <img src="Icon/appicon.png" width="256" alt="EsthioSotaria app icon" />
</p>

A local, **iOS** food recall tracker. It finds grocery stores near you, watches FDA and USDA food recalls, and escalates the ones that **could be at your stores** to the top.

This is deliberately **not** an exhaustive recall database — it's a focused filter that tells you what matters to you and hides the rest.

> ⚠️ Matching is brand-based confidence, not certainty: FDA recall data never names a specific store shelf. This app always says *"could be at your store"* — verify against the linked FDA notice before deciding.

## Why

Food recalls are published constantly (~1,400 FDA recalls/year), but only a fraction reach your state and only a handful touch stores you actually shop at. EsthioSotaria filters to what matters to you:

1. **Locate** — your position (never leaves the device) or a city you type.
2. **Discover** — grocery stores within a radius you choose (5–50 mi, default 10 mi, auto-expanding in 5-mi steps if nothing's nearby), via Apple Maps merged with OpenStreetMap.
3. **Track** — pick up to 4 stores.
4. **Match** — every ongoing FDA and USDA recall is scored:
   - 🔴 **Chain match** (escalated to the top + local notification): the recalling firm/brand matches one of your stores — e.g. a Kirkland Signature recall for Costco shoppers.
   - 🟠 **Regional**: the recall's distribution covers your state or is nationwide.
   - ⚪ Out-of-area recalls are hidden.

## Privacy

- No server, no account, no telemetry.
- Your location is used only to query store databases: Apple MapKit and OSM
  Overpass receive the coordinates needed for a local store search. They are
  never stored, uploaded to any server you control, or shared beyond those
  public services.
- Data sources: [openFDA enforcement API](https://open.fda.gov/apis/food/enforcement/), [USDA FSIS recall RSS](https://www.fsis.usda.gov/rss/recalls.xml), [OSM Overpass](https://overpass-api.de), Apple MapKit — all public, keyless at this usage level.

## Data sources & USA-wide coverage

EsthioSotaria pulls every ongoing food recall from the **two federal agencies**
that hold recall authority over food sold in the U.S. Together they cover the
whole country:

| Source | Regulates | Notes |
| --- | --- | --- |
| **openFDA** `api.fda.gov/food/enforcement.json` | All FDA-regulated food (everything except meat, poultry, processed egg) + dietary supplements | Recall Enterprise System, **2004–present**, refreshed weekly, **nationwide** |
| **FDA Food Safety recall RSS** | Same scope, **fresher** (published within days) | Supplements / outpaces openFDA until it catches up |
| **USDA FSIS** `fsis.usda.gov/rss/recalls.xml` | Meat, poultry, processed egg (the category FDA *doesn't* regulate) | Active recalls/public-health alerts only |

No third federal agency issues food recalls, and state agencies re-publish the same federal recalls (recall authority is federal wherever the product ships) — so the app already has complete **nationwide** coverage, matched against any of the **50 states + DC** via `StateMatcher`. There is no state-level API to add, and no state source would meaningfully extend coverage.

## Known limitations (by design, stated honestly)

- **openFDA lags** the live FDA recall site by days–weeks (it is batch-indexed).
- **USDA FSIS** (meat/poultry/egg) recalls are ingested from the FSIS RSS feed.
  FSIS's site bot-gates some datacenter IPs, so on those networks meat coverage
  may be incomplete — the app still shows FDA data and flags the gap.
- Independent stores (no chain brand) match only at the regional tier — there is no public feed saying which items an independent store stocks.

## Build

Requirements: macOS 14+, Xcode 15+, [xcodegen](https://github.com/yonaskolb/XcodeGen).

```bash
git clone https://github.com/Tinyvelocet/esthiosotaria.git
cd esthiosotaria
xcodegen generate          # -> EsthioSotaria.xcodeproj
open EsthioSotaria.xcodeproj
# Scheme: EsthioSotaria_iOS  (this is an iOS-only app)
```

The core logic lives in the UI-free **RecallKit** Swift package:

```bash
cd RecallKit
swift test                 # 104 tests — models, FDA/FSIS/feed clients, matching, POI parsing, dedup
```

## Architecture

```
RecallKit/            UI-free Swift package (the brain, fully unit-tested)
├── Models/           Recall, Store, Relevance
├── Sources/          FDAService (openFDA client, injectable transport)
├── Matching/         ChainCatalog, StateMatcher, MatchingEngine
└── Geo/              OverpassPOIService (OSM store discovery)

App/                  iOS app target (SwiftUI) + WidgetKit widget
├── Views/            Onboarding, StoreDashboard, RecallDetail, Settings
├── ViewModels/       RecallListViewModel (fetch + match + sort)
└── Services/         Location, StoreDiscovery (MapKit→OSM), Notifications
```

The bundled brand face is **DM Serif Display** ([SIL OFL 1.1](App/Resources/Fonts/OFL.txt))
in `App/Resources/Fonts`; body text uses the system SF font.

## Design

The app's look is **fully customizable** — it's driven by a small set of
central design tokens plus the bundled brand face, so restyling the whole app
is editing a handful of files, not hunting through views.

- **Palette & spacing** — every color, corner radius, and gap lives in
  [`App/Design/DesignTokens.swift`](App/Design/DesignTokens.swift). Change the
  warm paper base, the single danger red, or the brand navy there and it
  propagates everywhere.
- **Brand typeface** — swap `App/Resources/Fonts/DMSerifDisplay-Regular.ttf`
  (SIL OFL 1.1) for any font you like and register it in
  [`App/Info.plist`](App/Info.plist) (`UIAppFonts`) + `Design.BrandFont`.
- **App icon** — a 1024px source lives at [`Icon/appicon.png`](Icon/appicon.png);
  the compiled asset catalog is [`App/Assets.xcassets`](App/Assets.xcassets).
- **Screen-by-screen** — every major screen is an isolated SwiftUI view under
  `App/Views/`, and a screenshot tool renders each one at iPhone size from the
  app's own views + mock data. See [`design/`](design/) for the current
  Figma reference set and how to regenerate it after a design change.
- **Preview-first iteration** — each view ships `#Preview(...)` blocks, so you
  can open the SwiftUI previews and iterate on a screen without running the
  full app.

The screenshot renderer (a macOS-only tool, not shipped) lives in
[`scripts/ScreenshotGen/`](scripts/ScreenshotGen/).

## License

[Creative Commons Attribution-NonCommercial 4.0 (CC BY-NC 4.0)](LICENSE).

You are free to use, modify, and redistribute the source for **non-commercial
purposes** (with attribution). Commercial use — including building or selling a
commercial product from this code, or an adaptation of it — is permitted only
under a separate commercial license granted by the author.

The core branding, app icon, and any Apple-provided system assets are not
covered by this license.
