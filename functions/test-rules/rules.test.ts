import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { afterAll, beforeAll, beforeEach, describe, it } from "vitest";
import {
  assertFails, assertSucceeds, initializeTestEnvironment, type RulesTestEnvironment,
} from "@firebase/rules-unit-testing";
import { doc, getDoc, getDocs, collection, setDoc, updateDoc, deleteDoc, deleteField, query, where, serverTimestamp, writeBatch, Timestamp, arrayUnion } from "firebase/firestore";
import { ref, uploadBytes, getBytes, deleteObject } from "firebase/storage";

const root = resolve(__dirname, "../..");
let env: RulesTestEnvironment;

const A = "alice", B = "bob", C = "carol";
const CID = "alice_bob";
const MID = "msg1";

beforeAll(async () => {
  env = await initializeTestEnvironment({
    projectId: "demo-hushlo",
    firestore: { rules: readFileSync(resolve(root, "firestore.rules"), "utf8"), host: "127.0.0.1", port: 8080 },
    storage: { rules: readFileSync(resolve(root, "storage.rules"), "utf8"), host: "127.0.0.1", port: 9199 },
  });
});
afterAll(async () => { await env.cleanup(); });

beforeEach(async () => {
  await env.clearFirestore();
  await env.clearStorage();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    for (const u of [A, B, C]) {
      await setDoc(doc(db, `publicProfiles/${u}`), { uid: u, username: u, usernameLower: u, displayName: u, createdAt: Timestamp.now(), updatedAt: Timestamp.now() });
    }
    await setDoc(doc(db, `conversations/${CID}`), {
      type: "direct", memberIds: [A, B], createdBy: A, createdAt: Timestamp.now(), updatedAt: Timestamp.now(),
      lastMessageId: null, lastMessageAt: null, lastMessagePreview: null, lastSenderId: null,
    });
    await setDoc(doc(db, `conversations/${CID}/messages/existing`), { clientMessageId: "existing", senderId: B, type: "text", text: "hi", createdAt: Timestamp.now() });
  });
});

const dbOf = (uid: string | null) => (uid ? env.authenticatedContext(uid) : env.unauthenticatedContext()).firestore();
const stOf = (uid: string | null) => (uid ? env.authenticatedContext(uid) : env.unauthenticatedContext()).storage();

const textMsg = (over: Record<string, unknown> = {}) => ({
  clientMessageId: MID, senderId: A, type: "text", text: "hello", createdAt: serverTimestamp(),
  editedAt: null, deletedForEveryoneAt: null, replyToMessageId: null, ...over,
});
const sendPath = (id = MID) => `conversations/${CID}/messages/${id}`;

async function block(blocker: string, target: string) {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), `users/${blocker}/blocks/${target}`), { blockedUid: target, createdAt: Timestamp.now() });
  });
}

describe("auth basics", () => {
  it("unauthenticated is denied", async () => {
    const db = dbOf(null);
    await assertFails(getDoc(doc(db, `publicProfiles/${A}`)));
    await assertFails(getDoc(doc(db, `conversations/${CID}`)));
    await assertFails(setDoc(doc(db, sendPath()), textMsg()));
  });
});

describe("conversations & messages", () => {
  it("member can read, non-member cannot", async () => {
    await assertSucceeds(getDoc(doc(dbOf(A), `conversations/${CID}`)));
    await assertSucceeds(getDoc(doc(dbOf(A), `conversations/${CID}/messages/existing`)));
    await assertFails(getDoc(doc(dbOf(C), `conversations/${CID}`)));
    await assertFails(getDoc(doc(dbOf(C), `conversations/${CID}/messages/existing`)));
  });
  it("array-contains list query works for member only", async () => {
    await assertSucceeds(getDocs(query(collection(dbOf(A), "conversations"), where("memberIds", "array-contains", A))));
    await assertFails(getDocs(query(collection(dbOf(C), "conversations"), where("memberIds", "array-contains", A))));
    await assertFails(getDocs(collection(dbOf(A), "conversations")));
  });
  it("valid text message succeeds", async () => {
    await assertSucceeds(setDoc(doc(dbOf(A), sendPath()), textMsg()));
  });
  it("valid image message succeeds; wrong path prefix denied", async () => {
    const img = { ...textMsg(), type: "image", text: null, mediaPath: `chatMedia/${CID}/${A}/f1`, mimeType: "image/jpeg", sizeBytes: 1000, width: 10, height: 10 };
    await assertSucceeds(setDoc(doc(dbOf(A), sendPath()), img));
    await assertFails(setDoc(doc(dbOf(A), sendPath("m2")), { ...img, clientMessageId: "m2", mediaPath: `chatMedia/${CID}/${B}/f1` }));
    await assertFails(setDoc(doc(dbOf(A), sendPath("m3")), { ...img, clientMessageId: "m3", mimeType: "image/gif" }));
    await assertFails(setDoc(doc(dbOf(A), sendPath("m4")), { ...img, clientMessageId: "m4", sizeBytes: 11 * 1024 * 1024 }));
  });
  it("forged senderId denied", async () => {
    await assertFails(setDoc(doc(dbOf(A), sendPath()), textMsg({ senderId: B })));
  });
  it("non-member cannot send", async () => {
    await assertFails(setDoc(doc(dbOf(C), sendPath()), textMsg({ senderId: C })));
  });
  it("clientMessageId must equal doc id", async () => {
    await assertFails(setDoc(doc(dbOf(A), sendPath()), textMsg({ clientMessageId: "other" })));
  });
  it("extra fields denied", async () => {
    await assertFails(setDoc(doc(dbOf(A), sendPath()), textMsg({ isAdmin: true })));
  });
  it("blank, empty and oversized text denied", async () => {
    await assertFails(setDoc(doc(dbOf(A), sendPath()), textMsg({ text: "   \n " })));
    await assertFails(setDoc(doc(dbOf(A), sendPath()), textMsg({ text: "" })));
    await assertFails(setDoc(doc(dbOf(A), sendPath()), textMsg({ text: "x".repeat(4001) })));
    await assertSucceeds(setDoc(doc(dbOf(A), sendPath()), textMsg({ text: "x".repeat(4000) })));
  });
  it("createdAt must be server time", async () => {
    await assertFails(setDoc(doc(dbOf(A), sendPath()), textMsg({ createdAt: Timestamp.fromMillis(1000) })));
  });
  it("messages immutable for clients", async () => {
    await assertSucceeds(setDoc(doc(dbOf(A), sendPath()), textMsg()));
    await assertFails(updateDoc(doc(dbOf(A), sendPath()), { text: "edited" }));
    await assertFails(deleteDoc(doc(dbOf(A), sendPath())));
  });
  it("blocked users cannot send, both directions", async () => {
    await block(B, A); // bob blocked alice
    await assertFails(setDoc(doc(dbOf(A), sendPath()), textMsg()));
    await assertFails(setDoc(doc(dbOf(B), sendPath("m2")), textMsg({ clientMessageId: "m2", senderId: B })));
  });
  it("sender who blocked recipient cannot send", async () => {
    await block(A, B);
    await assertFails(setDoc(doc(dbOf(A), sendPath()), textMsg()));
  });
  it("client cannot update or delete conversation", async () => {
    await assertFails(updateDoc(doc(dbOf(A), `conversations/${CID}`), { lastMessagePreview: "x" }));
    await assertFails(updateDoc(doc(dbOf(A), `conversations/${CID}`), { updatedAt: serverTimestamp() }));
    await assertFails(deleteDoc(doc(dbOf(A), `conversations/${CID}`)));
  });
  it("hidden messages: owner only", async () => {
    await assertSucceeds(setDoc(doc(dbOf(A), `conversations/${CID}/members/${A}/hidden/existing`), { hiddenAt: Timestamp.now() }));
    await assertFails(setDoc(doc(dbOf(B), `conversations/${CID}/members/${A}/hidden/x`), { hiddenAt: Timestamp.now() }));
    await assertFails(getDoc(doc(dbOf(B), `conversations/${CID}/members/${A}/hidden/existing`)));
  });
  it("reactions: own doc, allowlisted emoji, members only", async () => {
    const p = (uid: string) => `conversations/${CID}/messages/existing/reactions/${uid}`;
    await assertSucceeds(setDoc(doc(dbOf(A), p(A)), { emoji: "👍", createdAt: serverTimestamp() }));
    await assertFails(setDoc(doc(dbOf(A), p(B)), { emoji: "👍", createdAt: serverTimestamp() }));
    await assertFails(setDoc(doc(dbOf(A), p(A)), { emoji: "💩", createdAt: serverTimestamp() }));
    await assertFails(setDoc(doc(dbOf(C), p(C)), { emoji: "👍", createdAt: serverTimestamp() }));
    await assertFails(getDoc(doc(dbOf(C), p(A))));
  });
});

