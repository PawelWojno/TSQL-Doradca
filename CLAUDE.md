# Rules for AI

This file provides guidance to AI Agent when working with code in this repository.

## Commands

- `npm run dev` — start dev server (Cloudflare workerd runtime)
- `npm run build` — production build (SSR via `@astrojs/cloudflare`)
- `npm run preview` — preview production build
- `npm run lint` — ESLint with type-checked rules
- `npm run lint:fix` — auto-fix lint issues
- `npm run format` — Prettier (includes prettier-plugin-astro + prettier-plugin-tailwindcss)
- `npm run smoke` — dependency-free auth-flow smoke test (`scripts/smoke.mjs`) against a running server, `BASE_URL` env (default `http://localhost:4321`). Run after dependency upgrades; CI runs it against the production preview with a local Supabase.

Pre-commit hooks: husky + lint-staged runs `eslint --fix` on `*.{ts,tsx,astro}` and `prettier --write` on `*.{json,css,md}`.

## Architecture

**Astro 7 SSR app** with React 19 islands, Tailwind 4, Supabase auth, and shadcn/ui components. Deployed to Cloudflare Workers.

### Rendering mode

Full server-side rendering (`output: "server"` in astro.config.mjs). All pages are server-rendered by default. API routes must export `const prerender = false`.

### Auth flow

- `src/lib/supabase.ts` — creates a Supabase SSR client using `@supabase/ssr` with cookie-based sessions. Uses `astro:env/server` for `SUPABASE_URL` and `SUPABASE_KEY` (server-only secrets declared in astro.config.mjs `env.schema`).
- `src/middleware.ts` — runs on every request, resolves the current user, attaches to `context.locals.user`. Redirects unauthenticated users away from routes listed in `PROTECTED_ROUTES`.
- API endpoints: `src/pages/api/auth/{signin,signup,signout}.ts`
- Auth pages: `src/pages/auth/{signin,signup,confirm-email}.astro`
- Protected page example: `src/pages/dashboard.astro`

### Key conventions

- **Path alias**: `@/*` maps to `./src/*` (tsconfig paths).
- **Astro components** for static content/layout; **React components** only when interactivity is needed.
- **Tailwind class merging**: use the `cn()` helper from `@/lib/utils` (clsx + tailwind-merge) for conditional/merged class names. Do not concatenate class strings manually.
- **shadcn/ui**: components live in `src/components/ui/`, "new-york" style variant. Install new ones with `npx shadcn@latest add [name]`.
- **API routes**: validate input with zod.
- **Supabase migrations**: `supabase/migrations/` using naming format `YYYYMMDDHHmmss_short_description.sql`. Always enable RLS on new tables with granular per-operation, per-role policies.
- **React**: no Next.js directives ("use client" etc.). Extract hooks to `src/components/hooks/`.
- **Services/helpers** go in `src/lib/` (or `src/lib/services/` for extracted business logic).
- **Shared types** (entities, DTOs) go in `src/types.ts`.

### Environment

- Node.js version per `@.nvmrc`
- Env vars: `SUPABASE_URL`, `SUPABASE_KEY` (copy `.env.example` to `.env` for Node, or `.dev.vars` for Cloudflare local dev). Both are declared `optional: true` in `astro.config.mjs` — the app boots without them and shows a "not configured" banner (`src/lib/config-status.ts`, `src/components/Banner.astro`/`Topbar.astro`) instead of crashing.
- Local Supabase: `npx supabase start` (requires Docker)
- Cloudflare local dev: secrets go in `.dev.vars` (gitignored)
- Deploy: `npx wrangler deploy` (requires Cloudflare account + `wrangler` auth)

## CI

GitHub Actions workflow (`.github/workflows/ci.yml`) has two jobs, on every push and PR to master:

- `ci`: `npm ci` → `npx astro sync` → `npm run lint` → `npx astro check` → `npm run build`. Requires `SUPABASE_URL`/`SUPABASE_KEY` repo secrets.
- `smoke`: spins up local Supabase, builds, runs preview, then `npm run smoke`.

<!-- BEGIN @przeprogramowani/10x-cli -->

## Zestaw narzędzi AI 10xDevs — Moduł 2, Lekcja 1

