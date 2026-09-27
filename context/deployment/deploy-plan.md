---
project: t-sql-doradca
platform: Cloudflare Workers
deployed_at: 2026-09-27
deployed_by: pwojno@merinosoft.com.pl
---

# First Production Deploy — T-SQL Doradca

## What was done

First production deployment of T-SQL Doradca to Cloudflare Workers, executed manually via `wrangler` CLI per `context/foundation/infrastructure.md`'s recommendation. Full plan: `~/.claude/plans/cosmic-twirling-twilight.md` (local to the operator's machine, not part of the repo).

**Confirmed deploy path**: Cloudflare **Workers** (not Pages) — verified via `wrangler.jsonc`'s `main` entrypoint + `assets.binding` shape before deploying, per the risk register's mitigation in `infrastructure.md`.

## `wrangler.jsonc` changes made

- `name`: `10x-astro-starter` → `t-sql-doradca` (was a leftover from the starter template; renamed before first deploy since renaming after would have orphaned a Worker at the old URL).
- Added `account_id`: `d509512d3acdca34d35f6677a83a9f0b` (explicit pin; wrangler was already OAuth-authenticated to this single account).
- Added `kv_namespaces` binding for `SESSION`: `{"binding": "SESSION", "id": "4d8113de422c4532a36fad2bf6aa7700"}`. This binding was **not anticipated by the original infra research** — `@astrojs/cloudflare` auto-provisions a KV namespace for session storage at deploy time if undeclared. The first deploy created it implicitly; it was then pinned explicitly in `wrangler.jsonc` (and the project rebuilt) so subsequent deploys reuse the same namespace deterministically instead of risking re-provisioning. Confirmed via a second deploy showing no new "Provisioning" step.
- Cloudflare also auto-attaches an `IMAGES` binding (image processing) with no config needed — informational only, no action required.

## Deployed URL

`https://t-sql-doradca.pawelwojno.workers.dev`

Current Version ID (post-KV-pin deploy): `fff9c0b0-556d-4d8b-8879-0bef592136d1`

## Secrets live in production

- `SUPABASE_URL` — set via `wrangler secret put`, 2026-09-27 (human-entered, real production Supabase project).
- `SUPABASE_KEY` — set via `wrangler secret put`, 2026-09-27 (human-entered, real production Supabase anon key).

Both confirmed registered via `wrangler secret list` (names only). Values were never seen by the agent or entered into this conversation.

## Verification results

| Check                                                                             | Result                                                                                                                                                                                                                                                            |
| --------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Homepage reachable                                                                | `200`                                                                                                                                                                                                                                                             |
| "Not configured" Supabase banner                                                  | Absent (confirmed via HTML grep for the banner's Polish message text) — secrets wired correctly                                                                                                                                                                   |
| `npm run smoke` against production                                                | **All 8 steps passed**: home renders, dashboard redirects anonymous user, signup creates account, signin rejects wrong password, signin accepts correct password, dashboard renders for signed-in user, signout clears session, dashboard redirects after signout |
| `wrangler tail` during fresh requests to `/`, `/dashboard`, `/auth/confirm-email` | All `Ok`, no runtime errors — the `nodejs_compat` risk (`require is not defined` / `[object Object]` rendering bug) flagged in `infrastructure.md`'s risk register did **not** manifest                                                                           |
| 404 fallback (`/some-nonexistent-path-xyz`)                                       | `404` — Astro's SSR routing handles this correctly despite no explicit `404.astro` existing in the repo                                                                                                                                                           |
| Production Supabase email confirmation                                            | Was already disabled prior to this deploy (confirmed by the operator) — smoke test's sign-up→sign-in flow depended on this                                                                                                                                        |
| CPU-time (Cloudflare dashboard → Workers → Analytics)                             | Not checked by the agent (dashboard UI, human-only) — operator should glance at this periodically given the free-tier 10ms CPU-time limit is the top flagged risk                                                                                                 |

## Known residual items (not blocking, carried forward)

- A test user was created in the production Supabase `auth.users` table by the smoke test's sign-up step. Not cleaned up — harmless, but noted so it isn't mistaken for a real signup later.
- No `404.astro` exists in the repo; the default SSR 404 behavior was verified acceptable, but a custom 404 page is not yet built.
- `package.json`'s `"name"` field is still `10x-astro-starter` (unrelated to the deployed URL, left as-is per the approved plan's explicit scope).

## CI/CD status

**No auto-deploy is implemented.** `.github/workflows/ci.yml` still only runs `ci` (lint/typecheck/build) and `smoke` (against local Supabase) jobs — it does **not** deploy to Cloudflare. Despite `tech-stack.md`'s `ci_default_flow: auto-deploy-on-merge` hint, this was never built by the bootstrapper and was explicitly scoped out of this deployment as a separate future task. **Every deploy until that's built must be triggered manually** via the command sequence below.

## Rollback

`npx wrangler rollback [deployment-id]` reverts Worker **code** only. It does **not** revert secrets or bindings (e.g. `kv_namespaces`, `account_id`) — a config-related incident needs a separate, deliberate fix, not just a rollback.

## Redeploy command sequence (for future reference)

```
npm run build
npx wrangler deploy
```

(Secrets and bindings are already persisted in `wrangler.jsonc` / Cloudflare — no need to re-run `wrangler secret put` unless rotating a value.)
