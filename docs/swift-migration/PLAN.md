# Scrunch: native Swift rewrite plan

Goal: replace the Expo / React Native iOS app with a native SwiftUI app that ships as an
**update to the same App Store app**. Backend (`convex/`) and Clerk auth stay as they are.

| Must stay the same | Value |
| --- | --- |
| App bundle ID | `com.nickmcblain.babysteps` |
| Widget extension bundle ID | `com.nickmcblain.babysteps.widgets` |
| App group | `group.com.nickmcblain.babysteps` |
| URL scheme | `babysteps` (Live Activity deep link `babysteps://baby/{id}/{kind}/timer`) |
| Widget kind | `BabyGlanceWidget` (existing home-screen widgets keep working after the update) |
| Convex deployment | same URL as `EXPO_PUBLIC_CONVEX_URL` |
| Clerk instance | same publishable key as `EXPO_PUBLIC_CLERK_PUBLISHABLE_KEY` |
| Notification identifiers | `feed-reminder:{babyId}`, `nap-reminder:{babyId}`, `medicine-reminder:{babyId}:{slug}`, `digest:{babyId}`, so the native app replaces anything the RN build scheduled |

The RN app in the repo root is left intact. The native app lives in `ios-native/`.

---

## 1. Key decisions

### Minimum iOS: 17.0

- **Clerk's iOS SDK (`clerk-ios` 1.x) requires iOS 17**, and so does the Clerk-Convex
  bridge. That alone sets the floor.
- iOS 17 also gives us the Observation framework (`@Observable`), the modern Swift Charts
  API (`chartXSelection`, `SectorMark`), `ContentUnavailableView`, interactive widgets,
  and `containerBackground` for widgets. These remove most of the custom-component work
  the RN app needed.
- iOS 17 covers the vast majority of active iPhones (anything from iPhone XS / XR onward).

### Packages

