# EsthioSotaria — Copy Deck

Complete inventory of every user-facing string in the app (English, hardcoded —
no `.strings` catalog yet). Tagged by screen and source file. Dynamic values
are shown as `{…}`. Use for tone review, consistency checking, and as the seed
for a future localization pass.

> Agency labels are enum raw values — `FDA` and `USDA` (`Recall.swift`).

---

## 1. Onboarding

### Welcome (`App/Views/Onboarding/OnboardingWelcomeView.swift`)
| String | Kind |
|---|---|
| "Food recalls for your stores" | Title |
| "EsthioSotaria watches FDA and USDA food recalls and flags the ones that could be on the shelves of up to 4 grocery stores near you. Your location never leaves this device." | Body |

### Locating (`OnboardingLocatingView.swift`)
| String | Kind |
|---|---|
| "Finding your location…" | Progress |
| "Location access was denied" | Error title |
| "No problem — type your city instead. Nothing is sent anywhere." | Error body |

### Store picker (`OnboardingStorePickerView.swift`)
| String | Kind |
|---|---|
| "Pick up to {RecallKit.maxSelectedStores} stores" | Header |
| "{selectedCount}/{maxSelectedStores} selected" | Counter |
| "{store name}" | Store row |
| "Chain store — recall matches escalate to the top" | Chain-store caption |
| "Stores found via {source.rawValue}" | Discovery label |
| "Search radius: {radiusMiles} mi" | Radius label |
| "Search radius" | Radius control header |
| "Searching for stores…" | Loading |
| "{errorMessage}" | Error (`Label(…, systemImage:"exclamationmark.triangle")`) |
| "No grocery stores found nearby. Try a wider radius." | Empty state |
| "Map unavailable" | Map fallback (`Label(…, systemImage:"map")`) |

### Manual entry (`OnboardingManualEntryView.swift`)
| String | Kind |
|---|---|
| "Where do you shop?" | Title |
| "{errorMessage}" | Error body |

### Map (`App/Views/Onboarding/StoreMapView.swift`)
| String | Kind |
|---|---|
| "Use my current location" | Button |
| "City or ZIP to search" | Text-field placeholder |
| "Search" | Button |
| "{store name}" | Map pin accessibility label |
| "{store name}" | Annotation |

---

## 2. Dashboard (`App/Views/StoreDashboardView.swift`)

| String | Kind |
|---|---|
| "Refresh recalls" | Refresh-button accessibility label |
| "Scan this location" | Scan-button accessibility label |
| "Settings" | Settings-button accessibility label |
| "Checking FDA and USDA recalls…" | Loading label |
| "Updated {HH:MM}" | Timestamp (`.formatted(date:.omitted, time:.shortened)`) |
| "SERIOUS RECALLS IN YOUR AREA" | Serious-region section title |
| "See everything in your area" | "View all" link |
| "No stores tracked yet" | Empty-store state title |
| "Add a store in Settings to start seeing danger scores here." | Empty-store state body |
| "Nothing active" | Per-store empty state |
| "Scan failed" | Alert title (`Alert("Scan failed", isPresented:$showScanError)`) |
| "{scan error message}" | Alert body |
| "{store name}" | Store header |

**Per-store tiles** (drill to `StoreRecallListView`), plus serious-region cards.

### Store recall list (`App/Views/StoreRecallListView.swift`)
| String | Kind |
|---|---|
| "{store name}" | Navigation title |
| "No active recalls for this store right now." | Empty state |
| "Matched by brand or recalling company. The FDA doesn't say which shelf a product was on — check the details before deciding." | Footer |

### Recall rows (`App/Views/Recalls/RecallRowView.swift`)
| String | Kind |
|---|---|
| "{product}" — `recall.shortProductName()` | Card title |
| "{reason}" — `recall.reasonSummary()` | Card body |
| "{store names}" — matched-store chips | Chips |
| "Could be at your store" | Chain-tier badge |
| "Muted — {mutedProductLabel}" | Muted pill (`Label(…, systemImage:"bell.slash.fill")`) |
| "Critical — Class I" / "Serious — Class II" / "Minor — Class III" / "Unclassified" | Severity label (duplicated in the widget) |

