# wyreframe-playground (recovered scaffold)

The original `wyreframe-playground` GitHub repo was deleted; this scaffold was
reconstructed on 2026-06-12 from Cloudflare-side artifacts.

See `recovery-notes.md` for the full inventory of what was recovered, what was
lost, and how each piece was retrieved.

## Layout

- `frontend/` — Vite + ReScript + React SPA. Deployed as a Cloudflare Pages
  project (`wyreframe-playground`, domains: `wyreframe.studio`,
  `wyreframe-playground.pages.dev`).
- `backend/` — Cloudflare Worker (`wyreframe-backend`) routed at
  `wyreframe.studio/api/*`. ReScript compiled via Vite + esbuild, deployed via
  `wrangler deploy`.
- `_recovered/` — raw artifacts pulled from Cloudflare (deployed bundles,
  schemas, config). Reference only, gitignored.

## Status of each piece

| Piece | State | Source |
| --- | --- | --- |
| Backend bundle (`Index.js`, 375 KB) | full | `wrangler init --from-dash` |
| Backend `wrangler.jsonc` | full | same |
| Backend file tree (13 modules) | names only | bundle source-path comments |
| Backend secrets | **lost** | Cloudflare does not expose values |
| Frontend bundle (`index-*.js/css`) | full | live site |
| Frontend file tree | partial | Vite minified module names |
| D1 schema | full | `wrangler d1 execute` |
| D1 data | empty (0 rows in app tables) | same |
| R2 bucket `wyreframe-assets` | empty (0 objects) | `wrangler r2 bucket info` |
| KV `SESSION_KV` | 2 keys (transient) | `wrangler kv key list` |

## Next steps

1. Reinstall dependencies in `frontend/` and `backend/`.
2. Re-author the ReScript modules listed in each `src/` tree. Use the bundle
   files under `_recovered/` as a reference (they are minified but readable).
3. Recreate the secrets in Cloudflare:
   - `ANTHROPIC_API_KEY` (likely the most critical)
   - any Langfuse / OAuth secrets
4. Reapply the D1 migration in `backend/migrations/0001_initial.sql`.
