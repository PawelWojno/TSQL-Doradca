# Repository Guidelines

T-SQL-Doradca is an Astro 7 SSR app (React 19 islands, Tailwind 4, Supabase auth, shadcn/ui) deployed to Cloudflare Workers, built on the 10x Astro Starter template. See @CLAUDE.md for full architecture detail — this file is a compact onboarding summary.

## Hard Rules

- API routes must export `const prerender = false`, even though the app runs in `output: "server"` mode.
- `SUPABASE_URL`/`SUPABASE_KEY` are `optional: true` server-only secrets in `astro.config.mjs`; the app boots without them and shows a "not configured" banner (`src/lib/config-status.ts`) instead of crashing — don't make them required to "fix" that.
- Use `cn()` from `@/lib/utils` for Tailwind class merging; never concatenate class strings manually.
- Add new protected routes to `PROTECTED_ROUTES` in `src/middleware.ts`, not via ad hoc redirects.

## Project Structure & Module Organization

- `src/pages/` — Astro pages, incl. `api/` (endpoints) and `auth/` (auth pages).
- `src/components/` — Astro for static content, React only where interactive; `auth/` React forms, `ui/` shadcn "new-york" variant.
- `src/lib/` — helpers (`supabase.ts`, `utils.ts`, `config-status.ts`); extract business logic to `src/lib/services/` as it grows.
- `supabase/migrations/` — none yet; when added, name `YYYYMMDDHHmmss_short_description.sql` with per-operation, per-role RLS policies.

## Build, Test, and Development Commands

See `@package.json` for the full script list. Notes beyond that:

- `dev`/`build`/`preview` all run on the Cloudflare workerd runtime via `@astrojs/cloudflare`.
- `smoke` needs a reachable Supabase (local or cloud) with email confirmation disabled; defaults to `BASE_URL=http://localhost:4321`.

## Coding Style & Naming Conventions

- TypeScript strict per `@eslint.config.js`: no implicit `any`, unused args/vars must be prefixed `_`; path alias `@/*` → `./src/*`.
- React components PascalCase.tsx (`SignInForm.tsx`); shadcn primitives lowercase (`button.tsx`); Astro components PascalCase.astro.
- API routes validate input with zod. No Next.js directives ("use client" etc.); extract hooks to `src/components/hooks/`.

## Testing Guidelines

No unit or integration test framework is configured yet — `npm run smoke` is the only automated check, and it only covers the auth flow end-to-end. Add a framework (e.g. Vitest) before relying on automated coverage for new features.

## Commit & Pull Request Guidelines

No commit-message convention or GitHub remote yet (2 commits so far). Once a convention is picked, follow it (e.g. Conventional Commits type(scope): subject); until then, keep the subject line under ~50 chars and in the imperative mood.

## Security & Configuration Tips

Copy `.env.example` to `.env` (Node) or `.dev.vars` (Cloudflare local dev); never commit either. CI's `ci` job needs `SUPABASE_URL`/`SUPABASE_KEY` repo secrets; the `smoke` job needs none (uses local Supabase via Docker).
