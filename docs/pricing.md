# Scrunch pricing

Scrunch 1.0 is UK only. It is a paid app with a usage-based free start: parents learn the app for
free, then subscribe once they rely on it. One auto-renewing subscription, sold through StoreKit 2.
Prices are set in App Store Connect and read from StoreKit at runtime; the app never hard-codes them.

| Plan | Product id | Price |
| --- | --- | --- |
| Monthly | `com.nickmcblain.babysteps.monthly` | about £2.99 |

Monthly only for launch: there is no yearly plan. Nothing in the code depends on the price; the local
StoreKit file uses a placeholder for testing only. The product sits in one subscription group,
**Scrunch**. There is no introductory free trial: the free entries are the trial.

## The rule

Each carer gets **5 free entries of each log type on each baby**. Sleep has no limit.

| Allowance | What counts |
| --- | --- |
| feeds | breast and bottle feeds (formula or expressed) together |
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
- **Sleep is free for good**: sleep logs, sleep timers, the sleep Live Activity and the sleep
  patterns chart.
- **Per carer, per baby.** Each carer has their own count on each baby, and their own subscription.
  A partner's subscription doesn't unlock anything for you: a baby shared between two parents needs
  two subscriptions for both to log past the free entries.
- **Entries ever created.** Deleting a log doesn't give it back. Moving a fresh log's time with the
  "−5 min" chip edits it in place and doesn't count again. The birth weight and height saved when a
  baby is added don't count.
- **Ask and the feed, tummy time and nappy pattern charts** are open during the free entries. Once
  any free allowance has run out, they need the subscription. Ask is also checked on the server
  (`chatAgent:ask`). The sleep patterns chart and the Home insight cards are never locked.
- **Your data is never held hostage.** Everything already logged stays visible on the timeline, home,
  growth charts and baby pages whether or not they subscribe. The paywall promises only that past
  logs stay readable; export will come in its own change.

The rule lives in one place on each side, and both have tests for the same cases:

- `FreeAllowance` in `ios-native/Packages/ScrunchCore/Sources/ScrunchCore/FreeAllowance.swift`
- `convex/lib/allowance.ts`

## Sharing needs a subscription

Each carer needs their own Scrunch subscription to share a baby. Convex enforces it
(`convex/lib/sharing.ts`):

- **Creating a share code** (`babies:createInvite`) needs an active subscription. Codes are made on
  first use, and `babies:list` and `babies:get` only send a baby's code to carers who are subscribed.
- **Redeeming a code** (`babies:joinByCode`) needs the joining carer's own subscription. Without one,
  Convex refuses before looking the code up, so it doesn't reveal whether a code exists. In the app,
  the join sheet opens the paywall over itself, keeps the code they typed, and finishes the join by
  itself after a purchase. Closing the paywall leaves the code there with a "Subscribe and join" button.
- **Sleep stays free for every carer**, but they can't join a shared baby without subscribing.
- **If a carer's subscription lapses**, they stay on the baby: they can still read everything, see
  past logs and log sleep. Non-sleep logging past their own free entries shows the paywall, and they
  can no longer see or create the share code. Rejoining a baby they're already on isn't blocked.

The sharing copy ("Each carer needs their own Scrunch subscription to share a baby.") is in the app's
String Catalog (`ios-native/Scrunch/Resources/Localizable.xcstrings`) and appears on the Kids screen,
the join sheet and the paywall.

## Gentle hint, no nagging

Once three or fewer free entries of a type are left, the app shows one quiet toast, for example
"3 of 5 free feeds left. Sleep is always free.", **at most once per type**, after the "Saved" toast
has gone. Nothing else counts down, flashes or interrupts. The paywall is never shown at sign-up,
onboarding or on launch.

## Where the limit is enforced

