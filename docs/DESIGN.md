# Design Guide — EsthioSotaria

Every major UI screen is **isolated in its own file**, renders from **mock data with zero network access**, and has **Xcode Previews**. Iterate freely.

## Where the screens live

| Screen | File | Previews included |
|---|---|---|
| Onboarding — Welcome | `App/Views/Onboarding/OnboardingWelcomeView.swift` | light + dark |
| Onboarding — Locating / denied | `App/Views/Onboarding/OnboardingLocatingView.swift` | both states |
| Onboarding — Manual entry | `App/Views/Onboarding/OnboardingManualEntryView.swift` | normal + error |
| Onboarding — Store picker | `App/Views/Onboarding/OnboardingStorePickerView.swift` | fresh + 2 selected |
| **Recall list (home)** | `App/Views/RecallListView.swift` | populated + FSIS-unavailable |
| **Recall card** (the repeated element) | `App/Views/Recalls/RecallRowView.swift` | single card + all severities |
| **Recall detail** | `App/Views/Recalls/RecallDetailView.swift` | chain match + FSIS regional |
| Settings | `App/Views/SettingsView.swift` | populated + empty |

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

## Architecture of a screen

Screens are **pure design surfaces**: they take data in via `let`/`@Binding` and report actions via closures. State ownership stays in the coordinator (`OnboardingView`) and the view model (`RecallListViewModel`). That's why they preview without network, location, or persistence.
