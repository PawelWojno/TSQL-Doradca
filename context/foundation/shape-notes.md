---
project: "T-SQL Doradca"
context_type: greenfield
created: 2026-09-21
updated: 2026-09-23
product_type: web-app
target_scale:
  users: small
  qps: low
  data_volume: small
timeline_budget:
  mvp_weeks: 1
  hard_deadline: null
  after_hours_only: true
checkpoint:
  current_phase: 8
  phases_completed: [1, 2, 3, 4, 5, 6, 7]
  gray_areas_resolved:
    - topic: "pain category"
      decision: "workflow friction — no shared, systematic way to catch known low-efficiency T-SQL patterns before they land in review or production"
    - topic: "insight"
      decision: "domain knowledge about known T-SQL anti-patterns, encodable as rules — generic linters/CI don't cover this"
    - topic: "persona scope"
      decision: "one development team inside one company, not multi-tenant"
    - topic: "access model"
      decision: "login required; flat role model, authorization is per-record ownership, not role-based"
    - topic: "account provisioning"
      decision: "invite-only — accounts are created by a team administrator; no self-service sign-up, so the team boundary is the list of invited accounts"
  frs_drafted: 8
  quality_check_status: accepted
---

# Shape Notes — T-SQL Doradca

## Vision & Problem Statement

**Ból / luka:** Deweloperzy w zespole piszą zapytania T-SQL bez wspólnego, systematycznego sposobu wychwytywania znanych, mało wydajnych wzorców (brak klauzuli WHERE na dużej tabeli, `SELECT *`, `LIKE` z wiodącym wildcardem, zagnieżdżone podzapytania zamiast JOIN-ów), zanim trafią do review lub produkcji.

**Osoba:** Deweloper w zespole, który pisze zapytania T-SQL dla warstwy bazodanowej firmy.

**Moment:** Przed scaleniem lub wdrożeniem zapytania T-SQL — dziś ta kontrola odbywa się doraźnie, indywidualnie, podczas pracy każdego dewelopera w jego własnym kliencie bazy danych.

**Koszt dziś:** Jedyną istniejącą kontrolą jest ręczny przegląd — każdy deweloper przegląda własne zapytanie (albo kolegi, nieformalnie) na oko. Jest to niespójne, zależy wyłącznie od uwagi i doświadczenia danej osoby, i nie zostawia żadnej wspólnej, przeszukiwalnej historii tego, co już wcześniej zostało wychwycone.

**Wgląd:** Zespół już wie, które wzorce T-SQL są problematyczne — tę wiedzę można zakodować jako niewielki zbiór statycznych reguł detekcji. To wąska, dobrze zdefiniowana wiedza domenowa, której nie dostarcza generyczny linter ani krok CI, i nie wymaga pełnego zrozumienia planu wykonania zapytania, by dać wartość.

## User & Persona

**Persona główna:** Deweloper w zespole, który pisze i odpowiada za zapytania T-SQL w warstwie bazodanowej firmy — nie anonimowy, ogólny "użytkownik", tylko członek konkretnej, znanej grupy pracującej nad tym samym kodem SQL.

**Zakres persony:** Jeden zespół deweloperski w jednej firmie. Nie produkt wielo-najemcowy dla wielu zewnętrznych zespołów/klientów.

**Moment, w którym sięga po produkt:** Przed scaleniem lub wdrożeniem zapytania T-SQL — wklejenie zapytania, żeby sprawdzić je pod kątem znanych antywzorców i zobaczyć (oraz wykorzystać) to, co już zgłosili koledzy z zespołu.

## Success Criteria

### Primary
- W ciągu dwóch tygodni od udostępnienia zespołowi wspólna historia zawiera co najmniej 5 zapisanych analiz od co najmniej 2 różnych osób — kontrola antywzorców przestaje być indywidualna i zostawia wspólny ślad.
- Każda sugestia zwrócona przez analizę jest oznaczona wagą (wysoka/średnia/niska), więc reviewer rozpoznaje istotność sugestii bez czytania całej listy.

