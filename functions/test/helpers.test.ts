import { describe, expect, it } from "vitest";
import {
  isQuietHours,
  buildPushPayload as buildPayloadForQuiet,
  buildGroupPushPayload as buildGroupPayloadForQuiet,
  QUIET_CHANNEL_ID,
  buildGroupPushBody, buildGroupPushPayload, isSystemMessage, selectGroupRecipients, removeMemberFromGroup, isOrphanCleanupCandidate,
  buildPushBody, buildPushPayload, buildSummaryPreview, isInvalidTokenErrorCode, isMuted,
  isNewerThanSummary, isOlderThan, isRecentAuth, pushSkipReason, resolveSettings, selectRecipient, truncate,
} from "../src/helpers";

describe("preview", () => {
  it("truncates to 80 chars", () => {
    const p = buildSummaryPreview({ type: "text", text: "a".repeat(200) });
    expect(Array.from(p).length).toBe(80);
    expect(p.endsWith("…")).toBe(true);
  });
  it("collapses whitespace", () => expect(truncate("a \n\n b")).toBe("a b"));
  it("image => Photo", () => expect(buildSummaryPreview({ type: "image", text: "cap" })).toBe("Photo"));
  it("voice => Voice message", () => expect(buildSummaryPreview({ type: "voice" })).toBe("Voice message"));
  it("voice push bodies (direct + group), and hidden when previews are off", () => {
    expect(buildPushBody({ type: "voice" }, true)).toBe("Sent a voice message");
    expect(buildPushBody({ type: "voice" }, false)).toBe("New message");
    expect(buildGroupPushBody({ type: "voice" }, "Ann", true)).toBe("Ann: Voice message");
    expect(buildGroupPushBody({ type: "voice" }, "Ann", false)).toBe("New message");
  });
  it("push body respects preview setting", () => {
    expect(buildPushBody({ type: "text", text: "hi" }, true)).toBe("hi");
    expect(buildPushBody({ type: "text", text: "hi" }, false)).toBe("New message");
    expect(buildPushBody({ type: "image" }, true)).toBe("Sent a photo");
    expect(buildPushBody({ type: "image", text: "secret" }, false)).toBe("New message");
  });
});

describe("recipient", () => {
  it("picks other member", () => {
    expect(selectRecipient(["a", "b"], "a")).toBe("b");
    expect(selectRecipient(["a", "b"], "b")).toBe("a");
  });
  it("rejects non-members and malformed lists", () => {
    expect(selectRecipient(["a", "b"], "c")).toBeNull();
    expect(selectRecipient(["a"], "a")).toBeNull();
    expect(selectRecipient(["a", "a"], "a")).toBeNull();
    expect(selectRecipient("ab", "a")).toBeNull();
    expect(selectRecipient([1, 2], "1")).toBeNull();
  });
});

describe("mute / settings / skip", () => {
  it("isMuted", () => {
    expect(isMuted(2000, 1000)).toBe(true);
    expect(isMuted(1000, 1000)).toBe(false);
    expect(isMuted(null, 1000)).toBe(false);
    expect(isMuted(undefined, 1000)).toBe(false);
  });
  it("defaults", () => {
    expect(resolveSettings(undefined)).toEqual({ notificationEnabled: true, showMessagePreview: false });
    expect(resolveSettings({ notificationEnabled: false, showMessagePreview: true }))
      .toEqual({ notificationEnabled: false, showMessagePreview: true });
  });
  const base = { recipientBlockedSender: false, recipientDeleted: false, mutedUntilMillis: null,
    nowMillis: 1000, settings: {}, deviceCount: 1 };
  it("skip reasons", () => {
    expect(pushSkipReason(base)).toBeNull();
    expect(pushSkipReason({ ...base, recipientBlockedSender: true })).toBe("recipient-blocked-sender");
    expect(pushSkipReason({ ...base, recipientDeleted: true })).toBe("recipient-deleted");
    expect(pushSkipReason({ ...base, mutedUntilMillis: 5000 })).toBe("muted");
    expect(pushSkipReason({ ...base, settings: { notificationEnabled: false } })).toBe("notifications-disabled");
    expect(pushSkipReason({ ...base, deviceCount: 0 })).toBe("no-devices");
  });
});

describe("summary ordering", () => {
  it("only newer wins", () => {
    expect(isNewerThanSummary(10, "m", null, null)).toBe(true);
    expect(isNewerThanSummary(10, "m", 5, "x")).toBe(true);
    expect(isNewerThanSummary(5, "m", 10, "x")).toBe(false);
    expect(isNewerThanSummary(10, "b", 10, "a")).toBe(true);
    expect(isNewerThanSummary(10, "a", 10, "a")).toBe(false);
  });
});

