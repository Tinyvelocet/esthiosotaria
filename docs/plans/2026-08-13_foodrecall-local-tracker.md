# Foodrecall — Local Food Recall Tracker (iOS + macOS) Implementation Plan

> **For Hermes:** Use the `subagent-driven-development` skill to implement this plan task-by-task.
> Each phase ends with a clean build + full test run + commit before the next begins.

**Goal:** A privacy-first, open-source iOS + macOS app that detects the user's location, lets them pick up to 4 nearby grocery stores (default 15-mile radius), and surfaces only the food recalls *relevant to them* — escalating any recall that could be at one of their stores to the top.

**Architecture:** A pure-Swift, UI-free `RecallKit` Swift Package owns all data logic (FDA/FSIS fetching, parsing, store↔recall relevance matching) and is fully unit-tested. A shared SwiftUI layer renders iOS + macOS targets. POI discovery uses MapKit `MKLocalSearch` with OSM Overpass as a keyless, verified fallback. Everything runs client-side against public APIs — no server, no account, no location ever leaves the device.

**Tech Stack:** Swift 6, SwiftUI (multiplatform), Swift Package Manager, XCTest/Swift Testing, MapKit, CoreLocation, URLSession, OSM Overpass (HTTP), GitHub Actions CI.

---

## 0. Ground truth established by live probes (2026-08-13)

| Source | What it gives | Status |
|---|---|---|
| `https://api.fda.gov/food/enforcement.json` | Recalls: `classification` (Class I/II/III), `status`, `recalling_firm`, `product_description`, `reason_for_recall`, `distribution_pattern` (free text), `report_date`, `openfda.brand_name` | ✅ Works, no key. 29,278 records; 1,425 in last 12 mo; 108 touched CA. Brand full-text search works. |
| OSM Overpass (`overpass-api.de`) | Grocery POIs near a coordinate (`shop=supermarket|grocery|wholesale`, `name`, `brand`) | ✅ Works, no key. Found Piazza's Fine Foods at 2.4 mi from Palo Alto center. |
| MapKit `MKLocalSearch` | Native Apple POI search | ⚠️ Correct for a shipping app; headless CLI probe returned 0 items (needs app entitlements). Verify in-app in Phase 3. |
| USDA FSIS (`fsis.usda.gov`) | Meat/poultry/egg recalls | ⚠️ Bot-blocked from probe. Defer to Phase 2 + manual verify. |

**Known limitation (encode in UI copy):** openFDA is batch-indexed and can lag the live FDA recall site by days–weeks. Matching is confidence-based ("could be at your store"), never certainty.

---

## 1. Product decisions (locked with user, 2026-08-13)

- **"Could be at your store" wording: APPROVED.** Matching = confidence tiers; UI always says "could be at your store", never "is". Tier 1 *chain match* (recalling firm/brand == selected store's chain, e.g. Costco/Kirkland) → escalated to top + notification. Tier 3 *regional* (distribution includes user's state or "Nationwide"). Tier 2 brand→category deferred. Home list sorts Tier 1 → Tier 3, then severity, then date.
- **"Relevant to you" filter:** show recalls whose `distribution_pattern` plausibly covers the user's state OR is nationwide, AND `status == Ongoing`. Never dump all 29k records.
- **Store cap:** 4 (`maxSelectedStores` constant). **Radius slider: 5–50 mi, default 15.**
- **POI discovery: MapKit `MKLocalSearch` FIRST**, automatic silent fallback to OSM Overpass if MapKit returns empty/errors (headless probe returned 0 items — verify in-app).
- **Location fallback:** if permission denied or coarse, allow manual city/ZIP entry.
- **Notifications: LOCAL FIRST.** Cross-device sharing: CloudKit silent push + `CKQuerySubscription` (no server) — each iOS device syncs recall state and schedules its own local notification. Caveat: macOS does not receive CloudKit silent pushes → Mac polls on launch. Deferred to post-MVP phase.
- **FSIS:** out of MVP (Phase 2 data source, needs manual bot-block verification).
- **License:** MIT. Repo-local generic git identity (`Tinyvelocet` / `269629886+Tinyvelocet@users.noreply.github.com`), no real name, no AI co-author trailers (per repo policy).
- **Repo name: `esthiosotaria` (LOCKED 2026-08-13).** User-chosen. Validation: 0 GitHub repos/users, 0 App Store results, all TLDs unregistered, no web footprint. (`sotaria` alone was rejected — live UK company "Sotaria Group", sotaria.io.) Create as `Tinyvelocet/esthiosotaria` on GitHub; local folder stays `~/Developer/Foodrecall` for now (rename optional later).

