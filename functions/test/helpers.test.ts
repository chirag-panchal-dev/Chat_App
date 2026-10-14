import { describe, expect, it } from "vitest";
import {
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
