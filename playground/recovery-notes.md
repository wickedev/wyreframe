# Recovery notes — 2026-06-12

## What was recovered

### Backend (Cloudflare Worker `wyreframe-backend`)

Pulled with `wrangler init --from-dash wyreframe-backend` (via
`create-cloudflare@2.50.0 --type=pre-existing --existing-script=...`).
Newer `create-cloudflare` versions reject `--type=pre-existing`; pin to
2.50.0 if you need to repull.

- `src/Index.js` (375 KB, bundled) — the deployed worker, minified but
  readable. Built from ReScript via Vite/esbuild with `unenv` Node compat.
- `wrangler.jsonc` — full config including:
  - route `wyreframe.studio/api/*`
  - vars: `ANTHROPIC_BASE_URL`, `LANGFUSE_BASE_URL`, `ENVIRONMENT`
  - R2 binding `ASSETS` → `wyreframe-assets`
  - D1 binding `DB` → `74509cf6-7f08-46a3-beed-452a580fdccc`
  - KV binding `SESSION_KV` → `065fd9abde394f2a977790854ad3f340`
  - `nodejs_compat`, observability + logs enabled, `upload_source_maps: true`
- ReScript module tree (from bundle `// lib/es6/src/...` comments):

  ```
  src/
    Index.mjs
    bindings/
      AnthropicSDK.mjs
      Langfuse.mjs
    core/Types.mjs
    lib/
      ErrorHandler.mjs
      SecurityUtils.mjs
      SSEStream.mjs
    prompts/WireframeAssistant.mjs
    routes/
      Chat.mjs
      Issues.mjs
      Monitoring.mjs
      OAuth.mjs
      Sessions.mjs
  ```

- API surface inferred from bundle + live probe:
  - `GET /api/status` → `{status, tokenCount, activeTokens, timestamp}`
  - `GET /api/tokens`, `POST /api/tokens/manual`, `/api/tokens/...`
  - `POST /api/auth/start` (OAuth flow)
  - `/api/chat` (SSE streaming — see `SSEStream.res`)
  - `/api/sessions`
  - `/api/issues/report`
  - `/api/usage/...`
  - `/api/monitoring/health|metrics|ready|live`
  - All unknown routes → JSON `{error:"NotFound", message, statusCode:404}`
- Framework: `hono` with `cors()` middleware and a custom metrics middleware.

### Frontend (Cloudflare Pages `wyreframe-playground`)

- All 5 deployed assets (live URL):
  - `index.html`, `favicon.svg`, `animations/empty-state.json` (Lottie)
  - `assets/index-BeStZnIN.js` (1.03 MB)
  - `assets/index-eMvltrb1.css` (100 KB)
- Tech stack confirmed from bundle:
  - ReScript + React (`make$N` identifiers, `Provider$1.make` patterns)
  - Vite build (hashed asset names, single entry)
  - Monaco editor (lazy-loaded from `cdn.jsdelivr.net`)
  - Radix UI primitives (Dialog, Portal, Select, Collection, RovingFocus, etc.)
  - React Router (`BrowserRouter`)
  - lucide-react icons
  - Tailwind + shadcn/ui (token classes: `.bg-card`, `.bg-popover`,
    `.text-primary`, `.border-input`, etc.)
  - Lottie web for animations
- Two ReScript module names survived minification: `Types.res`,
  `Primitive_module.res`. The rest are erased — names below are inferred from
  React component identifiers preserved in the bundle.
- Likely page/layout components: `LandingPage`, `PlaygroundLayout`, `Header`,
  `ErrorBoundary`, `LazyMonacoEditor`.
- UI strings preserved in bundle (originally localized; translated to English):
  - "Or sign in with OAuth locally:"
  - "Add an OAuth token above"
  - "OAuth only works on localhost"
- Built-in prompt examples preserved:
  - "Build a user profile card with avatar, name, bio, stats, and action buttons"
  - "Design a pricing table with 3 tiers: Free, Pro, and Enterprise with feature comparisons"
- Theme presets referenced: "Apple Human Interface", "Alibaba Ant Design".

### D1 (`74509cf6-7f08-46a3-beed-452a580fdccc`)

Full schema captured in `backend/migrations/0001_initial.sql`. Tables:
`sessions`, `chat_messages`, `exports`, `_migrations`. App tables are empty.

### R2 (`wyreframe-assets`)

Empty — 0 objects.

### KV (`SESSION_KV`)

2 keys at recovery time: `metrics:current` and one expiring
`session:<hash>`. Nothing worth restoring.

### Deployment history

22+ production deployments recorded on Cloudflare side, with commit hashes
and (truncated) commit messages. Most recent: `43249bb` — "refactor:
migrate from Claudius to official Anthropic SDK" (2026-02-07).

## What was lost

- All `.res` source files — only the compiled bundle remains.
- Cloudflare Worker source maps — `upload_source_maps: true` is set but the
  uploaded maps are not exposed via the public API; the
  `workers/scripts/.../source-map` endpoint returns the script, not the map.
- Secret values (Anthropic API key, OAuth secrets, etc.) — Cloudflare never
  exposes secret values back, by design.
- Build tooling config (vite.config, rescript.json) — inferred from the
  bundle output, not directly recovered.

## How to repull

```sh
# Backend
cd /tmp
npx create-cloudflare@2.50.0 wyreframe-backend \
  --type=pre-existing --existing-script=wyreframe-backend \
  --lang=ts --no-git --no-deploy

# Frontend deployed assets
for f in /index.html /favicon.svg /assets/index-BeStZnIN.js \
         /assets/index-eMvltrb1.css /animations/empty-state.json; do
  curl -sLO "https://wyreframe.studio$f"
done

# D1 schema
cd backend && npx wrangler d1 execute DB --remote \
  --command "SELECT sql FROM sqlite_master WHERE type='table'"
```