---

## 2. Repository layout

```
Foodrecall/
├── RecallKit/                       # UI-free Swift Package (the brain)
│   ├── Package.swift
│   ├── Sources/RecallKit/
│   │   ├── Models/Recall.swift
│   │   ├── Models/Store.swift
│   │   ├── Models/Relevance.swift
│   │   ├── Sources/FDAService.swift
│   │   ├── Sources/FSISService.swift        (Phase 2)
│   │   ├── Matching/MatchingEngine.swift
│   │   ├── Matching/ChainCatalog.swift
│   │   ├── Geo/OverpassPOIService.swift
│   │   └── Matching/StateMatcher.swift
│   └── Tests/RecallKitTests/
│       ├── FDAServiceTests.swift
│       ├── MatchingEngineTests.swift
│       ├── StateMatcherTests.swift
│       └── OverpassPOIServiceTests.swift
├── App/                             # SwiftUI app (iOS + macOS targets)
│   ├── FoodrecallApp.swift
│   ├── Views/…
│   └── Resources/
├── docs/plans/                      # this file
├── .github/workflows/ci.yml
├── README.md  LICENSE  .gitignore
```

---

## Phase 0 — Repo scaffold + open-source hygiene

**Objective:** Empty repo becomes a buildable multiplatform SwiftPM project with CI, license, and clean git identity.

### Task 0.1: Init git with repo-local identity + hooks
- **Files:** `.gitignore`, `.git/hooks` (local config only)
- **Steps:**
  ```bash
  cd ~/Developer/Foodrecall
  git init
  git config user.name "Tinyvelocet"
  git config user.email "you@example.com"     # generic, not real
  # block AI trailers
  printf '#!/bin/sh\nif git log -1 --pretty=%%B | grep -qi "Co-Authored-By: .*\\(claude\\|anthropic\\)"; then echo "blocked"; exit 1; fi\n' > .git/hooks/commit-msg
  chmod +x .git/hooks/commit-msg
  ```
- **Verify:** `git config user.name` → `Tinyvelocet`.

### Task 0.2: Create `RecallKit` package + `Package.swift`
- **Files:** `RecallKit/Package.swift`
- **Code:**
  ```swift
  // swift-tools-version:5.10
  import PackageDescription
  let package = Package(
      name: "RecallKit",
      platforms: [.iOS(.v17), .macOS(.v14)],
      products: [.library(name: "RecallKit", targets: ["RecallKit"])],
      targets: [
          .target(name: "RecallKit"),
          .testTarget(name: "RecallKitTests", dependencies: ["RecallKit"]),
      ]
  )
  ```
- **Verify:** `cd RecallKit && swift build` → `Build complete!`

### Task 0.3: LICENSE (MIT) + .gitignore + README stub
- **Files:** `LICENSE`, `.gitignore` (macOS/Swift/Xcode ignores), `README.md`
- **Verify:** files present.

### Task 0.4: GitHub Actions CI
- **Files:** `.github/workflows/ci.yml`
- **Code (runs package tests on macOS runner):**
  ```yaml
  name: CI
  on: [push, pull_request]
  jobs:
    test:
      runs-on: macos-14
      steps:
        - uses: actions/checkout@v4
        - name: Test RecallKit
          run: cd RecallKit && swift test
  ```
- **Commit:** `chore: scaffold repo, RecallKit package, MIT license, CI`

---

## Phase 1 — RecallKit models + openFDA client (TDD)

**Objective:** Fetch and decode real recalls from openFDA into typed models, fully tested.

