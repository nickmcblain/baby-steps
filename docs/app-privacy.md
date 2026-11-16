# App Privacy answers (draft)

Draft answers for App Store Connect › App Privacy for the native iOS app (`ios-native/`). Check them again whenever an SDK, a Convex function that calls out to a third party, or the Ask model changes. The privacy manifests in `ios-native/Scrunch/PrivacyInfo.xcprivacy` and `ios-native/ScrunchWidgets/PrivacyInfo.xcprivacy` should agree with this page.

## What ships

| Component | Where it runs | What it handles | Privacy manifest |
| --- | --- | --- | --- |
| Clerk iOS (`ClerkKit`, `ClerkKitUI`) 1.7.x | App | Sign-in: email, name, Apple/Google account link, session list, optional profile photo | Ships its own (name, email, phone, user ID, photos, coarse location, other diagnostics; UserDefaults CA92.1) |
| ConvexMobile 0.8.x | App | Transport to our Convex deployment. Sends only what the app passes it | None shipped. It's a Rust core over WebSocket; no required-reason APIs found in its Swift layer. Check Xcode's privacy report after each upgrade |
| ScrunchCore | App and widget | Local formatting and maths. No network | Covered by the app and widget manifests |
| Convex (server) | Convex cloud (US) | Stores account, babies, logs, Ask chats and remembered facts | n/a |
| OpenRouter → Google Gemini 2.5 Flash (server) | Called from `convex/chatAgent.ts` and `convex/voiceLog.ts` | Ask questions, chat history, baby profile, recent feeds and nappies, remembered facts; Speak transcripts | n/a |
| OpenRouter → OpenAI Whisper (server) | Called from `convex/voiceLog.ts` | Speak voice recordings, for transcription only. Not stored by Scrunch | n/a |

There are no analytics, advertising, attribution or crash-reporting SDKs. Nothing is used for tracking, so the app needs no App Tracking Transparency prompt.

## Answers

**Do you or your third-party partners collect data from this app?** Yes.

**Is any data used to track users?** No. `NSPrivacyTracking` is false and there are no tracking domains.

For every type below the answers are: **Linked to the user: Yes. Used for tracking: No. Purpose: App Functionality only.**

| App Store category | Data type | What it is in Scrunch | Collected by |
| --- | --- | --- | --- |
| Contact Info | Email Address | Sign-in email, also copied to the Convex `users` table | Clerk, Convex |
| Contact Info | Name | Account name from Clerk or Sign in with Apple, copied to `users.name` | Clerk, Convex |
| Health & Fitness | Health | Baby care logs: feeds, sleeps, nappies, weight, length, medicine, pumping | Convex |
| User Content | Audio Data | Speak recordings, sent through Convex to OpenRouter/Whisper for transcription and not kept. Declared because the recording leaves the device | Convex, OpenRouter |
| User Content | Photos or Videos | Only if someone uploads a profile photo in Clerk's Sign-in and security screen | Clerk |
| User Content | Other User Content | Baby name, date of birth and notes; Ask questions and answers; facts Ask remembers; log notes | Convex, OpenRouter (Ask) |
| Identifiers | User ID | Clerk user ID and the Convex user record | Clerk, Convex |
| Location | Coarse Location | Clerk records an approximate location from the IP address for the sessions list. Scrunch never asks for location | Clerk |
| Diagnostics | Other Diagnostic Data | Declared in Clerk's manifest. Confirm with Clerk whether its SDK telemetry is sent from release builds; untick if not | Clerk |

**Not collected:** phone number (unless phone sign-in is switched on in Clerk; if it is, add Contact Info › Phone Number), precise location, contacts, browsing or search history, purchases (see below), usage data, device ID, advertising data, financial info, sensitive info, crash data, performance data.

**Purchases:** when the StoreKit paywall lands, add Purchases › Purchase History if subscription status or transactions are sent to Convex. If entitlement checks stay on the device with StoreKit 2, nothing new is collected.

## Required-reason APIs

| Target | API category | Reason | Why |
| --- | --- | --- | --- |
| App | UserDefaults | CA92.1 | Remembers the active baby, AI consent and debug launch arguments for this app only |
| App | UserDefaults | 1C8F.1 | Shares the widget snapshot and the running timer with the widget through the app group |
| Widget | UserDefaults | 1C8F.1 | Reads the widget snapshot from the app group |

No file timestamp, system boot time, disk space or active keyboard APIs are used. Export files are written to the temporary folder and removed when the share sheet closes.

## Where people control their data

- **Delete account:** Profile › Delete account. Runs `account:deleteAccount`, which deletes the user's babies (or leaves shared ones with the partner), logs, Ask chats and remembered facts, then the Clerk user. It also clears the widget, reminders, timer and AI consent on the device.
- **Export:** Profile › Export care log, as PDF or CSV through the share sheet.
- **AI:** Profile › About Ask and Speak (AI) explains the provider and what's sent. Ask and Speak each ask for agreement before first use, and agreement can be withdrawn there.
- **Privacy policy:** Profile › Privacy policy opens `PRIVACY_POLICY_URL` from `Config/Shared.xcconfig`.

## Still to do before submission

1. Choose the domain, publish the privacy policy and set `PRIVACY_POLICY_URL` and `SUPPORT_EMAIL` in `ios-native/Config/Shared.xcconfig` (both are placeholders on `babysteps.app`). Use the same URL in App Store Connect.
2. The policy should cover: who the controller is; lawful bases under UK GDPR (contract for the account; explicit consent for the baby's health data, which is special category data); the processors above and that Clerk, Convex and OpenRouter are in the US (and the transfer safeguard used, such as the UK Extension to the Data Privacy Framework or the IDTA); retention, including that deleted data is gone from Convex within minutes and from backups on Convex's schedule; that AI providers process Ask and Speak content under their own terms; how to exercise rights; and the right to complain to the ICO.
3. In OpenRouter's privacy settings, turn off providers that may train on prompts, and turn on zero data retention if the plan allows. If `OPENROUTER_MODEL` changes, update `AIDisclosure` in `ScrunchCore/Privacy.swift` and bump `consentVersion`.