describe("payload", () => {
  const p = buildPushPayload({ tokens: ["t1"], senderDisplayName: " Ann ", conversationId: "c1", body: "New message", channelId: "messages" });
  it("shape", () => {
    expect(p.notification).toEqual({ title: "Ann", body: "New message" });
    expect(p.data).toEqual({ conversationId: "c1", type: "message" });
    expect(p.android).toEqual({ priority: "high", notification: { channelId: "messages" } });
    expect(p.apns.payload.aps).toEqual({ sound: "default", "thread-id": "c1" });
  });
  it("falls back to Hushlo title and has no text in data", () => {
    const q = buildPushPayload({ tokens: [], senderDisplayName: null, conversationId: "c", body: "secret text", channelId: "messages" });
    expect(q.notification.title).toBe("Hushlo");
    expect(JSON.stringify(q.data)).not.toContain("secret");
  });
});

describe("token classification", () => {
  it("invalid codes", () => {
    for (const c of ["messaging/registration-token-not-registered", "messaging/invalid-argument", "messaging/invalid-registration-token"])
      expect(isInvalidTokenErrorCode(c)).toBe(true);
    expect(isInvalidTokenErrorCode("messaging/internal-error")).toBe(false);
    expect(isInvalidTokenErrorCode(undefined)).toBe(false);
  });
});

describe("recent auth / age", () => {
  it("isRecentAuth", () => {
    const now = 1_000_000_000_000;
    expect(isRecentAuth(now / 1000 - 60, now)).toBe(true);
    expect(isRecentAuth(now / 1000 - 301, now)).toBe(false);
    expect(isRecentAuth(undefined, now)).toBe(false);
    expect(isRecentAuth("1", now)).toBe(false);
  });
  it("isOlderThan", () => {
    const now = Date.parse("2026-01-10T00:00:00Z");
    expect(isOlderThan("2026-01-07T00:00:00Z", now, 48)).toBe(true);
    expect(isOlderThan("2026-01-09T00:00:00Z", now, 48)).toBe(false);
    expect(isOlderThan(undefined, now, 48)).toBe(false);
  });
});

describe("groups", () => {
  it("recipients: all members except sender, unique; none if sender not a member", () => {
    expect(selectGroupRecipients(["a", "b", "c"], "b")).toEqual(["a", "c"]);
    expect(selectGroupRecipients(["a", "b", "b"], "a")).toEqual(["b"]);
    expect(selectGroupRecipients(["a", "b"], "z")).toEqual([]);
    expect(selectGroupRecipients("ab", "a")).toEqual([]);
    expect(selectGroupRecipients([1, "a"], "a")).toEqual([]);
  });
  it("body", () => {
    expect(buildGroupPushBody({ type: "text", text: "hi" }, "Ann", true)).toBe("Ann: hi");
    expect(buildGroupPushBody({ type: "image" }, "Ann", true)).toBe("Ann: Photo");
    expect(buildGroupPushBody({ type: "text", text: "hi" }, "Ann", false)).toBe("New message");
    expect(buildGroupPushBody({ type: "text", text: "hi" }, null, true)).toBe("Someone: hi");
  });
  it("payload: title is group name, data minimal", () => {
    const p = buildGroupPushPayload({ tokens: ["t"], groupName: " Team ", conversationId: "g_x", body: "b", channelId: "m" });
    expect(p.notification).toEqual({ title: "Team", body: "b" });
    expect(p.data).toEqual({ conversationId: "g_x", type: "message" });
    expect(buildGroupPushPayload({ tokens: [], groupName: "", conversationId: "g", body: "b", channelId: "m" }).notification.title).toBe("Hushlo");
  });
  it("system messages detected", () => {
    expect(isSystemMessage({ type: "system" })).toBe(true);
    expect(isSystemMessage({ type: "text" })).toBe(false);
  });
  it("removeMemberFromGroup", () => {
    expect(removeMemberFromGroup(["a", "b", "c"], ["a"], "b")).toEqual({ memberIds: ["a", "c"], adminIds: ["a"] });
    expect(removeMemberFromGroup(["a", "b", "c"], ["a"], "a")).toEqual({ memberIds: ["b", "c"], adminIds: ["b"] });
    expect(removeMemberFromGroup(["a", "b", "c"], ["a", "c"], "a")).toEqual({ memberIds: ["b", "c"], adminIds: ["c"] });
    expect(removeMemberFromGroup(["a"], ["a"], "a")).toEqual({ memberIds: [], adminIds: [] });
  });
  it("orphan cleanup never targets groupAvatars", () => {
    expect(isOrphanCleanupCandidate("chatMedia/c/u/f")).toBe(true);
    expect(isOrphanCleanupCandidate("groupAvatars/g_x/f")).toBe(false);
    expect(isOrphanCleanupCandidate("avatars/u/f")).toBe(false);
  });
});

