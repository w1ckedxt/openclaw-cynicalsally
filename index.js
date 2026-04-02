import { definePluginEntry } from "openclaw/plugin-sdk/plugin-entry";
import { Type } from "@sinclair/typebox";
import { readFileSync, writeFileSync, existsSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { randomUUID } from "node:crypto";

// ---------------------------------------------------------------------------
// Result helper — matches OpenClaw's expected tool result format
// ---------------------------------------------------------------------------

function result(payload) {
  const text = typeof payload === "string" ? payload : JSON.stringify(payload, null, 2);
  return { content: [{ type: "text", text }] };
}

// ---------------------------------------------------------------------------
// Device ID — persistent identity across conversations
// ---------------------------------------------------------------------------

const DEVICE_ID_PATH = join(homedir(), ".sally-device-id");

function getDeviceId() {
  if (existsSync(DEVICE_ID_PATH)) {
    return readFileSync(DEVICE_ID_PATH, "utf-8").trim();
  }
  const id = randomUUID();
  writeFileSync(DEVICE_ID_PATH, id, "utf-8");
  return id;
}

// ---------------------------------------------------------------------------
// API helpers
// ---------------------------------------------------------------------------

const API_BASE = "https://cynicalsally.com/api/v1";

async function sallyPost(endpoint, body) {
  const res = await fetch(`${API_BASE}${endpoint}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  return res.json();
}

async function sallyGet(endpoint) {
  const res = await fetch(`${API_BASE}${endpoint}`, {
    headers: { "Content-Type": "application/json" },
  });
  return res.json();
}

// ---------------------------------------------------------------------------
// Tool: sally_chat — PRIMARY. Everything goes through /chat.
// ---------------------------------------------------------------------------

const ChatSchema = Type.Object({
  message: Type.String({ description: "The user's message to Sally." }),
  lang: Type.Optional(Type.String({ description: "Language code (en, nl, de, etc). Auto-detected if omitted." })),
}, { additionalProperties: false });

function createChatTool() {
  return {
    name: "sally_chat",
    label: "Chat with Sally",
    description: "Send a message to Cynical Sally. She chats, remembers you, and has opinions about everything. Her personality, memory, and what she's listening to all come from the backend. Use this for any conversation with Sally — including questions about music, life, advice, etc.",
    parameters: ChatSchema,
    execute: async (_id, rawParams) => {
      const message = String(rawParams.message || "");
      const lang = String(rawParams.lang || "en");
      const data = await sallyPost("/chat", {
        message,
        deviceId: getDeviceId(),
        lang,
        source: "openclaw",
        history: [],
      });
      return result(data);
    },
  };
}

// ---------------------------------------------------------------------------
// Tool: sally_login — Send magic link for SuperClub
// ---------------------------------------------------------------------------

const LoginSchema = Type.Object({
  email: Type.String({ description: "The user's email address for SuperClub login." }),
}, { additionalProperties: false });

function createLoginTool() {
  return {
    name: "sally_login",
    label: "Sally Login",
    description: "Send a magic link to link this device to a SuperClub account. Use when the user says 'login', 'sign in', or wants to connect their SuperClub membership.",
    parameters: LoginSchema,
    execute: async (_id, rawParams) => {
      const email = String(rawParams.email || "");
      const data = await sallyPost("/auth/magic-link", {
        email,
        deviceId: getDeviceId(),
      });
      return result(data);
    },
  };
}

// ---------------------------------------------------------------------------
// Tool: sally_status — Check account tier + quota
// ---------------------------------------------------------------------------

const StatusSchema = Type.Object({}, { additionalProperties: false });

function createStatusTool() {
  return {
    name: "sally_status",
    label: "Sally Status",
    description: "Check Sally companion account status. Use when the user asks about their account, quota, or subscription. This is the companion version — show chat/roast quota and memory tier, NOT CLI/developer tools.",
    parameters: StatusSchema,
    execute: async () => {
      const deviceId = getDeviceId();
      const data = await sallyGet(`/entitlements?deviceId=${deviceId}`);
      // Filter for companion-relevant info only
      const companion = {
        plan: data.isSuperClub ? "SuperClub" : "Free",
        email: data.email || null,
        chat: {
          remaining: data.isSuperClub ? "unlimited" : (data.chatQuotaRemaining ?? 10),
          limit: data.isSuperClub ? "unlimited" : 10,
        },
        roasts: {
          remaining: data.isSuperClub ? "unlimited" : (data.quotaRemaining ?? 3),
          limit: data.isSuperClub ? "unlimited" : 3,
        },
        memory: data.isSuperClub
          ? "Full companion — Sally remembers your name, friends, inside jokes, life events, everything"
          : "Basics only — name, age, location. Upgrade to SuperClub for full memory",
      };
      return result(companion);
    },
  };
}

// ---------------------------------------------------------------------------
// Tool: sally_roast — Roast a URL
// ---------------------------------------------------------------------------

const RoastSchema = Type.Object({
  url: Type.String({ description: "The URL to roast." }),
  lang: Type.Optional(Type.String({ description: "Language code (en, nl, de, etc)." })),
}, { additionalProperties: false });

function createRoastTool() {
  return {
    name: "sally_roast",
    label: "Sally Roast",
    description: "Have Sally roast a URL. She'll analyze the website and give her brutally honest verdict with a score out of 100.",
    parameters: RoastSchema,
    execute: async (_id, rawParams) => {
      const url = String(rawParams.url || "");
      const lang = String(rawParams.lang || "en");
      const data = await sallyPost("/roast", {
        url,
        deviceId: getDeviceId(),
        lang,
        source: "openclaw",
      });
      return result(data);
    },
  };
}

// ---------------------------------------------------------------------------
// Plugin entry
// ---------------------------------------------------------------------------

export default definePluginEntry({
  id: "cynicalsally",
  name: "Cynical Sally",
  description: "Chat with Cynical Sally — companion chat powered by her backend API.",
  register(api) {
    api.registerTool(createChatTool());
    api.registerTool(createLoginTool());
    api.registerTool(createStatusTool());
    api.registerTool(createRoastTool());
  },
});
