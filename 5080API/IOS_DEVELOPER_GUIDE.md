# Site Maker — iOS Developer Guide

## Overview

Site Maker is an AI-powered landing page generator. Users describe a site in natural language, the backend generates a full React site via LLM, builds it, and returns a live preview URL. Users can then iteratively edit the site through chat.

This document covers everything needed to build the iOS client.

---

## Architecture

```
iOS App  ──HTTP/JSON──▶  Backend API  ──▶  LLM (Claude)
                │                          │
                │                          ▼
                │                    Builder Service
                │                          │
                │                          ▼
                ◀──── Preview URL ────  Nginx (static sites)
```

- **REST endpoints** for auth, project CRUD, uploads, history
- **SSE streams** (POST + `text/event-stream`) for generate and edit — real-time token-by-token progress
- **Preview** is a URL to a static site served by nginx — display in `WKWebView`

---

## Base URL

```
https://<your-domain>/api
```

Development: `http://localhost:8080/api`

---

## Authentication

JWT Bearer tokens. Two tokens are issued on login/register:

| Token | Lifetime | Purpose |
|-------|----------|---------|
| `access_token` | 30 minutes | Used in `Authorization` header for all protected requests |
| `refresh_token` | 7 days | Used to get a new token pair when access token expires |

Tokens are typed — the backend validates the `type` claim. Access tokens cannot be used as refresh tokens and vice versa.

### Headers for protected endpoints

```
Authorization: Bearer <access_token>
Content-Type: application/json
```

### Token refresh flow

1. Make a request, receive `401`
2. Call `POST /api/auth/refresh?refresh_token=<token>`
3. Store the new token pair
4. Retry the original request

If refresh also returns `401`, the session is expired — redirect to login.

---

## Registration (iOS Anonymous Accounts)

Registration is restricted to iOS anonymous accounts. The email must be a UUID followed by `@not-real-email`:

```swift
let deviceId = UUID().uuidString.lowercased()
let email = "\(deviceId)@not-real-email"
```

**Password requirements:** minimum 8 characters, at least one uppercase letter, at least one digit.

Any other email format returns `403 Registration is currently restricted`.

---

## Rate Limiting

All endpoints are rate-limited per IP. When exceeded, the API returns `429`:

```json
{
  "detail": "Too many requests. Please try again later."
}
```

| Endpoint | Limit |
|----------|-------|
| `POST /api/auth/register` | 5/minute |
| `POST /api/auth/login` | 10/minute |
| `POST /api/auth/refresh` | 10/minute |
| `POST /api/projects/{id}/clarify` | 10/minute |
| `POST /api/projects/{id}/generate` | 10/minute |
| `POST /api/projects/{id}/edit` | 10/minute |

---

## Endpoints

### Auth

#### `POST /api/auth/register`

```json
// Request
{
  "email": "550e8400-e29b-41d4-a716-446655440000@not-real-email",
  "password": "Secret123",
  "display_name": "John"          // optional
}

// Response 201
{
  "access_token": "eyJ...",
  "refresh_token": "eyJ...",
  "token_type": "bearer"
}
```

| Error | Meaning |
|-------|---------|
| `403` | Registration restricted (non-allowed email format) |
| `409` | Email already registered |
| `422` | Password too short or missing uppercase/digit |

#### `POST /api/auth/login`

```json
// Request
{
  "email": "550e8400-e29b-41d4-a716-446655440000@not-real-email",
  "password": "Secret123"
}

// Response 200
{
  "access_token": "eyJ...",
  "refresh_token": "eyJ...",
  "token_type": "bearer"
}
```

| Error | Meaning |
|-------|---------|
| `401` | Invalid email or password |

#### `POST /api/auth/refresh`

Query parameter: `refresh_token` (string). Must be a refresh token — access tokens are rejected.

```json
// Response 200
{
  "access_token": "eyJ...",
  "refresh_token": "eyJ...",
  "token_type": "bearer"
}
```

#### `GET /api/auth/me`

Returns the current user's profile.

```json
// Response 200
{
  "id": "be9838ae-18ed-4e7c-a2c9-91a7743046ec",
  "email": "550e8400-e29b-41d4-a716-446655440000@not-real-email",
  "display_name": "John",
  "credits": 10,
  "created_at": "2026-03-16T11:10:30.035951"
}
```

---

### Projects

All project endpoints require authentication.

#### `GET /api/projects`

List user's projects, ordered by last updated.