### Secondary
- Sugestie są grupowane/sortowane według wagi, tak by reviewer mógł szybko przejrzeć długi wynik.

### Guardrails
- MVP nigdy nie wykonuje przesłanego zapytania — analizuje wyłącznie tekst zapytania. Brak połączenia z żywą bazą danych.
- Analizy zapytań są widoczne wyłącznie dla zalogowanych członków zespołu, nigdy publicznie — treść zapytania i wyniki mogą ujawniać wrażliwe nazwy tabel/kolumn.

## User Stories

### US-01: Zespołowa analiza zapytania T-SQL pod kątem antywzorców

- **Given** zalogowany członek zespołu deweloperskiego
- **When** wklei treść zapytania T-SQL i uruchomi analizę, a następnie zapisze wynik
- **Then** widzi listę konkretnych sugestii z wagą (severity), a zapisana analiza staje się widoczna dla całego zespołu we wspólnej historii

#### Acceptance Criteria
- Analiza nigdy nie wykonuje zapytania — działa wyłącznie na tekście.
- Zapisana analiza jest natychmiast widoczna dla innych członków zespołu.
- Treść zapytania i wynik zapisanej analizy są niezmienne po zapisie.
- Tylko właściciel analizy może ją usunąć lub zmienić jej status; inni użytkownicy nie mają dostępu do modyfikacji.
- Zapytanie zawierające `SELECT *` skutkuje co najmniej jedną sugestią dotyczącą wskazania kolumn.

## Functional Requirements

### Analiza zapytań
- FR-001: Zalogowany członek zespołu może wkleić tekst zapytania T-SQL i uruchomić jego analizę. Priority: must-have
  > Socratic: Kontrargument rozważony: "ręczne wklejanie nie wejdzie w nawyk bez integracji z edytorem/CI". Rozwiązanie: zaakceptowane ryzyko na MVP; integracja z edytorem/CI to świadomie odłożone rozszerzenie, nie blocker startu.
- FR-002: Zalogowany członek zespołu otrzymuje konkretne sugestie optymalizacji wygenerowane na podstawie reguł statycznych (`SELECT *`, brak WHERE na dużej tabeli, `LIKE '%x%'`, zagnieżdżone podzapytania zamiast JOIN), każda oznaczona wagą (severity). Priority: must-have
  > Socratic: Kontrargument rozważony: "3-5 reguł to za mało, by dać realną wartość zespołowi". Rozwiązanie: zaakceptowane na MVP jako dowód koncepcji; rozbudowa liczby reguł to naturalny następny krok po MVP.
- FR-008: Zalogowany członek zespołu otrzymuje sugestie pogrupowane i posortowane według wagi (wszystkie sugestie wysokiej wagi razem). Priority: nice-to-have

### Historia i zarządzanie analizami
- FR-003: Zalogowany członek zespołu może zapisać wynik analizy (treść zapytania, wynik, data) do wspólnej historii zespołu. Priority: must-have
  > Socratic: Kontrargument rozważony: "użytkownicy zapomną kliknąć zapisz, historia będzie niekompletna". Rozwiązanie: świadomie zostaje ręczny zapis — użytkownik decyduje, które analizy trafiają do wspólnej historii, co zapobiega zaśmiecaniu jej eksperymentami.
- FR-004: Każdy zalogowany członek zespołu widzi pełną historię analiz wykonanych przez cały zespół. Priority: must-have
  > Socratic: Kontrargument rozważony: "pełna treść zapytań może ujawniać wrażliwe nazwy tabel/kolumn wewnątrz firmy". Rozwiązanie: zaakceptowane na MVP — to jeden zaufany zespół w jednej firmie; opcja prywatnych analiz jest już świadomie odłożona poza MVP.
- FR-005: Właściciel analizy może zmienić jej status (np. na "rozwiązane"). Priority: must-have
  > Socratic: Kontrargument rozważony: "często to reviewer, nie autor, faktycznie rozwiązuje problem". Rozwiązanie: zostaje tylko właściciel na MVP — prostszy model uprawnień; jeśli reviewer chce oznaczyć jako rozwiązane, prosi autora.
