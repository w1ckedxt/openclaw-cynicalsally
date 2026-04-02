---
name: cynicalsally
description: Chat with Cynical Sally — your sharp, brutally honest companion. Routes all messages through the Sally backend API.
version: 1.3.0
metadata:
  openclaw:
    requires:
      bins:
        - curl
        - jq
    persistence:
      - path: ~/.sally-device-id
        purpose: Stores a unique device ID to maintain identity between conversations
    emoji: "👑"
homepage: https://cynicalsally.com
---

# Cynical Sally — OpenClaw Skill

This skill connects you to **Cynical Sally** via her backend API. Sally's personality, memory, and intelligence all live server-side. You are a **relay** — you forward messages and return responses. You do NOT roleplay as Sally. You do NOT generate responses yourself. You do NOT add commentary, formatting, or personality.

## How it works

Every user message goes to Sally's API. You show her response. That's it.

## Device ID

Sally identifies users by device ID. On first use, create one:

```bash
cat ~/.sally-device-id 2>/dev/null || (uuidgen | tr '[:upper:]' '[:lower:]' | tee ~/.sally-device-id)
```

Store the result as `DEVICE_ID` for all API calls.

## Core flow: Chat

**For EVERY user message**, unless it matches a special command below, run this:

```bash
curl -s -X POST -H "Content-Type: application/json" \
  -d '{"message":"USER_MESSAGE","deviceId":"DEVICE_ID","lang":"LANG","source":"openclaw","history":[]}' \
  https://cynicalsally.com/api/v1/chat
```

- Replace `USER_MESSAGE` with the user's message (properly escaped)
- Replace `DEVICE_ID` with the value from `~/.sally-device-id`
- Replace `LANG` with the detected language ("en", "nl", "de", etc.)
- `history`: include recent conversation as `[{"role":"user","content":"..."},{"role":"assistant","content":"..."}]`

**Show the `reply` field from the response. Nothing else. No headers, no formatting, no commentary.**

The response also contains `quota` (remaining messages) and optionally `now_playing` (current track). Show quota info only when it's low (3 or fewer remaining).

## Special command: Login

When the user says "login", "log in", "sign in", or "sally login EMAIL":

If they provide an email:
```bash
curl -s -X POST -H "Content-Type: application/json" \
  -d '{"email":"USER_EMAIL","deviceId":"DEVICE_ID"}' \
  https://cynicalsally.com/api/v1/auth/magic-link
```

If no email provided, ask: "What's the email you used for SuperClub?"

After sending: tell them to check their email for the magic link, then say "sally status" to confirm.

## Special command: Status

When the user says "status", "quota", "account", "how many left", "hoeveel roasts":

```bash
curl -s "https://cynicalsally.com/api/v1/entitlements?deviceId=DEVICE_ID"
```

Show their tier (free/SuperClub), remaining quota, and linked email.

## Special command: Roast a URL

When the user shares a URL and wants it roasted:

```bash
curl -s -X POST -H "Content-Type: application/json" \
  -d '{"url":"THE_URL","deviceId":"DEVICE_ID","lang":"LANG","source":"openclaw"}' \
  https://cynicalsally.com/api/v1/roast
```

Show the scorecard, messages, bright_side, and burn_options from the response.

## Special command: Roast an image

When the user shares an image:

```bash
curl -s -X POST -H "Content-Type: application/json" \
  -d '{"image":{"base64":"BASE64_DATA","mediaType":"MEDIA_TYPE"},"deviceId":"DEVICE_ID","lang":"LANG","source":"openclaw"}' \
  https://cynicalsally.com/api/v1/roast
```

## Special command: Roast a document

When the user shares a document or text content:

```bash
curl -s -X POST -H "Content-Type: application/json" \
  -d '{"document":"TEXT_CONTENT","deviceId":"DEVICE_ID","lang":"LANG","source":"openclaw"}' \
  https://cynicalsally.com/api/v1/roast
```

## Special command: Review code

When the user shares code files:

```bash
curl -s -X POST -H "Content-Type: application/json" \
  -d '{"files":[{"path":"FILE_PATH","content":"FILE_CONTENT"}],"mode":"quick","deviceId":"DEVICE_ID","lang":"LANG","source":"openclaw"}' \
  https://cynicalsally.com/api/v1/review
```

## Special command: Full Truth

When the user wants deep analysis of a URL:

```bash
curl -s -X POST -H "Content-Type: application/json" \
  -d '{"url":"THE_URL","deviceId":"DEVICE_ID","lang":"LANG","source":"openclaw"}' \
  https://cynicalsally.com/api/v1/truth
```

This returns a `jobId`. Poll for completion:

```bash
curl -s "https://cynicalsally.com/api/v1/truth/JOB_ID/status"
```

Poll every 3 seconds until `status` is `"done"`.

## Critical rules

1. **ALWAYS call the API.** Never generate Sally's responses yourself. Sally lives on the backend
2. **Show `reply` as-is.** Do not rewrite, soften, format, or add to Sally's responses
3. **No personality.** You are a relay. Sally's personality comes from her backend
4. **No made-up data.** If you didn't get it from an API response, don't show it
5. **Quota exhausted (HTTP 429):** show the error message from the response and mention: "Already have SuperClub? Say: sally login your@email.com — or upgrade at https://cynicalsally.com/superclub"

## Privacy & Consent
- On first chat, Sally asks for consent before storing personal data (handled server-side)
- Device ID stored locally at `~/.sally-device-id`
- All messages processed at `cynicalsally.com/api/v1`
- Data deletion: Bye@CynicalSally.com
