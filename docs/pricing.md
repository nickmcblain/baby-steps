# Scrunch pricing

Scrunch 1.0 is UK only. It is a paid app with a usage-based free start: parents learn the app for
free, then subscribe once they rely on it. One auto-renewing subscription, sold through StoreKit 2.
Prices are set in App Store Connect and read from StoreKit at runtime; the app never hard-codes them.

| Plan | Product id | Price |
| --- | --- | --- |
| Monthly | `com.nickmcblain.babysteps.plus.monthly` | about £2.99 |
| Yearly | `com.nickmcblain.babysteps.plus.annual` | £19.99 or £24.99 (Nick to choose) |

Both sit at the same level in one subscription group, so switching is a crossgrade. There is no
introductory free trial: the free entries are the trial.

## The rule

Every baby gets **5 free entries of each log type**. Sleep has no limit.

| Allowance | What counts |
| --- | --- |
| feeds | breast feeds |
| bottles | bottle feeds (formula or expressed) |
| nappies | nappies |
| pumping sessions | pumps |
| growth entries | weights and heights |
| tummy times | tummy time |
| potty trips | potty |
| medicine doses | medicine |
| activities | activities |
| notes | custom events and appointments |

- **Saving the 6th entry of a type shows the paywall.** The entry is not saved unless they subscribe.
  What they typed is kept: after a successful purchase the same save runs straight away; if they close
  the paywall, the form is still there as they left it.
- **Sleep is free for good**: sleep logs, sleep timers and the sleep Live Activity.
- **Per baby, shared with carers.** The count belongs to the baby, so partners share one allowance,
  and a subscription from anyone the baby is shared with unlocks logging for all of them.
- **Entries ever created.** Deleting a log doesn't give it back. Moving a fresh log's time with the
  "−5 min" chip edits it in place and doesn't count again. The birth weight and height saved when a
  baby is added don't count.
- **Ask and the pattern charts** are open during the free entries. Once any free allowance has run out,
  they need the subscription. Ask is also checked on the server (`chatAgent:ask`).
- **Your data is never held hostage.** Everything already logged stays visible on the timeline, home,
  growth charts and baby pages whether or not they subscribe, and nothing here blocks reading or
  exporting it.

The rule lives in one place on each side, and both have tests for the same cases:

- `FreeAllowance` in `ios-native/Packages/ScrunchCore/Sources/ScrunchCore/FreeAllowance.swift`
- `convex/lib/allowance.ts`

## Gentle hint, no nagging

Once three or fewer free entries of a type are left, the app shows one quiet toast, for example
"3 of 5 free feeds left. Sleep is always free.", **at most once per type**, after the "Saved" toast
has gone. Nothing else counts down, flashes or interrupts. The paywall is never shown at sign-up,
onboarding or on launch.

## Where the limit is enforced

Convex is the source of truth. Every log goes through the insert helpers in `convex/lib/logEvents.ts`,
which call `chargeAllowance` before inserting: it counts the entry in the `logAllowances` table, or
throws `ConvexError({ code: "FREE_LIMIT_REACHED", type })` once the 5 are used and no carer subscribes.
That covers every `events:log*` mutation and voice and text logging (`voiceLog:*`, through
`voiceTools`).

The app applies the same rule up front so it can show the paywall before sending:

| Entry point | What happens past the allowance |
| --- | --- |
| Add-log forms, timers' save screens, growth, quick nappy on Home | `LogGate.save` shows the paywall and waits. Purchase: saves. Close: nothing saved, form unchanged. |
| Voice logging ("Speak") | The type isn't known until Convex reads the clip, so the server refuses, the paywall shows, and after purchase the same clip is sent again. |
| Siri and Shortcuts log intents, "Log from a description" | The log is held (not dropped), Siri says the free entries are used, and Scrunch opens to the paywall. |
| Home Screen and Lock Screen quick-log widget | Taps on locked buttons open Scrunch to the paywall. If a tap still gets through (stale widget), the log is held and the paywall shows when Scrunch opens. |
| Live Activity "Stop" and Control Centre | Starting a timer is free. Stopping a feed, pump or tummy timer past the allowance holds the log; the paywall shows when Scrunch opens. Sleep is never held. |

Held logs wait in the app group (`held-logs-v1`). The paywall says how many are waiting; subscribing
sends them, and Profile shows them with a "Discard waiting entries" button.

### Offline and queued logs