describe("conversation creation", () => {
  const newConv = (cid: string, members: string[], over: Record<string, unknown> = {}) => ({
    type: "direct", memberIds: members, createdBy: members[0], createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
    lastMessageId: null, lastMessageAt: null, lastMessagePreview: null, lastSenderId: null, ...over,
  });
  it("valid creation succeeds", async () => {
    await assertSucceeds(setDoc(doc(dbOf(A), "conversations/alice_carol"), newConv("alice_carol", [A, C])));
  });
  it("cid mismatch denied", async () => {
    await assertFails(setDoc(doc(dbOf(A), "conversations/carol_alice"), newConv("x", [A, C])));
    await assertFails(setDoc(doc(dbOf(A), "conversations/random"), newConv("x", [A, C])));
  });
  it("unsorted members denied", async () => {
    await assertFails(setDoc(doc(dbOf(C), "conversations/carol_alice"), newConv("x", [C, A], { createdBy: C })));
  });
  it("creator must be member / 3 members denied / non-null summary denied", async () => {
    await assertFails(setDoc(doc(dbOf(B), "conversations/alice_carol"), newConv("x", [A, C])));
    await assertFails(setDoc(doc(dbOf(A), "conversations/alice_bob_carol"), newConv("x", [A, B, C])));
    await assertFails(setDoc(doc(dbOf(A), "conversations/alice_carol"), newConv("x", [A, C], { lastMessagePreview: "hi" })));
  });
  it("blocked pair denied", async () => {
    await block(C, A);
    await assertFails(setDoc(doc(dbOf(A), "conversations/alice_carol"), newConv("x", [A, C])));
  });
  it("missing profile denied", async () => {
    await assertFails(setDoc(doc(dbOf(A), "conversations/alice_zed"), newConv("x", [A, "zed"])));
  });
  it("member doc: create in same batch as conversation; others denied", async () => {
    const db = dbOf(A);
    const b = writeBatch(db);
    b.set(doc(db, "conversations/alice_carol"), newConv("x", [A, C]));
    b.set(doc(db, `conversations/alice_carol/members/${A}`), { joinedAt: Timestamp.now(), lastReadAt: null, mutedUntil: null, archived: false, pinned: false });
    await assertSucceeds(b.commit());
    await assertFails(setDoc(doc(dbOf(A), `conversations/${CID}/members/${B}`), { joinedAt: Timestamp.now() }));
    await assertFails(setDoc(doc(dbOf(C), `conversations/${CID}/members/${C}`), { joinedAt: Timestamp.now() }));
    await assertFails(getDoc(doc(dbOf(B), `conversations/alice_carol/members/${A}`)));
  });
  it("member doc update own only", async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `conversations/${CID}/members/${A}`), { joinedAt: Timestamp.fromMillis(1000) });
    });
    await assertSucceeds(updateDoc(doc(dbOf(A), `conversations/${CID}/members/${A}`), { pinned: true }));
    await assertFails(updateDoc(doc(dbOf(B), `conversations/${CID}/members/${A}`), { pinned: true }));
    await assertFails(updateDoc(doc(dbOf(A), `conversations/${CID}/members/${A}`), { bogus: 1 }));
  });
});

describe("private user data", () => {
  it("settings: owner only + validation", async () => {
    const p = `users/${A}/private/settings`;
    await assertSucceeds(setDoc(doc(dbOf(A), p), { notificationEnabled: true, showMessagePreview: false, readReceiptsEnabled: true, lastSeenVisibility: "nobody", themeMode: "dark", updatedAt: serverTimestamp() }));
    await assertFails(setDoc(doc(dbOf(A), p), { lastSeenVisibility: "bogus" }));
    await assertFails(setDoc(doc(dbOf(A), p), { themeMode: "neon" }));
    await assertFails(setDoc(doc(dbOf(A), p), { notificationEnabled: "yes" }));
    await assertFails(setDoc(doc(dbOf(B), p), { notificationEnabled: true }));
    await assertFails(getDoc(doc(dbOf(B), p)));
    await assertSucceeds(getDoc(doc(dbOf(A), p)));
  });
  it("devices: owner only + validation", async () => {
    const p = `users/${A}/devices/d1`;
    const good = { token: "tok", platform: "android", appVersion: "1.0", lastSeenAt: Timestamp.now() };
    await assertSucceeds(setDoc(doc(dbOf(A), p), good));
    await assertFails(setDoc(doc(dbOf(B), p), good));
    await assertFails(setDoc(doc(dbOf(A), p), { ...good, platform: "web" }));
    await assertFails(getDoc(doc(dbOf(B), p)));
  });
  it("blocks: owner only", async () => {
    const good = { blockedUid: B, createdAt: Timestamp.now() };
    await assertSucceeds(setDoc(doc(dbOf(A), `users/${A}/blocks/${B}`), good));
    await assertFails(setDoc(doc(dbOf(C), `users/${A}/blocks/${B}`), good));
    await assertFails(getDoc(doc(dbOf(B), `users/${A}/blocks/${B}`)));
    await assertSucceeds(deleteDoc(doc(dbOf(A), `users/${A}/blocks/${B}`)));
  });
});

