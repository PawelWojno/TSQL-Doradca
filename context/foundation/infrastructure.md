---
project: t-sql-doradca
researched_at: 2026-09-27
recommended_platform: Cloudflare Workers
runner_up: Netlify
context_type: mvp
tech_stack:
  language: TypeScript
  framework: Astro 7 (React 19 islands)
  runtime: Cloudflare Workers (workerd)
---

## Recommendation

**Deploy on Cloudflare Workers.**

The project is already built on the official `@astrojs/cloudflare` adapter and `wrangler.jsonc` — Cloudflare is the only shortlisted platform requiring zero migration. It scores 5/5 Pass on the agent-friendly criteria, is effectively free at this project's scale (small user base, low QPS per the PRD), and matches the team's existing Cloudflare familiarity (interview P3). The anti-bias cross-check surfaced real risks (CPU-time limits, an active Pages→Workers platform shift, a `nodejs_compat` edge case), none of which were severe enough to outweigh the zero-migration, zero-cost advantage for a one-week, after-hours MVP.

## Platform Comparison

Scored Pass/Partial/Fail against the five agent-friendly criteria (`references/agent-friendly-criteria.md`), weighted by interview answers: P1=no persistent connections needed, P2=minimize cost, P3=existing Cloudflare familiarity, P4=single region sufficient, P5=external providers (Supabase) fine.

| Platform           | CLI-first                            | Managed/Serverless | Agent-readable docs               | Stable deploy API | MCP/Integration                           | Total       |
| ------------------ | ------------------------------------ | ------------------ | --------------------------------- | ----------------- | ----------------------------------------- | ----------- |
| Cloudflare Workers | Pass                                 | Pass               | Pass                              | Pass              | Pass                                      | 5 Pass      |
| Fly.io             | Pass                                 | Pass               | Pass                              | Pass              | Pass                                      | 5 Pass      |
| Vercel             | Pass                                 | Pass               | Partial                           | Pass              | Partial (MCP beta)                        | 3P/2Partial |
| Netlify            | Partial (rollback is dashboard-only) | Pass               | Pass                              | Partial           | Pass (GA MCP)                             | 3P/2Partial |
| Railway            | Partial                              | Pass               | Pass                              | Partial           | Partial (agent tooling new/preview-grade) | 2P/3Partial |
| Render             | Partial                              | Pass               | Partial (no docs-on-GitHub found) | Partial           | Partial (MCP maturity unlabeled)          | 1P/4Partial |

**Cloudflare Workers** — `wrangler` covers deploy/rollback/tail natively; docs are published as markdown/`llms.txt` explicitly for agents; D1/R2/KV/Queues are GA managed services; official MCP servers exist (docs + account management). Zero migration cost since the app is already built on this adapter.

**Fly.io** — ties Cloudflare on raw criteria (full Docker flexibility, `flyctl`, docs on GitHub, strong WebSocket support), but the free tier was removed in 2024 and this repo has no Dockerfile today — real migration effort (new adapter, new Dockerfile, new secrets flow) for a platform whose main advantage (persistent processes) this MVP doesn't need (interview P1 = No).

**Vercel** — solid technically, but the Hobby (free) tier's terms of service prohibit commercial use, which effectively forces the $20/mo Pro tier from day one — directly conflicts with the "minimize cost" priority (interview P2).

**Netlify** — GA MCP server and markdown docs are a genuine strength, but rollback requires the dashboard (no CLI rollback command), and the free tier switched to a credit-based pricing model in September 2025 that is harder to predict than Cloudflare's flat request-count-based free tier.

**Railway** — no permanent free tier (one-time trial credit only), agent/MCP tooling is newly launched and not yet GA-labeled, and only 4 regions with no built-in multi-region failover.

**Render** — weakest overall: no confirmed docs-on-GitHub source, free tier spins down after 15 minutes of inactivity (cold starts), and MCP server maturity is unlabeled in its own docs.

### Shortlisted Platforms

#### 1. Cloudflare Workers (Recommended)

Already implemented in this repo (`@astrojs/cloudflare`, `wrangler.jsonc`) — the only candidate with zero migration cost. 5/5 Pass on agent-friendly criteria. Free tier (100k requests/day) comfortably covers this MVP's expected small-scale, low-QPS traffic (PRD `target_scale: users=small, qps=low`). Matches the team's stated existing Cloudflare familiarity.

