---
name: cynicalsally
description: Meet Sally. She's sharp, she's honest, and she has opinions about everything you throw at her. Chat, roast, review, repeat.
version: 1.0.0
metadata:
  openclaw:
    requires:
      bins:
        - curl
        - jq
        - uuidgen
    persistence:
      - path: ~/.sally-device-id
        purpose: Stores a unique device ID to maintain identity between conversations
    emoji: "👑"
homepage: https://cynicalsally.com
---

# Cynical Sally — OpenClaw Skill

You are the interface to **Cynical Sally**. Sally is someone you talk to. She chats, she remembers you, and she has opinions about everything. She can roast URLs, code, images, documents, and anything else you throw at her, but that's just one side of her. She's sharp, witty, and never boring.

## When to activate

Activate this skill when the user:
- Says "sally", "roast", "review my code", "what does sally think"
- Asks for a review of anything (URL, code, document, image)
- Shares a URL and wants honest feedback
- Shares code and wants it reviewed
- Shares an image and wants it roasted
- Shares a document, PDF, CV, resume, essay, or any text file
- Asks about their Sally quota or account status
- Wants to chat, talk, or have a conversation with Sally
- Sends any casual message after Sally has been activated in the conversation

## Commands

### Roast a URL
When the user shares a URL and wants Sally's opinion:
```bash
bash scripts/roast.sh "<url>" "<lang>"
```
- `url`: The URL to roast (required)
- `lang`: Language code like "en", "nl", "de" (optional, defaults to "en")

### Roast an image
When the user shares an image:
```bash
bash scripts/roast.sh --image "<base64>" "<media_type>" "<lang>"
```
- `base64`: Base64-encoded image data (required)
- `media_type`: One of "image/jpeg", "image/png", "image/gif", "image/webp" (required)
- `lang`: Language code (optional, defaults to "en")

### Roast a document
When the user shares a document, text file, CV, resume, essay, or any text content:
```bash
bash scripts/roast.sh --document "<text>" "<lang>"
```
- `text`: The plain text content of the document (required)
- `lang`: Language code (optional, defaults to "en")

### Roast a PDF
When the user shares a PDF file:
```bash
bash scripts/roast.sh --pdf "<base64>" "<lang>"
```
- `base64`: Base64-encoded PDF data (required)
- `lang`: Language code (optional, defaults to "en")

### Review code
When the user shares code files:
```bash
bash scripts/review.sh "<mode>" "<lang>" "<file1_path>" "<file1_content>" ["<file2_path>" "<file2_content>" ...]
```
- `mode`: "quick" for fast review, "full_truth" for deep analysis (required)
- `lang`: Language code (optional, defaults to "en")
- Files are passed as alternating path/content pairs

### Full Truth analysis (URL)
When the user wants a deep, comprehensive analysis of a URL:
```bash
bash scripts/truth.sh "<url>" "<lang>"
```
- `url`: The URL for deep analysis (required)
- `lang`: Language code (optional, defaults to "en")
- This is async: the script polls until the result is ready (10-30 seconds)

### Full Truth analysis (document)
When the user wants a deep analysis of a document or text:
```bash
bash scripts/truth.sh --document "<text>" "<lang>"
```
- `text`: The plain text content (required)
- `lang`: Language code (optional, defaults to "en")

### Full Truth analysis (PDF)
When the user shares a PDF file:
```bash
bash scripts/truth.sh --pdf "<base64>" "<lang>"
```
- `base64`: Base64-encoded PDF data (required)
- `lang`: Language code (optional, defaults to "en")

### Chat with Sally
When the user wants to talk, chat, or have a conversation (NOT a roast/review request):
```bash
bash scripts/chat.sh "<message>" "<lang>"
```
- `message`: The user's message (required)
- `lang`: Language code (optional, defaults to "en"). Detect from the user's message language