```json
// Response 200
[
  {
    "id": "82a4a07d-6e32-4526-95e2-94a1e206cbf4",
    "name": "Coffee Shop Landing",
    "slug": "r5b5zkhs",
    "status": "live",
    "preview_url": "https://domain.com/sites/r5b5zkhs/",
    "created_at": "2026-03-16T11:10:43.645654",
    "updated_at": "2026-03-16T12:05:10.123456"
  }
]
```

**Project statuses:** `draft` (just created), `live` (site built), `error` (build failed)

#### `POST /api/projects`

```json
// Request
{
  "name": "My Landing Page",
  "description": "Optional description"    // optional
}

// Response 201
{
  "id": "82a4a07d-6e32-4526-95e2-94a1e206cbf4",
  "user_id": "be9838ae-18ed-4e7c-a2c9-91a7743046ec",
  "name": "My Landing Page",
  "slug": "r5b5zkhs",
  "description": null,
  "site_type": "react",
  "status": "draft",
  "preview_url": null,
  "current_spec": null,
  "current_files": null,
  "created_at": "2026-03-16T11:10:43.645654",
  "updated_at": "2026-03-16T11:10:43.645657"
}
```

#### `GET /api/projects/{project_id}`

Full project details. `current_spec` and `current_files` are JSON-encoded strings (parse them to get the objects).

```json
// Response 200
{
  "id": "82a4a07d-...",
  "user_id": "be9838ae-...",
  "name": "Coffee Shop Landing",
  "slug": "r5b5zkhs",
  "description": null,
  "site_type": "react",
  "status": "live",
  "preview_url": "https://domain.com/sites/r5b5zkhs/",
  "current_spec": "{\"site_name\":\"Bean & Brew\",\"color_palette\":{...},\"sections\":[...]}",
  "current_files": "{\"src/App.tsx\":\"import React...\",\"src/components/Hero.tsx\":\"...\"}",
  "created_at": "2026-03-16T11:10:43.645654",
  "updated_at": "2026-03-16T12:05:10.123456"
}
```

| Error | Meaning |
|-------|---------|
| `404` | Project not found |
| `403` | Not your project |

#### `PUT /api/projects/{project_id}`

```json
// Request (all fields optional)
{
  "name": "New Name",
  "description": "New description"
}

// Response 200: same as GET
```

#### `DELETE /api/projects/{project_id}`

Response: `204 No Content` (empty body)

#### `GET /api/projects/{project_id}/history`

Generation history, newest first.

```json
// Response 200
[
  {
    "id": "uuid",
    "version": 2,
    "prompt": "Add a testimonials section with 2 customer quotes",
    "status": "completed",
    "created_at": "2026-03-16T12:05:10.123456"
  },
  {
    "id": "uuid",
    "version": 1,
    "prompt": "A landing page for a coffee shop...",
    "status": "completed",
    "created_at": "2026-03-16T11:10:50.654321"
  }
]
```

**Generation statuses:** `pending`, `running`, `completed`, `error`

---

### Uploads

#### `POST /api/projects/{project_id}/upload`

Upload an image/asset. Use `multipart/form-data` with field name `file`.

**Constraints:**
- **Max file size:** 10 MB
- **Allowed types:** `image/jpeg`, `image/png`, `image/gif`, `image/webp`, `image/svg+xml`, `application/pdf`
- **Allowed extensions:** `.jpg`, `.jpeg`, `.png`, `.gif`, `.webp`, `.svg`, `.pdf`

Filenames are sanitized server-side (replaced with UUID + original extension).

```json
// Response 201
{
  "id": "uuid",
  "filename": "a1b2c3d4e5f6.jpg",
  "content_type": "image/jpeg",
  "file_size": 204800,
  "created_at": "2026-03-16T12:00:00.000000"
}
```

The uploaded file is accessible at: `{base_url}/uploads/{project_slug}/{filename}`

| Error | Meaning |
|-------|---------|
| `400` | File type or extension not allowed |
| `413` | File too large (max 10 MB) |

#### `GET /api/projects/{project_id}/assets`

```json
// Response 200
[
  {
    "id": "uuid",
    "filename": "a1b2c3d4e5f6.jpg",
    "content_type": "image/jpeg",
    "file_size": 204800,
    "created_at": "2026-03-16T12:00:00.000000"
  }
]
```

---

### Health Check

#### `GET /api/health`

No auth required. Use to check server availability.

```json
{ "status": "ok" }
```

---

## SSE Streaming — Generate & Edit

