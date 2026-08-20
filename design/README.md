# EsthioSotaria — Design Reference (Figma)

Rendered screenshots of the app's key screens, generated from the app's *own*
SwiftUI views + mock data at iPhone 15 frame size (1179×2556 @3x) — no
simulator chrome. Use these as Figma references while redesigning.

| File | Screen |
|------|--------|
| `01-onboarding-welcome.png` | Onboarding — welcome (brand headline) |
| `02-onboarding-locating.png` | Onboarding — locating in progress |
| `03-onboarding-location-denied.png` | Onboarding — permission denied |
| `04-onboarding-manual-entry.png` | Onboarding — manual city/ZIP entry |
| `05-onboarding-store-picker.png` | Onboarding — store picker (list + map) |
| `06-dashboard.png` | Home — store severity dashboard |
| `06b-scan-result.png` | "Scan this location" result (non-favorite store) |
| `07-recall-detail.png` | Recall detail — Class I chain match |
| `08-settings.png` | Settings |
| `09-area-list.png` | In-your-area (regional) recall feed |

## Regenerating

These are produced by the `EsthioSotaria_ScreenshotGen` tool (see
`scripts/ScreenshotGen/Runner.swift`), which compiles the same views/mock data
the app uses, so any design change propagates 1:1:

```bash
xcodegen generate
xcodebuild -scheme EsthioSotaria_ScreenshotGen -configuration Release build
./build-out/EsthioSotaria_ScreenshotGen    # from repo root
```

Output lands in `docs/screenshots/`; copy to `design/` for the Figma reference
set. Note: this is a macOS-only preview tool — it is not shipped with the iOS
app.

## Design tokens

- **Palette:** warm paper base (`#F6F1E8` / dark `#1B1815`), one saturated red
  for danger only (`#D0102A`), deep navy brand tint (`#16213C`) for chrome and
  interactive elements. See `App/Design/DesignTokens.swift`.
- **Typeface:** brand display serif = **DM Serif Display** (SIL OFL 1.1,
  bundled at `App/Resources/Fonts`); body/UI = system SF.
- **App icon:** `Icon/appicon.png` (1024×1024).