describe("profiles & usernames", () => {
  const prof = (u: string, name: string) => ({ uid: u, username: name, usernameLower: name, displayName: "D", createdAt: Timestamp.now(), updatedAt: Timestamp.now() });
  it("get allowed, list denied", async () => {
    await assertSucceeds(getDoc(doc(dbOf(A), `publicProfiles/${B}`)));
    await assertFails(getDocs(collection(dbOf(A), "publicProfiles")));
    await assertFails(getDocs(query(collection(dbOf(A), "publicProfiles"), where("usernameLower", "==", "bob"))));
    await assertFails(getDocs(collection(dbOf(A), "usernameIndex")));
  });
  it("claim username with profile in one batch", async () => {
    const db = dbOf("dave");
    const b = writeBatch(db);
    b.set(doc(db, "usernameIndex/dave_1"), { uid: "dave", createdAt: Timestamp.now() });
    b.set(doc(db, "publicProfiles/dave"), prof("dave", "dave_1"));
    await assertSucceeds(b.commit());
    await assertSucceeds(getDoc(doc(dbOf(A), "usernameIndex/dave_1")));
  });
  it("profile without index entry denied; bad username denied", async () => {
    await assertFails(setDoc(doc(dbOf("dave"), "publicProfiles/dave"), prof("dave", "dave_1")));
    const db = dbOf("dave");
    const b = writeBatch(db);
    b.set(doc(db, "usernameIndex/Da"), { uid: "dave", createdAt: Timestamp.now() });
    b.set(doc(db, "publicProfiles/dave"), prof("dave", "Da"));
    await assertFails(b.commit());
  });
  it("claim by another uid denied / cannot overwrite existing", async () => {
    await assertFails(setDoc(doc(dbOf(C), "usernameIndex/mallory"), { uid: A, createdAt: Timestamp.now() }));
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "usernameIndex/taken"), { uid: B, createdAt: Timestamp.now() });
    });
    const db = dbOf(C);
    const b = writeBatch(db);
    b.set(doc(db, "usernameIndex/taken"), { uid: C, createdAt: Timestamp.now() });
    b.set(doc(db, `publicProfiles/${C}`), prof(C, "taken"));
    await assertFails(b.commit());
    await assertFails(deleteDoc(doc(dbOf(C), "usernameIndex/taken")));
  });
  it("cannot write another user's profile; displayName/bio limits", async () => {
    await assertFails(setDoc(doc(dbOf(C), `publicProfiles/${A}`), prof(A, "alice")));
    const db = dbOf("eve");
    const mk = (over: Record<string, unknown>) => {
      const b = writeBatch(db);
      b.set(doc(db, "usernameIndex/eve_1"), { uid: "eve", createdAt: Timestamp.now() });
      b.set(doc(db, "publicProfiles/eve"), { ...prof("eve", "eve_1"), ...over });
      return b.commit();
    };
    await assertFails(mk({ bio: "x".repeat(161) }));
    await assertFails(mk({ displayName: "" }));
    await assertFails(mk({ displayName: "x".repeat(51) }));
    await assertSucceeds(mk({ bio: "x".repeat(160) }));
  });
});

describe("reports", () => {
  const rep = (over: Record<string, unknown> = {}) => ({ reporterId: A, reportedUid: B, reason: "spam", details: "d", createdAt: serverTimestamp(), status: "open", ...over });
  it("create ok, read/list/update/delete denied", async () => {
    await assertSucceeds(setDoc(doc(dbOf(A), "reports/r1"), rep()));
    await assertFails(getDoc(doc(dbOf(A), "reports/r1")));
    await assertFails(getDocs(collection(dbOf(A), "reports")));
    await assertFails(updateDoc(doc(dbOf(A), "reports/r1"), { status: "closed" }));
    await assertFails(deleteDoc(doc(dbOf(A), "reports/r1")));
  });
  it("invalid reports denied", async () => {
    await assertFails(setDoc(doc(dbOf(A), "reports/r2"), rep({ reporterId: B })));
    await assertFails(setDoc(doc(dbOf(A), "reports/r2"), rep({ reason: "meh" })));
    await assertFails(setDoc(doc(dbOf(A), "reports/r2"), rep({ status: "closed" })));
    await assertFails(setDoc(doc(dbOf(A), "reports/r2"), rep({ details: "x".repeat(501) })));
    await assertFails(setDoc(doc(dbOf(null), "reports/r2"), rep()));
  });
  it("functionMarkers and unknown paths denied", async () => {
    await assertFails(setDoc(doc(dbOf(A), "functionMarkers/x"), { a: 1 }));
    await assertFails(getDoc(doc(dbOf(A), "functionMarkers/x")));
    await assertFails(setDoc(doc(dbOf(A), "random/x"), { a: 1 }));
  });
});

describe("storage", () => {
  const bytes = (n: number) => new Uint8Array(n);
  const seedConv = async () => { /* conversation alice_bob seeded in beforeEach */ };

  it("chatMedia: member upload ok, wrong type / oversize / non-member / other uid denied", async () => {
    await seedConv();
    const p = `chatMedia/${CID}/${A}/f1`;
    await assertSucceeds(uploadBytes(ref(stOf(A), p), bytes(100), { contentType: "image/jpeg" }));
    await assertFails(uploadBytes(ref(stOf(A), `chatMedia/${CID}/${A}/f2`), bytes(100), { contentType: "application/pdf" }));
    await assertFails(uploadBytes(ref(stOf(A), `chatMedia/${CID}/${A}/f3`), bytes(11 * 1024 * 1024), { contentType: "image/png" }));
    await assertFails(uploadBytes(ref(stOf(C), `chatMedia/${CID}/${C}/f4`), bytes(100), { contentType: "image/jpeg" }));
    await assertFails(uploadBytes(ref(stOf(B), `chatMedia/${CID}/${A}/f5`), bytes(100), { contentType: "image/jpeg" }));
    await assertFails(uploadBytes(ref(stOf(null), `chatMedia/${CID}/${A}/f6`), bytes(100), { contentType: "image/jpeg" }));
  });
  it("chatMedia read: members only; delete by uploader only", async () => {
    const p = `chatMedia/${CID}/${A}/f1`;
    await assertSucceeds(uploadBytes(ref(stOf(A), p), bytes(100), { contentType: "image/jpeg" }));
    await assertSucceeds(getBytes(ref(stOf(B), p)));
    await assertFails(getBytes(ref(stOf(C), p)));
    await assertFails(deleteObject(ref(stOf(B), p)));
    await assertSucceeds(deleteObject(ref(stOf(A), p)));
  });
  it("avatars: signed-in read, owner write only, type/size limits", async () => {
    const p = `avatars/${A}/a.png`;
    await assertSucceeds(uploadBytes(ref(stOf(A), p), bytes(100), { contentType: "image/png" }));
    await assertSucceeds(getBytes(ref(stOf(B), p)));
    await assertFails(getBytes(ref(stOf(null), p)));
    await assertFails(uploadBytes(ref(stOf(B), `avatars/${A}/b.png`), bytes(100), { contentType: "image/png" }));
    await assertFails(uploadBytes(ref(stOf(A), `avatars/${A}/c.gif`), bytes(100), { contentType: "image/gif" }));
    await assertFails(uploadBytes(ref(stOf(A), `avatars/${A}/d.png`), bytes(5 * 1024 * 1024 + 1), { contentType: "image/png" }));
    await assertFails(deleteObject(ref(stOf(B), p)));
  });
  it("other storage paths denied", async () => {
    await assertFails(uploadBytes(ref(stOf(A), `misc/${A}/x`), bytes(10), { contentType: "image/png" }));
  });
});

describe("receipts", () => {
  const path = (u: string) => `conversations/${CID}/receipts/${u}`;
  it("member writes own receipt; peer can read it", async () => {
    await assertSucceeds(setDoc(doc(dbOf(B), path(B)), { lastDeliveredAt: serverTimestamp(), lastReadAt: serverTimestamp() }));
    await assertSucceeds(getDoc(doc(dbOf(A), path(B))));
  });
  it("member cannot write the other member's receipt", async () => {
    await assertFails(setDoc(doc(dbOf(A), path(B)), { lastReadAt: serverTimestamp() }));
  });
  it("non-member can neither read nor write", async () => {
    await assertFails(getDoc(doc(dbOf(C), path(B))));
    await assertFails(setDoc(doc(dbOf(C), path(C)), { lastReadAt: serverTimestamp() }));
  });
  it("rejects unknown fields and wrong types; no delete", async () => {
    await assertFails(setDoc(doc(dbOf(A), path(A)), { lastReadAt: serverTimestamp(), admin: true }));
    await assertFails(setDoc(doc(dbOf(A), path(A)), { lastReadAt: "yesterday" }));
    await assertSucceeds(setDoc(doc(dbOf(A), path(A)), { lastDeliveredAt: serverTimestamp() }));
    await assertFails(deleteDoc(doc(dbOf(A), path(A))));
  });
});

