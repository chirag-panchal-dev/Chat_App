// Pure helpers: no firebase imports, no network. Unit-tested in test/helpers.test.ts.

export const MAX_PREVIEW_LENGTH = 80;
export const REAUTH_WINDOW_SECONDS = 5 * 60;

export interface MessageLike {
  type?: unknown;
  text?: unknown;
}

/** Collapse whitespace and truncate to `max` chars (with ellipsis). */
export function truncate(s: string, max = MAX_PREVIEW_LENGTH): string {
  const clean = s.replace(/\s+/g, " ").trim();
  const chars = Array.from(clean); // code-point safe
  if (chars.length <= max) return clean;
  return chars.slice(0, max - 1).join("").trimEnd() + "…";
}

/** Conversation-list preview (<= 80 chars). Images => 'Photo'. */
export function buildSummaryPreview(msg: MessageLike): string {
  if (msg.type === "image") return "Photo";
  return typeof msg.text === "string" ? truncate(msg.text) : "";
}

/** Push body. Preview only if the recipient opted in. */
export function buildPushBody(msg: MessageLike, showMessagePreview: boolean): string {
  if (!showMessagePreview) return "New message";
  if (msg.type === "image") return "Sent a photo";
  const t = typeof msg.text === "string" ? truncate(msg.text, 120) : "";
  return t.length > 0 ? t : "New message";
}

/** The other participant of a 2-person conversation, or null if sender is not a member. */
export function selectRecipient(memberIds: unknown, senderId: string): string | null {
  if (!Array.isArray(memberIds) || memberIds.length !== 2) return null;
  if (!memberIds.every((m) => typeof m === "string")) return null;
  const [a, b] = memberIds as string[];
  if (a === b) return null;
  if (a === senderId) return b;
  if (b === senderId) return a;
  return null;
}

/** Muted when mutedUntil (ms since epoch) is in the future. */
export function isMuted(mutedUntilMillis: number | null | undefined, nowMillis: number): boolean {
  return typeof mutedUntilMillis === "number" && mutedUntilMillis > nowMillis;
}

export interface RecipientSettings {
  notificationEnabled?: unknown;
  showMessagePreview?: unknown;
}

/** Defaults: notifications on, previews OFF (privacy-first) when unset. */
export function resolveSettings(s: RecipientSettings | undefined | null): {
  notificationEnabled: boolean;
  showMessagePreview: boolean;
} {
  return {
    notificationEnabled: s?.notificationEnabled !== false,
    showMessagePreview: s?.showMessagePreview === true,
  };
}

/** True if this message is strictly newer than the current conversation summary. */
export function isNewerThanSummary(
  msgMillis: number,
  msgId: string,
  currentMillis: number | null | undefined,
  currentId: string | null | undefined
): boolean {
  if (typeof currentMillis !== "number") return true;
  if (msgMillis !== currentMillis) return msgMillis > currentMillis;
  return typeof currentId !== "string" || msgId > currentId;
}

export type SkipReason =
  | "recipient-blocked-sender"
  | "recipient-deleted"
  | "muted"
  | "notifications-disabled"
  | "no-devices";

export function pushSkipReason(opts: {
  recipientBlockedSender: boolean;
  recipientDeleted: boolean;
  mutedUntilMillis: number | null | undefined;
  nowMillis: number;
  settings: RecipientSettings | undefined | null;
  deviceCount: number;
}): SkipReason | null {
  if (opts.recipientBlockedSender) return "recipient-blocked-sender";
  if (opts.recipientDeleted) return "recipient-deleted";
  if (isMuted(opts.mutedUntilMillis, opts.nowMillis)) return "muted";
  if (!resolveSettings(opts.settings).notificationEnabled) return "notifications-disabled";
  if (opts.deviceCount === 0) return "no-devices";
  return null;
}

export interface PushPayload {
  tokens: string[];
  notification: { title: string; body: string };
  data: { conversationId: string; type: "message" };
  android: {
    priority: "high";
    notification: { channelId: string };
  };
  apns: {
    payload: { aps: { sound: string; "thread-id": string } };
  };
}

/** Builds the multicast payload. `data` never contains message text. */
export function buildPushPayload(opts: {
  tokens: string[];
  senderDisplayName: string | null | undefined;
  conversationId: string;
  body: string;
  channelId: string;
}): PushPayload {
  const title =
    typeof opts.senderDisplayName === "string" && opts.senderDisplayName.trim() !== ""
      ? opts.senderDisplayName.trim()
      : "Hushlo";
  return {
    tokens: opts.tokens,
    notification: { title, body: opts.body },
    data: { conversationId: opts.conversationId, type: "message" },
    android: { priority: "high", notification: { channelId: opts.channelId } },
    apns: { payload: { aps: { sound: "default", "thread-id": opts.conversationId } } },
  };
}

const INVALID_TOKEN_CODES = new Set([
  "messaging/registration-token-not-registered",
  "messaging/invalid-argument",
  "messaging/invalid-registration-token",
]);

/** True when the FCM error means the token should be deleted. */
export function isInvalidTokenErrorCode(code: string | undefined | null): boolean {
  return typeof code === "string" && INVALID_TOKEN_CODES.has(code);
}

/** True if auth_time (seconds since epoch) is within the reauth window. */
export function isRecentAuth(authTimeSeconds: unknown, nowMillis: number): boolean {
  if (typeof authTimeSeconds !== "number" || !Number.isFinite(authTimeSeconds)) return false;
  const ageSeconds = nowMillis / 1000 - authTimeSeconds;
  return ageSeconds >= -60 && ageSeconds <= REAUTH_WINDOW_SECONDS;
}

/** True if a stored object is older than `hours`. */
export function isOlderThan(timeCreatedIso: string | undefined, nowMillis: number, hours: number): boolean {
  if (!timeCreatedIso) return false;
  const t = Date.parse(timeCreatedIso);
  if (Number.isNaN(t)) return false;
  return nowMillis - t > hours * 3600 * 1000;
}