#### 2. Netlify

Strongest technical alternative: GA official MCP server, markdown-native docs, official `@astrojs/netlify` adapter (low-effort migration). Loses to Cloudflare on cost predictability (Sept 2025 credit-based free tier) and CLI completeness (no CLI rollback command — dashboard-only).

#### 3. Fly.io

The strongest "escape hatch" if the MVP later needs real persistent connections or WebSockets (explicitly out of scope today per PRD's non-goals and interview P1). Requires a new Dockerfile (none exists in this repo today), a new adapter (`@astrojs/node`), and has no free tier — real cost and effort for capability this project doesn't currently need.

## Anti-Bias Cross-Check: Cloudflare Workers

### Devil's Advocate — Weaknesses

1. The free tier caps CPU-time at **10ms per invocation** (I/O wait excluded) — the T-SQL rule engine (text parsing, pattern matching) is CPU-bound work, and long or complex pasted queries could realistically hit this limit, producing intermittent 500s exactly as traffic grows, with a non-obvious root cause (looks like a random failure, not a resource limit) unless CPU-time is specifically monitored.
2. Cloudflare is actively consolidating Pages into Workers (research flagged this as a "platform shift, verify before committing") — if `@astrojs/cloudflare` or its docs still default to describing the older Pages model in places, the project could be pointed at a deployment path Cloudflare is de-emphasizing without anyone noticing.
3. A documented bug: `nodejs_compat` combined with certain patterns (libraries pulling in `ws`/`node:net`) throws `require is not defined`, and non-prerendered routes have a known `[object Object]` rendering bug requiring the `disable_nodejs_process_v2` workaround flag — exactly the kind of "works locally, breaks on Workers" surprise that's hard to catch before deploying.
4. The stateless model (no persistent process) means any future need for long-running work (e.g., batch-analyzing many queries at once) would require learning Durable Objects — a new concept, not a simple extension of the current code.
5. `wrangler rollback` only reverts Worker code — bound resources (env vars, D1/R2 bindings) are **not** rolled back automatically, so a rollback after a config-related incident can leave the app in an inconsistent state.

### Pre-Mortem — How This Could Fail

The team deployed T-SQL Doradca to Cloudflare Workers, assuming that since the adapter worked locally, production would behave identically. Six months later, the rule engine — grown from 4 to a dozen-plus patterns after the MVP succeeded — started regularly exceeding the free tier's CPU-time limit on long, multi-thousand-character queries pasted by developers working against large stored procedures. Failures appeared randomly, affecting only some users, so the team initially suspected Supabase, not Cloudflare — days lost to the wrong diagnosis. Once they found the real cause, they upgraded to the paid plan ($5/mo), which fixed the symptom but not the root assumption: nobody had measured the rule engine's actual CPU usage before picking the platform. In parallel, an Astro/Cloudflare update shifted `nodejs_compat` default behavior, and the analysis-history page stopped rendering correctly (the same `[object Object]` bug from research) — with no regression test on non-prerendered routes, it reached production unnoticed for several days until a team member reported it.

### Unknown Unknowns

- Cloudflare is actively consolidating Pages into Workers, but docs and community content still largely use "Pages" language — easy to land on an outdated guide describing the path Cloudflare is moving away from.
- `wrangler rollback` reverts only Worker code — any env var/secret change made between deployments is **not** rolled back with it, which can create false confidence during incident response.
- The 10ms CPU-time free-tier limit is per-invocation, excluding I/O wait — standard "response time" monitoring won't surface it directly; CPU-time specifically must be checked in the Cloudflare dashboard.
- `nodejs_compat` only became default-on for compatibility dates ≥2026-08-04 — if `wrangler.jsonc`'s `compatibility_date` is older, Node-API behavior can differ unexpectedly on a routine dependency update.
- Cloudflare's official MCP servers are new (2025) and actively evolving — treat them as a convenience, not a stable contract, until independently verified.

## Operational Story

- **Preview deploys**: `wrangler versions upload` publishes a new Worker version with a preview URL without promoting it to production traffic; `wrangler versions deploy` promotes a specific version to production. No PR-fork restrictions apply since deploys are triggered from the repo's own CI, not third-party forks.
- **Secrets**: `SUPABASE_URL`/`SUPABASE_KEY` live in `.dev.vars` (gitignored) for local Cloudflare dev, and are pushed to production via `npx wrangler secret put <NAME>` — stored encrypted, readable only by the Worker at runtime, never committed to the repo. Rotation is done by re-running `wrangler secret put` with the new value.
- **Rollback**: `npx wrangler rollback [deployment-id]` reverts Worker code instantly. Caveat (see risk register): bound env vars/resources are not rolled back with it — a config-related incident needs a separate, deliberate fix.
- **Approval**: production deploys (`wrangler deploy` / `wrangler versions deploy`) are triggered by a human merging to `master` (CI auto-deploy per `tech-stack.md`'s `ci_default_flow: auto-deploy-on-merge`). Destructive actions — rotating the primary Supabase key, deleting the Worker, changing billing — remain manual dashboard/CLI actions performed by a human, never agent-initiated.
- **Logs**: `npx wrangler tail` streams live production logs read-only from the terminal; the Cloudflare dashboard's Analytics/Logs view is the fallback for historical data.

## Risk Register

| Risk                                                                                                                                 | Source                              | Likelihood | Impact | Mitigation                                                                                                                                                                                                                               |
| ------------------------------------------------------------------------------------------------------------------------------------ | ----------------------------------- | ---------- | ------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Free-tier 10ms CPU-time limit causes intermittent failures under load from CPU-bound rule matching                                   | Devil's advocate                    | M          | M      | Monitor CPU-time in the Cloudflare dashboard from launch; keep rule-matching logic to simple string/regex operations; upgrade to the $5/mo paid plan (30s CPU limit) proactively at the first sign of growth, not after failures appear. |
| Cloudflare's Pages→Workers consolidation could mean docs/examples target a path Cloudflare is de-emphasizing                         | Devil's advocate / Research finding | L          | M      | Explicitly confirm `wrangler.jsonc` targets the Workers deploy path (not legacy Pages) before the first production deploy; record the confirmed path in `context/deployment/deploy-plan.md`.                                             |
| `nodejs_compat` / Supabase client interaction bugs (`require is not defined`, `[object Object]` rendering on non-prerendered routes) | Devil's advocate / Research finding | M          | M      | Pin an explicit, recent `compatibility_date` in `wrangler.jsonc`; run the existing `npm run smoke` script in CI against every deploy, specifically exercising the dashboard and confirm-email routes (non-prerendered).                  |
| `wrangler rollback` reverts Worker code only, not env vars/bindings                                                                  | Devil's advocate / Unknown unknowns | L          | M      | Treat env var/secret changes as a separate, deliberate step from code rollback; document each production env var change alongside the corresponding deploy.                                                                              |
| Official Cloudflare MCP servers are new (2025) and actively evolving                                                                 | Research finding                    | L          | L      | Not required for MVP deploy — CLI (`wrangler`) is sufficient. Re-evaluate MCP adoption only if the agent starts repeating structured discovery queries against production state.                                                         |
| Stateless Workers model has no built-in path for future long-running/background work                                                 | Devil's advocate                    | L          | L      | Out of scope for this MVP (PRD non-goals exclude background jobs); revisit with Durable Objects only if a future requirement demands it.                                                                                                 |

## Getting Started

1. Confirm `wrangler.jsonc` targets the Workers deploy path (not legacy Pages) and pin an explicit, recent `compatibility_date` (≥2026-08-04, so `nodejs_compat` defaults on) before the first production deploy.
2. Push production secrets: `npx wrangler secret put SUPABASE_URL` and `npx wrangler secret put SUPABASE_KEY` (mirrors the `.dev.vars` values already used for local Cloudflare dev).
3. Run `npm run build` then `npx wrangler deploy` for the first production deployment.
4. Verify end-to-end with `npx wrangler tail` running alongside `BASE_URL=<production-url> npm run smoke` (or a manual signup/signin/dashboard/signout pass) against the production URL.
5. Add a periodic check of Workers CPU-time metrics (Cloudflare dashboard → Workers → Analytics) to the team's post-launch routine, to catch the free-tier 10ms limit before it causes intermittent failures.

## Out of Scope

The following were not evaluated in this research:

- Docker image configuration
- CI/CD pipeline setup
- Production-scale architecture (multi-region, HA, DR)