### Task 1.1: `Recall` model
- **Files:** `RecallKit/Sources/RecallKit/Models/Recall.swift`, test `FDAServiceTests.swift`
- **Step 1 (failing test):** assert a `Recall` decodes from a sample FDA JSON payload (fixture below).
- **Step 3 (implement):**
  ```swift
  public struct Recall: Codable, Identifiable, Equatable, Sendable {
      public enum Classification: String, Codable { case classI = "Class I", classII = "Class II", classIII = "Class III", unknown }
      public let id: String                 // recall_number
      public let status: String?            // Ongoing / Terminated
      public let classification: Classification?
      public let recallingFirm: String?
      public let productDescription: String?
      public let reasonForRecall: String?
      public let distributionPattern: String?
      public let reportDate: String?        // YYYYMMDD
      public let brandNames: [String]?      // openfda.brand_name

      enum CodingKeys: String, CodingKey {
          case id = "recall_number"; case status; case classification
          case recallingFirm = "recalling_firm"
          case productDescription = "product_description"
          case reasonForRecall = "reason_for_recall"
          case distributionPattern = "distribution_pattern"
          case reportDate = "report_date"
          case openfda
      }
      enum OpenFDACodingKeys: String, CodingKey { case brand_name }
      public init(from decoder: Decoder) throws {
          let c = try decoder.container(keyedBy: CodingKeys.self)
          id = try c.decode(String.self, forKey: .id)
          status = try c.decodeIfPresent(String.self, forKey: .status)
          classification = try c.decodeIfPresent(Classification.self, forKey: .classification)
          recallingFirm = try c.decodeIfPresent(String.self, forKey: .recallingFirm)
          productDescription = try c.decodeIfPresent(String.self, forKey: .productDescription)
          reasonForRecall = try c.decodeIfPresent(String.self, forKey: .reasonForRecall)
          distributionPattern = try c.decodeIfPresent(String.self, forKey: .distributionPattern)
          reportDate = try c.decodeIfPresent(String.self, forKey: .reportDate)
          if let sub = try? c.nestedContainer(keyedBy: OpenFDACodingKeys.self, forKey: .openfda) {
              brandNames = try sub.decodeIfPresent([String].self, forKey: .brand_name)
          } else { brandNames = nil }
      }
  }
  ```
- **Fixture** (`Tests/Fixtures/fda_sample.json`): paste one real record from `api.fda.gov/food/enforcement.json?limit=1`.
- **Verify:** `swift test --filter FDAService` passes.
- **Commit:** `feat(recallkit): Recall model + fixture decode`

### Task 1.2: `FDAService` fetch + URL building
- **Files:** `Sources/FDAService.swift`, tests
- **Step 1 (failing):** `testBuildsOngoingCAQuery` asserts the built URL contains `status:Ongoing` and `limit`.
- **Step 3 (implement):** a protocol-based service so tests inject a stub transport:
  ```swift
  public protocol HTTPTransport: Sendable { func data(for url: URL) async throws -> (Data, URLResponse) }

  public struct FDAService: Sendable {
      let transport: HTTPTransport
      public init(transport: HTTPTransport) { self.transport = transport }

      public func fetchOngoing(limit: Int = 200) async throws -> [Recall] {
          var comps = URLComponents(string: "https://api.fda.gov/food/enforcement.json")!
          comps.queryItems = [
              .init(name: "search", value: "status:Ongoing"),
              .init(name: "limit", value: String(limit)),
              .init(name: "sort", value: "report_date:desc"),
          ]
          let (data, _) = try await transport.data(for: comps.url!)
          struct Envelope: Decodable { let results: [Recall] }
          return try JSONDecoder().decode(Envelope.self, from: data).results
      }
  }
  ```
  *(Note: probe showed `sort=report_date:desc` works on enforcement.json; keep.)*
- **Verify:** stub transport returns fixture → decodes N recalls; `swift test` green.
- **Commit:** `feat(recallkit): FDAService with injectable transport`

---

## Phase 2 — Matching engine: store↔recall relevance (the core)

**Objective:** Given selected stores + a recall, produce a `Relevance` tier. Pure, unit-tested, no IO.

### Task 2.1: `Store` + `Relevance` models
- **Files:** `Models/Store.swift`, `Models/Relevance.swift`
- **Code:**
  ```swift
  public struct Store: Codable, Identifiable, Equatable, Sendable, Hashable {
      public let id: UUID
      public var name: String
      public var chain: String?      // normalized brand, e.g. "costco"
      public var latitude: Double
      public var longitude: Double
      public init(id: UUID = UUID(), name: String, chain: String?, latitude: Double, longitude: Double) { … }
  }

  public struct Relevance: Equatable, Sendable {
      public enum Tier: Int, Comparable { case chain = 0, brand = 1, regional = 2, none = 3
          public static func <(a: Tier, b: Tier) -> Bool { a.rawValue < b.rawValue } }
      public let tier: Tier
      public let matchedStoreIDs: [UUID]
      public let reason: String        // human-readable why
  }
  ```

