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
  if (msg.type === "voice") return "Voice message";
  if (msg.type === "video") return "Video";
  if (msg.type === "file") return "Document";
  return typeof msg.text === "string" ? truncate(msg.text) : "";
}

/** Push body. Preview only if the recipient opted in. */
export function buildPushBody(msg: MessageLike, showMessagePreview: boolean): string {
  if (!showMessagePreview) return "New message";
  if (msg.type === "image") return "Sent a photo";
  if (msg.type === "voice") return "Sent a voice message";
  if (msg.type === "video") return "Sent a video";
  if (msg.type === "file") return "Sent a document";
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
  quietHoursEnabled?: unknown;
  quietStartMin?: unknown;
  quietEndMin?: unknown;
  utcOffsetMin?: unknown;
}

const isMinuteOfDay = (v: unknown): v is number => typeof v === "number" && Number.isInteger(v) && v >= 0 && v < 1440;

/**
 * True when the recipient's local time is inside their quiet-hours window.
 * Local time = UTC now + the offset the app last stored (minutes). The window
 * may cross midnight; start == end is empty; anything malformed means "not quiet".
 */
export function isQuietHours(s: RecipientSettings | undefined | null, nowMillis: number): boolean {
  if (!s || s.quietHoursEnabled !== true) return false;
  if (!isMinuteOfDay(s.quietStartMin) || !isMinuteOfDay(s.quietEndMin)) return false;
  const off = typeof s.utcOffsetMin === "number" && Number.isFinite(s.utcOffsetMin) ? s.utcOffsetMin : 0;
  if (Math.abs(off) > 840) return false;
  const start = s.quietStartMin;
  const end = s.quietEndMin;
  if (start === end) return false;
  const local = ((Math.floor(nowMillis / 60000) + Math.trunc(off)) % 1440 + 1440) % 1440;
  return start < end ? local >= start && local < end : local >= start || local < end;
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
    payload: { aps: { sound?: string; "thread-id": string } };
  };
}

/** Silent delivery during quiet hours: low-importance Android channel, no iOS sound. */
export const QUIET_CHANNEL_ID = "messages_quiet";

/** Builds the multicast payload. `data` never contains message text. */
export function buildPushPayload(opts: {
  tokens: string[];
  senderDisplayName: string | null | undefined;
  conversationId: string;
  body: string;
  channelId: string;
  quiet?: boolean;
}): PushPayload {
  const title =
    typeof opts.senderDisplayName === "string" && opts.senderDisplayName.trim() !== ""
      ? opts.senderDisplayName.trim()
      : "Hushlo";
  return {
    tokens: opts.tokens,
    notification: { title, body: opts.body },
    data: { conversationId: opts.conversationId, type: "message" },
    android: { priority: "high", notification: { channelId: opts.quiet ? QUIET_CHANNEL_ID : opts.channelId } },
    apns: {
      payload: {
        aps: opts.quiet
          ? { "thread-id": opts.conversationId }
          : { sound: "default", "thread-id": opts.conversationId },
      },
    },
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

// ---------------------------------------------------------------------------
// Groups
// ---------------------------------------------------------------------------

export const MAX_GROUP_MEMBERS = 20;

/** System (event) messages never push and never update the summary. */
export function isSystemMessage(msg: MessageLike): boolean {
  return msg.type === "system";
}

/** Group push recipients: every unique string member except the sender; [] if sender is not a member. */
export function selectGroupRecipients(memberIds: unknown, senderId: string): string[] {
  if (!Array.isArray(memberIds) || !memberIds.every((m) => typeof m === "string")) return [];
  const members = memberIds as string[];
  if (!members.includes(senderId)) return [];
  return Array.from(new Set(members)).filter((m) => m !== senderId);
}

/** Group push body: `${sender}: ${text}` / `${sender}: Photo` when previews are on, else 'New message'. */
export function buildGroupPushBody(
  msg: MessageLike,
  senderDisplayName: string | null | undefined,
  showMessagePreview: boolean
): string {
  if (!showMessagePreview) return "New message";
  const name =
    typeof senderDisplayName === "string" && senderDisplayName.trim() !== "" ? senderDisplayName.trim() : "Someone";
  if (msg.type === "image") return `${name}: Photo`;
  if (msg.type === "voice") return `${name}: Voice message`;
  if (msg.type === "video") return `${name}: Video`;
  if (msg.type === "file") return `${name}: Document`;
  const t = typeof msg.text === "string" ? truncate(msg.text, 120) : "";
  return t.length > 0 ? `${name}: ${t}` : "New message";
}

/** Group multicast payload: title = group name; `data` is only {conversationId, type}. */
export function buildGroupPushPayload(opts: {
  tokens: string[];
  groupName: string | null | undefined;
  conversationId: string;
  body: string;
  channelId: string;
  quiet?: boolean;
}): PushPayload {
  const title =
    typeof opts.groupName === "string" && opts.groupName.trim() !== "" ? opts.groupName.trim() : "Hushlo";
  return {
    tokens: opts.tokens,
    notification: { title, body: opts.body },
    data: { conversationId: opts.conversationId, type: "message" },
    android: { priority: "high", notification: { channelId: opts.quiet ? QUIET_CHANNEL_ID : opts.channelId } },
    apns: {
      payload: {
        aps: opts.quiet
          ? { "thread-id": opts.conversationId }
          : { sound: "default", "thread-id": opts.conversationId },
      },
    },
  };
}

/**
 * Result of removing `uid` from a group (account deletion): drops uid from members/admins;
 * if no admin is left, promotes the first remaining member (memberIds order).
 */
export function removeMemberFromGroup(
  memberIds: unknown,
  adminIds: unknown,
  uid: string
): { memberIds: string[]; adminIds: string[] } {
  const members = (Array.isArray(memberIds) ? (memberIds as string[]) : []).filter((m) => m !== uid);
  let admins = (Array.isArray(adminIds) ? (adminIds as string[]) : []).filter((m) => m !== uid && members.includes(m));
  if (admins.length === 0 && members.length > 0) admins = [members[0]];
  return { memberIds: members, adminIds: admins };
}

/** Only chatMedia/ objects are orphan-cleaned; groupAvatars/ (and everything else) never. */
export function isOrphanCleanupCandidate(objectName: string): boolean {
  return objectName.startsWith("chatMedia/");
}