Logs from Siri, widgets and the Live Activity are queued on the device and sent when Scrunch is next
online. The app keeps a copy of each baby's allowance in the app group (`shared-allowance-v1`) so those
entry points can apply the rule without a connection, counting each queued log as it goes. The server
still has the final say: if a queued log is refused when it is sent (for example, a partner used the
last free nappy while this phone was offline), it moves to the held list instead of being dropped, and
the paywall shows. Logs typed in the app's forms need a connection, as before.

## The paywall

Apple's `SubscriptionStoreView`, so StoreKit shows the prices, billing periods and renewal terms. It
has a close button, Restore purchases, a Terms of Use link and StoreKit's Privacy Policy link. Our
copy says what they hit ("You've used your 5 free nappies"), that subscribing saves this entry straight
away, what the subscription includes, that sleep stays free and their logs stay theirs, and that it
renews automatically unless cancelled at least 24 hours before the end of the period. Closing it
leaves sleep logging working and every existing log viewable.

## Profile

The Subscription row shows either the plan and its state ("Renews on Thursday 3 December",
"Ends on …", "Shared with you through Family Sharing") or the free entries left for the active baby,
plus **Manage subscription** (`manageSubscriptionsSheet`) and **Restore purchases** (`AppStore.sync()`).

## Family Sharing: recommended on

Both parents usually log the same baby. Convex already unlocks a baby for every carer when one of them
subscribes, and Family Sharing covers the rest of an Apple family's devices. Turn it on for both
products in App Store Connect; it can't be turned off later.

## How entitlements work

- **On the device**, StoreKit 2: `Transaction.currentEntitlements` at launch and a
  `Transaction.updates` listener (`ios-native/Scrunch/Services/Entitlements.swift`).
- **On the server**, a `subscriptions` row per user with a stable UUID passed to StoreKit as
  `appAccountToken`.
  - `appStore:syncTransaction`: the app sends each verified transaction's JWS; Convex verifies Apple's
    signature and chain (Apple Root CA G3) with `@apple/app-store-server-library`.
  - `POST /appstore/notifications`: App Store Server Notifications V2 for renewals, expiry, billing
    retry, grace period, refunds and revocations.
  - An `active` row whose expiry passed more than a day ago without a renewal stops counting, in case
    a notification is missed.
- If Convex refuses a log that StoreKit says is paid for, the app re-sends its transactions and tries
  once more.

## Testing

- `ios-native/StoreKit/Scrunch.storekit` mirrors the products (UK storefront, placeholder prices, no
  trial). The Scrunch scheme's Run action uses it.
- Local StoreKit transactions are not signed by Apple. To test the full purchase-then-save flow
  against a **development** Convex deployment, set `APPSTORE_ACCEPT_XCODE=true` there. Never set it in
  production.
- `bun run test:convex`: Convex typecheck, the shared rule, the per-baby counter (limit, sleep,
  partner sharing, a carer's subscription, expiry) and the App Store status mapping.
- ScrunchCore: `FreeAllowanceTests` (the rule, hint, mirrored allowance, refusals) and
  `SubscriptionTests`.
- App: `FreeAllowanceAppTests` (forms, voice, Siri intents, widget taps, held logs, Ask and patterns,
  the hint), `EntitlementsStoreKitTests` (SKTestSession purchase, restore, cancel, expiry, refund) and
  `PaywallScreenshotTests`.
- DEBUG builds accept `-debugPaywall YES` to open the paywall for screenshots.

## Checklist for App Store Connect (Nick)

1. Accept the **Paid Apps agreement** and add banking and tax details.
2. Create one subscription group, **Scrunch**, with `…plus.monthly` (1 month, about £2.99) and
   `…plus.annual` (1 year, £19.99 or £24.99), both at the same level, **no introductory offer**,
   Family Sharing on, United Kingdom only, en-GB names and descriptions, and a review screenshot
   (`-debugPaywall YES`). Review notes should explain the 5 free entries per type and that sleep is free.
3. App Information > **App Store Server Notifications**: Production and Sandbox URLs
   `https://<deployment>.convex.site/appstore/notifications`, Version 2. Send a test notification.
4. Convex environment variable **`APPLE_APP_APPLE_ID`** on production.
5. A **privacy policy URL** in App Store Connect (StoreKit's paywall links to it).
6. Test with a Sandbox Apple ID on TestFlight before submitting.