Convex is the source of truth. Every log goes through the insert helpers in `convex/lib/logEvents.ts`,
which call `chargeAllowance` before inserting: it counts the entry in the `logAllowances` table
(per carer, baby and type), or throws `ConvexError({ code: "FREE_LIMIT_REACHED", type })` once that
carer's 5 are used and they don't subscribe.
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
still has the final say: if a queued log is refused when it is sent (for example, the subscription
lapsed while this phone was offline), it moves to the held list instead of being dropped, and
the paywall shows. Logs typed in the app's forms need a connection, as before.

## The paywall

Apple's `SubscriptionStoreView`, so StoreKit shows the prices, billing periods and renewal terms. It
has a close button, Restore purchases, a Terms of Use link and StoreKit's Privacy Policy link. Our
copy says what they hit ("You've used your 5 free nappies"), that subscribing saves this entry straight
away, what the subscription includes, that sleep (including sleep patterns) stays free and past logs stay readable, and that it
renews automatically unless cancelled at least 24 hours before the end of the period. Closing it
leaves sleep logging working and every existing log viewable.

## Profile

The Subscription row shows either the plan and its state ("Renews on Thursday 3 December",
"Ends on …") or this carer's free entries left on the active baby,
plus **Manage subscription** (`manageSubscriptionsSheet`) and **Restore purchases** (`AppStore.sync()`).

## Family Sharing: off

Entitlement is per carer, so Family Sharing stays **off** for the monthly product (it's off in the
local StoreKit file too). Once turned on in App Store Connect it can't be turned off. As a backstop,
Convex never applies a family-shared transaction, and the app ignores them.

## How entitlements work

- **On the device**, StoreKit 2: `Transaction.currentEntitlements` at launch and a
  `Transaction.updates` listener (`ios-native/Scrunch/Services/Entitlements.swift`).
- **On the server**, a `subscriptions` row per user (Clerk user) with a stable UUID passed to
  StoreKit as `appAccountToken`. A transaction unlocks only the account it was bought for: Convex
  refuses one carrying another account's token, or one another account has already claimed
  (`mayClaim` in `convex/lib/appStore.ts`). On the device, a transaction bought for a different
  Scrunch account on the same Apple ID doesn't count either.
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
- `bun run test:convex`: Convex typecheck, the shared rule, the per-carer counter (limit, sleep,
  each carer's own five, a subscription covering only its owner, expiry), sharing (creating and
  redeeming codes with and without a subscription, a lapsed carer), transaction ownership and the
  App Store status mapping.
- ScrunchCore: `FreeAllowanceTests` (the rule, hint, mirrored allowance, refusals) and
  `SubscriptionTests`.
- App: `FreeAllowanceAppTests` (forms, voice, Siri intents, widget taps, held logs, Ask and patterns,
  the hint), `SharingTests` (join and invite paywalls, joining after purchase with the same code,
  per-account entitlement, Family Sharing off, the String Catalog copy), `EntitlementsStoreKitTests`
  (SKTestSession purchase, restore, cancel, expiry, refund) and `PaywallScreenshotTests`.
- DEBUG builds accept `-debugPaywall YES` to open the paywall for screenshots.

## Checklist for App Store Connect (Nick)

1. Accept the **Paid Apps agreement** and add banking and tax details.
2. Create one subscription group, **Scrunch**, with one product, `com.nickmcblain.babysteps.monthly`
   (1 month, about £2.99), **no introductory offer**,
   **Family Sharing off**, United Kingdom only, en-GB names and descriptions, and a review screenshot
   (`-debugPaywall YES`). Review notes should explain the 5 free entries per type for each carer, that sleep is free,
   and that each carer needs their own subscription to share a baby.
3. App Information > **App Store Server Notifications**: Production and Sandbox URLs
   `https://<deployment>.convex.site/appstore/notifications`, Version 2. Send a test notification.
4. Convex environment variable **`APPLE_APP_APPLE_ID`** on production.
5. A **privacy policy URL** in App Store Connect (StoreKit's paywall links to it).
6. Test with a Sandbox Apple ID on TestFlight before submitting.