| Package | Version | Why |
| --- | --- | --- |
| [`get-convex/convex-swift`](https://github.com/get-convex/convex-swift) (`ConvexMobile`) | `from: 0.8.2` | Official Convex client; reactive subscriptions via Combine publishers |
| [`clerk/clerk-ios`](https://github.com/clerk/clerk-ios) (`ClerkKit`, `ClerkKitUI`) | `from: 1.7.2` | Native sign-in (`AuthView`) and account UI (`UserButton`) |
| [`clerk/clerk-convex-swift`](https://github.com/clerk/clerk-convex-swift) | **not used (yet), see below** | |

**Auth bridge decision.** `ClerkConvexAuthProvider` (clerk-convex-swift 0.1.0) sends
Clerk's *default session token* (`session.getToken()` with no template). The RN app sends
the **`convex` JWT template** (`@clerk/expo` + `ConvexProviderWithClerk`). Convex's
`auth.config.ts` checks `applicationID: "convex"`, i.e. `aud == "convex"`, which today
only the template guarantees.

So the native app ships a ~60-line `ClerkConvexTemplateAuthProvider`. It is the same
shape as the official bridge but calls `session.getToken(.init(template: "convex"))`.
That keeps the auth behaviour identical to the RN app with zero backend or dashboard
changes. Both token types carry the same `iss` and `sub`, so `tokenIdentifier` (and
therefore every `users` row) is unchanged.

If Nick activates the Clerk dashboard **Convex integration**, the default session token
gains `aud: "convex"`. At that point the official `ClerkConvexAuthProvider` can be dropped
in instead (a one-line swap in `ConvexService.swift`).

### Convex number and optional encoding (important)

- Every `v.number()` in the schema is a **float64**. ConvexMobile encodes Swift `Int` as a
  64-bit `$integer` (`v.int64()`), which `v.number()` **rejects**. All numeric args are
  therefore sent as `Double`.
- ConvexMobile encodes a `nil` dictionary value as JSON `null`. `v.optional(...)`
  **rejects `null`**; it only accepts the key being absent. Optional args are therefore
  **omitted** when nil.

Both rules live in one place. `ScrunchCore.ConvexValue` is a small JSON value enum, and
the typed call builders in `ScrunchCore.API` only produce `.number(Double)` and drop nil
keys. Both rules are unit-tested on Linux.

Decoding: numbers come back as plain JSON numbers (float64), sometimes with a trailing
`.0`. Models decode every number as `Double`, never `Int`, and expose integer
conveniences where needed.

### Deployment quirk carried over

`events.list` on the live deployment only accepts `{ babyId, paginationOpts }`. Passing
`kind` throws (see the comment in `components/EventList.tsx`). The native client sends only
those two args and filters by kind on the device, exactly like RN.

Pagination: ConvexMobile has no `usePaginatedQuery`. The native list subscribes with
`paginationOpts: { numItems: N, cursor: null }` and grows `N` on "Load older". That gives
40 to start, 200 when filtered by kind, and +20 per "Load older". It stays reactive and
matches the RN page sizes.

### Project layout

```
ios-native/
  project.yml                 XcodeGen spec (app, widget extension, unit tests)
  Config/                     xcconfigs (Secrets.xcconfig is gitignored)
  Packages/ScrunchCore/       Pure-Foundation Swift package, builds and tests on Linux
    Sources/ScrunchCore/      Models, Convex call builders, all ported lib/ logic, WHO data
    Tests/ScrunchCoreTests/   Ports of the TS tests plus new ones
  Scrunch/                    SwiftUI app target (iOS only)
  ScrunchWidgets/             WidgetKit + ActivityKit extension (iOS only)
  Shared/                     Files compiled into both app and extension (ActivityAttributes, app-group store)
```

Pure logic lives in `ScrunchCore` so it can be compiled and tested on Linux CI. The app
and widget targets depend on it as a local Swift package.

### Things deliberately not carried over

| RN | Native | Why |
| --- | --- | --- |
| `components/WheelPicker.tsx`, `lib/wheelPicker.ts` | SwiftUI `DatePicker` and `Picker(.wheel)` | Known fast-scroll bug, and native wheels are better |
| `components/BottomSheet.tsx` | `.sheet` + `presentationDetents` | Native |
| `components/DockScroll.tsx` (dock collapses on scroll) | Floating dock that stays put | Polish item. See Open questions |
| `lib/useMarkInteractive.ts` (expo-observe TTI marks) | Dropped | Expo-only telemetry |
| `lib/wakeWindows.ts`, `lib/weeklyDigest.ts`, `feedReminderHint` | Dropped | Not referenced by any RN screen (dead code). The weekly digest notification copy is static and is ported |
| `voiceLog.logFromImage` / `logFromText` | Not wired | RN client never calls them (only `logFromAudio`) |
| `babies.setNightWindow`, `events.weeklySummary`, `events.listByKindInRange` | Not wired | RN client never calls them. `recommendedDay` still honours `nightBedMin` / `nightWakeMin` if set |
| Custom SVG icons (`ActionIcons.tsx`, `TabIcons.tsx`) | SF Symbols | Native, dynamic-type aware. Mapping below |
| `app.json` `userInterfaceStyle: "light"` | `UIUserInterfaceStyle = Light` in Info.plist | Same forced-light behaviour; dark palette ported and one key away |

### Deliberate deviations from RN

- The Ask composer stays visible (RN hides it while scrolling up).
- Ask citations with a URL are tappable links.
- "Skip to manual" on a timer only stops the timer if it belongs to that screen.
- "Load older" re-subscribes with a bigger page instead of cursor pagination (see above).
- Feed-reminder suppression while the sleep timer runs is driven by `TimerStore` (the sleep
  timer refreshes the feed reminder on every start / stop) instead of RN's
  `onSleepTimerRunning` / `onSleepTimerIdle` hooks. Same outcome.

### Fonts

Fredoka (display, 600/700) and Nunito (body, 400/600/700) are SIL OFL Google Fonts. Static
TTFs are bundled in `ios-native/Shared/Fonts` (app and widget extension) with their OFL licence and
registered via `UIAppFonts`.

---

## 2. Inventory: RN → Swift

### 2.1 Screens (`app/`)

| RN route | Swift view | Notes |
| --- | --- | --- |
| `app/_layout.tsx` | `ScrunchApp`, `RootView` | `Clerk.configure`, missing-config screen, fonts, theme |
| `app/index.tsx` | `RootView` | Auth gate on `ConvexClientWithAuth.authState` |
| `app/(auth)/_layout.tsx`, `sign-in.tsx` | `SignInView` | Teal hero + `ClerkKitUI.AuthView(isDismissible: false)` in a 36-radius sheet |
| `app/(app)/_layout.tsx` | `SignedInRoot` | Runs `users:store` once (ex-`StoreUser.tsx`) and owns the `NavigationStack` |
| `app/(app)/(tabs)/_layout.tsx` | `MainTabView` + `FloatingDock` | Pill dock (Home, Timeline, Kids, Profile) + "+" FAB → `AddLogSheet` |
| `(tabs)/index.tsx` | `HomeView` | Vitals, week strip, sleep block (next nap, hero, rhythm bar), 3 rings |
| `(tabs)/timeline.tsx` | `TimelineTab` → `TimelineView` | List / Week |
| `(tabs)/kids.tsx` | `KidsView`, `JoinPartnerSheet` | 2-col tiles, invite code join |
| `(tabs)/profile.tsx` | `ProfileView` | `UserButton`, email, subscription line |
| `app/(app)/babies/new.tsx` | `NewBabyView` | Consent checkbox gates save |
| `baby/[id]/index.tsx` | `BabyHomeView` | Status tiles, 6 action tiles, Ask FAB |
| `baby/[id]/edit.tsx` | `EditBabyView` | |
| `baby/[id]/log.tsx` | `TimelineView` | Shared with the Timeline tab |
| `baby/[id]/event.tsx` | `CustomEventView` | Future dates allowed |
| `baby/[id]/feed/timer.tsx` | `FeedTimerView` | Left / Right, Live Activity |
| `baby/[id]/feed/manual.tsx` | `FeedManualView` | Breast / bottle |
| `baby/[id]/feed/patterns.tsx` | `PatternsView(kind: .feed)` | |
| `baby/[id]/sleep/timer.tsx` | `SleepTimerView` (`DurationTimerView(.sleep)`) | Live Activity, feed-reminder hooks |
| `baby/[id]/sleep/manual.tsx` | `SleepManualView` (`DurationManualView(.sleep)`) | |
| `baby/[id]/sleep/patterns.tsx` | `PatternsView(kind: .sleep)` | Bars / Chart toggle |
| `baby/[id]/tummy/timer.tsx` | `DurationTimerView(.tummy)` | |
| `baby/[id]/tummy/manual.tsx` | `DurationManualView(.tummy)` | |
| `baby/[id]/tummy/patterns.tsx` | `PatternsView(kind: .tummy)` | No event list (as RN) |
| `baby/[id]/pump/timer.tsx` | `FeedTimerView(mode: .pump)` | |
| `baby/[id]/pump/manual.tsx` | `PumpManualView` | |
| `baby/[id]/nappy/index.tsx` | `NappyView(kind: .nappy)` | |
| `baby/[id]/nappy/patterns.tsx` | `PatternsView(kind: .nappy)` | |
| `baby/[id]/potty.tsx` | `NappyView(kind: .potty)` | |
| `baby/[id]/medicine.tsx` | `MedicineView` | Reminder 4h/6h/8h/Off |
| `baby/[id]/activity.tsx` | `ActivityView` | |
| `baby/[id]/temp.tsx` | `ClothingView` | °C/°F, debounced `saveRoomTemp` |
| `baby/[id]/weight.tsx` | `GrowthLogView(metric: .weight)` | Growth chart + picker |
| `baby/[id]/height.tsx` | `GrowthLogView(metric: .height)` | |
| `baby/[id]/ask/index.tsx` | `AskView` | Emergency check, disclaimer, `q` auto-send |
| `baby/[id]/ask/history.tsx` | `AskHistoryView` | |

### 2.2 Components (`components/`)

| RN | Swift |
| --- | --- |
| `ui.tsx` (Card, Title, Subtitle, Pill, PrimaryButton, IconButton, Field, PlusMark) | `DesignSystem.swift` (`Card`, `ScreenTitle`, `Pill`, `PrimaryButton`, `CircleIconButton`, `FieldLabel`, `TextFieldStyle`) |
| `Screen.tsx`, `DockScroll.tsx` | `ScreenScaffold` |
| `CalTabBar.tsx`, `TabIcons.tsx` | `FloatingDock` + SF Symbols |
| `AddLogSheet.tsx`, `ActionIcons.tsx` | `AddLogSheet` + SF Symbols + `VoiceLogRecorder` |
| `BottomSheet.tsx` | Native `.sheet` |
| `DateOfBirthField.tsx` | `DateOfBirthField` (`DatePicker` in a UTC calendar) |
| `LoggedAtField.tsx` | `LoggedAtField` (`DatePicker`, snapped to minute) |
| `WeightField.tsx`, `HeightField.tsx`, `WheelPicker.tsx` | `WeightPicker`, `HeightPicker` (native wheel `Picker`) |
| `InviteCodeBoxes.tsx` | `InviteCodeField` |
| `DayRhythmBar.tsx` | `DayRhythmBar` |
| `WeekStrip.tsx` | `WeekStrip` |
| `WeekRhythmChart.tsx` | `WeekRhythmChart` |
| `SleepPatternChart.tsx` | `PatternChart` (Bars = custom rows, Chart = Swift Charts `RectangleMark`) |
| `GrowthChart.tsx` | `GrowthChart` (Swift Charts `LineMark` + `PointMark`) |
| `EventList.tsx` | `EventListView` |
| `ProgressRing.tsx` | `ProgressRing` |
| `StoreUser.tsx` | `SignedInRoot` `.task { users:store }` |

### 2.3 Library (`lib/`) → `ScrunchCore` (tested on Linux) or app services

| RN | Swift | Tested |
| --- | --- | --- |
| `dayRhythm.ts` | `ScrunchCore/DayRhythm.swift` | `DayRhythmTests` (port of `dayRhythm.test.ts`) |
| `sleepOffer.ts` | `ScrunchCore/SleepOffer.swift` | `SleepOfferTests` (port of `sleepOffer.test.ts`) |
| `sleepGoals.ts` | `ScrunchCore/SleepGoals.swift` | `SleepGoalsTests` (port of `sleepGoals.test.ts` + counts) |
| `clothingAdvice.ts` | `ScrunchCore/ClothingAdvice.swift` | `ClothingAdviceTests` |
| `feedWindows.ts` | `ScrunchCore/FeedWindows.swift` | `FeedWindowsTests` |
| `format.ts` | `ScrunchCore/Format.swift` | `FormatTests` |
| `eventCopy.ts` | `ScrunchCore/EventCopy.swift` | `EventCopyTests` |
| `weekGrid.ts` | `ScrunchCore/WeekGrid.swift` | `WeekGridTests` |
| `loggedAt.ts` | `ScrunchCore/LoggedAt.swift` | `LoggedAtTests` |
| `growth/lms.ts`, `growth/whoLmsData.ts` | `ScrunchCore/GrowthLMS.swift`, `WHOLMSData.swift` | `GrowthLMSTests` |
| `liveTimer.ts` (state + clock maths) | `ScrunchCore/TimerSession.swift` | `TimerSessionTests` |
| `liveTimer.ts` (ActivityKit) | `Scrunch/Services/LiveActivityController.swift` | Needs iOS |
| `feedReminders.ts`, `useFeedReminderSync.ts` | `ScrunchCore/ReminderPlans.swift` (decisions + copy) + `Scrunch/Services/Reminders.swift` | Plans tested; scheduling needs iOS |
| `napReminders.ts`, `medicineReminders.ts`, `digestReminder.ts` | Same as above | Same |
| `widgetSync.ts` | `ScrunchCore/Glance.swift` (payload + strings) + `Scrunch/Services/WidgetSync.swift` | Payload tested |
| `activeBaby.ts` | `Scrunch/Services/ActiveBabyStore.swift` (`UserDefaults`) | Needs iOS |
| `theme.ts`, `providers/ThemeProvider.tsx` | `Scrunch/DesignSystem/Theme.swift` | Needs iOS |
| `useVoiceLog.ts` | `Scrunch/Services/VoiceLogRecorder.swift` (AVAudioRecorder, m4a) | Needs iOS |
| Ask emergency regex, markdown rendering | `ScrunchCore/AskSafety.swift`, `ScrunchCore/MarkdownBlocks.swift` | `AskSafetyTests`, `MarkdownBlocksTests` |
| Home-screen string helpers (`formatCountdown`, `formatHours`, last-feed / last-nappy strips) | `ScrunchCore/HomeCopy.swift` | `HomeCopyTests` |
| Invite code sanitising (`InviteCodeBoxes`) | `ScrunchCore/InviteCode.swift` | `InviteCodeTests` |
| Pattern window / per-day bucketing (`SleepPatternChart`, pattern screens) | `ScrunchCore/Patterns.swift` | `PatternsTests` |

### 2.4 Convex functions the client uses

All are wrapped as typed `ConvexCall<Result>` builders in `ScrunchCore/API.swift`. Result
models live in `ScrunchCore/Models.swift`. Kinds: Q = query (subscribed), M = mutation,
A = action.

| Function | Kind | Args | Swift result |
| --- | --- | --- | --- |
| `users:store` | M | `{}` | `User` |
| `users:current` | Q | `{}` | `User?` |
| `babies:list` | Q | `{}` | `[Baby]` |
| `babies:get` | Q | `babyId` | `Baby?` |
| `babies:create` | M | `name, dateOfBirth, weightGrams, heightCm?, sex?, notes?, careDataConsent: true` | `String` |
| `babies:update` | M | `babyId, name, dateOfBirth, notes?, sex?, deliveryType?, gestationWeeks?, feedingMode?` | `null` |
| `babies:saveRoomTemp` | M | `babyId, tempC` | `null` |
| `babies:joinByCode` | M | `code` | `String` |
| `events:dashboard` | Q | `babyId` | `Dashboard` |
| `events:daySummary` | Q | `babyId, dayStart, dayEnd` | `DaySummary` |
| `events:growthSeries` | Q | `babyId, kind` | `GrowthSeries` |
| `events:list` | Q | `babyId, paginationOpts` | `EventPage` |
| `events:weekGrid` | Q | `babyId, weekStartMs` | `WeekGrid` |
| `events:sleepPatterns` | Q | `babyId, days, rangeEndMs` | `SleepPatterns` |
| `events:feedPatterns` | Q | same | `FeedPatterns` |
| `events:nappyPatterns` | Q | same | `NappyPatterns` |
| `events:tummyPatterns` | Q | same | `TummyPatterns` |
| `events:logFeed` | M | `babyId, loggedAt, feedKind, side?, durationMinutes?, amountMl?, milk?, note?` | `String` |
| `events:logNappy` | M | `babyId, loggedAt, nappy, weeSize?, pooSize?, note?` | `String` |
| `events:logPotty` | M | same as nappy | `String` |
| `events:logWeight` | M | `babyId, loggedAt, weightGrams, note?` | `String` |
| `events:logHeight` | M | `babyId, loggedAt, heightCm, note?` | `String` |
| `events:logSleep` | M | `babyId, loggedAt, durationMinutes, note?` | `String` |
| `events:logTummy` | M | `babyId, loggedAt, durationMinutes, note?` | `String` |
| `events:logPump` | M | `babyId, loggedAt, side, durationMinutes, amountMl?, note?` | `String` |
| `events:logMedicine` | M | `babyId, loggedAt, title, note?` | `String` |
| `events:logActivity` | M | `babyId, loggedAt, title, durationMinutes?, note?` | `String` |
| `events:logCustom` | M | `babyId, loggedAt, title, note?` | `String` |
| `events:remove` | M | `eventId` | `null` |
| `chat:ensureThread` | M | `babyId` | `String` |
| `chat:createThread` | M | `babyId` | `String` |
| `chat:listThreads` | Q | `babyId` | `[ChatThread]` |
| `chat:listMessages` | Q | `threadId` | `[ChatMessage]` |
| `chatAgent:ask` | A | `babyId, threadId, message` | `AskReply` |
| `voiceLog:logFromAudio` | A | `babyId, audioBase64, format: "m4a"` | `VoiceLogResult` |

**Backend changes: none.** The native client needs nothing new from `convex/`.

### 2.5 Platform features

| RN | Native |
| --- | --- |
| `expo-widgets` `BabyGlanceWidget` (small / medium) | `ScrunchWidgets/BabyGlanceWidget.swift` (WidgetKit, same kind). App writes `GlanceSnapshot` JSON into app-group `UserDefaults` and calls `WidgetCenter.reloadTimelines` |
| `expo-widgets` `BabyTimerActivity` | `ScrunchWidgets/BabyTimerLiveActivity.swift` (ActivityKit). `Shared/BabyTimerAttributes.swift`. Count-up clock via `Text(timerInterval:countsDown: false)` |
| `expo-notifications` | `UNUserNotificationCenter` with the same identifiers and copy |
| `expo-audio` recorder | `AVAudioRecorder` (AAC m4a, mono 44.1 kHz) |
| AsyncStorage | `UserDefaults` (app group for anything the widget reads) |
| `expo-router` deep links | `onOpenURL` → `AppRouter` handles `babysteps://baby/{id}/{kind}/timer` |
| Expo `Haptics` | `sensoryFeedback` |

### 2.6 SF Symbol mapping

| RN icon | SF Symbol |
| --- | --- |
| Feed / bottle | `drop.fill` |
| Sleep | `moon.fill` |
| Nappy | `circle.grid.2x2.fill` |
| Tummy | `figure.arms.open` |
| Pump | `drop.halffull` |
| Medicine | `pills.fill` |
| Potty | `toilet.fill` |
| Activity | `figure.play` |
| Note / event | `calendar.badge.plus` |
| Clothing | `tshirt.fill` |
| Ask | `bubble.left.and.text.bubble.right.fill` |
| Speak | `mic.fill` |
| Tabs: Home / Timeline / Kids | `house.fill` / `list.bullet.rectangle.fill` / `figure.and.child.holdinghands` |

---

## 3. Phases

Each phase is one or more commits on `feat/native-swift-rewrite-8927`.

1. **Foundation + auth + data layer.** XcodeGen project, xcconfigs, entitlements,
   `ScrunchCore` package (models, `ConvexValue`, API builders), `ConvexService`, Clerk
   template auth provider, `users:store`, sign-in screen, missing-config screen.
2. **Core logic port + tests.** dayRhythm, sleepOffer, sleepGoals, clothing, feed windows,
   formatters, event copy, week grid, loggedAt, growth LMS + WHO data, timer maths,
   reminder plans, glance payload.
3. **Core logging.** Feed / sleep / tummy / pump timers + manual entry, nappy, potty,
   medicine, activity, custom event, weight, height.
4. **Home + timeline.** Home tab, week strip, rhythm bar, rings, timeline list + week
   chart, delete.
5. **Charts + growth.** Pattern screens (Swift Charts), growth chart with UK-WHO centiles.
6. **Sharing / invites + babies.** Kids tab, join by code, new baby, edit baby, baby home.
7. **Voice + Ask.** Speak tile, Ask chat, history, emergency check, disclaimer.
8. **Notifications.** Feed, nap, medicine, weekly digest.
9. **Widget + Live Activity.** Glance widget, timer Live Activity, deep links.
10. **Settings / profile.** Profile tab, clothing helper.
11. **Polish / accessibility / dark mode.** Dynamic Type, VoiceOver labels, dark palette,
    dock collapse, haptics, empty states.

---

## 4. Parity checklist

Legend:

- `[x]` means the code is written and, where it is pure logic, verified by `swift test` on Linux.
- `[~]` means the code is written but **unverified on iOS** (no Xcode in this environment).
- `[ ]` means not started.

### Foundation

- [x] XcodeGen `project.yml` (app, widgets, tests), bundle IDs, app group, URL scheme (generates cleanly)
- [~] xcconfig-based `CLERK_PUBLISHABLE_KEY` / `CONVEX_URL` (secrets gitignored)
- [~] Info.plist: mic string, Live Activities, forced light, fonts (photo / camera strings dropped until image logging exists)
- [~] Fonts bundled (Fredoka, Nunito) + OFL licence
- [~] App icon from `assets/icon.png`
- [x] `ConvexValue` encoding (Double-only numbers, nil keys omitted)
- [x] Typed API builders for all 35 client-used functions
- [x] Codable models for every query result
- [~] `ConvexService` (subscribe / mutation / action) + `Live<T>` observable
- [~] Clerk `convex` template auth provider + `users:store`
- [~] Sign-in screen + missing-config screen

### Logic (ported with tests)

- [x] dayRhythm (`recommendedDay`, `nextSleepCountdown`, `dayBarOffset`)
- [x] sleepOffer (`daytimeWakeGaps`, `personalWakeGap`, `predictedNapAt`, `predictedNapLabel`)
- [x] sleepGoals (sleep range, feed / nappy counts)
- [x] clothingAdvice
- [x] feedWindows
- [x] format (age, weight, height, relative, DOB)
- [x] eventCopy
- [x] weekGrid
- [x] loggedAt
- [x] growth LMS + WHO tables
- [x] timer maths (`formatTimerClock`, elapsed, Live Activity props, minutes rounding)
- [x] reminder plans (feed / nap / medicine / digest copy and timing)
- [x] glance widget payload
- [x] home copy (countdown, hours, last strips)
- [x] Ask emergency check + markdown blocks
- [x] invite code sanitising
- [x] pattern bucketing

### Screens

- [~] Home tab
- [~] Timeline (list + week)
- [~] Kids tab + join partner
- [~] Profile tab
- [~] Add-log sheet (11 tiles + Speak)
- [~] Baby home
- [~] New baby (with consent)
- [~] Edit baby
- [~] Feed timer + manual
- [~] Sleep timer + manual
- [~] Tummy timer + manual
- [~] Pump timer + manual
- [~] Nappy, Potty
- [~] Medicine (+ reminder)
- [~] Activity
- [~] Custom event
- [~] Weight + growth chart
- [~] Height + growth chart
- [~] Clothing / TOG
- [~] Sleep / feed / nappy / tummy patterns
- [~] Ask + history

### Platform

- [~] Glance widget (small + medium)
- [~] Timer Live Activity (lock screen + Dynamic Island)
- [~] Deep link `babysteps://baby/{id}/{kind}/timer`
- [~] Feed reminders (+ sleep-timer suppression)
- [~] Nap reminders
- [~] Medicine reminders
- [~] Weekly digest
- [~] Voice logging

### Polish

- [~] Dark palette (ported; app forced light like RN)
- [~] VoiceOver labels on icon-only buttons, rings and charts
- [~] Dynamic Type (fonts scale relative to body)
- [ ] Dock collapse on scroll
- [~] App unit tests for deep-link routing (`ScrunchTests`)
- [ ] Snapshot / UI tests on device

---

## 5. Verification status

| What | How | Status |
| --- | --- | --- |
| `ScrunchCore` builds | `swift build` on Linux (Swift 6.x) | Verified |
| `ScrunchCore` tests | `swift test` on Linux | Verified |
| App / widget / app-test Swift syntax | `swiftc -parse` on every file | Verified (syntax only; not type-checked) |
| App unit tests (`ScrunchTests`: deep links, routing) | Xcode | **Not verified** |
| App / widget type-check, link, run | Xcode 16+ / iOS 17 simulator | **Not verified**: no Xcode on Linux |
| XcodeGen spec generates a project | `xcodegen generate` (XcodeGen built from source on Linux) | Verified |
| Clerk sign-in, Convex auth round-trip | Device / simulator | **Not verified** |
| Widget, Live Activity, notifications, mic | Device | **Not verified** |

---

## 6. Open questions for Nick

1. **Auth token**: keep the `convex` JWT template provider (zero config change), or
   activate Clerk's Convex integration and switch to the official `ClerkConvexAuthProvider`?
2. **In-flight state on upgrade**: the RN app keeps the running timer and active baby in
   AsyncStorage, which the native app can't read. Anyone mid-timer when the update lands
   loses that timer, and the app re-selects the first baby. Acceptable?
3. **Apple Developer setup**: the widget target was generated by expo-widgets. Please
   confirm the provisioning profiles for `com.nickmcblain.babysteps.widgets` and the app
   group carry over, and add the Team ID to `Config/Secrets.xcconfig`.
4. **Dock collapse on scroll**: worth porting, or is a fixed floating dock fine?
5. **Dark mode**: RN forces light. Keep forcing light, or follow the system now that the
   dark palette is native?
6. **Image logging** (`voiceLog:logFromImage`) exists on the backend and RN ships photo /
   camera permission strings, but the RN client never calls it. The native app drops those
   strings for now. Add the feature?
7. **Build number**: the App Store needs `CURRENT_PROJECT_VERSION` above the last EAS build
   number. Set it in `Config/Secrets.xcconfig` (or `Shared.xcconfig`) before archiving.
8. **Small behaviour differences** (listed in section 1, "Deliberate deviations"): OK?
