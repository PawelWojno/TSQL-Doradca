# Doradca T-SQL — aplikacja wspomagająca optymalizację zapytań SQL

## Pytanie kontrolne (z tabeli lekcji "Projekt kursowy - mniejszy, niż myślisz")

> **Aplikacja wspomaga Dewelopera baz danych w optymalizacji zapytań T-SQL, wykrywając mało wydajne wzorce kodu.**

Jedno zdanie, bez "i" / "oraz" / "a także" — spełnia kryterium z lekcji. Jasno określa: kto (deweloper baz danych), co (optymalizacja zapytań T-SQL) i jak (wykrywanie mało wydajnych wzorców).

## Persona i kontrola dostępu (doprecyzowane)

**Persona:** zespół deweloperów w firmie — nie pojedynczy anonimowy "użytkownik", a konkretna grupa osób pracujących nad tym samym kodem T-SQL.

**Kontrola dostępu (odczyt vs modyfikacja):**
- Każdy członek zespołu **widzi wszystkie** analizy zapytań wykonane przez innych — wspólna, współdzielona historia.
- Każdy może **modyfikować/usuwać tylko własne** analizy.
- Uwierzytelnianie realizowane przez mechanizm dostarczony przez scaffold `10x-astro-starter` (Supabase auth) — wykorzystywany jako gotowy fundament techniczny, nie jako istniejący produkt z zachowaniem do zachowania (nie ma dziś wdrożonej aplikacji ani jej użytkowników — zespół pracuje w SQL Studio).

**Szacunek czasu pierwszego przepływu:** mieści się w tydzień pracy po godzinach — auth i CI/CD są już gotowe z istniejącego projektu, a MVP to 4 reguły regex + prosty CRUD + jeden test end-to-end. Największe ryzyko czasowe to nie kod, a pokusa podłączenia żywej bazy danych (patrz sekcja "Największe ryzyko" niżej). Szacunek do zweryfikowania w praktyce, nie twarda obietnica.

## MVP — jeden konkretny przepływ

Rdzeń projektu na pierwszy tydzień:

> Użytkownik wkleja zapytanie SQL → aplikacja analizuje je i pokazuje konkretne sugestie optymalizacji (np. `SELECT *` zamiast wskazanych kolumn, brak `WHERE` na dużej tabeli, `LIKE '%x%'` z wildcardem na początku) → użytkownik zapisuje historię analiz.

**Czego NIE potrzeba na start:**
- podłączenia do żywej bazy danych,
- automatycznego wykonywania zapytań,
- wsparcia dla wielu dialektów SQL naraz (Postgres/MySQL/Oracle),
- integracji z CI/CD klienta.

## Mapowanie na sześć wymagań z lekcji

| # | Wymaganie | Realizacja w projekcie |
|---|---|---|
| 1 | Kontrola dostępu | Supabase auth (mechanizm dostarczony przez scaffold `10x-astro-starter`) — cały zespół widzi wszystkie analizy, modyfikacja/usuwanie tylko własnych |
| 2 | Zarządzanie danymi | CRUD na analizowanych zapytaniach: treść zapytania, wynik analizy, data, status (open/resolved — zmienialny tylko przez właściciela); przegląd historii, usuwanie starych analiz (tylko własnych) |
| 3 | Logika biznesowa | Wykrywanie antywzorców T-SQL — patrz sekcja niżej |
| 4 | Artefakty (PRD, kontekst dla AI) | Naturalnie powstaną w modułach 1-3 kursu |
| 5 | Test kluczowego przepływu | Test end-to-end: zapytanie z `SELECT *` → aplikacja zwraca sugestię dot. kolumn |
| 6 | CI/CD | Już gotowe w obecnym projekcie (lint → build → deploy) |

## Logika biznesowa — dwie możliwe ścieżki

**Prostsza (rekomendowana na start):**
Reguły statyczne (regex / parser SQL) wykrywające znane antywzorce:
- `SELECT *`
- brak `WHERE` na dużej tabeli
- `LIKE '%x%'` blokujące wykorzystanie indeksu
- zagnieżdżone podzapytania zamiast JOIN-a

**Trudniejsza (bardziej "AI", opcjonalnie później):**
Wysłanie zapytania do LLM z promptem analizującym pod kątem wydajności i sparsowanie odpowiedzi na strukturalne sugestie.

Na start: 3-5 reguł statycznych — łatwiejsze do przetestowania i wystarczające jako "jedno zdanie logiki biznesowej".

## Obrona wyboru: regex zamiast parsera AST / LLM

> **Zdaję sobie sprawę, że regex może dać fałszywy alarm na nietypowo sformatowanym zapytaniu — np. złapać wzorzec `LIKE '%x%'` wewnątrz komentarza SQL, mimo że nie jest on częścią właściwej klauzuli. Parser AST by tego uniknął, bo operuje na strukturze zapytania, nie na tekście. Na etapie MVP akceptuję to ryzyko, ponieważ sugestia zawsze przechodzi przez użytkownika przed wdrożeniem — błędna podpowiedź kosztuje sekundy uwagi, nie awarię produkcyjną. Jeśli projekt się rozwinie, przejście na AST jest naturalnym następnym krokiem bez zmiany reszty architektury.**

Rozbicie tego rozumowania na dwa kryteria z lekcji o wyborze modeli/podejść (Jak trudno zrobić to dobrze? / Ile kosztuje pomyłka?), zastosowane tu do wyboru techniki implementacji:

