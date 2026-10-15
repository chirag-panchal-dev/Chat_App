<div align="center">

<img src="assets/branding/hushlo_mark.png" width="96" alt="Hushlo logo" />

# Hushlo

**Good conversations, less noise.**

A calm, private chat app for the people you already know — no feed, no strangers, no contact-book upload.
Built with Flutter (Android + iOS) and Firebase.

![Flutter](https://img.shields.io/badge/Flutter-3.29-02569B?logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.7-0175C2?logo=dart&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-Auth%20%C2%B7%20Firestore%20%C2%B7%20Storage%20%C2%B7%20FCM%20%C2%B7%20Functions-FFCA28?logo=firebase&logoColor=black)
![Platforms](https://img.shields.io/badge/platforms-Android%20%7C%20iOS-3DDC84)

</div>

> **Name notice:** "Hushlo" is a working codename and has **not** been trademark-cleared. Check app stores,
> domains and trademark registries before using it publicly.
>
> **Not end-to-end encrypted.** Messages are encrypted in transit and protected by Firestore/Storage access
> rules, but they are stored in the cloud and are **not** end-to-end encrypted. The app says so in its UI.

---

## Screenshots

<sub>Rendered by the in-repo design harness (`tool/screenshots/`) with sample data — light and dark.</sub>

| Light |
|---|
| ![Light theme](docs/screenshots/light.png) |

| Dark |
|---|
| ![Dark theme](docs/screenshots/dark.png) |

*Left to right: intro · chats · conversation · contact info · settings.*

---

## Features

**Accounts & discovery**
- Email/password sign-up with email verification and password reset; Google sign-in (Sign in with Apple is built and opt-in).
- Unique usernames reserved transactionally (race-safe). People are found **only by exact username** — there is no user directory.
- Optional avatar and short bio; invite a friend with a share sheet.

**Messaging**
- Real-time one-to-one chat with bounded live window + cursor pagination (no unbounded history reads).
- Optimistic sending with idempotent message IDs, offline queue, retry/remove for failed sends.
- **WhatsApp-style ticks:** ✓ sent · ✓✓ delivered · blue ✓✓ read (respects a "Read receipts" privacy switch).
- **Typing indicator** and **online / last seen** (shared "Last seen & online" privacy switch).
- Reply (swipe, or tap the quote to jump to the original), emoji reactions (tap again to remove),
  copy, multi-select, **delete for me**, **delete for everyone** (sender, 48 h), **clear chat**.
- Photos: gallery/camera, client-side compression + thumbnail, real upload progress, cancel/retry, full-screen viewer.
- Day separators, grouped bubbles, scroll position preserved while reading, "new messages" pill.

**Group chats** (up to 20 people)
- Create a group from your chats or by exact username; group name + photo; group avatar, member list and admin badges.
- **Admin-only** add/remove members, rename, change photo, promote/demote admins; the last admin can't be removed and a leaving last admin hands over automatically.
- **Invite codes with admin approval:** admins create/reset/turn off a code; people enter it under "Join with a code" and an admin approves the request.
- Sender names + avatars, system notices ("Aarav added Meera"), swipe-to-reply, reactions, delete, clear chat, leave group.
- **Per-person receipts:** ticks turn ✓✓ when *everyone* received it and blue when *everyone* read it; **Message info** lists who read / received / hasn't received it.
- "Aarav, Meera are typing…" in the header and the chat list.

**Inbox & control**
- Pin, mute, archive, search, All/Unread/Pinned filters; last message, time, unread dot and live "typing…" per row.
- Block and report (reports are write-only for clients; only a moderator process can read them).
- Notification permission asked in context; previews off by default (notifications say "New message").

**Chat themes**
- ⋯ menu → Chat theme (or the Chat theme row in contact / group info): pick Ocean, Violet, Rose, Sunset, Forest or Graphite, or go back to Default. It changes your outgoing bubble colour and the wallpaper tint, in light and dark mode, and applies instantly.
- Personal: it's stored in your own member doc (`chatTheme`, only the owner can read or write it, ids allowlisted in the rules), so each person picks their own look and nobody else sees your choice.
- Every bubble colour keeps white text at WCAG AA contrast (checked by a test). Unknown theme ids (from a newer app version) fall back to the default look.

**Documents and videos**
- The + menu offers Gallery, Camera, **Video** (from the gallery), **Record video** and **Document**.
- Documents: PDF, Word, Excel, PowerPoint, TXT, CSV and ZIP up to **25 MB** (an allowlist in the app, the Firestore rules and the Storage rules: no executables, scripts or HTML). The card shows a type badge, the file name and size; tap downloads it under its real name and opens the system share sheet ("Open in…", "Save to Files").
- Videos: MP4 / iPhone MOV up to **50 MB** and 10 minutes. The bubble is a play card (length, size) and tapping plays it full screen with scrubbing.
- While uploading, the chat already shows the final-looking card (local PDF preview / video frame, pages, size) with a progress ring and ✕ to cancel; if it fails the same card stays with a ↻ retry control and "Not sent · Retry · Remove" (retry reuses the same message id, so there are no duplicates). Photos work the same way: tapping send in the photo preview returns to the chat at once and the photo uploads there with a progress ring. Photos, videos and PDFs with a preview fill the bubble edge to edge (no padding); voice notes still use a simpler pill.
- Previews like WhatsApp: a PDF card shows an image of its first page with the name and "12 pages · 2.3 MB · PDF" below; a video shows a frame from the video with a play button and its length. They are made on the **sender's phone** (pdfx renders page 1, video_thumbnail grabs a frame), uploaded as small JPEGs, and shown to everyone, so receivers never render anything. If a preview can't be made (damaged or password-protected PDF) the file is still sent, just without it. Other documents (Word, Excel, …) show a type badge, not a page image.
- Honest limits: no video compression (big videos upload at full size), no captions, no in-app document viewer, and the new Storage limits need `firebase deploy --only storage`. Storage and egress cost money on Blaze, which is why the limits are modest.

**Voice messages**
- Hold the mic to record (slide left to cancel, slide up to lock) or tap it for hands-free recording; 1 s minimum, 5 min maximum.
- AAC (m4a) at 64 kbps; the waveform is generated while recording so bubbles render without downloading audio.
- Play/pause, tap/drag to seek, 1x / 1.5x / 2x speed, one note plays at a time. Upload progress, cancel and retry (same id, no duplicates).
- Needs microphone permission and Firebase Storage (rules enforce type, size and path). Android minSdk is 24.

**Saved messages**
- A private notes space at the top of your chat list (also under the ✏️ button): type notes to yourself, or select messages in any chat and tap the bookmark to copy their text there ("From Aarav").
- Stored at `users/{uid}/saved`, readable only by you (rules-tested); deleted with your account. Works offline. Long-press a note to copy or delete.
- Text only for now (photos/voice aren't copied), newest 500 notes are loaded, notes can't be edited.

**Quiet hours**
- Settings → Notifications → Quiet hours: pick a daily window (default 22:00–07:00, may cross midnight). Notifications still arrive but silently (no sound or vibration) on a low-importance Android channel / without an iOS sound.
- Enforced by the `onMessageCreated` Cloud Function using the window and the phone's UTC offset stored in `users/{uid}/private/settings` (refreshed each app start while enabled, so travel/daylight saving self-correct); foreground alerts follow the same rule on-device.
- Needs the Cloud Functions deploy (Blaze). Until then pushes aren't sent at all, so quiet hours has nothing to quiet. The window is evaluated per message and per person, so each user decides for themselves; mute still wins over quiet hours.

**Search in a chat**
- ⋯ menu → Search: type to find text (and photo captions) in that conversation; ↑/↓ jump between matches with "2 of 7", the current match is highlighted.
- Honest limit: Firestore has no text search, so the app searches the messages loaded on the phone and fetches older pages as you step back (up to 8 pages per step). Deleted messages, voice notes and system notices are skipped.

**Editing messages**
- Select your own text message → pencil icon → the bubble itself becomes editable in place → ✓ to save, ✕ to cancel. Allowed for 15 minutes after sending (enforced by the security rules, not just the app).
- Everyone sees an "Edited" label next to the time. Only the latest text is kept (no edit history); photos and voice notes can't be edited; deleted messages can't be revived.
- Not pushed again: a notification already delivered keeps the original text.

**Disappearing messages**
- Per chat: Off / 24 hours / 7 days / 90 days. Either person in a direct chat can change it; in groups only admins. Everyone sees a notice when it changes.
- New messages carry an `expiresAt`; the app hides them the moment they expire and a Firestore **TTL policy** on `messages.expiresAt` deletes them. TTL needs the Blaze plan, so it is *not* in `firestore.indexes.json` (that would block free-plan deploys); after enabling Blaze run `gcloud firestore fields ttls update expiresAt --collection-group=messages --enable-ttl --project=<id>` (deletion can lag by up to a day). Until then expired messages are only hidden in the app, not deleted.
- Photos/voice files are removed afterwards by the daily `cleanupOrphanedMedia` function (needs Blaze). Reactions under an expired message are not cleaned up yet.
- Honest limits: it only affects *new* messages, and nothing stops the other person from copying or screenshotting before they vanish.

**App lock**
- Optional Face ID / fingerprint / phone-passcode lock (system prompt; Hushlo never sees biometrics or the passcode).
- Choose when it locks: immediately, or after 1 / 5 / 15 minutes or 1 hour in the background; always locked on a cold start.
- "Hide app preview" covers the app in the app switcher. Turning the lock on or off requires authenticating first.
- Device-local setting (each phone decides); needs a screen lock set up on the phone.

**Trust & compliance**
- In-app account deletion (with re-auth and an anonymous "why are you leaving" reason) plus a public deletion page (`public_web/`).
- Privacy policy / terms / community guidelines **drafts** bundled in-app (`assets/legal`) — they need legal review before release.
- Strict deny-by-default Firestore and Storage security rules, covered by emulator tests.

**Design**
- Material 3 with centralised design tokens, Inter typeface, gradient avatars, generated illustrations, light/dark/system themes,
  reduced-motion support, large-text support, 48 dp tap targets, semantic labels on icon-only controls.

### Not in v1 (by design)
Voice/video *calls* (voice *messages* are supported), public groups/communities, stories/feeds, public channels, bots, payments, contact-book discovery, E2EE, web/desktop.

---

## Tech stack

| Area | Choice |
|---|---|
| App | Flutter 3.29.3 / Dart 3.7.2, Material 3 |
| State | `flutter_riverpod` 3 (Notifier view-models), no service locator |
| Navigation | `go_router` 17 (auth/verification/profile guards, notification deep links) |
| Backend (managed) | Firebase Auth, Cloud Firestore, Cloud Storage, FCM, App Check, Cloud Functions (Node 20, TypeScript) |
| Plugins pinned for Flutter 3.29 | `firebase_core 3.x`, `firebase_auth 5.x`, `cloud_firestore 5.x`, `firebase_storage 12.x`, `firebase_messaging 15.x`, `firebase_app_check 0.3.x`, `cloud_functions 5.x` |
| Other | `google_sign_in 7`, `flutter_local_notifications`, `cached_network_image`, `image_picker`, `flutter_image_compress`, `connectivity_plus`, `share_plus` |
| Tests | `flutter_test`, `mocktail`, Firebase Emulator Suite + `@firebase/rules-unit-testing`, `vitest` |

> Firebase plugin versions are intentionally pinned to the releases compatible with Flutter 3.29. Newer plugin
> majors need a newer Flutter (they reference iOS APIs introduced in later Flutter versions).

---

## Architecture

Feature-first clean architecture with unidirectional data flow. **UI never talks to Firebase directly.**

```
Widget ──event──▶ ViewModel (Riverpod Notifier) ──▶ UseCase (when policy is involved)
   ▲                                                      │
   │ immutable state                                      ▼
   └─────────────────────────── Repository interface ◀── Firebase service (data layer)
                                                            │
                                         Firestore · Auth · Storage · FCM · Functions
```

```
lib/
├── main.dart · bootstrap.dart · app.dart · firebase_options.dart (generated)
├── core/            config, errors (typed Failures), theme tokens, router, l10n, shared widgets, utils
├── l10n/            app_en.arb (+ generated AppL10n)
└── features/
    ├── auth/ · onboarding/ · profile/ · user_search/
    ├── conversations/   inbox, member prefs (pin/mute/archive/clear)
    ├── chat/            timeline, bubbles, composer, receipts, typing, reactions
    ├── attachments/     picker → compress → upload → message
    ├── notifications/   FCM tokens, foreground/tap routing
    ├── presence/        online / last seen
    ├── privacy_settings/ · safety/ (block, report) · account_deletion/
    └── <feature>/{data,domain,presentation}
functions/           Cloud Functions + Firestore/Storage rules tests
public_web/          static privacy / terms / account-deletion pages (Firebase Hosting)
tool/screenshots/    design-review screenshot harness
```

Key decisions: typed `Failure`s mapped to localized copy (raw Firebase errors are never shown); Firestore's local
cache *is* the optimistic layer (`hasPendingWrites` drives the "sending" state); deterministic direct-chat IDs
(`uidA_uidB`, sorted) so a pair can never get two chats.

---

## Getting started

### Prerequisites
- Flutter **3.29.x** (`flutter --version`) and the Android SDK / Xcode (iOS builds need macOS)
- Node.js 20 and the [Firebase CLI](https://firebase.google.com/docs/cli) (`npm i -g firebase-tools`)
- FlutterFire CLI: `dart pub global activate flutterfire_cli`
- A Firebase project (a separate project for dev and prod is recommended)

### 1. Clone and install
```bash
git clone <your-repo-url> hushlo && cd hushlo
flutter pub get
```

### 2. Choose your app IDs
The project ships with the placeholder ID **`com.example.hushlo`**, which cannot be published. Pick a reverse-domain ID
and change it in `android/app/build.gradle.kts` (`namespace`, `applicationId`), the Kotlin package of `MainActivity`,
and Xcode (Runner → Bundle Identifier). Use the **same** ID for Firebase below.

### 3. Create the Firebase project
In the [Firebase console](https://console.firebase.google.com/):
1. **Authentication** → enable **Email/Password** (and **Google** if you want it).
2. **Firestore Database** → create → **Standard edition**, database `(default)`, **production mode**, pick a region and note it.
3. **Storage** → enable (needed for photos/avatars; may require the Blaze plan).
4. **Blaze plan** + a budget alert — required for Cloud Functions (push, account deletion, orphan cleanup).

### 4. Link the app to your project
```bash
firebase login
flutterfire configure --project=<PROJECT_ID> --platforms=android,ios \
  --android-package-name=<APP_ID> --ios-bundle-id=<APP_ID> --yes
```
This generates the files that are **git-ignored on purpose** (they contain per-project API keys that GitHub's secret
scanner flags): `lib/firebase_options.dart`, `android/app/google-services.json`,
`ios/Runner/GoogleService-Info.plist`. **A fresh clone does not compile until they exist**, so run this step first.

> Just want to see the UI shell without Firebase? `cp lib/firebase_options.dart.template lib/firebase_options.dart`
> — the app then shows a "Firebase is not configured" screen. (Android additionally needs a `google-services.json`,
> so use `flutterfire configure` for a real build.)

Then point the repo at your project and deploy the rules/indexes:
```bash
echo '{"projects":{"default":"<PROJECT_ID>"}}' > .firebaserc
firebase deploy --only firestore:rules,firestore:indexes   # add ",storage" once Storage is enabled
```
Wait for the indexes to finish building (Console → Firestore → Indexes) before testing the chat list.

### 5. Run
```bash
flutter run
```

### Google sign-in setup
1. Console → Authentication → Sign-in method → **Google** → Enable.
2. **Android:** add your SHA-1 and SHA-256 (`keytool -list -v -alias androiddebugkey -keystore ~/.android/debug.keystore -storepass android`)
   under Project settings → your Android app, then re-run `flutterfire configure`.
3. **iOS:** after re-running `flutterfire configure`, copy `REVERSED_CLIENT_ID` from `GoogleService-Info.plist` into the
   `CFBundleURLSchemes` entry of `ios/Runner/Info.plist`.
4. Set `GOOGLE_SERVER_CLIENT_ID` (Web client ID from the Google provider settings) — see flags below.
5. Sign in with Apple (`--dart-define=APPLE_SIGN_IN=true`) needs a paid Apple Developer account and the capability;
   Apple requires it before App Store release whenever Google sign-in is offered.

### Build-time flags (`--dart-define`)
| Flag | Default | Purpose |
|---|---|---|
| `SOCIAL_SIGN_IN` | `true` | Show "Continue with Google" |
| `APPLE_SIGN_IN` | `false` | Show "Continue with Apple" (iOS) |
| `GOOGLE_SERVER_CLIENT_ID` | this project's Web client ID | **Override with your own** Web client ID |
| `SUPPORT_EMAIL` | *(hidden)* | Shows a Support row in Settings |
| `WEB_BASE_URL` | *(none)* | Base URL of the hosted legal/deletion pages |
| `FUNCTIONS_REGION` | `us-central1` | Must match the deployed Functions region |
| `USE_EMULATOR` / `EMULATOR_HOST` | `false` / `localhost` | Run against the Firebase Emulator Suite |

---

## Backend

| Piece | Location | Notes |
|---|---|---|
| Firestore rules | `firestore.rules` | Deny-by-default; schema validated per collection |
| Storage rules | `storage.rules` | Membership, ownership, content-type and size checks |
| Indexes | `firestore.indexes.json` | Inbox query + media cleanup |
| Cloud Functions | `functions/src` | `onMessageCreated` (summary + push), `deleteUserAccount`, `cleanupOrphanedMedia` |
| Static pages | `public_web/` | Privacy / terms / **account-deletion** pages for store listings |

```bash
cd functions && npm install && npm run build
firebase deploy --only functions          # needs the Blaze plan
firebase deploy --only hosting            # publishes public_web/
```
Set the Functions region to match Firestore (see `functions/README.md`). Account-deletion policy, push payload rules and
the Sign in with Apple token-revocation TODO are documented there.

**Without Functions:** text chat, search, receipts, typing, presence and the inbox still work (the inbox reads the latest
message directly). Push notifications, account deletion and orphan cleanup need Functions.

### Data model (summary)
| Path | Purpose |
|---|---|
| `publicProfiles/{uid}` · `usernameIndex/{name}` | Public profile; exact-lookup username reservation |
| `users/{uid}/private/settings` · `users/{uid}/devices/{id}` · `users/{uid}/blocks/{uid}` | Owner-only settings, FCM tokens, blocks |
| `presence/{uid}` | `lastActiveAt` heartbeat (readable by people you share a chat with) |
| `conversations/{uid_uid}` · `conversations/g_<id>` | Direct chat or group (members, admins, name, photo) + server-maintained summary |
| `groupInvites/{code}` · `…/joinRequests/{uid}` | Admin-created invite codes; join requests awaiting admin approval |
| `…/members/{uid}` · `…/receipts/{uid}` · `…/typing/{uid}` | Per-user prefs (pin/mute/archive/cleared), delivery/read receipts, typing signal |
| `…/messages/{id}` (+ `reactions/{uid}`) | Immutable messages (only the sender may wipe content within 48 h) |
| `reports/{id}` · `deletionFeedback/{id}` | Write-only for clients |

---

## Testing

```bash
flutter analyze
flutter test                                   # unit + widget tests (view-models, validators, receipts, bubbles, screens)

cd functions
npm install
npm test                                       # Firestore/Storage rules (emulator) + Cloud Function unit tests

# Design-review screenshots (all screens, light + dark, no Firebase needed)
SHOT_DIR=/tmp/shots flutter test tool/screenshots/screens_test.dart
```

What is **not** covered by automation: real-device push delivery, APNs, multi-device ticks/typing end-to-end,
and the Cloud Functions running in an emulator. Test those manually on two real devices before release.

---

## Release builds

```bash
flutter build apk --release
flutter build appbundle --release
flutter build ipa --release          # macOS + Xcode + signing required
```
- Create an Android upload key and a `key.properties` (both git-ignored); configure signing in `android/app/build.gradle.kts`
  (the template falls back to the debug key, which is **not** acceptable for the Play Store).
- iOS: set your Team/bundle ID, enable **Push Notifications**, upload an APNs `.p8` key to Firebase → Cloud Messaging.
- Toolchain used: AGP 8.9.1 · Gradle 8.11.1 · Kotlin 2.2.20 · compileSdk 36 · minSdk 24 · iOS 15.0.
- Before store submission: real privacy policy + Data safety / App Privacy answers, a working account-deletion URL
  (`public_web/delete-account.html`), real screenshots, and a trademark check on the name.

---

## Security & privacy notes
- No secrets in the repo: signing keys, `.p8`, service accounts and `.env*` are git-ignored. **Never commit them.**
- Client Firebase config is not a secret, but restrict your API keys in Google Cloud Console and enable **App Check**
  (Play Integrity / App Attest) before enforcing it.
- Rules are the security boundary — keep the emulator tests green when changing them.
- Logs never contain message text, emails, tokens or media URLs.
- Presence/typing/read receipts are reciprocal: turning them off hides yours **and** theirs from you.
- Online status is an approximate heartbeat (~1/min while the app is foregrounded); delivery ticks are recorded while the
  recipient's app is running.

## Cost drivers
Firestore reads/listeners (inbox rows listen to a latest-message, receipts and typing doc each), Storage + egress for
photos, Cloud Functions invocations, and FCM. Queries are bounded and images are compressed; set a Firebase budget alert.

---

## Contributing
1. Fork and create a feature branch.
2. `flutter analyze` and `flutter test` must pass; run `npm test` in `functions/` if you touch rules or functions.
3. Keep Firebase calls inside `data/` layers, add strings to `lib/l10n/app_en.arb`, and add tests for new logic.
4. Open a pull request describing the change and how you tested it.

## License
No license has been chosen yet. Until one is added (for example MIT or Apache-2.0 in a `LICENSE` file), all rights are
reserved by the author(s).

## Credits
- Typeface: [Inter](https://rsms.me/inter/) (SIL Open Font License 1.1, see `assets/fonts/Inter-LICENSE.txt`).
- App icon, illustrations and UI are original artwork generated for this project.