describe("delete for everyone", () => {
  const wipe = (extra: Record<string, unknown> = {}) => ({
    deletedForEveryoneAt: serverTimestamp(), text: deleteField(), ...extra,
  });
  beforeEach(async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), sendPath("mine")), textMsg({ clientMessageId: "mine", createdAt: Timestamp.now() }));
      await setDoc(doc(ctx.firestore(), sendPath("old")), textMsg({ clientMessageId: "old", createdAt: Timestamp.fromMillis(Date.now() - 72 * 3600 * 1000) }));
    });
  });
  it("sender can wipe their own recent message", async () => {
    await assertSucceeds(updateDoc(doc(dbOf(A), sendPath("mine")), wipe()));
  });
  it("other member cannot delete it for everyone", async () => {
    await assertFails(updateDoc(doc(dbOf(B), sendPath("mine")), wipe()));
  });
  it("non-member cannot", async () => {
    await assertFails(updateDoc(doc(dbOf(C), sendPath("mine")), wipe()));
  });
  it("too old (>48h) cannot", async () => {
    await assertFails(updateDoc(doc(dbOf(A), sendPath("old")), wipe()));
  });
  it("cannot edit text or change other fields", async () => {
    await assertFails(updateDoc(doc(dbOf(A), sendPath("mine")), { text: "edited" }));
    await assertFails(updateDoc(doc(dbOf(A), sendPath("mine")), wipe({ senderId: B })));
    await assertFails(updateDoc(doc(dbOf(A), sendPath("mine")), { ...wipe(), text: "still here" }));
  });
  it("cannot fake the tombstone time", async () => {
    await assertFails(updateDoc(doc(dbOf(A), sendPath("mine")), { deletedForEveryoneAt: Timestamp.fromMillis(5), text: deleteField() }));
  });
  it("cannot be deleted outright or wiped twice", async () => {
    await assertFails(deleteDoc(doc(dbOf(A), sendPath("mine"))));
    await assertSucceeds(updateDoc(doc(dbOf(A), sendPath("mine")), wipe()));
    await assertFails(updateDoc(doc(dbOf(A), sendPath("mine")), wipe()));
  });
});

describe("presence", () => {
  it("owner writes own presence; chat partner can read it", async () => {
    await assertSucceeds(setDoc(doc(dbOf(A), `presence/${A}`), { lastActiveAt: serverTimestamp() }));
    await assertSucceeds(getDoc(doc(dbOf(B), `presence/${A}`)));
  });
  it("stranger cannot read presence", async () => {
    await assertSucceeds(setDoc(doc(dbOf(A), `presence/${A}`), { lastActiveAt: serverTimestamp() }));
    await assertFails(getDoc(doc(dbOf(C), `presence/${A}`)));
  });
  it("cannot write someone else's presence, fake time, or extra fields", async () => {
    await assertFails(setDoc(doc(dbOf(B), `presence/${A}`), { lastActiveAt: serverTimestamp() }));
    await assertFails(setDoc(doc(dbOf(A), `presence/${A}`), { lastActiveAt: Timestamp.fromMillis(1) }));
    await assertFails(setDoc(doc(dbOf(A), `presence/${A}`), { lastActiveAt: serverTimestamp(), online: true }));
  });
  it("owner can hide by deleting; no list", async () => {
    await assertSucceeds(setDoc(doc(dbOf(A), `presence/${A}`), { lastActiveAt: serverTimestamp() }));
    await assertSucceeds(deleteDoc(doc(dbOf(A), `presence/${A}`)));
    await assertFails(getDocs(collection(dbOf(A), "presence")));
  });
});

describe("deletionFeedback", () => {
  it("signed-in user can submit anonymous feedback, nobody can read it", async () => {
    await assertSucceeds(setDoc(doc(dbOf(A), "deletionFeedback/f1"), { reason: "privacy", details: "x", createdAt: serverTimestamp() }));
    await assertFails(getDoc(doc(dbOf(A), "deletionFeedback/f1")));
  });
  it("rejects unknown reasons, extra fields (e.g. uid) and anonymous callers", async () => {
    await assertFails(setDoc(doc(dbOf(A), "deletionFeedback/f2"), { reason: "nope", createdAt: serverTimestamp() }));
    await assertFails(setDoc(doc(dbOf(A), "deletionFeedback/f3"), { reason: "other", uid: A, createdAt: serverTimestamp() }));
    await assertFails(setDoc(doc(dbOf(null), "deletionFeedback/f4"), { reason: "other", createdAt: serverTimestamp() }));
  });
});

describe("typing indicator", () => {
  const path = (u: string) => `conversations/${CID}/typing/${u}`;
  it("member writes own typing doc; the other member can read it", async () => {
    await assertSucceeds(setDoc(doc(dbOf(A), path(A)), { typingAt: serverTimestamp() }));
    await assertSucceeds(getDoc(doc(dbOf(B), path(A))));
  });
  it("cannot write someone else's typing doc", async () => {
    await assertFails(setDoc(doc(dbOf(B), path(A)), { typingAt: serverTimestamp() }));
  });
  it("non-member can neither read nor write", async () => {
    await assertFails(getDoc(doc(dbOf(C), path(A))));
    await assertFails(setDoc(doc(dbOf(C), path(C)), { typingAt: serverTimestamp() }));
  });
  it("rejects fake timestamps and extra fields", async () => {
    await assertFails(setDoc(doc(dbOf(A), path(A)), { typingAt: Timestamp.fromMillis(1) }));
    await assertFails(setDoc(doc(dbOf(A), path(A)), { typingAt: serverTimestamp(), draft: "secret" }));
  });
  it("owner can clear it", async () => {
    await assertSucceeds(setDoc(doc(dbOf(A), path(A)), { typingAt: serverTimestamp() }));
    await assertSucceeds(deleteDoc(doc(dbOf(A), path(A))));
  });
});

describe("clear chat (clearedAt on own member doc)", () => {
  const mem = (u: string) => `conversations/${CID}/members/${u}`;
  beforeEach(async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), mem(A)), { joinedAt: Timestamp.now(), lastReadAt: null, mutedUntil: null, archived: false, pinned: false });
    });
  });
  it("owner can set clearedAt on their own member doc", async () => {
    await assertSucceeds(updateDoc(doc(dbOf(A), mem(A)), { clearedAt: serverTimestamp() }));
  });
  it("cannot clear (or tamper with) the other member's view", async () => {
    await assertFails(updateDoc(doc(dbOf(B), mem(A)), { clearedAt: serverTimestamp() }));
  });
  it("rejects a non-timestamp clearedAt", async () => {
    await assertFails(updateDoc(doc(dbOf(A), mem(A)), { clearedAt: "yesterday" }));
  });
  it("clearing does not delete anything the other member can see", async () => {
    await assertSucceeds(updateDoc(doc(dbOf(A), mem(A)), { clearedAt: serverTimestamp() }));
    await assertSucceeds(getDoc(doc(dbOf(B), `conversations/${CID}/messages/existing`)));
  });
});


