# Schemat Supabase dla zapisanych analiz (F-01) Implementation Plan

## Overview

Dodajemy pierwszą migrację Supabase w tym projekcie: dwie tabele (`analyses`, `analysis_suggestions`) przechowujące zapisane analizy T-SQL wraz z granularnym RLS per-operację oraz trigger wymuszający niezmienność treści zapytania po zapisie. Dokładamy też pierwsze współdzielone typy TS w `src/types.ts`. To czysto fundamentowa (foundation) zmiana — bez endpointów API ani UI; odblokowuje S-01 i S-02 z roadmapy.

## Current State Analysis

- `supabase/migrations/` nie istnieje — to pierwsza migracja w projekcie (`supabase/config.toml` już jest, `supabase/.gitignore` też).
- `src/types.ts` nie istnieje — nie ma jeszcze żadnych współdzielonych encji/DTO.
- `src/lib/supabase.ts:5-21` tworzy klient SSR (`createServerClient`) bez generycznego typu `Database` — typowanie klienta pod schemat jest świadomie odłożone do S-01, kiedy powstaną endpointy korzystające z tych tabel.
- `src/middleware.ts:1-25` chroni tylko `/dashboard` (`PROTECTED_ROUTES`) — rozszerzenie o strony analizy należy do S-01 (FR-007), nie do tej migracji.
- `CLAUDE.md` narzuca konwencję nazwy migracji `YYYYMMDDHHmmss_short_description.sql` oraz wymóg włączenia RLS z granularnymi politykami per-operację, per-rolę na każdej nowej tabeli.
- `tech-stack.md` potwierdza, że Postgres + RLS zostały wybrane świadomie właśnie po to, by odwzorować regułę "tylko właściciel modyfikuje/usuwa" z PRD § Access Control.

## Desired End State

Po zastosowaniu migracji (`npx supabase db reset` lokalnie) w bazie istnieją tabele `analyses` i `analysis_suggestions` z włączonym RLS i triggerem wymuszającym niezmienność. `src/types.ts` eksportuje typy encji odzwierciedlające ten schemat. Żaden istniejący kod aplikacji się nie zmienia — brak nowych stron, endpointów czy zmian w `middleware.ts`.

### Key Discoveries:

