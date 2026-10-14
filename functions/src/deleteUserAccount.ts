import "./admin";
import { getAuth } from "firebase-admin/auth";
import { getFirestore, FieldValue, type BulkWriter } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import { FUNCTION_REGION } from "./config";
import { isRecentAuth, removeMemberFromGroup } from "./helpers";

/**
 * Account deletion. Policy is documented in functions/README.md.
 * Safe to retry: every step is idempotent and the Auth user is deleted last.
 */
export const deleteUserAccount = onCall(
  { region: FUNCTION_REGION, timeoutSeconds: 540, memory: "512MiB" },
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Sign-in required");
    const uid = request.auth.uid;
    if (!isRecentAuth(request.auth.token.auth_time, Date.now())) {
      throw new HttpsError("failed-precondition", "reauthentication-required");
    }

    const db = getFirestore();
    const bucket = getStorage().bucket();
    const bw = db.bulkWriter();
    bw.onWriteError((err) => err.failedAttempts < 5); // retry transient failures

    // 1. Conversations the user belongs to.
    const convs = await db.collection("conversations").where("memberIds", "array-contains", uid).get();
    for (const conv of convs.docs) {
      await removeFromConversation(db, bw, bucket, conv.ref, uid);
    }
    await bw.flush();

    // 1b. Join requests the user filed in any group, and their invites (deactivated).
    for (const jr of (await db.collectionGroup("joinRequests").where("uid", "==", uid).get()).docs) {
      void bw.delete(jr.ref);
    }
    for (const inv of (await db.collection("groupInvites").where("createdBy", "==", uid).get()).docs) {
      void bw.update(inv.ref, { active: false });
    }
    await bw.flush();

    // 2. users/{uid}/** (settings, devices, blocks, ...)
    await db.recursiveDelete(db.doc(`users/${uid}`), bw);

    // 3. public profile + username reservation
    const profileRef = db.doc(`publicProfiles/${uid}`);
    const profile = await profileRef.get();
    const usernameLower = profile.data()?.usernameLower;
    if (typeof usernameLower === "string" && usernameLower) {
      const idxRef = db.doc(`usernameIndex/${usernameLower}`);
      const idx = await idxRef.get();
      if (idx.exists && idx.data()?.uid === uid) void bw.delete(idxRef);
    }
    if (profile.exists) void bw.delete(profileRef);
    await bw.close();

    // 4. avatars
    await bucket.deleteFiles({ prefix: `avatars/${uid}/`, force: true });

    // 5. Sign in with Apple token revocation (stub, see below)
    await revokeAppleSignInTokens(uid);

    // 6. Auth account last, so a failed run can be retried.
    try {
      await getAuth().deleteUser(uid);
    } catch (e) {
      if ((e as { code?: string }).code !== "auth/user-not-found") throw e;
    }
    logger.info("account deleted", { uid });
    return { deleted: true };
  }
);

async function removeFromConversation(
  db: FirebaseFirestore.Firestore,
  bw: BulkWriter,
  bucket: ReturnType<ReturnType<typeof getStorage>["bucket"]>,
  convRef: FirebaseFirestore.DocumentReference,
  uid: string
): Promise<void> {
  const cid = convRef.id;
  const messages = convRef.collection("messages");

  // Reactions the user left on anyone's messages (ids only; no data reads).
  for (const m of await messages.listDocuments()) {
    void bw.delete(m.collection("reactions").doc(uid));
  }

  // Messages authored by the user are deleted (with their reactions subcollections).
  const authored = await messages.where("senderId", "==", uid).get();
  for (const m of authored.docs) await db.recursiveDelete(m.ref, bw);

  // The user's member doc (+ hidden/ subcollection).
  await db.recursiveDelete(convRef.collection("members").doc(uid), bw);
  void bw.delete(convRef.collection("receipts").doc(uid));
  void bw.delete(convRef.collection("typing").doc(uid));
  void bw.delete(convRef.collection("joinRequests").doc(uid));

  // Media uploaded by the user in this conversation.
  await bucket.deleteFiles({ prefix: `chatMedia/${cid}/${uid}/`, force: true });
  await bw.flush();

  // Re-derive the summary if it pointed at a deleted message.
  const conv = (await convRef.get()).data() ?? {};
  const update: Record<string, unknown> = { deletedAccounts: FieldValue.arrayUnion(uid) };
  const isGroup = conv.type === "group";
  if (isGroup) {
    const next = removeMemberFromGroup(conv.memberIds, conv.adminIds, uid);
    update.memberIds = next.memberIds;
    update.adminIds = next.adminIds;
  }
  if (conv.lastSenderId === uid) {
    // System (group event) messages are never the summary.
    const latest = await messages.orderBy("createdAt", "desc").limit(10).get();
    const l = latest.docs.find((d) => d.data().type !== "system");
    update.lastMessageId = l ? l.id : null;
    update.lastMessageAt = l ? l.data().createdAt : null;
    update.lastMessagePreview = l ? (l.data().type === "image" ? "Photo" : String(l.data().text ?? "").slice(0, 80)) : null;
    update.lastSenderId = l ? l.data().senderId : null;
  }
  await convRef.update(update);

  // Both participants gone: remove the whole conversation and its media.
  const after = (await convRef.get()).data();
  const members: string[] = after?.memberIds ?? [];
  const gone: string[] = after?.deletedAccounts ?? [];
  const allGone = isGroup ? members.length === 0 : members.length > 0 && members.every((m) => gone.includes(m));
  if (allGone) {
    await db.recursiveDelete(convRef, bw);
    await bucket.deleteFiles({ prefix: `chatMedia/${cid}/`, force: true });
  }
}

/**
 * TODO(apple): Sign in with Apple token revocation. NOT IMPLEMENTED.
 *
 * App Store guideline 5.1.1(v) requires revoking the Apple refresh token when an account
 * that signed in with Apple is deleted. To implement, here:
 *   1. Store Apple credentials as secrets (defineSecret): APPLE_TEAM_ID, APPLE_KEY_ID,
 *      APPLE_SERVICES_ID/bundle id, APPLE_PRIVATE_KEY (.p8), and declare them in the
 *      onCall options `secrets: [...]`.
 *   2. Have the client pass the Apple authorization code (or persist the refresh token
 *      server-side at sign-in time).
 *   3. Build an ES256 client_secret JWT, exchange the code at
 *      https://appleid.apple.com/auth/token, then POST the refresh_token to
 *      https://appleid.apple.com/auth/revoke.
 * Currently this only logs so the gap is visible.
 */
async function revokeAppleSignInTokens(uid: string): Promise<void> {
  try {
    const user = await getAuth().getUser(uid);
    if (user.providerData.some((p) => p.providerId === "apple.com")) {
      logger.warn("Apple token revocation NOT implemented (TODO); Apple-linked account deleted without revocation", { uid });
    }
  } catch (e) {
    if ((e as { code?: string }).code !== "auth/user-not-found") throw e;
  }
}