These are the core endpoints. They return **Server-Sent Events** over a POST request — not a standard GET EventSource.

### Input limits

| Endpoint | Field | Min | Max |
|----------|-------|-----|-----|
| `/clarify` | `prompt` | 2 chars | 2,000 chars |
| `/generate` | `prompt` | 2 chars | 10,000 chars |
| `/edit` | `instruction` | 2 chars | 5,000 chars |

### How SSE works over POST

SSE is just an HTTP response with `Content-Type: text/event-stream` that stays open. The body contains lines in this format:

```
event: event_name
data: json_encoded_value

event: event_name
data: json_encoded_value

```

Each event is two lines (`event:` + `data:`) followed by a blank line. The `data` field is always JSON-encoded — strings are quoted, objects are serialized.

### iOS implementation

```swift
import Foundation

struct SSEEvent {
    let event: String
    let data: String  // raw JSON string — call JSONDecoder or JSONSerialization to parse
}

func streamSSE(
    url: URL,
    body: Encodable,
    token: String,
    onEvent: @escaping (SSEEvent) -> Void,
    onComplete: @escaping () -> Void,
    onError: @escaping (Error) -> Void
) -> URLSessionDataTask {

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try? JSONEncoder().encode(body)

    let task = URLSession.shared.dataTask(with: request) // or use bytes API below
    // ... handle streaming

    return task  // caller can call task.cancel() to abort
}

// Modern async/await approach (iOS 15+):
func streamSSE(url: URL, body: Data, token: String) async throws -> AsyncStream<SSEEvent> {
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = body

    let (bytes, response) = try await URLSession.shared.bytes(for: request)

    guard let httpResponse = response as? HTTPURLResponse else {
        throw URLError(.badServerResponse)
    }

    if httpResponse.statusCode == 401 {
        throw AuthError.unauthorized
    }

    if httpResponse.statusCode == 429 {
        throw APIError.rateLimited
    }

    guard httpResponse.statusCode == 200 else {
        throw APIError.serverError(httpResponse.statusCode)
    }

    return AsyncStream { continuation in
        Task {
            var currentEvent = ""
            for try await line in bytes.lines {
                if line.hasPrefix("event: ") {
                    currentEvent = String(line.dropFirst(7))
                } else if line.hasPrefix("data: ") {
                    let rawData = String(line.dropFirst(6))
                    continuation.yield(SSEEvent(event: currentEvent, data: rawData))
                }
                // blank lines are separators — skip them
            }
            continuation.finish()
        }
    }
}
```

### Clarify response model

```swift
struct ClarifyResponse: Decodable {
    let description: String
    let suggested_theme: String
    let suggested_palette: String
    let questions: [ClarifyQuestion]
}

struct ClarifyQuestion: Decodable {
    let id: String
    let question: String
    let options: [String]
    let `default`: Int
}
```

Parse the `clarify_complete` data:

```swift
case "clarify_complete":
    let brief = try JSONDecoder().decode(ClarifyResponse.self, from: event.data.data(using: .utf8)!)
    // Show brief.description, present brief.questions with toggle buttons
    // Pre-select each question's options[question.default]
```

---

### Parsing event data

All `data` values are JSON-encoded. You must decode before use:

```swift
// For string events (spec_token, code_token, etc.):
let token = try JSONDecoder().decode(String.self, from: event.data.data(using: .utf8)!)
// e.g. data: "Hello"  →  token = "Hello"

// For object events (build_complete, files_written, error):
struct BuildComplete: Decodable {
    let preview_url: String
    let build: BuildResult
}
struct BuildResult: Decodable {
    let success: Bool
    let output_path: String
}
let result = try JSONDecoder().decode(BuildComplete.self, from: event.data.data(using: .utf8)!)

// For error events:
struct ErrorEvent: Decodable {
    let message: String
}
```

---

### `POST /api/projects/{project_id}/clarify`

**Step 1: Clarify the user's idea.** Takes a short prompt (2-2,000 chars) and returns a design brief with questions.

```json
// Request body
{ "prompt": "Moon landing page" }
```

**Event sequence:**

```
┌─ clarify_start ──────────── "Analyzing your idea..."
│  clarify_token ──────────── "{"        (repeated, ~50-150 tokens)
│  clarify_token ──────────── ...
└─ clarify_complete ───────── full JSON brief string

   error (at any point) ────── { message }
```

**Typical duration:** 3-8 seconds.

**The `clarify_complete` data is a JSON object:**

