---
project: "T-SQL Doradca"
version: 1
status: draft
created: 2026-09-28
updated: 2026-09-29
prd_version: 1
main_goal: speed
top_blocker: time
milestone_id: shared-query-analysis-loop
milestone_seq: 1
milestone_status: open
---

# Roadmap: T-SQL Doradca

> Derived from `context/foundation/prd.md` (v1) + auto-researched codebase baseline.
> Edit-in-place; archive when superseded.
> Slices below are listed in dependency order. The "At a glance" table is the index.

## Milestone

**M-1: Shared query analysis loop** — Status: open

- **Intent:** Dostarczyć pełen zakres MVP z PRD v1 — pojedynczą pionową pętlę: wklej zapytanie T-SQL → zobacz sugestie oznaczone wagą → zapisz do wspólnej historii zespołu → zarządzaj (status/usunięcie) własnymi analizami.
- **Source materials:** `context/foundation/prd.md` (v1)
- **Done when:** F-01, S-01 i S-02 poniżej mają status `done`.
- **Scope anchors:** US-01, FR-001 – FR-008.

## Vision recap

Deweloperzy w zespole dziś sprawdzają zapytania T-SQL pod kątem znanych antywzorców (np. `SELECT *`, brak `WHERE` na dużej tabeli) wyłącznie na oko, indywidualnie, bez żadnego wspólnego śladu. T-SQL Doradca koduje tę wiedzę zespołu jako niewielki zbiór reguł statycznych i dodaje jedną rzecz, której brakuje dzisiejszemu ręcznemu przeglądowi: wspólną, przeszukiwalną historię tego, co już zostało wychwycone.

## North star

**S-01: Zalogowany członek zespołu wkleja zapytanie T-SQL, widzi sugestie oznaczone wagą i zapisuje wynik do wspólnej historii zespołu** — to najmniejszy kompleksowy przepływ, którego dostarczenie udowadnia główną hipotezę produktu (kontrola antywzorców przestaje być indywidualna i zostawia wspólny ślad), więc jest ustawiony na samym początku, zaraz po fundamencie danych, od którego zależy.

> "Gwiazda przewodnia" (north star) oznacza tu: najmniejszy kompleksowy wycinek, którego udane dostarczenie jako pierwsze udowadnia, że produkt działa — dopiero po nim reszta pracy zaczyna mieć sens. Ten dopisek pojawia się raz, przy pierwszym użyciu terminu w dokumencie.

## At a glance

| ID   | Change ID                        | Outcome (user can …)                                                    | Prerequisites | PRD refs                                      | Status      |
| ---- | -------------------------------- | ----------------------------------------------------------------------- | ------------- | --------------------------------------------- | ----------- |
| F-01 | analysis-history-schema          | (foundation) tabela `analyses` z RLS per-właściciel istnieje w Supabase | —             | NFR (trwałość), Access Control                | in-progress |
| S-01 | first-gated-query-analysis       | wkleja zapytanie, widzi sugestie z wagą, zapisuje do wspólnej historii  | F-01          | US-01, FR-001, FR-002, FR-003, FR-004, FR-007 | proposed    |
| S-02 | owner-managed-analysis-lifecycle | zmienia status własnej analizy i usuwa własną analizę                   | S-01          | FR-005, FR-006                                | proposed    |

## Baseline

What's already in place in the codebase as of `2026-09-28` (auto-researched + user-confirmed).
Foundations below assume these are present and do NOT re-scaffold them.

- **Frontend:** present — Astro 7 SSR + React 19 islands, shadcn/ui "new-york" (per `tech-stack.md`)
- **Backend / API:** partial — tylko `src/pages/api/auth/{signin,signout,signup}.ts`; brak endpointów analizy zapytań
- **Data:** absent — brak katalogu `supabase/migrations`, brak `src/types.ts`; żadnej tabeli na analizy
- **Auth:** present — pełny flow signin/signup/signout, `src/middleware.ts` z `PROTECTED_ROUTES = ["/dashboard"]`, potwierdzone działające przez smoke test na produkcji (`context/deployment/deploy-plan.md`)
- **Deploy / infra:** present — Cloudflare Workers live (`https://t-sql-doradca.pawelwojno.workers.dev`), CI/CD auto-deploy na merge do `master` działa
- **Observability:** absent — brak sentry/datadog/otel w `package.json`

## Foundations

### F-01: Schemat danych dla zapisanych analiz

- **Outcome:** (foundation) w Supabase istnieje tabela przechowująca zapisane analizy (treść zapytania, wynik, data, właściciel) z RLS: odczyt dla każdego zalogowanego członka zespołu, modyfikacja/usunięcie tylko dla właściciela rekordu.
- **Change ID:** analysis-history-schema
- **PRD refs:** NFR ("Zapisane analizy są trwałe między sesjami"), Access Control ("Modyfikacja / usunięcie: tylko właściciel analizy")
- **Unlocks:** S-01, S-02
- **Prerequisites:** —
- **Parallel with:** —
- **Blockers:** —
- **Unknowns:** —
- **Risk:** Pierwsza migracja Supabase w tym projekcie (baseline: brak `supabase/migrations`) — ryzyko niskie: jedna tabela, RLS per-właściciel, wzorzec migracji już opisany w `CLAUDE.md`.
- **Status:** in-progress

## Slices

### S-01: Zespołowa analiza zapytania T-SQL pod kątem antywzorców

