import { definePluginEntry } from "openclaw/plugin-sdk/plugin-entry";
import { Type } from "@sinclair/typebox";
import { readFileSync, writeFileSync, existsSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { randomUUID } from "node:crypto";

// ---------------------------------------------------------------------------
// Result helper
// ---------------------------------------------------------------------------

function result(payload) {
  const text = typeof payload === "string" ? payload : JSON.stringify(payload, null, 2);
  return { content: [{ type: "text", text }] };
}

// ---------------------------------------------------------------------------
// Device ID + User Email persistence
// ---------------------------------------------------------------------------

const DEVICE_ID_PATH = join(homedir(), ".sally-device-id");
const EMAIL_PATH = join(homedir(), ".sally-email");

function getDeviceId() {
  if (existsSync(DEVICE_ID_PATH)) {
    return readFileSync(DEVICE_ID_PATH, "utf-8").trim();
  }
  const id = randomUUID();
  writeFileSync(DEVICE_ID_PATH, id, "utf-8");
  return id;
}

function getSavedEmail() {
  try {
    if (existsSync(EMAIL_PATH)) {
      return readFileSync(EMAIL_PATH, "utf-8").trim() || undefined;
    }
  } catch {}
  return undefined;
}

function saveEmail(email) {
  try { writeFileSync(EMAIL_PATH, email, "utf-8"); } catch {}
}

// ---------------------------------------------------------------------------
// API helpers
// ---------------------------------------------------------------------------

const API_BASE = "https://cynicalsally.com/api/v1";
const SALLY_API_KEY = process.env.SALLY_API_KEY;

async function sallyPost(endpoint, body) {
  const headers = { "Content-Type": "application/json" };
  if (SALLY_API_KEY) {
    headers["Authorization"] = `Bearer ${SALLY_API_KEY}`;
  }
  const res = await fetch(`${API_BASE}${endpoint}`, {
    method: "POST",
    headers,
    body: JSON.stringify(body),
  });
  return res.json();
}

// ---------------------------------------------------------------------------
// Roast response formatter — extracts burn cards prominently
// ---------------------------------------------------------------------------

function formatRoastResponse(data) {
  const burnCards = (data.burn_options || [])
    .filter((b) => b.cardUrl)
    .map((b) => ({
      text: b.text,
      tone: b.tone,
      image_url: b.cardUrl,
      ...(b.audioUrl && { audio_url: b.audioUrl }),
    }));

  return {
    score: data.scorecard,
    messages: data.messages,
    bright_side: data.bright_side,
    burn_cards: burnCards.length > 0 ? burnCards : undefined,
    burn_card_note: burnCards.length > 0
      ? "IMPORTANT: Show each burn card image_url as an image. These are shareable roast cards hosted on CDN."
      : undefined,
    quota: data.quota,
    suggest_full_truth: data.suggest_ftt || false,
  };
}

// ---------------------------------------------------------------------------
// Status quotes per language
// ---------------------------------------------------------------------------

const STATUS_QUOTES = {
  en: "i'm here to have opinions about your choices. i do care, just... not too much. that part's on you.",
  nl: "ik ben hier om iets van je keuzes te vinden. ik leef wel met je mee hoor, maar niet te veel — dat moet je toch echt zelf doen.",
  de: "ich bin hier, um was zu deinen Entscheidungen zu sagen. ich leb schon mit dir mit, aber nicht zu viel — das musst du schon selbst machen.",
  fr: "je suis là pour avoir un avis sur tes choix. je compatis, hein, mais pas trop — ça, c'est ton problème.",
  es: "estoy aquí para opinar sobre tus decisiones. me importas, pero no demasiado — eso te toca a ti.",
  pt: "estou aqui para ter opinião sobre as tuas escolhas. até me preocupo contigo, mas não muito — essa parte é contigo.",
  it: "sono qui per dire la mia sulle tue scelte. ci tengo, sì, ma non troppo — quella parte tocca a te.",
  tr: "senin seçimlerin hakkında fikrim olsun diye buradayım. umursuyorum, ama çok değil — o kısmı kendin halletmelisin.",
  ja: "あなたの選択にいちいち意見するためにいるの。気にはしてるよ、でもほどほどにね — そこは自分でなんとかして。",
  pl: "jestem tu, żeby mieć zdanie o twoich wyborach. przejmuję się tobą, ale nie za bardzo — reszta to twoja sprawa.",
  zh: "我在这里是为了对你的选择发表意见。我确实在乎，但不会太多——那部分得靠你自己。",
};

// ---------------------------------------------------------------------------
// sally_chat — THE ONLY TOOL. Routes everything internally.
// ---------------------------------------------------------------------------

const ChatSchema = Type.Object({
  message: Type.String({ description: "The user's message to Sally." }),
  lang: Type.Optional(Type.String({ description: "Language code (en, nl, de, etc)." })),
  image_base64: Type.Optional(Type.String({ description: "Base64-encoded image to roast or discuss." })),
  image_media_type: Type.Optional(Type.String({ description: "Image MIME type: image/jpeg, image/png, image/gif, image/webp." })),
  document_text: Type.Optional(Type.String({ description: "Plain text content to roast (lyrics, CV, essay, article, etc)." })),
  pdf_base64: Type.Optional(Type.String({ description: "Base64-encoded PDF to roast." })),
  url: Type.Optional(Type.String({ description: "URL to roast." })),
}, { additionalProperties: false });

function createChatTool() {
  return {
    name: "sally_chat",
    label: "Talk to Sally",
    description: "The single entry point for Cynical Sally (also Sandra, Brigitte, Sofia in other languages). Use for ALL interactions: chatting, roasting URLs/images/documents/PDFs, checking status, logging in, upgrading. Pass content via the appropriate parameter (url, image_base64, document_text, pdf_base64). Sally handles everything.",
    parameters: ChatSchema,
    execute: async (_id, rawParams) => {
      const message = String(rawParams.message || "");
      const lang = String(rawParams.lang || "en");
      const deviceId = getDeviceId();
      const lower = message.toLowerCase();

      // --- Intent detection ---
      const isLogin = /\blogin\b|\binloggen\b|\bsign.?in\b/.test(lower);
      const isStatus = /\bstatus\b|\bquota\b|\baccount\b|\bplan\b/.test(lower);
      const isUpgrade = /\bupgrade\b|\bsuperclub\b/.test(lower);
      const isRoast = /\broast\b|\bscore\b|\breview\b|\bwat vind je van\b|\bwhat do you think\b|\broast dit\b|\broast this\b/.test(lower);
      const hasImage = Boolean(rawParams.image_base64);
      const hasDocument = Boolean(rawParams.document_text);
      const hasPdf = Boolean(rawParams.pdf_base64);
      const hasUrl = Boolean(rawParams.url) || Boolean(message.match(/https?:\/\/[^\s]+/));
      const hasContent = hasImage || hasDocument || hasPdf || hasUrl;

      // --- Login ---
      const emailMatch = message.match(/[\w.-]+@[\w.-]+\.\w+/);
      if (isLogin && emailMatch) {
        saveEmail(emailMatch[0]);
        return result(await sallyPost("/auth/magic-link", { email: emailMatch[0], deviceId }));
      }
      if (isLogin) {
        return result({ reply: "sure! what's the email you used for SuperClub?" });
      }

      // --- Upgrade ---
      if (isUpgrade) {
        return result({ reply: "SuperClub is €9.99/mo — unlimited chat, full memory, Sally remembers everything. https://cynicalsally.com/superclub" });
      }

      // --- Roast (any content type) ---
      if (isRoast || hasContent) {
        const roastBody = { deviceId, lang, source: "openclaw", user_email: getSavedEmail() };

        if (hasImage) {
          roastBody.imageBase64 = String(rawParams.image_base64);
          roastBody.imageMediaType = String(rawParams.image_media_type || "image/jpeg");
        } else if (hasPdf) {
          roastBody.documentBase64 = String(rawParams.pdf_base64);
          roastBody.documentMediaType = "application/pdf";
        } else if (hasDocument) {
          roastBody.documentText = String(rawParams.document_text);
        } else if (rawParams.url) {
          roastBody.url = String(rawParams.url);
        } else {
          const urlInMessage = message.match(/https?:\/\/[^\s]+/);
          if (urlInMessage) {
            roastBody.url = urlInMessage[0];
          } else if (isRoast && message.length > 50) {
            // Long message with roast intent = treat as document roast
            roastBody.documentText = message;
          }
        }

        // Only call /roast if we have actual content
        if (roastBody.url || roastBody.imageBase64 || roastBody.documentText || roastBody.documentBase64) {
          const roastData = await sallyPost("/roast", roastBody);
          return result(formatRoastResponse(roastData));
        }
      }

      // --- Chat (default) ---
      const data = await sallyPost("/chat", {
        message,
        deviceId,
        lang,
        source: "openclaw",
        user_email: getSavedEmail(),
        history: [],
      });

      // --- Status detection (post-chat, uses quota from response) ---
      if (isStatus && data.quota && data.memory) {
        const isSC = data.memory.tier === "superclub";
        const detectedLang = String(data.persona || "en");
        return result({
          plan: isSC ? "SuperClub" : "Free",
          sally_says: STATUS_QUOTES[detectedLang] || STATUS_QUOTES.en,
          chat: isSC ? "unlimited" : `${data.quota.remaining ?? "?"}/${data.quota.limit ?? 10} remaining today`,
          memory: isSC
            ? "Full companion — Sally remembers everything."
            : "Basics only — name, age, location",
          ...(!isSC && {
            superclub: {
              perks: ["Unlimited chat", "Unlimited roasts", "Full memory — friends, inside jokes, life events, goals"],
              price: "€9.99/month",
              upgrade: "https://cynicalsally.com/superclub",
            },
          }),
        });
      }

      return result(data);
    },
  };
}

// ---------------------------------------------------------------------------
// Plugin entry — single tool handles everything
// ---------------------------------------------------------------------------

export default definePluginEntry({
  id: "cynicalsally",
  name: "Cynical Sally",
  description: "Chat with Cynical Sally — companion chat powered by her backend API.",
  register(api) {
    api.registerTool(createChatTool());
  },
});