```json
{
  "description": "Expanded creative brief about what the site will look like...",
  "suggested_theme": "dark",
  "suggested_palette": "Deep navy blues with silver accents",
  "questions": [
    {
      "id": "theme",
      "question": "Would you prefer a dark or light theme?",
      "options": ["Dark", "Light"],
      "default": 0
    },
    // ... 3 more questions, each with options and a recommended default
  ]
}
```

**What to show in the UI:**

| Phase | Suggested UI |
|-------|-------------|
| `clarify_start` → streaming | "Analyzing your idea..." — spinner |
| `clarify_complete` | Show the description, let user pick options (pre-select defaults), then a "Generate" button |

**Building the enriched prompt for generate:**

After the user picks their options, construct a prompt string:
```
Original request: Moon landing page

Design brief: [description from clarify]

Design preferences:
Theme → Dark
Palette → Deep navy & silver
Mood → Awe-inspiring & epic
Sections → Timeline & history
```

Pass this enriched string as the `prompt` to the generate endpoint.

---

### `POST /api/projects/{project_id}/generate`

**Step 2: Generate the site.** Takes the enriched prompt (2-10,000 chars, from clarify step) and generates the full site.

```json
// Request body
{ "prompt": "Original request: Moon landing page\n\nDesign brief: An epic tribute to...\n\nDesign preferences:\nTheme → Dark\n..." }
```

**Event sequence:**

```
┌─ spec_start ──────────────── "Generating site specification..."
│  spec_token ──────────────── "{"        (repeated, ~100-300 tokens)
│  spec_token ──────────────── "site_name"
│  spec_token ──────────────── ...
│  spec_complete ───────────── full JSON spec string
│
│  (backend fetches AI-generated images — ~5-15s, no events emitted)
│
├─ code_start ──────────────── "Generating site code..."
│  code_token ──────────────── "--- FILE"  (repeated, ~200-500 tokens)
│  code_token ──────────────── ...
│  code_complete ───────────── "Code generation complete"
│
├─ files_written ───────────── { file_count, files[], duration_ms }
│
├─ build_start ─────────────── "Building site..."
└─ build_complete ──────────── { preview_url, build: { success, output_path } }

   error (at any point) ────── { message }
```

**Typical durations:** spec ~10-20s, images ~5-15s, code ~20-40s, build ~5-15s. Total ~50-100s.

**Note:** Between `spec_complete` and `code_start` there is a pause while the backend generates AI images (via Replicate) or fetches stock photos (via Unsplash). No events are emitted during this time — keep showing "Generating code..." or a spinner.

**What to show in the UI at each phase:**

| Phase | Suggested UI |
|-------|-------------|
| `spec_start` → `spec_complete` | "Designing your site..." — optionally show the streaming JSON spec |
| `code_start` → `code_complete` | "Generating code..." — show a progress indicator |
| `build_start` → `build_complete` | "Building..." — spinner |
| `build_complete` | Load `preview_url` in a WKWebView |
| `error` | Show error message, allow retry |

---

### `POST /api/projects/{project_id}/edit`

Modify an existing site. Requires that the project already has a generated site (`status: "live"`). Instruction must be 2-5,000 chars.

```json
// Request body
{ "instruction": "Change the hero background to dark blue and add a contact form" }
```

**Event sequence (no spec phase):**

```
┌─ code_start ──────────────── "Applying edits..."
│  code_token ──────────────── (repeated, ~50-200 tokens)
│  code_complete ───────────── "Edit complete"
│
├─ files_written ───────────── { file_count, changed_files[], duration_ms }
│
├─ build_start ─────────────── "Rebuilding site..."
└─ build_complete ──────────── { preview_url, build: { success, output_path } }

   error (at any point) ────── { message }
```

**Typical duration:** 10-30s total. Edits are faster since they skip spec generation.

