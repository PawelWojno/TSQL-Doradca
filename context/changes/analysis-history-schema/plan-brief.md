# Schemat Supabase dla zapisanych analiz (F-01) — Plan Brief

> Full plan: `context/changes/analysis-history-schema/plan.md`

## What & Why

Budujemy fundament danych pod całe MVP T-SQL Doradcy: tabelę na zapisane analizy T-SQL (treść zapytania, wynik, status, właściciel) z RLS wymuszającym regułę "cały zespół widzi, tylko właściciel modyfikuje/usuwa" z PRD. Bez tego F-01 żadna z dwóch kolejnych pozycji roadmapy (S-01: analiza + zapis, S-02: zarządzanie cyklem życia) nie ma gdzie zapisywać danych.

## Starting Point

Projekt ma skonfigurowany Supabase CLI (`supabase/config.toml`) i pełny flow auth (`src/lib/supabase.ts`, `src/middleware.ts`), ale nie ma jeszcze ani jednej migracji (`supabase/migrations/` nie istnieje) ani pliku `src/types.ts` na współdzielone typy.

## Desired End State

Po tej zmianie w bazie Supabase istnieją dwie tabele z włączonym RLS — `analyses` i `analysis_suggestions` — gotowe do zapisu przez przyszłe endpointy S-01. `src/types.ts` eksportuje odpowiadające im typy TS. Aplikacja nie zyskuje żadnego nowego ekranu ani endpointu — to czysty fundament.

## Key Decisions Made

| Decision                             | Choice                                                        | Why (1 sentence)                                                                                                                      | Source |
| ------------------------------------ | ------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------- | ------ |
| Przechowywanie wyniku analizy        | Osobna tabela `analysis_suggestions` (nie JSONB)              | Wybór użytkownika — normalizacja zamiast blobu                                                                                        | Plan   |
| Model statusu                        | Zamknięty `CHECK` z dwiema wartościami (`open`/`resolved`)    | PRD podaje tylko jeden przykład stanu; zamknięta lista upraszcza UI i zapobiega literówkom                                            | Plan   |
| Klucz główny                         | `uuid` z `gen_random_uuid()`                                  | Spójne z `auth.users.id` (też `uuid`), bez konwersji typów w FK/RLS                                                                   | Plan   |
| Usunięcie konta właściciela          | `ON DELETE RESTRICT` na `owner_id`                            | Wspólna historia zespołu to ślad audytowy — RESTRICT chroni przed cichą utratą danych                                                 | Plan   |
| Śledzenie zmian statusu              | Kolumna `updated_at` + trigger                                | Tani koszt teraz, pozwala pokazać "kiedy oznaczono jako rozwiązane" bez migracji później                                              | Plan   |
| Niezmienność `query_text` po zapisie | Trigger `BEFORE UPDATE`, nie tylko RLS                        | RLS pozwala właścicielowi na UPDATE (dla statusu), ale nie ogranicza kolumn — bez triggera właściciel mógłby nadpisać treść zapytania | Plan   |
| Kolejność sugestii                   | Kolumna `position smallint` + `unique(analysis_id, position)` | Zwykły SELECT nie gwarantuje kolejności wstawienia, zwłaszcza przy identycznym `created_at` w batch insert                            | Plan   |

## Scope

**In scope:**

- Migracja SQL: tabele `analyses` + `analysis_suggestions`, RLS per-operację, trigger niezmienności/`updated_at`
- `src/types.ts`: typy `Analysis`, `AnalysisSuggestion`, `AnalysisStatus`, `AnalysisSeverity`

**Out of scope:**

- Generowanie typowanego klienta Supabase (`Database` types) — S-01
- Endpointy API i UI do analizy/zapisu/zarządzania — S-01, S-02
- Rozszerzenie `PROTECTED_ROUTES` w middleware — S-01
- Silnik reguł statycznych (`rule_code` values) — S-01
- Grupowanie/sortowanie wg wagi (FR-008) — sparkowane w roadmapie

## Architecture / Approach

Jedna addytywna migracja Supabase z dwiema znormalizowanymi tabelami połączonymi `ON DELETE CASCADE`, granularnym RLS (SELECT dla całego zespołu, INSERT/UPDATE/DELETE tylko dla właściciela) i jednym triggerem `BEFORE UPDATE` na `analyses`, który jednocześnie blokuje zmianę niezmiennych kolumn i utrzymuje `updated_at`. Druga faza dokłada odpowiadające typy TS bez dotykania istniejącego kodu.

## Phases at a Glance

| Phase                    | What it delivers                                           | Key risk                                                                                                                |
| ------------------------ | ---------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| 1. Migracja Supabase     | Tabele `analyses`/`analysis_suggestions` z RLS i triggerem | Pierwsza migracja w projekcie — brak lokalnego wzorca do skopiowania, opieramy się wyłącznie na konwencji z `CLAUDE.md` |
| 2. Współdzielone typy TS | `src/types.ts` z encjami dla nowego schematu               | Niskie — czyste deklaracje typów, zero logiki                                                                           |

**Prerequisites:** Docker uruchomiony lokalnie (wymagany przez `npx supabase start` do weryfikacji migracji)
**Estimated effort:** ~1 sesja, 2 fazy

## Open Risks & Assumptions

- Zakładamy, że `rule_code` pozostaje wolnym tekstem (nie enum/CHECK) — lista reguł należy do S-01 i nie powinna wymagać migracji schematu przy każdej nowej regule.
- Zakładamy angielskie wartości `severity`/`status` (`high`/`medium`/`low`, `open`/`resolved`) jako wewnętrzny kontrakt danych, tłumaczony na polski dopiero w UI przez S-01.

## Success Criteria (Summary)

- Migracja aplikuje się czysto lokalnie (`supabase db reset`) i tworzy obie tabele z włączonym RLS
- Dwóch testowych użytkowników potwierdza ręcznie: współdzielona widoczność (SELECT), wyłączność właściciela (UPDATE/DELETE), niezmienność treści zapytania (trigger)
- `npx astro check` i `npm run lint` przechodzą po dodaniu `src/types.ts`