### Task 2.2: `ChainCatalog` — chain → trigger keywords
- **Files:** `Matching/ChainCatalog.swift`, tests
- **Rationale:** openFDA never names "this shelf"; we match on firm/brand text. Build a small, extensible dictionary of normalized chain → known firm/brand strings.
- **Code:**
  ```swift
  public enum ChainCatalog {
      // normalized chain id -> substrings that indicate that chain in firm/brand text
      public static let triggers: [String: [String]] = [
          "costco":     ["costco", "kirkland"],
          "wholefoods": ["whole foods", "whole foods market", "365 everyday value", "365 by whole foods"],
          "traderjoes": ["trader joe", "trader joes"],
          "safeway":    ["safeway"],
          "kroger":     ["kroger"],
          "walmart":    ["walmart", "great value", "marketside"],
          "target":     ["target", "good & gather"],
          "sprouts":    ["sprouts"],
      ]
      public static func normalize(_ name: String) -> String? {
          let lower = name.lowercased()
          for (chain, keys) in triggers where keys.contains(where: lower.contains) { return chain }
          return nil
      }
  }
  ```
- **Test:** `ChainCatalog.normalize("Kirkland Signature") == "costco"`.
- **Commit:** `feat(recallkit): ChainCatalog keyword mapping`

### Task 2.3: `StateMatcher` — does `distribution_pattern` cover me?
- **Files:** `Matching/StateMatcher.swift`, tests
- **Rationale:** `distribution_pattern` is free text ("PA, DE, NJ", "Nationwide", "Only in NY"). Treat nationwide + state match as regional relevance.
- **Code:**
  ```swift
  public enum StateMatcher {
      public static func coversState(_ pattern: String?, state: String) -> Bool {
          guard let p = pattern?.lowercased() else { return false }
          if p.contains("nationwide") || p.contains("nation") { return true }
          let s = state.lowercased()
          return p.contains(s) || p.contains(abbreviation(for: state).lowercased())
      }
      public static func abbreviation(for state: String) -> String { /* full map */ "CA" }
  }
  ```
- **Tests:** nationwide→true; "CA"→true; "Only in NY" vs CA→false.
- **Commit:** `feat(recallkit): StateMatcher distribution coverage`

### Task 2.4: `MatchingEngine` — combine tiers
- **Files:** `Matching/MatchingEngine.swift`, tests
- **Code:**
  ```swift
  public struct MatchingEngine: Sendable {
      public let userState: String
      public init(userState: String) { self.userState = userState }

      public func relevance(for recall: Recall, stores: [Store]) -> Relevance {
          let haystack = ([recall.recallingFirm, recall.productDescription] + (recall.brandNames ?? []))
              .compactMap { $0 }.joined(separator: " ").lowercased()

          // Tier 1: chain match against selected stores
          var matched: [UUID] = []
          for store in stores {
              guard let chain = store.chain else { continue }
              if let keys = ChainCatalog.triggers[chain],
                 keys.contains(where: haystack.contains) { matched.append(store.id) }
          }
          if !matched.isEmpty {
              return Relevance(tier: .chain, matchedStoreIDs: matched,
                               reason: "Recall matches a brand sold at your selected store.")
          }
          // Tier 3: regional coverage of user's state
          if StateMatcher.coversState(recall.distributionPattern, state: userState) {
              return Relevance(tier: .regional, matchedStoreIDs: [],
                               reason: "Recall distribution includes your area.")
          }
          return Relevance(tier: .none, matchedStoreIDs: [], reason: "Outside your area.")
      }
  }
  ```
  *(Tier 2 brand→category is intentionally deferred; Tier 1 + 3 cover the real value.)*
- **Tests:** Costco recall + selected Costco → `.chain`; nationwide recall, no chain match → `.regional`; NY-only recall → `.none`.
- **Verify:** `swift test` green.
- **Commit:** `feat(recallkit): MatchingEngine tiered relevance`

---

## Phase 3 — POI store discovery (MapKit primary, Overpass fallback)

**Objective:** Given a coordinate + radius, return candidate grocery stores to pick from.