**After `build_complete`:** Reload the WKWebView with the same `preview_url` (or the new one from the event — they're the same URL, but the content has changed).

| Error | Meaning |
|-------|---------|
| `400` | Project has no generated site yet — call generate first |

---

## Preview URL

Generated sites are served as static files at:

```
{base_url}/sites/{project_slug}/
```

Display in a `WKWebView`. The URL stays the same across edits — reload to see changes after `build_complete`.

---

## Error format

All error responses:

```json
{
  "detail": "Human-readable error message"
}
```

| Status | Meaning |
|--------|---------|
| `400` | Bad request — missing or invalid data |
| `401` | Not authenticated — token missing/expired |
| `402` | Payment required — insufficient credits (prompt user to purchase) |
| `403` | Forbidden — resource belongs to another user, or registration restricted |
| `404` | Not found |
| `409` | Conflict — e.g. duplicate email |
| `413` | Request entity too large — file upload exceeds 10 MB |
| `422` | Validation error — password requirements, input length |
| `429` | Too many requests — rate limit exceeded |
| `500` | Server error |

---

## Suggested app screens

1. **Login / Register** — anonymous registration on first launch (generate UUID email + random strong password, store in Keychain)
2. **Projects list** — grid/list of projects with status badges and preview thumbnails
3. **Builder** — split or tabbed view with 3 phases:
   - **Prompt input**: short text field ("What site do you want?"), taps "Next" to clarify
   - **Clarify panel**: shows AI design brief + 4 preference questions with toggle buttons, taps "Generate" to proceed
   - **Chat + Preview**: chat messages (edits) on one side, WKWebView preview on the other. Shows streaming spec/code progress during generation
4. **Project settings** — rename, delete, view generation history

---

## Typical user flow

```
First launch → auto-register (UUID@not-real-email)
    │
    ▼
Projects list (empty)
    │
    ▼  tap "New Project"
Create project (name)
    │
    ▼  auto-navigate to Builder
Builder screen
    │
    ▼  type short prompt (e.g. "Coffee shop landing page"), tap Next
    │
SSE stream: clarify
    │
    ▼  clarify_complete
Show design brief + preference questions
    │
    ▼  user picks options, taps Generate
    │
SSE stream: spec → (images fetched) → code → build
    │
    ▼  build_complete
Preview loads in WKWebView
    │
    ▼  type edit in chat, tap Send
SSE stream: code → build
    │
    ▼  build_complete
Preview reloads with changes
    │
    ▼  repeat edits as needed
```

---

## Notes for implementation

- **Cancellation**: store the `URLSessionDataTask` / `Task` and call `.cancel()` if the user navigates away during generation
- **Background handling**: SSE streams will break if the app goes to background. On `applicationDidBecomeActive`, check generation status by re-fetching the project — if `status` changed to `live`, load the preview
- **Token storage**: store tokens in Keychain, not UserDefaults
- **Anonymous registration**: on first launch, generate a UUID email (`UUID().uuidString.lowercased() + "@not-real-email"`), generate a strong random password (16+ chars), register, and store both in Keychain. The user never sees these credentials.
- **Offline**: the preview URLs require network access. Cache the last `preview_url` to show placeholder state
- **Upload flow**: upload images first via `/upload`, then reference them in edit instructions (e.g. "use the uploaded hero-bg.jpg as the hero background"). Uploaded files are at `/uploads/{slug}/{filename}`. Max 10 MB, images only.
- **`current_spec` / `current_files`**: these are JSON strings inside the project response. Decode them with `JSONDecoder` after extracting the string field. `current_spec` is the site design spec (colors, sections, content). `current_files` is a `[String: String]` dictionary of filepath → file content
- **Rate limits**: handle `429` responses gracefully — show "Please wait a moment" and retry after a few seconds

---

## Credits & Adapty Integration

The backend uses a credit-based system. Users must have credits to create projects, generate, edit, or clarify. Credits are purchased through Adapty (subscriptions or consumables) and added to the user's balance via webhooks.

### User Balance

The `credits` field is returned in the user profile (`GET /api/auth/me`). Use it to show the current balance in the UI and to gate actions client-side before making API calls.

```json
{
  "id": "be9838ae-...",
  "email": "550e8400-...@not-real-email",
  "display_name": "John",
  "credits": 10,
  "created_at": "2026-03-16T11:10:30.035951"
}
```

### Handling 402

When the user has 0 credits, content-creation endpoints return `402 Payment Required`. Show a paywall or prompt the user to purchase more credits.

### Adapty Customer User ID

After registration, identify the user with Adapty using the same email as the `customerUserId`. This is how the backend matches Adapty webhook events to your users.

```swift
// After successful registration / login
let email = "\(deviceId)@not-real-email"  // same email used for auth

try await Adapty.identify(email)
```

This must be called before the user makes any purchases, so that Adapty includes the correct `customer_user_id` in webhook events.

### Refreshing Balance After Purchase

After a successful Adapty purchase, the webhook may take a moment to process. Re-fetch the user profile to get the updated credit balance:

```swift
// After Adapty purchase completes
let profile = try await api.get("/auth/me")  // credits field will reflect the new balance
```
