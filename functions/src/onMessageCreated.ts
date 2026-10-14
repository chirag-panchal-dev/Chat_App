import "./admin";
import { getFirestore, Timestamp, FieldValue } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import * as logger from "firebase-functions/logger";
import { ANDROID_CHANNEL_ID, FUNCTION_REGION } from "./config";
import {
  buildPushBody,
  buildPushPayload,
  buildSummaryPreview,
  isInvalidTokenErrorCode,
  isNewerThanSummary,
  pushSkipReason,
  resolveSettings,
  selectRecipient,
} from "./helpers";

/**
 * Trigger: conversations/{cid}/messages/{mid} created.
 *  1. Validates conversation + sender membership (never trusts the client).
 *  2. Updates the conversation summary if the message is newer (idempotent, order-safe).
 *  3. Sends a push to the other member, guarded by a functionMarkers/{eventId} marker
 *     so retried/duplicate deliveries don't double-notify (at-most-once push).
 */
export const onMessageCreated = onDocumentCreated(
  { document: "conversations/{cid}/messages/{mid}", region: FUNCTION_REGION },
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const { cid, mid } = event.params;
    const msg = snap.data();
    const db = getFirestore();

    const convRef = db.doc(`conversations/${cid}`);
    const convSnap = await convRef.get();
    if (!convSnap.exists) {
      logger.warn("conversation missing", { cid, mid });
      return;
    }
    const conv = convSnap.data()!;
    const senderId = msg.senderId;
    if (typeof senderId !== "string") return;
    const recipientId = selectRecipient(conv.memberIds, senderId);
    if (!recipientId) {
      logger.warn("sender is not a member / bad memberIds", { cid, mid });
      return;
    }

    const createdAt: Timestamp =
      msg.createdAt instanceof Timestamp ? msg.createdAt : snap.createTime ?? Timestamp.now();

    // ---- 2. summary update (only if newer) ----
    await db.runTransaction(async (tx) => {
      const cur = (await tx.get(convRef)).data();
      if (!cur) return;
      const newer = isNewerThanSummary(
        createdAt.toMillis(),
        mid,
        cur.lastMessageAt instanceof Timestamp ? cur.lastMessageAt.toMillis() : null,
        cur.lastMessageId
      );
      if (!newer) return;
      tx.update(convRef, {
        lastMessageId: mid,
        lastMessageAt: createdAt,
        lastMessagePreview: buildSummaryPreview(msg),
        lastSenderId: senderId,
        updatedAt: FieldValue.serverTimestamp(),
      });
    });

    // ---- 3. idempotency marker for the push ----
    const markerRef = db.doc(`functionMarkers/onMessageCreated_${event.id}`);
    try {
      await markerRef.create({
        cid,
        mid,
        createdAt: FieldValue.serverTimestamp(),
        // Configure a Firestore TTL policy on `expireAt` to auto-clean markers.
        expireAt: Timestamp.fromMillis(Date.now() + 7 * 24 * 3600 * 1000),
      });
    } catch (e) {
      if ((e as { code?: number }).code === 6) {
        logger.info("duplicate delivery, push already handled", { eventId: event.id });
        return;
      }
      throw e;
    }

    // ---- push ----
    const [blockSnap, memberSnap, settingsSnap, devicesSnap, profileSnap] = await Promise.all([
      db.doc(`users/${recipientId}/blocks/${senderId}`).get(),
      db.doc(`conversations/${cid}/members/${recipientId}`).get(),
      db.doc(`users/${recipientId}/private/settings`).get(),
      db.collection(`users/${recipientId}/devices`).get(),
      db.doc(`publicProfiles/${senderId}`).get(),
    ]);

    const mutedUntil = memberSnap.data()?.mutedUntil;
    const reason = pushSkipReason({
      recipientBlockedSender: blockSnap.exists,
      recipientDeleted: Array.isArray(conv.deletedAccounts) && conv.deletedAccounts.includes(recipientId),
      mutedUntilMillis: mutedUntil instanceof Timestamp ? mutedUntil.toMillis() : null,
      nowMillis: Date.now(),
      settings: settingsSnap.data(),
      deviceCount: devicesSnap.size,
    });
    if (reason) {
      logger.info("push skipped", { cid, mid, reason });
      return;
    }

    const devices = devicesSnap.docs
      .map((d) => ({ ref: d.ref, token: d.data().token as unknown }))
      .filter((d): d is { ref: typeof d.ref; token: string } => typeof d.token === "string" && d.token !== "")
      .slice(0, 500);
    if (devices.length === 0) return;

    const body = buildPushBody(msg, resolveSettings(settingsSnap.data()).showMessagePreview);
    const payload = buildPushPayload({
      tokens: devices.map((d) => d.token),
      senderDisplayName: profileSnap.data()?.displayName,
      conversationId: cid,
      body,
      channelId: ANDROID_CHANNEL_ID,
    });

    const res = await getMessaging().sendEachForMulticast(payload);
    const bad: Promise<unknown>[] = [];
    res.responses.forEach((r, i) => {
      if (!r.success && isInvalidTokenErrorCode(r.error?.code)) bad.push(devices[i].ref.delete());
    });
    await Promise.all(bad);
    logger.info("push sent", { cid, mid, success: res.successCount, failure: res.failureCount, pruned: bad.length });
  }
);