- FR-006: Właściciel analizy może usunąć własną analizę; inni członkowie zespołu nie mogą usuwać ani modyfikować cudzych analiz. Priority: must-have
  > Socratic: Kontrargument rozważony: "usuwanie w ogóle niepotrzebne — historia powinna być append-only". Rozwiązanie: zostaje usuwanie własnych analiz — możliwość posprzątania błędnie wklejonych/testowych zapytań przeważa nad ryzykiem "zgubionej historii".

### Dostęp
- FR-007: Niezalogowany użytkownik próbujący wejść na dowolną stronę produktu jest przekierowywany do logowania. Priority: must-have
  > Socratic: Kontrargument rozważony: "ryzyko, że któraś ze stron produktu zostanie przypadkiem wystawiona bez wymogu logowania". Rozwiązanie: FR stoi; kontrargument staje się wymogiem testowym — test end-to-end powinien objąć też sprawdzenie, że wejście na stronę bez zalogowania kończy się przekierowaniem.

## Non-Functional Requirements

- Wynik analizy tekstu zapytania pojawia się w czasie odczuwalnym jako natychmiastowy (poniżej 1 sekundy dla pojedynczego zapytania).
- Zapisane analizy przetrwają odświeżenie strony i ponowne wejście do aplikacji — historia zespołu jest trwała między sesjami.
- Treść zapytania i wyniki analizy nigdy nie są dostępne bez zalogowania ani poza kontem danego zespołu/firmy.

## Business Logic

Aplikacja wykrywa mało wydajne wzorce w tekście zapytania T-SQL i zwraca konkretne, dopasowane do wzorca sugestie optymalizacji.

Wejściem reguły jest tekst zapytania T-SQL wklejony przez użytkownika. Wyjściem jest lista konkretnych sugestii optymalizacji, każda przypisana do rozpoznanego wzorca (np. `SELECT *` zamiast wskazanych kolumn, brak WHERE na dużej tabeli, `LIKE` z wiodącym wildcardem, zagnieżdżone podzapytanie zamiast JOIN) i oznaczona wagą (severity). Użytkownik napotyka tę regułę bezpośrednio po wklejeniu zapytania — wynik pojawia się w tej samej sesji, przed ewentualnym zapisaniem do wspólnej historii zespołu.

## Access Control

Wymagane logowanie — każda akcja w produkcie wymaga uwierzytelnionej sesji. Brak dostępu anonimowego.

Konta powstają wyłącznie z zaproszenia wystawionego przez administratora zespołu — nie ma samodzielnej rejestracji. Granica zespołu to lista zaproszonych kont: "zalogowany" i "członek zespołu" są tożsame, bo nikt z zewnątrz nie może utworzyć konta. Logowanie jest jedyną ścieżką wejścia do produktu.

Płaski model ról — brak hierarchii ról. Autoryzacja jest egzekwowana na poziomie rekordu, na podstawie własności:
- **Podgląd**: każdy zalogowany członek zespołu widzi każdą analizę (wspólna historia zespołu).
- **Modyfikacja / usunięcie**: tylko właściciel analizy może zmienić jej status lub ją usunąć.
- Niezalogowany użytkownik próbujący wejść na dowolną stronę produktu jest przekierowywany do logowania.

## Non-Goals