### Swipe action (`App/Views/Recalls/MuteSwipeAction.swift`)
| String | Kind |
|---|---|
| "Not something I buy" | Mute swipe label (`Label(…, systemImage:"bell.slash.fill")`) |
| "I buy this" | Unmute swipe label (`Label(…, systemImage:"bell.fill")`) |

### Detail page (`App/Views/Recalls/RecallDetailView.swift`)
| String | Kind |
|---|---|
| "Recall details" | Navigation title |
| "Could be at your store" | Chain-match badge (`Label(…, systemImage:"exclamationmark.triangle.fill")`) |
| "Muted — you said you don't buy this" | Muted badge (`Label(…, systemImage:"bell.slash.fill")`) |
| "{recallingFirm}" / "Unknown company" | Title |
| "Recall {id}" | Recall-id caption |
| "WHAT TO LOOK FOR" | Section (rendered uppercase) |
| "{productDescription}" / "No product details published." | Body |
| "WHY IT WAS RECALLED" | Section (rendered uppercase) |
| "{reasonForRecall}" / "No reason published." | Body |
| "WHAT YOU CAN DO" | Section (rendered uppercase) |
| "Check the product in your pantry or fridge against the description above. If it matches, don't eat it — return it to the store for a refund or throw it away." (+ " This is a Class I recall (serious health risk). If you ate the product and feel unwell, contact a doctor." for Class I) | Advice body |
| "OFFICIAL NOTICE" | Section (rendered uppercase) |
| "Open the {FDA/USDA} recall record" | Link label (`Label(…, systemImage:"arrow.up.right.square")`) |
| "I've handled this recall" | Toggle (`Label(…, systemImage:"checkmark.circle")`) |
| "I don't buy {productName}" | Mute toggle (`Label(…, systemImage:"bell.slash")`) |

---

## 3. Scan result (`App/Views/ScanResultView.swift`)

| String | Kind |
|---|---|
| "Scan — {store name}" | Navigation title |
| "Done" | Toolbar button |
| "{store name}" | Header |
| "Checked against the latest FDA & USDA recalls." | Header caption |
| "Match at {store name}" | Chain section title (uppercased) |
| "Also in your area" | Regional section title (uppercased) |
| "All safe at {store name}" | All-clear card (`Label(…, systemImage:"checkmark.circle.fill")`) |
| "No recall matches right now for the kind of products this store carries." | All-clear card body |

---

## 4. Area list (`App/Views/AreaListView.swift`)

| String | Kind |
|---|---|
| "In your area" | Navigation title |
| "Refresh recalls" | Refresh-button accessibility label |
| "No active recalls match your area right now." | Empty state |
| "USDA meat/poultry feed unavailable — FDA recalls shown only." | USDA-unavailable banner (`Label(…, systemImage:"exclamationmark.triangle")`) |
| "Updated {HH:MM}. FDA data may lag the official recall site by days." | Timestamp/info caption |
| "{category name}" | Section header |
| (rows reuse `RecallRowView`) | Cards |

---

## 5. Settings (`App/Views/SettingsView.swift`)

### Section headers (rendered UPPERCASE by `sectionHeader`)
| String | Kind |
|---|---|
| "Your stores" | Section |
| "Add a store" | Section |
| "Products you don't buy" | Section |
| "Notifications" | Section |
| "About" | Section |

### Your stores
| String | Kind |
|---|---|
| "{store name}" | Row |
| "{chain}" (capitalized) | Row caption |
| "Remove store" | Trash-button tooltip |
| "Remove {store name}" | Accessibility label |
| "No stores selected. Add one below." | Empty state |

### Add a store
| String | Kind |
|---|---|
| "Use my current location" / "Locating…" (`scanButtonLabel`) | Button |
| "City or ZIP to search" | Text-field placeholder |
| "Search" | Button |
| "{store name}" | Discovered store row |
| "Couldn't find that place." | Geocode error |
| "{error.localizedDescription}" | Location error |

