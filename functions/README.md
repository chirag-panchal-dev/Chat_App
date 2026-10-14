# Hushlo Cloud Functions

TypeScript, Node 20, firebase-functions v2, firebase-admin.

## Configuration
- `FUNCTION_REGION` (string param, default `us-central1`). Set via `functions/.env.<projectId>` (e.g. `FUNCTION_REGION=europe-west1`). Must be compatible with your Firestore location.
- Android push channel id the app must create: `messages`.

## Functions
- `onMessageCreated` - on `conversations/{cid}/messages/{mid}` create: validates sender membership, updates the conversation summary only if the message is newer, then pushes to the other member. Skips when the recipient blocked the sender, muted the chat (`members/{uid}.mutedUntil` in the future), disabled notifications, or left the conversation. Preview text is sent only if `showMessagePreview == true` (default false); otherwise body is "New message". FCM `data` never contains message text. Idempotency: marker doc `functionMarkers/onMessageCreated_{eventId}` (push is at-most-once). Add a Firestore TTL policy on `functionMarkers.expireAt`. Invalid tokens are deleted.
- `deleteUserAccount` (callable) - requires auth and `auth_time` within 5 minutes, else `HttpsError('failed-precondition', 'reauthentication-required')`.
- `cleanupOrphanedMedia` - daily; scans at most 500 `chatMedia/` objects per run (resuming via a cursor in `functionMarkers/cleanupOrphanedMedia`), deletes those older than 48h not referenced by any message `mediaPath`/`thumbnailPath` (collection-group indexes in `firestore.indexes.json`).

## Account deletion policy
1. For each conversation the user is a member of: delete messages authored by the user (and their reactions), the user's reactions on other messages, the user's `members/{uid}` doc (and `hidden/`), and files under `chatMedia/{cid}/{uid}/`. Messages authored by the *other* participant are kept. The conversation gets `deletedAccounts: arrayUnion(uid)` so the app renders "Deleted account", and its summary is recomputed if it pointed at a deleted message. If both participants are deleted, the whole conversation and its media are removed.
1b. **Groups** (`type: 'group'`): the same cleanup runs per group (authored messages incl. system messages, reactions, `members/receipts/typing/joinRequests` docs, `chatMedia/{gid}/{uid}/`), and additionally the uid is removed from `memberIds` and `adminIds` (if no admin remains, the first remaining uid in `memberIds` order is promoted) and added to `deletedAccounts`. If no members remain the whole group (and its media) is deleted. `groupAvatars/` is never touched by deletion or by `cleanupOrphanedMedia` (only `chatMedia/` is scanned). Join requests the user filed in other groups are deleted (collection-group query on `joinRequests.uid`, see `firestore.indexes.json`), and `groupInvites` they created are kept but set `active: false`.
2. Delete `users/{uid}/**` (settings, devices, blocks), `publicProfiles/{uid}`, `usernameIndex/{usernameLower}`, and `avatars/{uid}/`.
3. Delete the Auth user last (so a failed run can be retried).
Not deleted: `reports` (retained for moderation/legal reasons), other users' block entries pointing at the deleted uid.
**TODO - Sign in with Apple token revocation** is NOT implemented. See `revokeAppleSignInTokens` in `src/deleteUserAccount.ts` (needs Apple key credentials as secrets).

## Tests
`npm test` builds, runs unit tests (vitest, no network), then rules tests under `firebase emulators:exec --only firestore,storage` (Java required; emulator jars download on first run).
Note: `test:rules` uses `$npm_node_execpath` because the standalone `firebase` binary shadows `node` inside `emulators:exec`; run it through `npm run`.