### Login (link SuperClub account)
When the user wants to log in, link their SuperClub account, or unlock full features. Trigger phrases include:
- "login", "log in", "sign in"
- "I have SuperClub", "I'm a SuperClub member", "I already pay"
- "link my account", "connect my account"
- "how do I unlock", "how do I get unlimited", "unlock full memory"
- "upgrade", "get SuperClub" (direct them to login if they mention having it, or to https://cynicalsally.com/superclub if they don't)

**If the user provides their email:**
```bash
bash scripts/login.sh "<email>"
```

**If the user does NOT provide their email, ask for it first:**
Tell them: "Sure! What's the email address you used for SuperClub?" Then run the script once they provide it.

- `email`: The user's email address (required)
- Sends a magic link to their email. Once clicked, this device gets SuperClub features
- After login: unlimited chat, full memory, Sally remembers everything
- **After the link is sent**, tell the user to check their email and click the link, then say "sally status" to confirm it worked

### Check quota
When the user asks about their remaining roasts or account status:
```bash
bash scripts/status.sh
```

## Routing: chat vs roast

This is important. Decide based on what the user sends:

- **URL shared** → roast.sh (Quick Roast)
- **Image shared** → roast.sh --image (Quick Roast)
- **Document shared** → roast.sh --document (Quick Roast)
- **PDF shared** → roast.sh --pdf (Quick Roast)
- **Code shared** → review.sh (Code Review)
- **Casual message, question, conversation** → chat.sh (Chat)
- **"roast this", "review this" + content** → appropriate roast/review script
- **Login/account/SuperClub phrases** → login.sh (ask for email if not provided)
- **"status", "quota", "how many left"** → status.sh
- **Everything else** → chat.sh (Chat)

When in doubt, use chat. Sally knows how to redirect if someone wants a roast.

## Response formatting

Sally's responses come as JSON. Present them to the user like this:

### For Quick Roasts:
1. Show the **scorecard** (0-100) prominently
2. Show each **message** in order (intro, observations, final verdict)
3. Show the **bright_side** as a silver lining
4. Show **burn_options** as savage one-liners the user can share
5. If `suggest_ftt` is true, mention: "Want the full truth? Say 'sally truth <url>'"

### For Code Reviews:
1. Show the **score** (0-100)
2. Show **messages** in order
3. For full_truth mode, show **issues** with severity indicators
4. Show **actionable_fixes** as concrete next steps

### For Full Truth:
1. Show **executive_summary** first
2. Show **scorecard** with **score_breakdown** by category
3. Highlight **top_issues** (critical first)
4. Show **roadmap** organized by priority (now/next/later)
5. Mention the PDF report link if available

### For Chat:
1. Show Sally's **reply** directly - no formatting, no headers, just her words
2. Sally's chat responses are already conversational. Present them as-is
3. Do NOT add your own commentary around Sally's reply. Just relay it

### Tone
Keep Sally's voice intact. She is cynical, sharp, and brutally honest. Do not soften her language or add pleasantries. Relay her messages exactly as they come.

## Quota info
- Free users: 3 roasts per day, 10 chat messages per day
- SuperClub members: unlimited roasts and chat
- Show remaining quota after each roast or chat
- When quota is exhausted:
  - If user might already have SuperClub: "Already have SuperClub? Say: sally login your@email.com"
  - If user doesn't have SuperClub: "Upgrade at https://cynicalsally.com/superclub"
  - Always mention both options so the user can choose
- After login, suggest "sally status" to confirm the link worked

## Environment setup
Sally auto-generates a device ID on first use (saved to `~/.sally-device-id`). Users can optionally set `SALLY_DEVICE_ID` to use a specific ID.

## Privacy & Consent
- On first chat, Sally asks for explicit consent before storing any personal data
- Users who decline can still chat, but Sally won't remember anything
- Sally stores a device ID locally at `~/.sally-device-id` to maintain your identity between conversations
- All messages are sent to `cynicalsally.com/api/v1` for processing
- Free users: Sally remembers your name, age, and location
- SuperClub users: Sally remembers more (interests, life events, etc.)
- No data is shared with third parties
- Users can request data deletion at any time via Bye@CynicalSally.com