### Task 3.1: `OverpassPOIService` (keyless, testable)
- **Files:** `Geo/OverpassPOIService.swift`, tests (decode fixture)
- **Query template (verified working):**
  ```
  [out:json][timeout:25];
  (node["shop"~"supermarket|grocery|wholesale"](around:RADIUS,lat,lon);
   way["shop"~"supermarket|grocery|wholesale"](around:RADIUS,lat,lon););
  out center tags;
  ```
- Decode elements → `[Store]` using `tags.name` / `tags.brand`, `ChainCatalog.normalize(name)` for `chain`.
- **Verify:** fixture decode test green; live smoke test prints stores near Palo Alto (Piazza's expected).
- **Commit:** `feat(recallkit): OverpassPOIService store discovery`

### Task 3.2: `MapKitPOIService` + in-app verification
- **Files:** `App/Services/MapKitPOIService.swift` (lives in app target — needs entitlements)
- **Implement** `MKLocalSearch` with `naturalLanguageQuery = "grocery store"` scoped to a region of `radius`.
- **CRITICAL verify task:** run the real app on device/simulator, grant location, and confirm `MKLocalSearch` returns items. **If it returns empty (as the headless probe did), the app must silently fall back to `OverpassPOIService`.** Encode the fallback now:
  ```swift
  func discoverStores(near c: CLLocationCoordinate2D, radiusMeters: Double) async throws -> [Store] {
      do { let r = try await mapKitSearch(...); if !r.isEmpty { return r } }
      catch { }
      return try await overpass.stores(near: c, radiusMeters: radiusMeters)
  }
  ```
- **Commit:** `feat(app): MapKit discovery with Overpass fallback`

---

## Phase 4 — Location + onboarding

### Task 4.1: `LocationService` (CoreLocation, coarse-friendly)
- **Files:** `App/Services/LocationService.swift`
- Request `.authorizedWhenInUse`; on denial/failure expose a manual city/ZIP entry path.
- Store only a coarse coordinate + derived state; never transmit.

### Task 4.2: Onboarding flow UI
- **Files:** `App/Views/OnboardingView.swift`
- **Screens:** (1) explain + request location, (2) map/list of discovered stores within radius, (3) pick up to `maxSelectedStores` (default 4), radius control (default 15 mi).
- Persist selection (Phase 6).

---

## Phase 5 — SwiftUI UI (shared iOS + macOS)

### Task 5.1: Home list — "Recalls near you"
- **Files:** `App/Views/RecallListView.swift`, `App/ViewModels/RecallListViewModel.swift`
- **Behavior:** fetch ongoing recalls → run `MatchingEngine` → drop `.none` → sort `chain` → `regional`, then severity (Class I→III), then date. Section headers: **"Could be at your stores"** (chain), **"In your area"** (regional).
- **Card:** severity dot + plain label ("Critical — Class I"), product name, 1-line reason, matched-store chips, date.

### Task 5.2: Detail view
- Show what to look for (UPC/lot when present), plain reason, "what to do," link to FDA source record, **"Mark as handled"** button.

### Task 5.3: Settings
- Edit selected stores, radius, manual location override, severity notification threshold (UI only in MVP).

---

## Phase 6 — Persistence + handled state
- **Files:** `App/Services/Store.swift` (persistence, not to be confused with model)
- Codable JSON file in Application Support for: selected stores, handled recall IDs, radius. (No Core Data — YAGNI.)

## Phase 7 — Polish
- Accessibility labels (pair every icon with text), empty states ("No recalls match your area right now"), error/loading states, dark mode, Dynamic Type.

## Phase 8 — Open-source release
- README (screenshots, privacy statement, data sources + their limits), CONTRIBUTING, CHANGELOG, tags, first GitHub release.

---

## Risks & mitigations
| Risk | Mitigation |
|---|---|
| openFDA lag → user misses a fresh recall | UI copy states data freshness; Phase 9 adds FDA listing page / FSIS RSS |
| Matching overclaims certainty | Tiered confidence + "could be" wording, never "is" |
| MapKit empty in some contexts | Automatic Overpass fallback (tested, keyless) |
| FSIS bot-blocking | Deferred Phase 2 with manual verify; meat coverage via openFDA brand matches meanwhile |
| Rate limits | openFDA keyless = 240 req/min/IP; app polls a few times/day — fine |

## Future (explicitly out of MVP)
FSIS ingestion · push/local notifications · faster feeds (FDA listing page RSS) · CloudKit sync across devices · Tier-2 brand→category matching · more than 4 stores.