- **Outcome:** zalogowany członek zespołu wkleja tekst zapytania T-SQL, uruchamia analizę opartą o reguły statyczne (`SELECT *`, brak `WHERE` na dużej tabeli, `LIKE '%x%'`, zagnieżdżone podzapytanie zamiast JOIN), widzi listę sugestii oznaczonych wagą, i zapisuje wynik do wspólnej historii zespołu.
- **Change ID:** first-gated-query-analysis
- **PRD refs:** US-01, FR-001, FR-002, FR-003, FR-004, FR-007
- **Prerequisites:** F-01
- **Parallel with:** —
- **Blockers:** —
- **Unknowns:** —
- **Risk:** Największy wycinek MVP — łączy silnik reguł regex, zapis i wspólną widoczność w jednym przepływie. Regex nie rozumie struktury zapytania, więc może dać false positive (np. wzorzec wewnątrz komentarza SQL); niski koszt pomyłki (żadna sugestia nie trafia automatycznie na produkcję, użytkownik ocenia ją sam) akceptuje to ryzyko na etapie MVP (decyzja już podjęta w `shape-notes.md` § Forward: technical-roadmap). Wymaga też rozszerzenia `PROTECTED_ROUTES` w `src/middleware.ts` o nowe strony tego wycinka, żeby spełnić FR-007.
- **Status:** proposed

### S-02: Zarządzanie własnymi zapisanymi analizami

- **Outcome:** właściciel analizy zmienia jej status (np. na "rozwiązane") i może usunąć własną analizę; inni członkowie zespołu widzą, ale nie mogą modyfikować ani usuwać cudzych analiz.
- **Change ID:** owner-managed-analysis-lifecycle
- **PRD refs:** FR-005, FR-006
- **Prerequisites:** S-01
- **Parallel with:** —
- **Blockers:** —
- **Unknowns:** —
- **Risk:** Mały wycinek działający na rekordach już utworzonych przez S-01; główne ryzyko to poprawne wymuszenie autoryzacji po stronie serwera (RLS + walidacja), nie tylko ukrycie przycisków w UI.
- **Status:** proposed

## Backlog Handoff

| Roadmap ID | Change ID                        | Suggested issue title                                             | Ready for `/10x-plan` | Notes         |
| ---------- | -------------------------------- | ----------------------------------------------------------------- | --------------------- | ------------- |
| F-01       | analysis-history-schema          | Schemat Supabase dla zapisanych analiz T-SQL (RLS per-właściciel) | yes                   | —             |
| S-01       | first-gated-query-analysis       | Analiza zapytania T-SQL + zapis do wspólnej historii zespołu      | no                    | Czeka na F-01 |
| S-02       | owner-managed-analysis-lifecycle | Zmiana statusu i usuwanie własnej analizy                         | no                    | Czeka na S-01 |

This table is the clean handoff to Jira/Linear or any MCP-backed backlog. Include one row for every `F-NN` and `S-NN`. It should be compact enough to copy into issues, but it must not duplicate the detailed roadmap body.

## Open Roadmap Questions

1. **Czy zaproszenie nowego członka zespołu odbywa się w produkcie, czy poza nim (ręcznie przez administratora)?** — Owner: user. Block: roadmap-wide (nie blokuje żadnego F-NN/S-NN — Non-Goals PRD wyklucza dziś panel administracyjny, więc domyślnie zakładanie kont dzieje się poza produktem).

## Parked

- **Wsparcie dla dialektów SQL innych niż T-SQL** (Postgres, MySQL, Oracle) — Why parked: PRD § Non-Goals, projekt celuje wyłącznie w T-SQL/SQL Server.
- **Automatyczne wykonywanie zapytań na żywej bazie danych** — Why parked: PRD § Non-Goals / Guardrails, MVP analizuje wyłącznie tekst zapytania.
- **Zarządzanie uprawnieniami i kontami wewnątrz produktu** (panel administracyjny, ekrany zaproszeń) — Why parked: PRD § Non-Goals, płaski model kont z zaproszeniami poza produktem wystarcza na MVP.
- **Wzorce wymagające wiedzy o schemacie bazy** (brakujący indeks, nieoptymalna kolejność JOIN-ów) — Why parked: PRD § Non-Goals, wymaga metadanych schematu/planu wykonania, nie tylko tekstu zapytania.
- **Prywatna widoczność analiz** — Why parked: PRD § Non-Goals, koszt pomyłki w uprawnieniach dostępu (cichy wyciek bez sygnału) przewyższa wartość tej opcji na tym etapie.
- **Parser AST** (np. `node-sql-parser`, `sqlglot`) zamiast regexów — Why parked: `shape-notes.md` § Forward: technical-roadmap, świadome rozszerzenie po MVP, nie warunek startu; niski koszt pomyłki na MVP nie uzasadnia jeszcze tej inwestycji.
- **Analiza przez LLM / hybryda regex+LLM** — Why parked: `shape-notes.md` § Forward: technical-roadmap, odłożone po MVP jako pogłębione wyjaśnienie na żądanie.
- **Grupowanie/sortowanie sugestii według wagi** (FR-008, nice-to-have) — Why parked: cel sekwencjonowania to `speed` — ścisła ścieżka must-have (FR-001–007) idzie pierwsza; to dopracowanie nie blokuje walidacji głównej hipotezy (5 zapisanych analiz od 2 osób) i można je dodać po north star bez zmiany schematu danych.

## Milestone History

(brak — pierwszy kamień milowy tego projektu)

## Done

(brak — jeszcze nic nie zostało zarchiwizowane)
