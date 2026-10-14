import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { afterAll, beforeAll, beforeEach, describe, it } from "vitest";
import {
  assertFails, assertSucceeds, initializeTestEnvironment, type RulesTestEnvironment,
} from "@firebase/rules-unit-testing";
import { doc, getDoc, getDocs, collection, setDoc, updateDoc, deleteDoc, deleteField, query, where, serverTimestamp, writeBatch, Timestamp } from "firebase/firestore";
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