- **Trudność zadania**: wykrywanie znanych antywzorców SQL (np. `SELECT *`, `LIKE '%x%'`) to zadanie wąskie i wzorcowe — nie wymaga rozumienia pełnej struktury zapytania, żeby dać wartość.
- **Koszt pomyłki**: sugestia z aplikacji nigdy nie trafia bezpośrednio na produkcję. Użytkownik czyta, ocenia i testuje propozycję, zanim cokolwiek zmieni w prawdziwym kodzie — błąd (false positive) kosztuje tyle, co kilka sekund uwagi użytkownika, nie awarię produkcyjną.

**Konkretna strata przy wyborze regexów:** regex nie rozumie struktury zapytania, tylko jego tekst. Może dać false positive na nietypowo sformatowanym zapytaniu (np. złapać wzorzec wewnątrz komentarza SQL albo stringa, który nie jest częścią właściwej klauzuli). Parser AST (Abstract Syntax Tree) nie popełniłby tego błędu, bo operuje na strukturze, a nie na surowym tekście.

**Dlaczego mimo to regex jest właściwym wyborem na MVP:** niski koszt pomyłki + szybkość implementacji + pełna testowalność każdej reguły osobno przeważają nad ryzykiem rzadkich false positive na etapie projektu kursowego.

## Plan dalszego rozwoju (poza MVP)

Trzy kierunki rozbudowy logiki biznesowej, do rozważenia **po** zaliczeniu podstawowego MVP — nie jako wymóg startowy:

1. **Parser AST** (np. `node-sql-parser` w TS, `sqlglot` w Pythonie) — zamiana zapytania na drzewo składniowe i analiza struktury zamiast tekstu. Eliminuje false positive z regexów, ale wymaga nauki nowej biblioteki i przechodzenia po drzewie.
2. **Analiza przez LLM** — wysłanie zapytania do modelu z promptem wymuszającym strukturalną odpowiedź JSON (`findings` z polami `issue`, `severity`, `explanation`, `suggestion`). Do prostego, dobrze zdefiniowanego zadania wystarczy model z profilu "lekki" (np. Haiku) — niższy koszt i czas odpowiedzi bez utraty jakości przy tak wąskim zadaniu.
3. **Hybryda** — regex jako szybka pierwsza warstwa (pewne, częste przypadki), LLM jako opcjonalne "pogłębione wyjaśnienie" wywoływane na żądanie użytkownika dla bardziej złożonych zapytań.
4. **Widoczność publiczna/prywatna analiz** — autor może oznaczyć swoją analizę jako prywatną (niewidoczną dla reszty zespołu). Wymaga dwóch skrzyżowanych polityk RLS (SELECT: `is_private = false OR user_id = auth.uid()`; UPDATE/DELETE: tylko właściciel) oraz testu potwierdzającego, że prywatna analiza jest **niewidoczna** dla innego użytkownika (nie tylko że jest widoczna dla właściciela — to dwa osobne testy). Zidentyfikowane przez `/10x-idea-check` jako nietrywialne z uwagi na koszt pomyłki (błąd w RLS ujawniłby prywatne dane cicho, bez sygnału) — odłożone poza MVP świadomie, nie z powodu braku pomysłu na rozwiązanie.
5. **Zmiana statusu przez dowolnego członka zespołu, nie tylko właściciela** — rozwiązuje realny scenariusz "reviewer, nie autor, faktycznie naprawia problem". Wymaga RLS różnicującego uprawnienia per-pole (UPDATE statusu dostępne dla całego zespołu, pozostałe pola — treść, wynik analizy — tylko dla właściciela), technicznie trudniejsze niż prosta reguła ownership na całym wierszu z MVP. Na MVP: reviewer prosi autora o zmianę statusu — akceptowalne tarcie.

Rekomendacja: zacząć od regexów (MVP), traktować AST i LLM jako świadome rozszerzenia po zaliczeniu podstawowych wymagań, a nie jako warunek startu.

## Non-goals (trwale poza zakresem, nie "na później")

Odróżnione od sekcji "Plan dalszego rozwoju" wyżej — to nie rzeczy odłożone w czasie, a świadomie wykluczone z tego projektu:

- **Wsparcie dla dialektów SQL innych niż T-SQL** (Postgres, MySQL, Oracle) — projekt celuje wyłącznie w T-SQL/SQL Server.
- **Automatyczne wykonywanie zapytań na żywej bazie danych** — aplikacja analizuje wyłącznie treść tekstową zapytania, nigdy go nie uruchamia.
- **Zarządzanie uprawnieniami na poziomie roli/administratora zespołu** — nie budujemy panelu administracyjnego do zarządzania członkami zespołu; korzystamy z istniejącego mechanizmu kont.
- **Integracja z zewnętrznymi narzędziami CI/CD klienta** (poza własnym pipeline'em projektu).
- **Edycja treści zapisanej analizy** — analizy są create + read + delete (własne) + zmiana statusu; treść zapytania i wynik analizy są niemodyfikowalne po zapisaniu — jeśli coś jest złe, usuwasz i analizujesz ponownie.
- **Automatyczny zapis analizy** — zapis do historii jest zawsze świadomym, ręcznym krokiem użytkownika, nie dzieje się automatycznie po każdej analizie (kompensuje brak flagi prywatności na tym etapie).
- **Zmiana statusu analizy przez kogoś innego niż właściciel** (np. reviewer, lead) w MVP — patrz punkt 5 w "Plan dalszego rozwoju".

## Największe ryzyko: próg zero-to-one

Pokusa podłączenia się do prawdziwej bazy danych i uruchamiania `EXPLAIN ANALYZE` brzmi kusząco, ale wprowadza tydzień pracy nad bezpiecznym łączeniem się z cudzą bazą, zanim cokolwiek zadziała.

**Decyzja:** MVP działa wyłącznie na treści tekstowej zapytania, bez wykonywania go gdziekolwiek. Podłączenie do żywej bazy — jako rozszerzenie "na później", jeśli starczy czasu.