// ---------------------------------------------------------------------------
// Groups
// ---------------------------------------------------------------------------
describe("groups", () => {
  const D = "dave";
  const GID = "g_" + "a".repeat(32);
  const GID2 = "g_" + "b".repeat(32);
  const gp = (g = GID) => `conversations/${g}`;
  const gmsg = (id: string, uid: string, extra: Record<string, unknown> = {}) => ({
    clientMessageId: id, senderId: uid, type: "text", text: "hey", createdAt: serverTimestamp(), ...extra,
  });
  const sys = (id: string, uid: string, event: string, targetUid: string | null) => ({
    clientMessageId: id, senderId: uid, type: "system", event, targetUid, createdAt: serverTimestamp(),
  });
  const newGroup = (over: Record<string, unknown> = {}) => ({
    type: "group", memberIds: [A, B, C], adminIds: [A], name: "Team", photoPath: null, createdBy: A,
    createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
    lastMessageId: null, lastMessageAt: null, lastMessagePreview: null, lastSenderId: null, ...over,
  });
  const users = (n: number) => [A, ...Array.from({ length: n - 1 }, (_, i) => `u${i}`)];

  async function seed(over: Record<string, unknown> = {}, g = GID) {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), gp(g)), {
        ...newGroup(), createdAt: Timestamp.now(), updatedAt: Timestamp.now(), ...over,
      });
      await setDoc(doc(ctx.firestore(), `${gp(g)}/messages/old`), { clientMessageId: "old", senderId: B, type: "text", text: "yo", createdAt: Timestamp.now() });
      await setDoc(doc(ctx.firestore(), `${gp(g)}/receipts/${B}`), { lastReadAt: Timestamp.now() });
      await setDoc(doc(ctx.firestore(), `${gp(g)}/typing/${B}`), { typingAt: Timestamp.now() });
    });
  }

  describe("create", () => {
    it("valid create (+ own member doc in same batch)", async () => {
      const db = dbOf(A);
      const b = writeBatch(db);
      b.set(doc(db, gp()), newGroup());
      b.set(doc(db, `${gp()}/members/${A}`), { joinedAt: Timestamp.now() });
      await assertSucceeds(b.commit());
    });
    it("with valid photoPath ok, other gid's photoPath denied", async () => {
      await assertSucceeds(setDoc(doc(dbOf(A), gp()), newGroup({ photoPath: `groupAvatars/${GID}/p.png` })));
      await assertFails(setDoc(doc(dbOf(A), gp(GID2)), newGroup({ photoPath: `groupAvatars/${GID}/p.png` })));
    });
    it("20 members ok, 21 denied, 1 denied", async () => {
      await assertSucceeds(setDoc(doc(dbOf(A), gp()), newGroup({ memberIds: users(20) })));
      await assertFails(setDoc(doc(dbOf(A), gp(GID2)), newGroup({ memberIds: users(21) })));
      await assertFails(setDoc(doc(dbOf(A), gp(GID2)), newGroup({ memberIds: [A] })));
    });
    it("duplicate members / duplicate or extra admin denied", async () => {
      await assertFails(setDoc(doc(dbOf(A), gp()), newGroup({ memberIds: [A, B, B] })));
      await assertFails(setDoc(doc(dbOf(A), gp()), newGroup({ adminIds: [A, A] })));
      await assertFails(setDoc(doc(dbOf(A), gp()), newGroup({ adminIds: [A, B] })));
      await assertFails(setDoc(doc(dbOf(A), gp()), newGroup({ adminIds: [B] })));
    });
    it("bad names denied", async () => {
      await assertFails(setDoc(doc(dbOf(A), gp()), newGroup({ name: "" })));
      await assertFails(setDoc(doc(dbOf(A), gp()), newGroup({ name: "   " })));
      await assertFails(setDoc(doc(dbOf(A), gp()), newGroup({ name: "x".repeat(51) })));
      await assertSucceeds(setDoc(doc(dbOf(A), gp()), newGroup({ name: "x".repeat(50) })));
    });
    it("bad gid denied", async () => {
      await assertFails(setDoc(doc(dbOf(A), "conversations/g_short"), newGroup()));
      await assertFails(setDoc(doc(dbOf(A), "conversations/" + "a".repeat(34)), newGroup()));
      await assertFails(setDoc(doc(dbOf(A), "conversations/g_" + "A".repeat(32)), newGroup()));
    });
    it("non-creator / creating as someone else / creator not member denied", async () => {
      await assertFails(setDoc(doc(dbOf(D), gp()), newGroup()));
      await assertFails(setDoc(doc(dbOf(B), gp()), newGroup({ createdBy: A })));
      await assertFails(setDoc(doc(dbOf(D), gp()), newGroup({ createdBy: D, adminIds: [D] })));
    });
    it("non-null summary / fake times / extra keys denied", async () => {
      await assertFails(setDoc(doc(dbOf(A), gp()), newGroup({ lastMessagePreview: "x" })));
      await assertFails(setDoc(doc(dbOf(A), gp()), newGroup({ createdAt: Timestamp.fromMillis(5) })));
      await assertFails(setDoc(doc(dbOf(A), gp()), newGroup({ deletedAccounts: [] })));
    });
  });

  describe("read access: conversation, messages, receipts, typing", () => {
    beforeEach(() => seed());
    it("members read; non-member denied", async () => {
      await assertSucceeds(getDoc(doc(dbOf(B), gp())));
      await assertSucceeds(getDoc(doc(dbOf(B), `${gp()}/messages/old`)));
      await assertFails(getDoc(doc(dbOf(D), gp())));
      await assertFails(getDoc(doc(dbOf(D), `${gp()}/messages/old`)));
      await assertFails(getDoc(doc(dbOf(D), `${gp()}/receipts/${B}`)));
      await assertFails(getDoc(doc(dbOf(D), `${gp()}/typing/${B}`)));
    });
    it("member can list receipts and typing collections; non-member cannot", async () => {
      await assertSucceeds(getDocs(collection(dbOf(A), `${gp()}/receipts`)));
      await assertSucceeds(getDocs(collection(dbOf(A), `${gp()}/typing`)));
      await assertFails(getDocs(collection(dbOf(D), `${gp()}/receipts`)));
      await assertFails(getDocs(collection(dbOf(D), `${gp()}/typing`)));
    });
    it("array-contains list works for group members", async () => {
      await assertSucceeds(getDocs(query(collection(dbOf(B), "conversations"), where("memberIds", "array-contains", B))));
      await assertFails(getDocs(query(collection(dbOf(D), "conversations"), where("memberIds", "array-contains", B))));
    });
    it("members write own receipt/typing/reactions; not others'", async () => {
      await assertSucceeds(setDoc(doc(dbOf(C), `${gp()}/receipts/${C}`), { lastDeliveredAt: serverTimestamp() }));
      await assertFails(setDoc(doc(dbOf(C), `${gp()}/receipts/${B}`), { lastDeliveredAt: serverTimestamp() }));
      await assertSucceeds(setDoc(doc(dbOf(C), `${gp()}/typing/${C}`), { typingAt: serverTimestamp() }));
      await assertSucceeds(setDoc(doc(dbOf(C), `${gp()}/messages/old/reactions/${C}`), { emoji: "👍", createdAt: serverTimestamp() }));
      await assertFails(setDoc(doc(dbOf(D), `${gp()}/receipts/${D}`), { lastDeliveredAt: serverTimestamp() }));
    });
    it("added member can lazily create own member doc after being added", async () => {
      await assertFails(setDoc(doc(dbOf(D), `${gp()}/members/${D}`), { joinedAt: Timestamp.now() }));
      await assertSucceeds(updateDoc(doc(dbOf(A), gp()), { memberIds: [A, B, C, D], updatedAt: serverTimestamp() }));
      await assertSucceeds(setDoc(doc(dbOf(D), `${gp()}/members/${D}`), { joinedAt: Timestamp.now() }));
    });
  });

  describe("admin updates", () => {
    beforeEach(() => seed());
    it("admin adds member; non-admin cannot", async () => {
      await assertFails(updateDoc(doc(dbOf(B), gp()), { memberIds: [A, B, C, D], updatedAt: serverTimestamp() }));
      await assertSucceeds(updateDoc(doc(dbOf(A), gp()), { memberIds: [A, B, C, D], updatedAt: serverTimestamp() }));
    });
    it("21st member denied, 20th ok", async () => {
      await seed({ memberIds: users(19), adminIds: [A] });
      await assertSucceeds(updateDoc(doc(dbOf(A), gp()), { memberIds: [...users(19), D], updatedAt: serverTimestamp() }));
      await seed({ memberIds: users(20), adminIds: [A] });
      await assertFails(updateDoc(doc(dbOf(A), gp()), { memberIds: [...users(20), D], updatedAt: serverTimestamp() }));
    });
    it("admin removes member; removed member loses access", async () => {
      await assertSucceeds(updateDoc(doc(dbOf(A), gp()), { memberIds: [A, C], updatedAt: serverTimestamp() }));
      await assertFails(getDoc(doc(dbOf(B), gp())));
      await assertFails(setDoc(doc(dbOf(B), `${gp()}/messages/m1`), gmsg("m1", B)));
    });
    it("non-admin member cannot remove others, rename, or promote self", async () => {
      await assertFails(updateDoc(doc(dbOf(B), gp()), { memberIds: [A, B], updatedAt: serverTimestamp() }));
      await assertFails(updateDoc(doc(dbOf(B), gp()), { name: "Hax", updatedAt: serverTimestamp() }));
      await assertFails(updateDoc(doc(dbOf(B), gp()), { adminIds: [A, B], updatedAt: serverTimestamp() }));
    });
    it("rename + photoPath validation", async () => {
      await assertSucceeds(updateDoc(doc(dbOf(A), gp()), { name: "New", updatedAt: serverTimestamp() }));
      await assertFails(updateDoc(doc(dbOf(A), gp()), { name: "  ", updatedAt: serverTimestamp() }));
      await assertFails(updateDoc(doc(dbOf(A), gp()), { name: "x".repeat(51), updatedAt: serverTimestamp() }));
      await assertSucceeds(updateDoc(doc(dbOf(A), gp()), { photoPath: `groupAvatars/${GID}/p.jpg`, updatedAt: serverTimestamp() }));
      await assertFails(updateDoc(doc(dbOf(A), gp()), { photoPath: `groupAvatars/${GID2}/p.jpg`, updatedAt: serverTimestamp() }));
      await assertFails(updateDoc(doc(dbOf(A), gp()), { photoPath: "avatars/x/y", updatedAt: serverTimestamp() }));
      await assertSucceeds(updateDoc(doc(dbOf(A), gp()), { photoPath: null, updatedAt: serverTimestamp() }));
    });
    it("promote/demote admins; at least one admin; admins must be members", async () => {
      await assertSucceeds(updateDoc(doc(dbOf(A), gp()), { adminIds: [A, B], updatedAt: serverTimestamp() }));
      await assertFails(updateDoc(doc(dbOf(A), gp()), { adminIds: [A, D], updatedAt: serverTimestamp() }));
      await assertFails(updateDoc(doc(dbOf(A), gp()), { adminIds: [], updatedAt: serverTimestamp() }));
      await assertFails(updateDoc(doc(dbOf(A), gp()), { adminIds: [A, A], updatedAt: serverTimestamp() }));
    });
    it("admin cannot remove an admin from members without un-adminning; cannot change immutable/summary fields", async () => {
      await assertFails(updateDoc(doc(dbOf(A), gp()), { memberIds: [B, C], updatedAt: serverTimestamp() }));
      await assertFails(updateDoc(doc(dbOf(A), gp()), { createdBy: B }));
      await assertFails(updateDoc(doc(dbOf(A), gp()), { type: "direct" }));
      await assertFails(updateDoc(doc(dbOf(A), gp()), { lastMessagePreview: "x" }));
      await assertFails(updateDoc(doc(dbOf(A), gp()), { name: "ok", updatedAt: Timestamp.fromMillis(5) }));
      await assertFails(deleteDoc(doc(dbOf(A), gp())));
    });
    it("direct chats remain un-updatable", async () => {
      await assertFails(updateDoc(doc(dbOf(A), `conversations/${CID}`), { memberIds: [A, B, C] }));
    });
  });

  describe("leave", () => {
    beforeEach(() => seed());
    it("member leaves (self) with system message in same batch", async () => {
      const db = dbOf(B);
      const b = writeBatch(db);
      b.update(doc(db, gp()), { memberIds: [A, C], updatedAt: serverTimestamp() });
      b.set(doc(db, `${gp()}/messages/l1`), sys("l1", B, "left", B));
      await assertSucceeds(b.commit());
      await assertFails(getDoc(doc(dbOf(B), gp())));
    });
    it("non-admin cannot remove someone else via leave path or touch adminIds", async () => {
      await assertFails(updateDoc(doc(dbOf(B), gp()), { memberIds: [A, B], updatedAt: serverTimestamp() }));
      await assertFails(updateDoc(doc(dbOf(B), gp()), { memberIds: [A, C], adminIds: [A, C], updatedAt: serverTimestamp() }));
      await assertFails(updateDoc(doc(dbOf(B), gp()), { memberIds: [C], updatedAt: serverTimestamp() }));
    });
    it("last admin leaving without promotion denied; with promotion ok", async () => {
      await assertFails(updateDoc(doc(dbOf(A), gp()), { memberIds: [B, C], adminIds: [], updatedAt: serverTimestamp() }));
      await assertFails(updateDoc(doc(dbOf(A), gp()), { memberIds: [B, C], updatedAt: serverTimestamp() }));
      const db = dbOf(A);
      const b = writeBatch(db);
      b.update(doc(db, gp()), { memberIds: [B, C], adminIds: [B], updatedAt: serverTimestamp() });
      b.set(doc(db, `${gp()}/messages/l1`), sys("l1", A, "left", A));
      await assertSucceeds(b.commit());
    });
    it("leave cannot promote a non-member", async () => {
      await assertFails(updateDoc(doc(dbOf(A), gp()), { memberIds: [B, C], adminIds: [D], updatedAt: serverTimestamp() }));
    });
  });

  describe("messages", () => {
    beforeEach(() => seed());
    it("text by member ok; non-member and forged sender denied", async () => {
      await assertSucceeds(setDoc(doc(dbOf(C), `${gp()}/messages/m1`), gmsg("m1", C)));
      await assertFails(setDoc(doc(dbOf(D), `${gp()}/messages/m1`), gmsg("m1", D)));
      await assertFails(setDoc(doc(dbOf(C), `${gp()}/messages/m1`), gmsg("m1", B)));
    });
    it("blocks are not enforced in groups", async () => {
      await block(B, C);
      await assertSucceeds(setDoc(doc(dbOf(C), `${gp()}/messages/m1`), gmsg("m1", C)));
    });
    it("image message with group media path ok", async () => {
      await assertSucceeds(setDoc(doc(dbOf(C), `${gp()}/messages/m1`), gmsg("m1", C, {
        type: "image", text: null, mediaPath: `chatMedia/${GID}/${C}/f`, mimeType: "image/png", sizeBytes: 10, width: 1, height: 1 })));
    });
    it("text with event fields denied", async () => {
      await assertFails(setDoc(doc(dbOf(A), `${gp()}/messages/m1`), gmsg("m1", A, { event: "added", targetUid: B })));
    });
    it("system: admin added/removed/renamed ok", async () => {
      await assertSucceeds(setDoc(doc(dbOf(A), `${gp()}/messages/s1`), sys("s1", A, "added", D)));
      await assertSucceeds(setDoc(doc(dbOf(A), `${gp()}/messages/s2`), sys("s2", A, "removed", B)));
      await assertSucceeds(setDoc(doc(dbOf(A), `${gp()}/messages/s3`), sys("s3", A, "renamed", null)));
      await assertSucceeds(setDoc(doc(dbOf(A), `${gp()}/messages/s4`), { clientMessageId: "s4", senderId: A, type: "system", event: "renamed", createdAt: serverTimestamp() }));
    });
    it("system: member forging added/removed/renamed denied", async () => {
      await assertFails(setDoc(doc(dbOf(B), `${gp()}/messages/s1`), sys("s1", B, "added", D)));
      await assertFails(setDoc(doc(dbOf(B), `${gp()}/messages/s2`), sys("s2", B, "removed", C)));
      await assertFails(setDoc(doc(dbOf(B), `${gp()}/messages/s3`), sys("s3", B, "renamed", null)));
    });
    it("system 'left': only for self", async () => {
      await assertSucceeds(setDoc(doc(dbOf(B), `${gp()}/messages/s1`), sys("s1", B, "left", B)));
      await assertFails(setDoc(doc(dbOf(B), `${gp()}/messages/s2`), sys("s2", B, "left", C)));
    });
    it("system: invalid shapes denied", async () => {
      await assertFails(setDoc(doc(dbOf(A), `${gp()}/messages/s1`), { ...sys("s1", A, "added", D), text: "hi" }));
      await assertFails(setDoc(doc(dbOf(A), `${gp()}/messages/s2`), sys("s2", A, "kicked", D)));
      await assertFails(setDoc(doc(dbOf(A), `${gp()}/messages/s3`), sys("s3", A, "added", null)));
      await assertFails(setDoc(doc(dbOf(A), `${gp()}/messages/s4`), sys("s4", A, "renamed", D)));
      await assertFails(setDoc(doc(dbOf(A), `${gp()}/messages/s5`), { ...sys("s5", A, "added", D), mediaPath: "x" }));
      await assertFails(setDoc(doc(dbOf(D), `${gp()}/messages/s6`), sys("s6", D, "left", D)));
    });
    it("system messages denied in direct chats", async () => {
      await assertFails(setDoc(doc(dbOf(A), sendPath("s1")), sys("s1", A, "added", C)));
      await assertFails(setDoc(doc(dbOf(A), sendPath("s2")), sys("s2", A, "renamed", null)));
    });
    it("system messages are immutable (no delete-for-everyone); text still deletable by sender", async () => {
      await env.withSecurityRulesDisabled(async (ctx) => {
        await setDoc(doc(ctx.firestore(), `${gp()}/messages/s9`), { ...sys("s9", A, "renamed", null), createdAt: Timestamp.now() });
        await setDoc(doc(ctx.firestore(), `${gp()}/messages/t9`), { ...gmsg("t9", C), createdAt: Timestamp.now() });
      });
      await assertFails(updateDoc(doc(dbOf(A), `${gp()}/messages/s9`), { deletedForEveryoneAt: serverTimestamp() }));
      await assertSucceeds(updateDoc(doc(dbOf(C), `${gp()}/messages/t9`), { deletedForEveryoneAt: serverTimestamp(), text: deleteField() }));
    });
  });

  describe("invites", () => {
    const inv = (over: Record<string, unknown> = {}) => ({ gid: GID, groupName: "Team", createdBy: A, createdAt: serverTimestamp(), active: true, ...over });
    const CODE = "AbCdEfGhIjKl";
    beforeEach(() => seed());
    async function seedInvite(code = CODE, over: Record<string, unknown> = {}) {
      await env.withSecurityRulesDisabled(async (ctx) => {
        await setDoc(doc(ctx.firestore(), `groupInvites/${code}`), { ...inv(), createdAt: Timestamp.now(), ...over });
      });
    }
    it("create by admin ok; by member / non-member denied", async () => {
      await assertSucceeds(setDoc(doc(dbOf(A), `groupInvites/${CODE}`), inv()));
      await assertFails(setDoc(doc(dbOf(B), `groupInvites/${CODE}`), inv({ createdBy: B })));
      await assertFails(setDoc(doc(dbOf(D), `groupInvites/${CODE}`), inv({ createdBy: D })));
    });
    it("create validation: code, createdBy, active, groupName, gid, direct gid", async () => {
      await assertFails(setDoc(doc(dbOf(A), "groupInvites/short"), inv()));
      await assertFails(setDoc(doc(dbOf(A), `groupInvites/${CODE}`), inv({ createdBy: B })));
      await assertFails(setDoc(doc(dbOf(A), `groupInvites/${CODE}`), inv({ active: false })));
      await assertFails(setDoc(doc(dbOf(A), `groupInvites/${CODE}`), inv({ groupName: "Other" })));
      await assertFails(setDoc(doc(dbOf(A), `groupInvites/${CODE}`), inv({ gid: GID2 })));
      await assertFails(setDoc(doc(dbOf(A), `groupInvites/${CODE}`), inv({ gid: CID })));
      await assertFails(setDoc(doc(dbOf(A), `groupInvites/${CODE}`), inv({ extra: 1 })));
    });
    it("get by any signed-in user; anonymous denied", async () => {
      await seedInvite();
      await assertSucceeds(getDoc(doc(dbOf(D), `groupInvites/${CODE}`)));
      await assertFails(getDoc(doc(dbOf(null), `groupInvites/${CODE}`)));
    });
    it("list only constrained to own invites", async () => {
      await seedInvite();
      await seedInvite("ZzZzZzZzZzZz", { createdBy: B });
      await assertSucceeds(getDocs(query(collection(dbOf(A), "groupInvites"), where("createdBy", "==", A), where("gid", "==", GID))));
      await assertSucceeds(getDocs(query(collection(dbOf(A), "groupInvites"), where("createdBy", "==", A))));
      await assertFails(getDocs(query(collection(dbOf(A), "groupInvites"), where("gid", "==", GID))));
      await assertFails(getDocs(collection(dbOf(A), "groupInvites")));
      await assertFails(getDocs(query(collection(dbOf(A), "groupInvites"), where("createdBy", "==", B))));
      await assertFails(getDocs(query(collection(dbOf(null), "groupInvites"), where("createdBy", "==", A))));
    });
    it("revoke by admin only; other fields locked", async () => {
      await seedInvite();
      await assertFails(updateDoc(doc(dbOf(B), `groupInvites/${CODE}`), { active: false }));
      await assertFails(updateDoc(doc(dbOf(D), `groupInvites/${CODE}`), { active: false }));
      await assertFails(updateDoc(doc(dbOf(A), `groupInvites/${CODE}`), { gid: GID2 }));
      await assertFails(updateDoc(doc(dbOf(A), `groupInvites/${CODE}`), { createdBy: B }));
      await assertSucceeds(updateDoc(doc(dbOf(A), `groupInvites/${CODE}`), { active: false }));
    });
    it("groupName update must match group name; delete by admin only", async () => {
      await seedInvite();
      await assertFails(updateDoc(doc(dbOf(A), `groupInvites/${CODE}`), { groupName: "Bogus" }));
      await updateDoc(doc(dbOf(A), gp()), { name: "Renamed", updatedAt: serverTimestamp() });
      await assertSucceeds(updateDoc(doc(dbOf(A), `groupInvites/${CODE}`), { groupName: "Renamed" }));
      await assertFails(deleteDoc(doc(dbOf(B), `groupInvites/${CODE}`)));
      await assertSucceeds(deleteDoc(doc(dbOf(A), `groupInvites/${CODE}`)));
    });
  });

  describe("join requests", () => {
    const CODE = "AbCdEfGhIjKl";
    const jr = (uid: string, over: Record<string, unknown> = {}) => ({ uid, code: CODE, createdAt: serverTimestamp(), ...over });
    const jp = (uid: string) => `${gp()}/joinRequests/${uid}`;
    beforeEach(async () => {
      await seed();
      await env.withSecurityRulesDisabled(async (ctx) => {
        await setDoc(doc(ctx.firestore(), `groupInvites/${CODE}`), { gid: GID, groupName: "Team", createdBy: A, createdAt: Timestamp.now(), active: true });
        await setDoc(doc(ctx.firestore(), `groupInvites/REVOKEDCODE1`), { gid: GID, groupName: "Team", createdBy: A, createdAt: Timestamp.now(), active: false });
        await setDoc(doc(ctx.firestore(), `groupInvites/OTHERGRPCODE1`), { gid: GID2, groupName: "Other", createdBy: A, createdAt: Timestamp.now(), active: true });
      });
    });
    it("valid request ok; requester can get own", async () => {
      await assertSucceeds(setDoc(doc(dbOf(D), jp(D)), jr(D)));
      await assertSucceeds(getDoc(doc(dbOf(D), jp(D))));
    });
    it("revoked / wrong-group / missing invite denied", async () => {
      await assertFails(setDoc(doc(dbOf(D), jp(D)), jr(D, { code: "REVOKEDCODE1" })));
      await assertFails(setDoc(doc(dbOf(D), jp(D)), jr(D, { code: "OTHERGRPCODE1" })));
      await assertFails(setDoc(doc(dbOf(D), jp(D)), jr(D, { code: "NOSUCHCODE123" })));
    });
    it("existing member denied; someone else's uid denied; bad shape denied", async () => {
      await assertFails(setDoc(doc(dbOf(B), jp(B)), jr(B)));
      await assertFails(setDoc(doc(dbOf(D), jp(C)), jr(C)));
      await assertFails(setDoc(doc(dbOf(D), jp(D)), jr(C)));
      await assertFails(setDoc(doc(dbOf(D), jp(D)), jr(D, { createdAt: Timestamp.fromMillis(5) })));
      await assertFails(setDoc(doc(dbOf(D), jp(D)), jr(D, { extra: 1 })));
    });
    it("full group (20) denied", async () => {
      await seed({ memberIds: users(20), adminIds: [A] });
      await assertFails(setDoc(doc(dbOf(D), jp(D)), jr(D)));
      await seed({ memberIds: users(19), adminIds: [A] });
      await assertSucceeds(setDoc(doc(dbOf(D), jp(D)), jr(D)));
    });
    it("cannot be updated; requester cannot read others; admin can get/list; member non-admin cannot list", async () => {
      await assertSucceeds(setDoc(doc(dbOf(D), jp(D)), jr(D)));
      await assertFails(updateDoc(doc(dbOf(D), jp(D)), { code: CODE }));
      await assertFails(getDoc(doc(dbOf(C), jp(D))));
      await assertFails(getDoc(doc(dbOf("eve"), jp(D))));
      await assertSucceeds(getDoc(doc(dbOf(A), jp(D))));
      await assertSucceeds(getDocs(collection(dbOf(A), `${gp()}/joinRequests`)));
      await assertFails(getDocs(collection(dbOf(B), `${gp()}/joinRequests`)));
      await assertFails(getDocs(collection(dbOf(D), `${gp()}/joinRequests`)));
    });
    it("owner cancels; admin deletes; others cannot", async () => {
      await assertSucceeds(setDoc(doc(dbOf(D), jp(D)), jr(D)));
      await assertFails(deleteDoc(doc(dbOf(B), jp(D))));
      await assertSucceeds(deleteDoc(doc(dbOf(D), jp(D))));
      await assertSucceeds(setDoc(doc(dbOf(D), jp(D)), jr(D)));
      await assertSucceeds(deleteDoc(doc(dbOf(A), jp(D))));
    });
    it("approve batch by admin: add member + delete request + system 'added'", async () => {
      await assertSucceeds(setDoc(doc(dbOf(D), jp(D)), jr(D)));
      const db = dbOf(A);
      const b = writeBatch(db);
      b.update(doc(db, gp()), { memberIds: arrayUnion(D), updatedAt: serverTimestamp() });
      b.delete(doc(db, jp(D)));
      b.set(doc(db, `${gp()}/messages/ad1`), sys("ad1", A, "added", D));
      await assertSucceeds(b.commit());
      await assertSucceeds(getDoc(doc(dbOf(D), gp())));
    });
    it("approve batch by non-admin denied", async () => {
      await assertSucceeds(setDoc(doc(dbOf(D), jp(D)), jr(D)));
      const db = dbOf(B);
      const b = writeBatch(db);
      b.update(doc(db, gp()), { memberIds: arrayUnion(D), updatedAt: serverTimestamp() });
      b.delete(doc(db, jp(D)));
      b.set(doc(db, `${gp()}/messages/ad1`), sys("ad1", B, "added", D));
      await assertFails(b.commit());
    });
    it("requester cannot self-add via conversation update", async () => {
      await assertFails(updateDoc(doc(dbOf(D), gp()), { memberIds: arrayUnion(D), updatedAt: serverTimestamp() }));
    });
  });

  describe("storage", () => {
    const bytes = (n: number) => new Uint8Array(n);
    const p = (f = "a.png") => `groupAvatars/${GID}/${f}`;
    beforeEach(() => seed());
    it("admin upload ok; member upload denied; non-member denied", async () => {
      await assertSucceeds(uploadBytes(ref(stOf(A), p()), bytes(100), { contentType: "image/png" }));
      await assertFails(uploadBytes(ref(stOf(B), p("b.png")), bytes(100), { contentType: "image/png" }));
      await assertFails(uploadBytes(ref(stOf(D), p("d.png")), bytes(100), { contentType: "image/png" }));
      await assertFails(uploadBytes(ref(stOf(null), p("n.png")), bytes(100), { contentType: "image/png" }));
    });
    it("wrong type / oversize denied; webp/jpeg ok", async () => {
      await assertFails(uploadBytes(ref(stOf(A), p("a.gif")), bytes(100), { contentType: "image/gif" }));
      await assertFails(uploadBytes(ref(stOf(A), p("a.png")), bytes(5 * 1024 * 1024 + 1), { contentType: "image/png" }));
      await assertSucceeds(uploadBytes(ref(stOf(A), p("a.webp")), bytes(100), { contentType: "image/webp" }));
      await assertSucceeds(uploadBytes(ref(stOf(A), p("a.jpg")), bytes(100), { contentType: "image/jpeg" }));
    });
    it("read: members only; delete: admin only", async () => {
      await assertSucceeds(uploadBytes(ref(stOf(A), p()), bytes(100), { contentType: "image/png" }));
      await assertSucceeds(getBytes(ref(stOf(B), p())));
      await assertFails(getBytes(ref(stOf(D), p())));
      await assertFails(deleteObject(ref(stOf(B), p())));
      await assertSucceeds(deleteObject(ref(stOf(A), p())));
    });
    it("admin of another group / nonexistent group cannot write", async () => {
      await assertFails(uploadBytes(ref(stOf(A), `groupAvatars/${GID2}/a.png`), bytes(10), { contentType: "image/png" }));
    });
    it("chatMedia in group: member ok, non-member denied, read by members only", async () => {
      const m = `chatMedia/${GID}/${B}/f1`;
      await assertSucceeds(uploadBytes(ref(stOf(B), m), bytes(100), { contentType: "image/jpeg" }));
      await assertFails(uploadBytes(ref(stOf(D), `chatMedia/${GID}/${D}/f2`), bytes(100), { contentType: "image/jpeg" }));
      await assertSucceeds(getBytes(ref(stOf(C), m)));
      await assertFails(getBytes(ref(stOf(D), m)));
    });
  });
});