Przejdź od konfiguracji sprintu zerowego do orkiestracji projektu za pomocą **łańcucha roadmapy**:

```
(Module 1 foundation docs) -> /10x-roadmap -> backlog-ready roadmap items
```

`/10x-roadmap` jest tematem lekcji. `/10x-new` zostaje celowo wprowadzone w Module 2, Lesson 2, gdy wybrany element roadmapy staje się folderem zmiany implementacyjnej.

### Router zadań — od czego zacząć

| Skill                                                                                                                   | Użyj, gdy                                                                                                                                                                                                                                                                                                                                                                                                                             |
| ----------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Roadmap (temat lekcji)**                                                                                              |                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| `/10x-roadmap`                                                                                                          | Masz `context/foundation/prd.md` oraz przygotowaną bazę projektu i potrzebujesz roadmapy MVP o priorytecie pionowych przekrojów. Skill odczytuje PRD, analizuje bazę kodu, wykorzystuje dostępne dokumenty podstawowe, takie jak `tech-stack.md`, `infrastructure.md` i `deploy-plan.md`, a następnie zapisuje `context/foundation/roadmap.md`. Użyj go PRZED utworzeniem folderów dla poszczególnych zmian lub planów implementacji. |
| **W razie potrzeby uruchom ponownie etap wcześniejszy**                                                                 |                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| `/10x-shape` / `/10x-prd` / `/10x-tech-stack-selector` / `/10x-bootstrapper` / `/10x-agents-md` / `/10x-infra-research` | Zestawione z Module 1, aby kontrakty podstawowe można było poprawić przed ustaleniem kolejności roadmapy. Jeśli generowanie roadmapy ujawni lukę w PRD, popraw PRD, zanim uznasz backlog za gotowy.                                                                                                                                                                                                                                   |

### Jak łańcuch przekazuje pracę dalej

- `/10x-roadmap` łączy produkt z implementacją. Nie wybiera frameworków, nie projektuje schematów ani nie tworzy planu implementacji dla pojedynczej zmiany.
- Wynikiem jest `context/foundation/roadmap.md`: uporządkowane kamienie milowe, pionowe przekroje, ograniczone fundamenty, zależności, niewiadome, ryzyka oraz pola przekazania do backlogu.
- Elementy roadmapy powinny otrzymywać stabilne, czytelne dla ludzi identyfikatory w narzędziach backlogu. Rzeczywisty folder `context/changes/<change-id>/` zostanie utworzony w Lekcji 2 za pomocą `/10x-new`.

### Granice roadmapy

- Domyślnie stosuj pionowe przekroje: widoczne dla użytkownika rezultaty obejmujące UI, dane, logikę biznesową i integracje.
- Praca horyzontalna jest dozwolona tylko jako ograniczony element umożliwiający realizację, który wskazuje docelowy pionowy kamień milowy, jaki odblokowuje.
- Unikaj osieroconej pracy horyzontalnej, takiej jak „zbuduj całą bazę danych”, „zbuduj wszystkie endpointy API” lub „zaprojektuj cały UI” przed pierwszym przepływem widocznym dla użytkownika.
- Roadmapa nie jest estymacją kalendarzową. Nie wymyślaj dat, punktów historyjek ani prędkości sprintu, chyba że użytkownik wyraźnie poprosi o osobny artefakt planowania.

### Ścieżki podstawowe używane przez tę lekcję

- `context/foundation/prd.md` — dane wejściowe
- `context/foundation/tech-stack.md` — opcjonalne dane wejściowe
- `context/foundation/infrastructure.md` — opcjonalne dane wejściowe
- `context/deployment/deploy-plan.md` — opcjonalne dane wejściowe
- `context/foundation/roadmap.md` — dane wyjściowe
- `context/foundation/lessons.md` — powtarzające się reguły i pułapki
- `docs/reference/contract-surfaces.md` — rejestr nazw krytycznych dla działania

Skills nie mogą zapisywać do `context/archive/`. Zarchiwizowane zmiany są niezmienne; jeśli rozwiązana ścieżka docelowa zaczyna się od `context/archive/`, przerwij z komunikatem: „This change is archived. Open a new change with `/10x-new` instead.”

<!-- END @przeprogramowani/10x-cli -->
