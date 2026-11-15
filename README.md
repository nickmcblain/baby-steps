# Scrunch

iOS-first Expo app for logging feeds and nappies, plus a room-temperature clothing helper. Syncs with Convex so both parents share one timeline.

## Look

Light, bubbly, high-radius cards. Teal pills, 2×2 action tiles, soft shadows — closer to a friendly lifestyle app than a medical dashboard.

## Tooling

Use **Bun** for installs and scripts (`bun install`, `bun run …`, `bunx …`).

Expo’s Metro bundler still runs on Node under the hood. That is expected. Do not swap Metro for Bun’s bundler.

| Task | Command |
| --- | --- |
| Install | `bun install` |
| App | `bun start` |
| Convex | `bun run convex` |
| iOS native build | `bun run ios:run` |
| Types | `bun run typecheck` |

EAS picks Bun automatically from `bun.lock`.

## Setup

1. Copy `.env.example` to `.env`.
2. Create a [Clerk](https://clerk.com) application. Enable email. Create a JWT template named `convex`.
3. Create a [Convex](https://convex.dev) project:
   ```bash
   bunx convex dev
   ```
   Set Convex env `CLERK_JWT_ISSUER_DOMAIN` to your Clerk Frontend API URL (e.g. `https://your-app.clerk.accounts.dev`).
4. Put `EXPO_PUBLIC_CLERK_PUBLISHABLE_KEY` and `EXPO_PUBLIC_CONVEX_URL` in `.env`.

Clerk’s native `AuthView` needs a development build, not Expo Go.

```bash
bun install
bun start
bun run ios:run
```

## Native tests

Run from `ios-native/`:

```bash
(cd Packages/ScrunchCore && swift test)
xcodebuild -project Scrunch.xcodeproj -scheme Scrunch -destination "id=$SIM" test CODE_SIGNING_ALLOWED=NO
```

Boot the simulator and let it settle before running the app tests, for example with `xcrun simctl boot $SIM && xcrun simctl bootstatus $SIM` and then a minute's wait. On a freshly created or cold simulator, the StoreKit test daemon can fail to load `StoreKit/Scrunch.storekit`. When that happens, `EntitlementsStoreKitTests`, `FreeAllowanceAppTests`, `PaywallScreenshotTests` and some `SharingTests` fail with no products or with purchase errors. Rerun on the warm simulator before treating those failures as real.