### Products you don't buy
| String | Kind |
|---|---|
| "{product}" | Muted product row |
| "Remove from muted products" | Trash-button tooltip |
| "Unmute {product}" | Accessibility label |
| "Nothing muted yet. Swipe a recall card, or use its detail page, to mark a brand \"not something I buy.\"" | Empty state |
| "Brand or company name" | Text-field placeholder |
| "Mute" | Button |
| "Muted products won't trigger notifications or the red \"could be at your store\" alert, but their recalls still show up in your store's list." | Footer |

### Notifications
| String | Kind |
|---|---|
| "Notify me about recall matches" | Toggle |
| "Notify me when I enter a store" | Toggle |
| "Fires when you're near one of your tracked stores. Needs \"Always\" location access and a real device (the Simulator can't monitor regions)." | Caption |

### About
| String | Kind |
|---|---|
| "Data source" → "openFDA (FDA enforcement reports)" | Labeled content |
| "Matching" → "Brand-based — could be, not certainty" | Labeled content |
| "Recall data can lag the official FDA site by days to weeks." | Caption |

### Navigation
| String | Kind |
|---|---|
| "Settings" | Navigation title |

---

## 6. Loading & errors (`App/Views/RecallListView.swift`)

| String | Kind |
|---|---|
| "Checking FDA recalls…" | Loading `ProgressView` |
| "Couldn't load recalls" | Error headline |
| "{message}" | Error detail |
| "Try again" | Retry button |

---

## 7. Widget (`Widget/RecallWidgetEntryView.swift`)

| String | Kind |
|---|---|
| "Could be at your store" (`hasStoreMatch`) / "Recalls near you" | Header badge |
| "{product}" — `shortProductName()` | Row title |
| "• {matched store names}" | Store chips row |
| "Critical — Class I" / "Serious — Class II" / "Minor — Class III" / "Unclassified" | Severity |
| "No recalls match your stores" (small) | Empty |
| "No active recalls match your area." (medium/large) | Empty |
| "Open EsthioSotaria to set up" | Not-set-up state |
| "Updated {HH:MM}" | Timestamp footer |

---

## 8. Notifications (`App/Services/`)

### Chain / regional recall matches (`NotificationScheduler.swift`)
| String | Kind |
|---|---|
| "Recall could be at your store" | Chain title |
| "{store label}: {product} — {reason}" | Chain body |
| "Serious recall in your area" | Regional title |
| "{product} — {reason}" | Regional body |

### Store-entry geofence (`StoreGeofenceService.swift`)
| String | Kind |
|---|---|
| "All safe at {store name}." | Title |
| "EsthioSotaria checked the latest recall data for {store name}." | Body (fresh data) |
| "All safe per your latest recall check for {store name}. Couldn't refresh right now." | Body (stale/offline) |

---

## 9. Privacy / Info.plist (`App/Info.plist`)

| String | Key |
|---|---|
| "EsthioSotaria uses your location to find grocery stores near you. It never leaves this device." | `NSLocationWhenInUseUsageDescription` |
| "EsthioSotaria uses your location to notify you when you enter one of your tracked stores. It never leaves this device." | `NSLocationAlwaysAndWhenInUseUsageDescription` |
| "EsthioSotaria" | `CFBundleDisplayName` |

---

## Notes / observations
- **Tone**: warm, plain, honesty-forward — "Brand-based — could be, not certainty", "Checked against the latest FDA & USDA recalls", the truthful "couldn't refresh right now" fallback, and "No problem — type your city instead." Keep this voice; it's a real differentiator for a safety app.
- **Privacy-first language** runs throughout ("never leaves this device", "Nothing is sent anywhere") — keep consistent.
- **No localization catalog exists.** All strings are inline SwiftUI literals. A future pass should move them into `Localizable.xcstrings`.
- **Interpolated strings** marked with `{…}` — tail-check pluralization/word order when localizing.
- **Severity labels** ("Critical — Class I" etc.) are duplicated between `RecallRowView` and the widget — consider extracting to a shared constant.
- **Section titles** ("What to look for", "Why it was recalled", "What you can do", "Official notice", plus all Settings section headers) are stored in their natural case and rendered uppercase via `.uppercased()`; display-uppercase, not a copy change.
- Widget empty state differs by family ("your stores" vs "your area") — intentional, matches the content each family carries.