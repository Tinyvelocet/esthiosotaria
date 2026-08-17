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
| **Root (home) coordinator** — gates on load state, hosts the two tabs | `App/Views/RecallListView.swift` | populated + FSIS-unavailable |
| **Store dashboard** (Stores tab — quadrant grid, one tile per store) | `App/Views/StoreDashboardView.swift` | populated + empty |
| **Store recall list** (drill-down from a dashboard tile) | `App/Views/StoreRecallListView.swift` | single store |
| **Area list** (Area tab — regional/nationwide recalls) | `App/Views/AreaListView.swift` | populated |
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
| Store identity badges (color + monogram) | `App/Design/StoreIdentity.swift` |
| Danger fill mark (per-store aggregate score, geometric circle) | `App/Design/DangerMark.swift` |
| Generative scattered-circle background | `App/Design/PatternBackground.swift` |
| Aggregate danger score formula (pure, tested) | `RecallKit/Sources/RecallKit/Matching/DangerScore.swift` |
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
  - **Per-store aggregate** is a **continuous 0...1 danger score** (`DangerScore.score(for:)` in RecallKit — worst classification dominates, multiple recalls give a small boost, capped at 1.0), rendered as a proportional fill in `DangerMark`. This is a *different signal* (a store's overall risk right now), not a replacement for the per-recall classification.
- **Copy honesty:** always "could be at your store", never "is".
- **Icon + text pairing** everywhere (accessibility rule).
- Store chips on chain matches are red (`Design.Accent.storeMatch`) — they are the escalation signal.
- The "In your area" section (now the **Area tab**, `AreaListView.swift`) must keep the FSIS-unavailable warning slot (orange `Label`).
- **One interactive tint**, `Design.Accent.brand` (navy), applied once via `.tint(...)` in `EsthiosotariaApp`. Never hardcode `.blue`/`Color.accentColor` in a screen — it silently drifts from this the moment the token changes. The one deliberate exception is `StoreMapView`'s "you are here" dot and radius circle, which stay the system Maps blue by convention, not brand color.
- **Store identity is a badge, not a color-you-invent-locally**: every place a store is referenced (recall card chips, map markers, the picker, the detail header, dashboard tiles) uses `StoreBadge` from `StoreIdentity.swift` — a deterministic color + monogram per store, so the same store looks the same everywhere. Don't hand-roll a new per-store treatment; extend `StoreIdentity` if it needs a new size or state instead.
- **Corner radius** is `Design.Radius.card` (12pt) everywhere a rounded rect appears. Don't add a second radius value without a reason.
- **Onboarding step titles** are `.title2.bold()` — one consistent role for "the title of this step". The Welcome screen is the deliberate exception (`.title.bold()`, since it's the app's first impression and earns the extra size); nothing else should invent a third size for the same job.
- **`Design.Paper.background` is the screen background everywhere** — set once per screen root (List/Form need `.scrollContentBackground(.hidden)` first since they paint their own system background otherwise). `RootView` sets it at the top level so onboarding inherits it too; don't rely on that alone when adding a new top-level screen outside `RootView`'s tree — set it explicitly.
- **No manual store filter chips.** The dashboard prioritizes by danger score instead of offering hide/show controls — don't reintroduce per-store filter UI without revisiting that decision.
- **Muting is by brand/firm, global, and downgrades rather than hides.** Recall *events* never repeat, so "products I don't buy" mutes key off `ProductKey.displayName(for:)` (brand name, falling back to recalling firm) via `UserSettingsStore.payload.mutedProducts` — one flat list, not per-store. A muted recall keeps showing up in its store's list and the Area tab (so the user isn't blind to it if they change their mind) but loses the red "could be at your store" treatment, is excluded from a dashboard tile's active count/danger score, and never triggers a notification or a widget entry. Mute/unmute from `RecallDetailView`'s toggle or the `.muteSwipeAction` on any recall row; review/remove from Settings' "Products you don't buy" section.

## Home screen architecture (dashboard + area tabs)

`RecallListView` no longer renders a scrolling list itself — it gates on load state, then hosts a `TabView` with two `NavigationStack`-wrapped tabs:

- **Stores** (`StoreDashboardView`) — a 2-column quadrant grid, one tile per tracked store. Each tile shows that store's `DangerMark` (aggregate score fill) and `StoreBadge`; tapping drills into `StoreRecallListView` for that store's actual recall rows.
- **Area** (`AreaListView`) — everything regional/nationwide, not tied to a specific store. Split out because a store-quadrant grid has no natural home for data that isn't about a store.

`PatternBackground`'s density (`intensity`) tracks the worst danger score across all tracked stores — the background gets busier, not just the tiles, when something is more dangerous. It's `.allowsHitTesting(false)` and purely decorative — never encode information only in the pattern that isn't also in a tile.

## Widget architecture (widget-first product)

The widget is a **reader**, not a fetcher: the app does all network + matching, writes a `RecallSnapshot` to the shared App Group (`group.dev.tinyvelocet.esthiosotaria`), and calls `WidgetCenter.shared.reloadAllTimelines()`. The widget timeline provider just loads the snapshot. Consequences for design:

- Widget views never show loading/error — they show either data or "Open EsthioSotaria to set up".
- iOS freshness: `BGAppRefreshTask` (registered in `App/Services/BackgroundRefresh.swift`) republishes hourly-ish when iOS allows. macOS: refreshed whenever the Mac app runs.
- The three families (small/medium/large) live in one file — `RecallWidgetEntryView.swift` — with a `familyOverride` init for design renders.

## Architecture of a screen

Screens are **pure design surfaces**: they take data in via `let`/`@Binding` and report actions via closures. State ownership stays in the coordinator (`OnboardingView`) and the view model (`RecallListViewModel`). That's why they preview without network, location, or persistence.
