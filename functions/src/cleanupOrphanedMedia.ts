import "./admin";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";
import { onSchedule } from "firebase-functions/v2/scheduler";
import * as logger from "firebase-functions/logger";
import { FUNCTION_REGION } from "./config";
import { isOlderThan, isOrphanCleanupCandidate } from "./helpers";

const MAX_FILES_PER_RUN = 500;
const MIN_AGE_HOURS = 48;
const CURSOR_DOC = "functionMarkers/cleanupOrphanedMedia";

/**
 * Daily: scans up to MAX_FILES_PER_RUN objects under chatMedia/ (resuming from a stored
 * page-token cursor), deletes those older than 48h that no message references via
 * mediaPath / thumbnailPath (collection-group queries, see firestore.indexes.json).
 */
export const cleanupOrphanedMedia = onSchedule(
  { schedule: "every 24 hours", region: FUNCTION_REGION, timeoutSeconds: 540 },
  async () => {
    const db = getFirestore();
    const bucket = getStorage().bucket();
    const cursorRef = db.doc(CURSOR_DOC);
    const pageToken: string | undefined = (await cursorRef.get()).data()?.pageToken ?? undefined;

    const [files, nextQuery] = await bucket.getFiles({
      prefix: "chatMedia/",
      maxResults: MAX_FILES_PER_RUN,
      pageToken,
      autoPaginate: false,
    });

    let deleted = 0;
    let referenced = 0;
    for (const f of files) {
      if (!isOrphanCleanupCandidate(f.name)) continue; // never touch groupAvatars/ etc.
      if (!isOlderThan(f.metadata.timeCreated as string | undefined, Date.now(), MIN_AGE_HOURS)) continue;
      const [a, b] = await Promise.all([
        db.collectionGroup("messages").where("mediaPath", "==", f.name).limit(1).get(),
        db.collectionGroup("messages").where("thumbnailPath", "==", f.name).limit(1).get(),
      ]);
      if (!a.empty || !b.empty) {
        referenced++;
        continue;
      }
      await f.delete({ ignoreNotFound: true });
      deleted++;
    }

    const next = (nextQuery as { pageToken?: string } | null)?.pageToken ?? null;
    await cursorRef.set({ pageToken: next, updatedAt: FieldValue.serverTimestamp() });
    logger.info("cleanupOrphanedMedia done", { scanned: files.length, deleted, referenced, more: next !== null });
  }
);