- Brak `supabase/migrations/` (baseline `context/foundation/roadmap.md` § Baseline, potwierdzone) — pierwsza migracja, brak wzorca do skopiowania z tego repo; opieramy się na konwencji z `CLAUDE.md`.
- `src/lib/supabase.ts:5-21` — klient SSR bez generyku `Database`; ta zmiana go nie dodaje (patrz „What We're NOT Doing”).
- PRD § Access Control: "Modyfikacja / usunięcie: tylko właściciel analizy" — mapuje się wprost na RLS per `owner_id = auth.uid()`.
- PRD Acceptance Criteria US-01: "Treść zapytania i wynik zapisanej analizy są niezmienne po zapisie" — RLS samo w sobie by na to nie wystarczyło, bo polityka UPDATE dla właściciela (potrzebna dla FR-005 — zmiana statusu) pozwoliłaby też zmienić `query_text`, gdyby nie dodatkowy trigger.

## What We're NOT Doing

- Generowanie typowanego klienta Supabase (`supabase gen types typescript` → `Database` type, podłączenie do `createServerClient`) — odłożone do S-01, kiedy powstaną pierwsze endpointy korzystające z tych tabel.
- Endpointy API do tworzenia/odczytu/zmiany statusu/usuwania analiz — to S-01 i S-02.
- Rozszerzenie `PROTECTED_ROUTES` w `src/middleware.ts` — dotyczy stron S-01, nie tej migracji.
- Silnik reguł statycznych i lista `rule_code` — logika S-01; ta migracja tylko rezerwuje kolumnę `text` na kod reguły.
- Grupowanie/sortowanie sugestii wg wagi (FR-008) — nice-to-have, sparkowane w roadmapie.
- Dane testowe / seed — nie jest wymagany przez żaden FR tej zmiany.

## Implementation Approach

Jedna addytywna migracja SQL z dwiema znormalizowanymi tabelami (wybór użytkownika: osobna tabela `analysis_suggestions` zamiast kolumny JSONB) połączonymi FK z `ON DELETE CASCADE`, granularnym RLS per `CLAUDE.md`, oraz jednym lekkim triggerem `BEFORE UPDATE` na `analyses`, który jednocześnie: (a) blokuje zmianę niezmiennych kolumn (`query_text`, `owner_id`, `created_at`) i (b) ustawia `updated_at = now()` przy każdej dozwolonej zmianie (czyli przy zmianie `status`). Druga faza dokłada odpowiadające typy TS w `src/types.ts`, bez zmiany istniejącego kodu.

## Critical Implementation Details

**Kolejność sugestii bez kolumny porządkującej gubi się.** Silnik reguł (S-01) wygeneruje listę sugestii w konkretnej kolejności, ale zwykły `SELECT` z tabeli `analysis_suggestions` nie gwarantuje zwrotu wierszy w kolejności wstawienia — a wiersze tej samej analizy mogą mieć identyczny `created_at` (batch insert). Dlatego `analysis_suggestions` dostaje kolumnę `position smallint not null` z ograniczeniem `unique(analysis_id, position)`; S-01 musi ją wypełniać przy zapisie i sortować po niej przy odczycie.

**RLS samo nie wystarcza do wymuszenia niezmienności `query_text`.** Polityka UPDATE dla `analyses` musi istnieć (właściciel zmienia `status` — FR-005), ale RLS nie ogranicza, _które_ kolumny UPDATE może zmienić w obrębie dozwolonego wiersza. Stąd trigger `analyses_guard_update` (patrz Phase 1) — bez niego właściciel mógłby przez zwykły UPDATE nadpisać treść już zapisanego zapytania, łamiąc acceptance criterion z PRD.

## Phase 1: Migracja Supabase — tabele, RLS, trigger

### Overview

Tworzy tabele `analyses` i `analysis_suggestions`, włącza RLS z granularnymi politykami per-operację, dodaje trigger wymuszający niezmienność i `updated_at`.

### Changes Required:

#### 1. Migracja SQL

**File**: `supabase/migrations/20260929120000_analysis_history_schema.sql` (nowy plik)

**Intent**: Zdefiniować schemat zapisanych analiz T-SQL zgodnie z PRD § Access Control / NFR oraz roadmapą F-01: tabela nadrzędna `analyses` (treść zapytania, status, właściciel, znaczniki czasu) i podrzędna `analysis_suggestions` (jedna sugestia = jeden wiersz, z wagą i pozycją), obie z RLS: odczyt dla całego zalogowanego zespołu, zapis/zmiana/usunięcie tylko dla właściciela.

**Contract**:

```sql
create table public.analyses (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id) on delete restrict,
  query_text text not null,
  status text not null default 'open' check (status in ('open', 'resolved')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.analysis_suggestions (
  id uuid primary key default gen_random_uuid(),
  analysis_id uuid not null references public.analyses (id) on delete cascade,
  rule_code text not null,
  message text not null,
  severity text not null check (severity in ('high', 'medium', 'low')),
  position smallint not null,
  created_at timestamptz not null default now(),
  unique (analysis_id, position)
);

alter table public.analyses enable row level security;
alter table public.analysis_suggestions enable row level security;

-- analyses: SELECT dla całego zespołu, INSERT/UPDATE/DELETE tylko właściciel
create policy analyses_select_team on public.analyses
  for select to authenticated using (true);

create policy analyses_insert_own on public.analyses
  for insert to authenticated with check (owner_id = auth.uid());

create policy analyses_update_own on public.analyses
  for update to authenticated using (owner_id = auth.uid()) with check (owner_id = auth.uid());

create policy analyses_delete_own on public.analyses
  for delete to authenticated using (owner_id = auth.uid());

-- analysis_suggestions: SELECT dla całego zespołu, INSERT tylko gdy analiza należy do wywołującego, brak UPDATE, DELETE tylko przez CASCADE
create policy analysis_suggestions_select_team on public.analysis_suggestions
  for select to authenticated using (true);

create policy analysis_suggestions_insert_own on public.analysis_suggestions
  for insert to authenticated with check (
    exists (
      select 1 from public.analyses a
      where a.id = analysis_id and a.owner_id = auth.uid()
    )
  );

-- trigger: query_text/owner_id/created_at niezmienne po zapisie; updated_at aktualizowany przy każdym dozwolonym UPDATE
create or replace function public.analyses_guard_update()
returns trigger
language plpgsql
as $$
begin
  if new.query_text is distinct from old.query_text
     or new.owner_id is distinct from old.owner_id
     or new.created_at is distinct from old.created_at then
    raise exception 'analyses.query_text, owner_id and created_at are immutable after insert';
  end if;
  new.updated_at := now();
  return new;
end;
$$;

create trigger analyses_guard_update
  before update on public.analyses
  for each row
  execute function public.analyses_guard_update();
```

### Success Criteria:

#### Automated Verification:

- Nazwa pliku migracji odpowiada konwencji `YYYYMMDDHHmmss_short_description.sql` z `CLAUDE.md`
- Migracja aplikuje się bez błędów: `npx supabase start` a następnie `npx supabase db reset`

#### Manual Verification:

- W Supabase Studio (lokalnie, po `supabase start`) utworzyć dwóch testowych użytkowników (A i B) w `auth.users`
- Jako A: INSERT wiersza `analyses` + kilku `analysis_suggestions` z rosnącym `position` — udaje się
- Jako B: SELECT widzi wiersz A (współdzielona historia zespołu — FR-004)
- Jako B: próba UPDATE/DELETE wiersza A w `analyses` jest odrzucona przez RLS
- Jako A: UPDATE `status` na `'resolved'` udaje się i `updated_at` się zmienia (FR-005)
- Jako A: próba UPDATE `query_text` na tym samym wierszu kończy się błędem triggera (niezmienność z PRD)
- Jako A: próba INSERT do `analysis_suggestions` z `analysis_id` wskazującym na analizę B jest odrzucona przez RLS

**Implementation Note**: After completing this phase and all automated verification passes, pause here for manual confirmation from the human that the manual testing was successful before proceeding to the next phase.

---

## Phase 2: Współdzielone typy TS

### Overview

Dodaje pierwsze encje/DTO w `src/types.ts` odzwierciedlające nowy schemat, gotowe do importu przez S-01/S-02.

### Changes Required:

#### 1. Typy encji

**File**: `src/types.ts` (nowy plik)

**Intent**: Ustanowić współdzielone typy TS dla tabel `analyses` i `analysis_suggestions` zgodnie z konwencją `CLAUDE.md` ("Shared types (entities, DTOs) go in `src/types.ts`"), tak by S-01/S-02 miały gotowy punkt odniesienia zamiast redefiniować kształt danych.

**Contract**: Eksportowane typy — `AnalysisStatus = "open" | "resolved"`, `AnalysisSeverity = "high" | "medium" | "low"`, `Analysis` (pola: `id`, `ownerId`, `queryText`, `status: AnalysisStatus`, `createdAt`, `updatedAt`), `AnalysisSuggestion` (pola: `id`, `analysisId`, `ruleCode`, `message`, `severity: AnalysisSeverity`, `position`, `createdAt`). Nazwy pól w camelCase; mapowanie z kolumn snake_case bazy danych należy do warstwy repozytorium/serwisu budowanej w S-01, nie do tego pliku.

### Success Criteria:

#### Automated Verification:

- Sprawdzanie typów przechodzi: `npx astro check`
- Linting przechodzi: `npm run lint`

---

## Testing Strategy

### Unit Tests:

- Brak — ta zmiana to schemat SQL i deklaracje typów, bez logiki aplikacyjnej do testowania jednostkowo.

### Integration Tests:

- Zachowanie RLS i triggera weryfikowane ręcznie w Supabase Studio z dwoma kontami testowymi (patrz Phase 1 Manual Verification) — brak jeszcze warstwy API, przez którą dałoby się to zautomatyzować (to zadanie S-01).

### Manual Testing Steps:

1. `npx supabase start`
2. `npx supabase db reset` (aplikuje migrację od zera)
3. W Supabase Studio utworzyć dwóch testowych użytkowników w `auth.users`
4. Jako użytkownik A: zapisać analizę z 2-3 sugestiami (rosnący `position`)
5. Jako użytkownik B: potwierdzić SELECT widzi wiersz A, a UPDATE/DELETE są odrzucane
6. Jako użytkownik A: zmienić `status` na `'resolved'` (sukces, `updated_at` się zmienia), spróbować zmienić `query_text` (błąd triggera)
7. Jako użytkownik A: spróbować dodać `analysis_suggestions` do analizy należącej do B (odrzucone przez RLS)

## Performance Considerations

Nie dotyczy — nowe tabele, znikoma liczba wierszy przy skali "small" z PRD § target_scale.

## Migration Notes

Nie dotyczy — greenfield, brak istniejących danych do migracji.

## References

- PRD: `context/foundation/prd.md` § Access Control, FR-002 – FR-006, NFR
- Roadmap: `context/foundation/roadmap.md` § F-01
- Auth wzorzec: `src/lib/supabase.ts:5-21`, `src/middleware.ts:1-25`
- Konwencje: `CLAUDE.md` § Key conventions (migracje Supabase, RLS, shared types)

## Progress

> Convention: `- [ ]` pending, `- [x]` done. Append ` — <commit sha>` when a step lands. Do not rename step titles. See `references/progress-format.md`.

### Phase 1: Migracja Supabase — tabele, RLS, trigger

#### Automated

- [x] 1.1 Nazwa pliku migracji odpowiada konwencji `YYYYMMDDHHmmss_short_description.sql` — cab415b
- [x] 1.2 Migracja aplikuje się bez błędów (`supabase start` + `supabase db reset`) — cab415b

#### Manual

- [x] 1.3 Utworzono dwóch testowych użytkowników (A i B) w `auth.users` — cab415b
- [x] 1.4 Jako A: INSERT wiersza `analyses` + kilku `analysis_suggestions` z rosnącym `position` się udaje — cab415b
- [x] 1.5 SELECT: obaj testowi użytkownicy widzą wszystkie wiersze `analyses`/`analysis_suggestions` — cab415b
- [x] 1.6 UPDATE/DELETE `analyses`: dozwolone tylko właścicielowi, odrzucone dla innych — cab415b
- [x] 1.7 Jako A: UPDATE `status` na `'resolved'` się udaje i `updated_at` się zmienia — cab415b
- [x] 1.8 Jako A: UPDATE `query_text` kończy się błędem triggera (niezmienność) — cab415b
- [x] 1.9 INSERT `analysis_suggestions` z cudzym `analysis_id` jest odrzucony przez RLS — cab415b

### Phase 2: Współdzielone typy TS

#### Automated

- [x] 2.1 `npx astro check` przechodzi bez błędów
- [x] 2.2 `npm run lint` przechodzi bez błędów
