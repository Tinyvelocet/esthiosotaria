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
| **Recall list (home)** | `App/Views/RecallListView.swift` | populated + FSIS-unavailable |
| **Recall card** (the repeated element) | `App/Views/Recalls/RecallRowView.swift` | single card + all severities |
| **Recall detail** | `App/Views/Recalls/RecallDetailView.swift` | chain match + FSIS regional |
| Settings | `App/Views/SettingsView.swift` | populated + empty |
| **Widget UI (all 3 families)** | `Widget/RecallWidgetEntryView.swift` | Xcode widget previews in `RecallWidget.swift` |
| Widget entry point | `Widget/RecallWidget.swift` | small/medium/large previews |
| Widget data provider | `Widget/RecallTimelineProvider.swift` | reads App Group cache only |

Support:

| Purpose | File |
|---|---|
| Design tokens (colors, spacing) | `App/Design/DesignTokens.swift` |
| Mock stores & recalls (realistic, deterministic) | `App/Design/MockData.swift` |
| All-screens gallery | `App/Design/DesignGalleryView.swift` |

## Three ways to see your changes

1. **Xcode Previews** — open any screen file, hit the preview button. Fastest loop.
2. **Design Gallery at launch** — set `DesignGalleryView.showAtLaunch = true` in `DesignGalleryView.swift`, run the app: every screen on one scrollable canvas.
3. **Mock-data injection** — `RecallListView(viewModel: .designState())` and `UserSettingsStore.designState()` give you pre-populated state without any network.

## Design constraints (keep these when restyling)

- **Severity is dot + words**, never icon-only: "Critical — Class I", "Serious — Class II", "Minor — Class III". Colorblind-safe palette (red/orange/gray) in `DesignTokens.swift`.
- **Copy honesty:** always "could be at your store", never "is".
- **Icon + text pairing** everywhere (accessibility rule).
- Store chips on chain matches are red (`Design.Accent.storeMatch`) — they are the escalation signal.
- The "In your area" section must keep the FSIS-unavailable warning slot (orange `Label`).

## Widget architecture (widget-first product)

The widget is a **reader**, not a fetcher: the app does all network + matching, writes a `RecallSnapshot` to the shared App Group (`group.dev.tinyvelocet.esthiosotaria`), and calls `WidgetCenter.shared.reloadAllTimelines()`. The widget timeline provider just loads the snapshot. Consequences for design:

- Widget views never show loading/error — they show either data or "Open EsthioSotaria to set up".
- iOS freshness: `BGAppRefreshTask` (registered in `App/Services/BackgroundRefresh.swift`) republishes hourly-ish when iOS allows. macOS: refreshed whenever the Mac app runs.
- The three families (small/medium/large) live in one file — `RecallWidgetEntryView.swift` — with a `familyOverride` init for design renders.

## Architecture of a screen

Screens are **pure design surfaces**: they take data in via `let`/`@Binding` and report actions via closures. State ownership stays in the coordinator (`OnboardingView`) and the view model (`RecallListViewModel`). That's why they preview without network, location, or persistence.
