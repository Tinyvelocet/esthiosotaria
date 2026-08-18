# Design Guide — EsthioSotaria

Every major UI screen is **isolated in its own file**, renders from **mock data with zero network access**, and has **Xcode Previews**. Iterate freely.

## Where the screens live

| Screen | File | Previews included |
|---|---|---|
| Onboarding — Welcome | `App/Views/Onboarding/OnboardingWelcomeView.swift` | light + dark |
| Onboarding — Locating / denied | `App/Views/Onboarding/OnboardingLocatingView.swift` | both states |
| Onboarding — Manual entry | `App/Views/Onboarding/OnboardingManualEntryView.swift` | normal + error |
| Onboarding — Store picker (split list+map) | `App/Views/Onboarding/OnboardingStorePickerView.swift` | fresh + 2 selected |
| Store picker map (MapKit) | `App/Views/Onboarding/StoreMapView.swift` | own preview; needs running app for tiles |
| **Root (home) coordinator** — gates on load state, hosts the single dashboard destination | `App/Views/RecallListView.swift` | populated + FSIS-unavailable |
| **Store dashboard** (the app's home screen — severity-ranked stores + serious regional section) | `App/Views/StoreDashboardView.swift` | populated + empty |
| **Store recall list** (drill-down from a dashboard row) | `App/Views/StoreRecallListView.swift` | single store |
| **Area list** (opt-in full regional/nationwide log, reached via "See everything in your area") | `App/Views/AreaListView.swift` | populated |
| **Recall card** (the repeated element) | `App/Views/Recalls/RecallRowView.swift` | single card + all severities |
| **Recall detail** | `App/Views/Recalls/RecallDetailView.swift` | chain match + FSIS regional |
| Settings | `App/Views/SettingsView.swift` | populated + empty |
| **Widget UI (all 3 families)** | `Widget/RecallWidgetEntryView.swift` | Xcode widget previews in `RecallWidget.swift` |
| Widget entry point | `Widget/RecallWidget.swift` | small/medium/large previews |
| Widget data provider | `Widget/RecallTimelineProvider.swift` | reads App Group cache only |

Support:

| Purpose | File |
|---|---|
| Design tokens (colors, spacing, radius) | `App/Design/DesignTokens.swift` |
| Custom `ButtonStyle`s (primary filled, secondary outlined) | `App/Design/Controls.swift` |
| Shared dot-grid primitive (bitmask → cluster of dots) | `App/Design/DotGlyph.swift` |
| Store identity badges (color + monogram) | `App/Design/StoreIdentity.swift` |
| Danger mark — per-store aggregate score as a dot-matrix numeral | `App/Design/DangerMark.swift` |
| App mark — dot-ring seal with a dot-matrix exclamation, first impression only | `App/Design/RecallMark.swift` |
| Generative scattered-circle background | `App/Design/PatternBackground.swift` |
| Aggregate danger score formula (pure, tested) | `RecallKit/Sources/RecallKit/Matching/DangerScore.swift` |
| Notification/visibility severity gate — Class I/II only (pure, tested) | `RecallKit/Sources/RecallKit/Matching/AlertPolicy.swift` |
| Brand/firm key for muting "products I don't buy" (pure, tested) | `RecallKit/Sources/RecallKit/Matching/ProductKey.swift` |
| Mute/unmute swipe action (shared across recall-list screens) | `App/Views/Recalls/MuteSwipeAction.swift` |
| Mock stores & recalls (realistic, deterministic) | `App/Design/MockData.swift` |
| All-screens gallery | `App/Design/DesignGalleryView.swift` |

## Three ways to see your changes

1. **Xcode Previews** — open any screen file, hit the preview button. Fastest loop.
2. **Design Gallery at launch** — set `DesignGalleryView.showAtLaunch = true` in `DesignGalleryView.swift`, run the app: every screen on one scrollable canvas.
3. **Mock-data injection** — `RecallListView(viewModel: .designState())` and `UserSettingsStore.designState()` give you pre-populated state without any network.

## Design constraints (keep these when restyling)

- **Palette is cream / red / navy**, inspired by the Monoprix rebrand ([wconrandesign.com/work/monoprix-is-back](https://www.wconrandesign.com/work/monoprix-is-back/)) — elegant, minimal, high-contrast, not a generic "app blue" palette. `Design.Paper` (background/surface/line/ink) and `Design.Accent.brand` (navy) live in `DesignTokens.swift`, both light+dark via `Color.dynamic(light:dark:)`. Red is spent entirely on danger — never used as a neutral accent.
- **Two distinct severity systems, don't conflate them**:
  - **Per-recall classification** stays discrete, **dot + words**, never icon-only: "Critical — Class I", "Serious — Class II", "Minor — Class III". Colorblind-safe palette (`Design.Severity`: red/orange/gray).
  - **Per-store aggregate** is a **continuous 0...1 danger score** (`DangerScore.score(for:)` in RecallKit — worst classification dominates, multiple recalls give a small boost, capped at 1.0), rendered as a **dot-matrix numeral** in `DangerMark`. This is a *different signal* (a store's overall risk right now), not a replacement for the per-recall classification.
- **Copy honesty:** always "could be at your store", never "is".
- **Icon + text pairing** everywhere (accessibility rule).
- Store chips on chain matches are red (`Design.Accent.storeMatch`) — they are the escalation signal.
- The "In your area" section (`AreaListView.swift`, now an opt-in destination — see below) must keep the FSIS-unavailable warning slot (orange `Label`).
- **One interactive tint**, `Design.Accent.brand` (navy), applied once via `.tint(...)` in `EsthiosotariaApp`. Never hardcode `.blue`/`Color.accentColor` in a screen — it silently drifts from this the moment the token changes. The one deliberate exception is `StoreMapView`'s "you are here" dot and radius circle, which stay the system Maps blue by convention, not brand color.
- **Store identity is a badge, not a color-you-invent-locally**: every place a store is referenced (recall card chips, map markers, the picker, the detail header, dashboard tiles) uses `StoreBadge` from `StoreIdentity.swift` — a deterministic color + monogram per store, so the same store looks the same everywhere. Don't hand-roll a new per-store treatment; extend `StoreIdentity` if it needs a new size or state instead.
- **Corner radius** is `Design.Radius.card` (12pt) everywhere a rounded rect appears. Don't add a second radius value without a reason.
- **Onboarding step titles** are `.title2.bold()` — one consistent role for "the title of this step". The Welcome screen is the deliberate exception (`.title.bold()`, since it's the app's first impression and earns the extra size); nothing else should invent a third size for the same job.
- **`Design.Paper.background` is the screen background everywhere** — set once per screen root (List/Form need `.scrollContentBackground(.hidden)` first since they paint their own system background otherwise). `RootView` sets it at the top level so onboarding inherits it too; don't rely on that alone when adding a new top-level screen outside `RootView`'s tree — set it explicitly.
- **No manual store filter chips.** The dashboard prioritizes by danger score instead of offering hide/show controls — don't reintroduce per-store filter UI without revisiting that decision.
- **No progress rings, gauges, or sparklines standing in for content.** `DangerMark` was originally a circular progress-ring fill — indistinguishable from a battery indicator or Screen Time ring, and a banned pattern for exactly that reason. It now renders the score as a numeral built from the same dot primitive as `PatternBackground` (`DotGlyph`) instead. Don't reach for a ring/gauge/sparkline as a shortcut for "show a number visually" anywhere else in the app.
- **Buttons use `PrimaryButtonStyle`/`SecondaryButtonStyle` from `Controls.swift`**, not `.borderedProminent`/`.bordered`. Primary is the one-CTA-per-screen filled navy pill; secondary is the outlined navy variant for a lesser action sitting next to something else (e.g. Settings' "Search"/"Mute"). Don't reach for stock button styles — that was the single largest source of "generic SwiftUI app" in the pre-exploration audit. `Toggle` stays the system `.switch` style deliberately (it already inherits the app tint; a custom toggle would be reinventing a standard affordance without real payoff).
- **List rows that push to a detail screen are `NavigationLink`, never `.onTapGesture` + `.navigationDestination(item:)`.** The latter loses the disclosure chevron every iOS user expects and the automatic accessibility button trait — it was a real bug, not a style choice. `StoreDashboardView`'s tiles are the deliberate exception: they're not `List` rows, and `Button` + `.navigationDestination(item:)` is the correct idiom for triggering navigation from a custom (non-`List`) view.
- **Icon-only controls get an explicit `.accessibilityLabel`.** A `Label` with visible text already covers itself; a bare `Image(systemName:)` inside a `Button` (refresh, gear, trash, map pins) does not — VoiceOver has nothing to read otherwise. Also keep icon-only tap targets at or above 44×44pt even when the icon itself is smaller.
- **Muting is by brand/firm, global, and downgrades rather than hides.** Recall *events* never repeat, so "products I don't buy" mutes key off `ProductKey.displayName(for:)` (brand name, falling back to recalling firm) via `UserSettingsStore.payload.mutedProducts` — one flat list, not per-store. A muted recall keeps showing up in its store's list and the Area log (so the user isn't blind to it if they change their mind) but loses the red "could be at your store" treatment, is excluded from a dashboard row's active count/danger score, and never triggers a notification or a widget entry. Mute/unmute from `RecallDetailView`'s toggle or the `.muteSwipeAction` on any recall row; review/remove from Settings' "Products you don't buy" section.
- **Product ethos is simplicity + safety: alert on what's relevant, not everything that exists.** Two consequences, both backed by `AlertPolicy.warrantsNotification(_:)` (Class I/II only — Class III is the FDA's own "unlikely harm" tier):
  - **Notifications are severity-gated**, for chain *and* regional matches alike. A Class III match never pushes a notification — sending the same interrupt for "unlikely harm" as for "serious harm/death" is what trains people to dismiss the one that's actually serious. It still shows up in its list, just quietly.
  - **The home screen shows only *your* stores plus serious (Class I/II) regional recalls** — not a full unfiltered "everything happening nearby" feed. The complete regional log still exists (`AreaListView`) but is opt-in, one tap away via "See everything in your area," not a competing primary destination. Don't reintroduce a full-feed tab/section as default-visible without revisiting this decision.
  - A store row's text leads with the worst active classification when it's Class I/II ("Class I recall active") instead of a bare count — the *text* should carry urgency, not only the `DangerMark`'s color. Class III-only stores keep the generic "N active recalls," since naming "Class III" would overstate what it actually means.

## Home screen architecture (single destination, not tabs)

`RecallListView` no longer renders a scrolling list itself, and no longer hosts a `TabView` — it gates on load state, then pushes straight into `StoreDashboardView` as the single home screen. There used to be a second co-equal "Area" tab; it was removed because framing "browse every regional recall" as equally important as "check your own stores" fought the product's own simplicity/relevance ethos (see the constraint above). The screen now has three parts, top to bottom:

1. **Your stores** — a **severity-ranked stack**, one row per tracked store, worst first. Urgency reshapes the layout itself instead of only recoloring a fixed grid: a store scoring ≥0.7 gets a full-width hero row (large `DangerMark`, prominent name/count), a store with a minor match gets a compact row, and a quiet store (score 0) collapses to a single line with no `DangerMark` at all — absence of the graphic reinforces absence of danger. Tapping a row drills into `StoreRecallListView` for that store's actual recall rows. Don't revert this to a uniform grid; the whole point is that a dangerous store and a quiet one shouldn't look the same size.
2. **Serious recalls in your area** — only rendered when non-empty. Regional-tier matches that clear `AlertPolicy.warrantsNotification` (Class I/II), muted brands excluded. This is deliberately *not* the full regional feed — it's the handful that are actually alert-worthy, using `RecallRowView` rows pushed straight to `RecallDetailView`.
3. **"See everything in your area"** — a quiet, secondary `NavigationLink` (text + chevron, not a button) to `AreaListView` — the complete, unfiltered regional log, unchanged in content, just no longer competing for attention as a primary destination.

`PatternBackground`'s density (`intensity`) tracks the worst danger score across all tracked stores — the background gets busier, not just the rows, when something is more dangerous. It's `.allowsHitTesting(false)` and purely decorative — never encode information only in the pattern that isn't also in a row.

## Widget architecture (widget-first product)

The widget is a **reader**, not a fetcher: the app does all network + matching, writes a `RecallSnapshot` to the shared App Group (`group.dev.tinyvelocet.esthiosotaria`), and calls `WidgetCenter.shared.reloadAllTimelines()`. The widget timeline provider just loads the snapshot. Consequences for design:

- Widget views never show loading/error — they show either data or "Open EsthioSotaria to set up".
- iOS freshness: `BGAppRefreshTask` (registered in `App/Services/BackgroundRefresh.swift`) republishes hourly-ish when iOS allows. macOS: refreshed whenever the Mac app runs.
- The three families (small/medium/large) live in one file — `RecallWidgetEntryView.swift` — with a `familyOverride` init for design renders.

## Architecture of a screen

Screens are **pure design surfaces**: they take data in via `let`/`@Binding` and report actions via closures. State ownership stays in the coordinator (`OnboardingView`) and the view model (`RecallListViewModel`). That's why they preview without network, location, or persistence.