- **Wsparcie dla dialektów SQL innych niż T-SQL** (Postgres, MySQL, Oracle) — projekt celuje wyłącznie w T-SQL/SQL Server.
- **Automatyczne wykonywanie zapytań na żywej bazie danych** — aplikacja analizuje wyłącznie treść tekstową zapytania, nigdy go nie uruchamia.
- **Zarządzanie uprawnieniami i kontami wewnątrz produktu** — płaski model kont z zaproszeniami wystarcza; nie budujemy panelu administracyjnego ani ekranów zapraszania.
- **Wzorce wymagające wiedzy o schemacie bazy** (np. brakujący indeks, nieoptymalna kolejność JOIN-ów) — ich wykrycie wymaga dostępu do metadanych schematu lub planu wykonania, a nie tylko tekstu zapytania; MVP ogranicza się do wzorców wykrywalnych statycznie z samego tekstu (patrz FR-002).
- **Prywatna widoczność analiz** — każda zapisana analiza jest widoczna dla całego zespołu; oznaczanie analiz jako prywatnych jest poza MVP, bo koszt pomyłki w uprawnieniach dostępu (cichy wyciek bez żadnego sygnału) przewyższa wartość tej opcji na tym etapie.

## Open Questions

1. **Czy zaproszenie nowego członka zespołu odbywa się w produkcie, czy poza nim (ręcznie przez administratora)?** — Owner: user. Block: no (nie wpływa na żaden FR MVP; Non-Goals wyklucza dziś panel administracyjny, więc domyślnie zakładanie kont dzieje się poza produktem).

## Forward: technical-roadmap

Nie część PRD — do podjęcia po MVP, jako świadome rozszerzenia, nie warunek startu.

**Dlaczego MVP startuje od regex, nie od parsera AST ani LLM:** rozważone kryteria to trudność zadania (wykrywanie znanych antywzorców jest wąskie i wzorcowe, nie wymaga pełnej struktury zapytania) i koszt pomyłki (sugestia nigdy nie trafia bezpośrednio na produkcję — użytkownik czyta, ocenia i testuje, zanim cokolwiek zmieni; błąd kosztuje sekundy uwagi, nie awarię). Regex nie rozumie struktury zapytania, tylko tekst — może dać false positive na nietypowo sformatowanym zapytaniu (np. wzorzec wewnątrz komentarza SQL). Niski koszt pomyłki, szybkość implementacji i pełna testowalność każdej reguły osobno przeważają nad tym ryzykiem na etapie MVP.

1. **Parser AST** (np. `node-sql-parser`, `sqlglot`) — eliminuje false positive z regexów przez analizę struktury zamiast tekstu.
2. **Analiza przez LLM** — wysłanie zapytania do modelu (profil "lekki", np. Haiku) z promptem wymuszającym strukturalną odpowiedź JSON (`findings`: `issue`, `severity`, `explanation`, `suggestion`).
3. **Hybryda** — regex jako szybka pierwsza warstwa, LLM jako opcjonalne pogłębione wyjaśnienie na żądanie.
4. **Widoczność publiczna/prywatna analiz** — autor oznacza analizę jako prywatną, widoczną tylko dla siebie. Odłożone świadomie z uwagi na koszt pomyłki przy uprawnieniach dostępu (cichy wyciek danych bez sygnału), nie z braku pomysłu na rozwiązanie.
5. **Wykrywanie wzorców wymagających metadanych schematu / planu wykonania** (brakujący indeks, kolejność JOIN-ów) — kierunek rozwoju po MVP; sama decyzja zakresowa dla MVP mieszka w `## Non-Goals`.

## Forward: tech-stack

**Zakres integracji CI/CD:** projekt nie integruje się z zewnętrznymi narzędziami CI/CD klienta — wystarczy własny pipeline projektu. To decyzja o kształcie CI/CD, czyli materiał dla kroku doboru stacku, nie non-goal produktowy.

Projekt startuje na fundamencie `10x-astro-starter` (Astro 6 SSR + React 19 islands, Supabase auth, Cloudflare Workers) — istniejące moduły auth/middleware/CI-CD tego startera są traktowane jako techniczny punkt wyjścia, nie jako "istniejący produkt" z realnymi użytkownikami. Nowy moduł ma korzystać z istniejącej sesji logowania i konwencji projektu (walidacja zod, `cn()` do klas Tailwind, typy w `src/types.ts`, migracje Supabase z RLS per-operację/per-rolę) zamiast budować własne od zera. To wskazówka dla kroku doboru/oceny stacku, nie treść PRD.