describe("quiet hours", () => {
  const at = (h: number, m = 0) => Date.UTC(2026, 0, 15, h, m);
  const q = (over: Record<string, unknown> = {}) => ({
    quietHoursEnabled: true, quietStartMin: 22 * 60, quietEndMin: 7 * 60, utcOffsetMin: 0, ...over,
  });

  it("off by default / when disabled / when malformed", () => {
    expect(isQuietHours(undefined, at(23))).toBe(false);
    expect(isQuietHours({}, at(23))).toBe(false);
    expect(isQuietHours(q({ quietHoursEnabled: false }), at(23))).toBe(false);
    expect(isQuietHours(q({ quietStartMin: "22:00" }), at(23))).toBe(false);
    expect(isQuietHours(q({ quietEndMin: 1440 }), at(23))).toBe(false);
    expect(isQuietHours(q({ quietStartMin: -1 }), at(23))).toBe(false);
    expect(isQuietHours(q({ utcOffsetMin: 99999 }), at(23))).toBe(false);
  });
  it("window crossing midnight", () => {
    expect(isQuietHours(q(), at(22, 0))).toBe(true);
    expect(isQuietHours(q(), at(23, 59))).toBe(true);
    expect(isQuietHours(q(), at(0, 0))).toBe(true);
    expect(isQuietHours(q(), at(6, 59))).toBe(true);
    expect(isQuietHours(q(), at(7, 0))).toBe(false);
    expect(isQuietHours(q(), at(12, 0))).toBe(false);
    expect(isQuietHours(q(), at(21, 59))).toBe(false);
  });
  it("same-day window", () => {
    const w = q({ quietStartMin: 13 * 60, quietEndMin: 14 * 60 });
    expect(isQuietHours(w, at(13, 0))).toBe(true);
    expect(isQuietHours(w, at(13, 59))).toBe(true);
    expect(isQuietHours(w, at(14, 0))).toBe(false);
    expect(isQuietHours(w, at(12, 59))).toBe(false);
  });
  it("start == end is empty", () => {
    expect(isQuietHours(q({ quietStartMin: 600, quietEndMin: 600 }), at(10, 0))).toBe(false);
  });
  it("uses the user's local time (offset in minutes)", () => {
    // 17:30 UTC is 23:00 in India (+330) -> quiet; in UTC it is not.
    expect(isQuietHours(q({ utcOffsetMin: 330 }), at(17, 30))).toBe(true);
    expect(isQuietHours(q({ utcOffsetMin: 0 }), at(17, 30))).toBe(false);
    // 03:00 UTC is 22:00 the previous day at UTC-5 -> quiet.
    expect(isQuietHours(q({ utcOffsetMin: -300 }), at(3, 0))).toBe(true);
    // negative offset wrapping below midnight: 08:00 UTC at UTC-8 is 00:00 local
    expect(isQuietHours(q({ utcOffsetMin: -480 }), at(8, 0))).toBe(true);
    expect(isQuietHours(q({ utcOffsetMin: -480 }), at(2, 0))).toBe(false); // 18:00 local
  });
  it("quiet payloads use the silent channel and drop the iOS sound", () => {
    const base = { tokens: ["t"], conversationId: "c", body: "b", channelId: "messages" };
    const loud = buildPayloadForQuiet({ ...base, senderDisplayName: "A" });
    const quiet = buildPayloadForQuiet({ ...base, senderDisplayName: "A", quiet: true });
    expect(loud.android.notification.channelId).toBe("messages");
    expect(loud.apns.payload.aps.sound).toBe("default");
    expect(quiet.android.notification.channelId).toBe(QUIET_CHANNEL_ID);
    expect(quiet.apns.payload.aps.sound).toBeUndefined();
    expect(quiet.data).toEqual({ conversationId: "c", type: "message" });
    const g = buildGroupPayloadForQuiet({ ...base, groupName: "G", quiet: true });
    expect(g.android.notification.channelId).toBe(QUIET_CHANNEL_ID);
    expect(g.apns.payload.aps.sound).toBeUndefined();
  });
});

describe("documents and videos", () => {
  it("summary previews never reveal file names", () => {
    expect(buildSummaryPreview({ type: "video" })).toBe("Video");
    expect(buildSummaryPreview({ type: "file", text: "secret.pdf" })).toBe("Document");
  });
  it("push bodies respect the preview setting", () => {
    expect(buildPushBody({ type: "video" }, false)).toBe("New message");
    expect(buildPushBody({ type: "video" }, true)).toBe("Sent a video");
    expect(buildPushBody({ type: "file" }, true)).toBe("Sent a document");
  });
  it("group push bodies", () => {
    expect(buildGroupPushBody({ type: "video" }, "Aarav", true)).toBe("Aarav: Video");
    expect(buildGroupPushBody({ type: "file" }, "Aarav", true)).toBe("Aarav: Document");
    expect(buildGroupPushBody({ type: "file" }, "Aarav", false)).toBe("New message");
  });
});
