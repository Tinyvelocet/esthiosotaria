---
target: EsthioSotaria app-wide UI
total_score: 13
max_score: 20
na_heuristics: 
p0_count: 0
p1_count: 3
timestamp: 2026-08-18T00-16-11Z
slug: esthiosotaria-app-wide-ui
---
# EsthioSotaria — Design Critique (native-adapted dual-agent)

## Design Health Score (native-adapted, replaces Nielsen-10)
| # | Dimension | Score | Key Finding |
|---|---|---|---|
| 1 | Accessibility | 2/4 | Zero accessibilityLabel/Value/Hint anywhere in the codebase |
| 2 | Performance | 3/4 | No red flags; lists virtualized |
| 3 | Appearance & Theming | 2/4 | Real token system, but every interactive control is unmodified stock SwiftUI |
| 4 | Platform Conformance | 3/4 | Correct native primitives; .onTapGesture instead of NavigationLink on primary gesture |
| 5 | Adaptivity | 3/4 | Real size-class engineering; dashboard grid never reflows to store count or window width |
| Total | | 13/20 | Competent with real gaps |

## Design Specificity Verdict
Competently built, confidently mis-decorated. Native APIs used correctly (Assessment B, 13/20
conditional pass) but almost every custom component is the default SwiftUI/HIG catalog choice with
a coat of paint (Assessment A). The cream/red/navy palette is genuinely sourced (Monoprix reference)
and is the one element that survives a "could any app use this unchanged" test; it is carrying nearly
the whole burden of "this looks designed" alone.

## What's Working
- Content honesty and severity discipline (dot+word severity, "could be" never "is", mute downgrades
  rather than hides) — real domain thinking, keep untouched.
- Dark mode is first-class: warm near-black paper, no contrast/legibility failures found by either
  assessor.
- The sourced palette itself.
- FlowLayout custom Layout conformance, size-class-driven onboarding layout, careful macOS window/menu
  handling.

## Priority Issues
- [P1] Interaction layer is 100% stock SwiftUI (zero ButtonStyle/ToggleStyle anywhere) while the
  identity layer is custom — root cause of the generic read, not general blandness.
- [P1] DangerMark + StoreTile read as a stock gauge/stats-card (battery/Screen-Time/progress-ring),
  not a signature mark, despite code-comment ambition to echo custom numerals.
- [P1] Zero accessibility labeling anywhere; .onTapGesture instead of NavigationLink on the app's
  primary gesture (loses disclosure chevron + button trait); sub-44pt touch targets (map annotations,
  Settings trash buttons).
- [P2] Tab bar, toolbar, and Settings carry zero brand authorship — stock system chrome frames every
  screen; Settings is the only screen where a user would feel like they left the app.
- [P2] Danger expressed only through color/fill, never through structure — dashboard grid is rigid,
  doesn't reflow to store count (dead space with <4 stores) or window width.
- [P3] No motion anywhere (zero .animation/withAnimation/.transition in the codebase); onboarding's
  first impression (cart.fill + bold title + gray subtitle + pill button) is the most generic screen
  and is commerce-coded, not food-safety-coded; OnboardingStorePickerView.swift:220 hardcodes
  Color.accentColor, violating DESIGN.md's own documented rule — token system isn't enforced anywhere.
- Craft bug (not scored): RecallDetailView's mute toggle is partially obscured behind the floating tab
  bar in both light and dark mode — ScrollView doesn't reserve tab-bar clearance.

## Persona Red Flags
- Sam (Accessibility-dependent): no VoiceOver labels on any control; sub-44pt tap targets; safety-
  critical text (.lineLimit(2) on recall reasons/store names) will clip at larger Dynamic Type sizes.
- Jordan (First-timer): cart.fill hero reads as commerce, not food-safety alert; DangerMark's
  percentage-in-a-fill-circle has no immediate mental model without exploring further.
- Alex (Power user, macOS): no keyboard shortcuts beyond inherited Cmd+W; every recall handled one at
  a time, no bulk action despite tracking up to 4 stores' worth of matches at once.

## Minor Observations
- agencyPill and mutedPill both use the generic .background(.quaternary, in: Capsule()) "make it a
  chip" idiom.
- SF Symbols used at default weight/scale throughout, no symbolRenderingMode customization.
- DesignGalleryView (dev-tool only) has nested-NavigationStack title-hijacking bug; not shipped, but
  worth flagging before reused.
