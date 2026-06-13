# Review: `feat/rebuild-utopia-cli` — 2026-06-10

Zakres: wartość biznesowa, review implementacyjne, kierunki rozwoju, feedback loop 3 niezależnych agentów (2 rundy). Branch: 12 commitów (2 fazy: 17.05 i 10.06), 111 plików, +7362/−2330. Autor: Opus 4.8.

## TL;DR

Architektura i myślenie projektowe są mocne (najlepsze elementy: `describe`/`doctor` z wersjonowaną schemą, dyscyplina scopingu MCP, 42 sensowne testy, CI). Ale **dwie rzeczy, dla których ten rebuild istnieje, nie działają w punkcie użycia**: integracja Claude Code skills (zły schemat `settings.json`) i resolucja bricków po instalacji z pub.dev na Windows. Do tego doctor nigdy nie zwraca non-zero, a PLAN/REVIEW zawierają ~12 fałszywych/nieaktualnych twierdzeń. Zgodna ocena 3 agentów + moja: **5/10, po naprawie release-gate → 7/10**. Nie mergować bez poprawek z sekcji „Priorytety".

## 1. Blockery (zweryfikowane w kodzie i oficjalnych docs)

**B1. Wygenerowany `.claude/settings.json` używa nieistniejących kluczy** — flagowa funkcja CLI jest martwa. Brick emituje `"marketplaces": [{"source": "github:..."}]` + `"enabledPlugins": ["utopia-hooks"]`. Aktualny schemat Claude Code (code.claude.com/docs/en/settings): `extraKnownMarketplaces` (mapa nazwa → `{source: {source: "github", repo: "..."}}`) i `enabledPlugins` jako obiekt `"utopia-hooks@<marketplace>": true`. URL `$schema` w pliku zwraca 404 (prawdziwy: json.schemastore.org/claude-code-settings.json). Zły format jest powielony w 3 brickach + zakodowany w checku doctora (`checks.dart:182` — substring `'"utopia-hooks"'` po poprawce zacznie flagować *poprawne* configi) + w fixture'ach testów. Bonus: repo marketplace zostało przemianowane na `Utopia-USS/utopia-skills` (301 z starej nazwy). Ryzyko było flagowane w PLAN §11.2 i REVIEW §2 — i mimo to wyshipowane jako ✓. Fix: jedna współdzielona stała schematu (brick + check + testy), godziny pracy.

**B2. `BrickLocator` nie znajdzie bricków po `dart pub global activate` na Windows.** Strategie pub-cache są bramkowane substringiem `'.pub-cache'` (`brick_locator.dart:41`), a domyślny cache na Windows to `%LOCALAPPDATA%\Pub\Cache`. Brak fallbacku `PUB_CACHE`/package_config — mimo że PLAN §3.4 twierdzi, że istnieje. Każde `create`/`add`/`init` rzuci wyjątkiem po publikacji u największej kohorty userów Fluttera. CI nie ma joba Windows, więc tego nie widzi.

**B3. Wygenerowana apka nie jest „flutter run-ready".** `app_localizations.dart` ma `part 'app_localizations.g.dart'` (plik nigdy nie generowany, wymaga build_runnera i realnego Google Sheet — placeholder `DOCID`/`SHEETID`), a output sukcesu mówi `→ flutter run` bez słowa o codegen. Do tego stary `.gitkeep` z instrukcjami MVP trafia do rootu każdej wygenerowanej apki.

**B4. Fałszywe sukcesy.** Porażki `flutter create`/`git init`/`pub get` → exit 0 + success next-steps. `doctor` na nieistniejącym roocie → exit 0 i czysty raport. `doctor` w ogóle nie może zwrócić non-zero (zero reguł o severity `error` — test sam to przyznaje), więc reklamowany „CI gate" jest pusty. Dla konsumenta-agenta to najgorsza klasa błędu: czyta sukces i jedzie dalej na śmieciach.

## 2. Wartość biznesowa (lens: praca developerska + CLI dla agentów AI)

Kontekst rynkowy (zweryfikowany przez agenta-biznesowego): utopia_hooks ~8 like'ów na pub.dev, skills repo 0 gwiazdek; very_good_cli 1.0 ma własny MCP server i AI plugin; Google shipuje oficjalny `dart mcp-server`. Wniosek: generyczne warstwy są skomodytyzowane — broni się tylko to, co zna **semantykę utopii**.

| Komenda | Wartość wewn. | Wartość zewn. | Werdykt |
|---|---|---|---|
| `create flutter_app` | średnio-wysoka | niska (VGV) | table stakes; dziś poniżej — output się nie kompiluje (B3) |
| `create flutter_package` | niska | ~zero | nice-to-have |
| `add screen` | średnia | niska | redundancja ze skillem `/utopia-hooks` — zunifikować, nie dublować |
| `init skills` | średnia | **potencjalnie najwyższa konwersja** | dziś martwe (B1); po fixie — najlepszy lejek do stacku |
| `describe` | średnio-wysoka (agenci wewn.) | niska | ciekawy zakład; największy koszt utrzymania (regex rot — 9 fixów przed startem) |
| `doctor` | **wysoka** | najlepszy kandydat | działa na obcych repo (`artifacts:bloc/riverpod/...`) → instrument pre-sales konsultingu („policz artefakty BLoC, wyceń migrację"); wymaga B4 + ścieżek |
| `mcp` | średnia | mała | scoping (bez generatorów) słuszny; as-built to czysty transport — brak `outputSchema`/`structuredContent`, brak bundlingu w pluginie |
| `bump` | niska | ~zero | vanity — Renovate/Dependabot to rozwiązały; zamrozić |
| `update` | niska | niska | table stakes; uwaga: nag przy lokalnej wersji nowszej niż pub.dev |

**Kierunek „CLI dla agentów AI" — ocena:** trend realny (agent-friendly CLI z `--json` to standard 2025-26), scoping MCP-vs-Bash w branchu jest *lepszy* niż u VGV. Ale przewaga nie leży w „MCP dla Fluttera" (skomodytyzowane), tylko w **kontrakcie architektonicznym**: deterministyczny, wersjonowany opis konwencji utopia + audyt z exit code, którego CI może pilnować. Agent czytający kod daje opinię; `doctor` daje regression test architektury. To jest wedge — pod warunkiem, że przestanie kłamać (B4, hardcoded `confidence: high`, `registered_in` bez weryfikacji członkostwa w mapie route'ów).

## 3. Review implementacyjne per segment

| Segment | Werdykt | Najważniejsze |
|---|---|---|
| runner + bin + update | acceptable | nag/downgrade gdy lokalna > pub.dev (`isUpToDate` nieużyte); update-check pisze na stdout po sesji MCP; brak catch-all dla wyjątków poza Usage |
| create + bricki | needs-work | B3, B4; `# TODO remove unnecessary dependencies` w każdym pubspecu; zmienna `year` deklarowana, nieużywana; stary README bricka |
| add screen + locator | needs-work | B2; przy wielu wersjach w hosted cache bierze pierwszą z `listSync` (łamie „atomic versioning" — powinno matchować `utopia_cli-$packageVersion`); brak checku, czy jesteśmy w projekcie |
| init skills | broken (B1) | mechanika komendy OK (`--force`, hinty doctorowe — dobre); jedyna działająca ścieżka to ręczny `/plugin marketplace add` z `.claude/README.md` |
| describe | acceptable+ | najlepiej zaprojektowany moduł; drift doc-vs-impl na „pinned v1": `config_builder` zawsze null, `generated_at_git_ref` nieemitowane, `confidence` zawsze `high` (0 konstrukcji medium/low), nieosiągalne enumy (`subscreen_fragment`, `cross_package_import`...), nagłówek „DRAFT" + wyciekła ścieżka `~/.claude/plans/...`; CLI `--routes-only` i MCP `describe_routes` emitują różne kształty; go_router scan z `take(200)` (dotyczy tylko detekcji go_routera — skan foreign artifacts jest pełny); RegExp kompilowany per linia × ~18 wzorców (perf na dużych repo) |
| doctor | needs-work | B4; ścieżki `Finding.file` **mieszane** (część project-root-, część package-relative) → auto-fix agenta w monorepo Melos trafia w złe pliki, a monorepo to deklarowany główny case; crashed check nieodróżnialny od passed w JSON; `--human` idzie na stdout, nie stderr (psuje `| jq`); same gate'y aktywacji — dobre |
| mcp | acceptable | zero testów (skasowane przy removal, nieprzywrócone przy re-add); `_runDoctor` bez per-check try/catch |
| bump | acceptable | regex pomija pre-release (`^0.0.1-dev.2`) — a ekosystem utopii jest dev-suffix-heavy — bez żadnej notki; zero testów jedynej komendy mutującej pliki usera; sam patching (reverse-offset) poprawny |
| testy + CI + publish | needs-work | describe/doctor testy realne (25); create/add tylko walidacje negatywne; locator: brak testów pub-cache wbrew REVIEW §3.1; pubspec ma 6 topics (limit pub.dev: 5); PLAN/REVIEW/schema-doc pójdą do paczki (brak `.pubignore`) z osobistą ścieżką `/Users/jakobkirchner/...` i nazwami projektów klienckich; CONTRIBUTING/CHANGELOG miejscami nieaktualne |
| `.utopia.yaml` | dead code | `UtopiaConfig.load` — zero call sites; README sprzedaje to jako działające |

**Meta-wniosek o pracy Opus 4.8:** wzorzec spójny — bardzo dobre dokumenty projektowe i szkielet, słabe domknięcie weryfikacji dokładnie na szwach integracyjnych (settings.json, pub-cache, exit codes). PLAN/REVIEW nie są wiarygodne bez weryfikacji linia-po-linii: m.in. „package_config fallback" (nie istnieje), „update --force" (brak), „--lints flag" (brak), „first commit staged" (brak), „testy pub-cache layout" (brak), „localization udokumentowana w next-steps" (nie jest). REVIEW.md uczciwie flaguje część ryzyk — ale flagowanie nie zastąpiło 5-minutowego sprawdzenia docs.

## 4. Kierunki rozwoju (konwergencja agentów + moje)

1. **Jeden silnik reguł, trzy powierzchnie.** `doctor --files <paths>` jako backend PostToolUse hooka ze skilla (per-edit), pełny `doctor` w CI (per-repo), MCP dla sesji. Dziś `quality_check.sh` i doctor to dwa rozjeżdżające się zbiory reguł.
2. **Generatory transakcyjne dla agentów.** `add screen --register-route --json` → `{files_created, route_registered_at: "file:line"}` (describe zna `routing.config_file`). Zamienia 3-krokowy workflow agenta w 1 zweryfikowany krok. Skill = frontend konwersacyjny, CLI = deterministyczny backend.
3. **Doctor jako instrument konsultingowy.** Po B4 + ścieżkach: podsumowanie per-framework counts, case study before/after migracji BLoC→utopia na realnym repo. Jedyna ścieżka do zewnętrznego przychodu niezależna od adopcji stacku.
4. **Pomiar zamiast wiary (90 dni).** Zainstrumentować własnych agentów/skille: czy faktycznie wołają describe/doctor wielokrotnie per sesja? Jeśli nie — teza „CLI dla agentów" sfalsyfikowana wewnętrznie, zanim poprosimy o uwagę społeczność.
5. **Analyzer-backed core (v2, warunkowo).** Regex rot to argument za cienkim layerem na Dart analyzer dla 5 semantyk utopii (screen-kind, state attachment, global registration, route membership, view purity) — nie za porzuceniem. Tylko po pozytywnym wyniku pomiaru z pkt 4.
6. **Moje dodatkowe:** (a) `utopia init agents` — generowanie `CLAUDE.md` z konwencjami stacku + snapshotem describe (tani, wysoka wartość dla agentów, nieobecny dziś); (b) doctor jako publikowany GitHub Action (turnkey CI gate); (c) agregacja raportów doctor across repo klienckich = „fleet dashboard" driftu architektury dla software house'u. MCP: zamrozić (nie kasować) do czasu konsumenta bez Basha; describe-kosmetyka (filtry, --compact) za pomiarami.

## 5. Feedback loop — przebieg

Runda 1: trzej niezależni agenci (implementacja / biznes / agent-infra), neutralne briefy, bez moich ocen. **Wszyscy trzej niezależnie znaleźli B1** (w tym 404 na `$schema`) — silna kalibracja. Runda 2: wymiana pełnych recenzji, rebuttale z re-weryfikacją w źródłach. Efekty pętli: korekta twierdzenia z rundy 1 (`take(200)` dotyczy tylko go_routera, nie skanu artefaktów — skan jest pełny, co *wzmacnia* wedge doctora); eskalacja problemu ścieżek doctora (są mieszane, nie jednolicie package-relative); zgoda, że „blocker" to właściwa rama mimo statusu pre-publish (pierwsze 20 zewn. userów to cały pula ewangelistów). Rozbieżność nierozstrzygnięta: MCP — „keep thin + frozen" (implementacja, infra) vs „park i wyciąć z marketingu README" (biznes). Wspólny mianownik: zero dalszych inwestycji w MCP do czasu realnego konsumenta. Oceny po dwóch rundach: 5/10 u wszystkich (niezależnie), ścieżka do 7/10 = release gate + doctor honest outcomes.

## 6. Priorytety (skonsolidowane, kolejność wykonania)

1. **(S) Release gate:** wspólna stała schematu `settings.json` (`extraKnownMarketplaces` + `enabledPlugins@marketplace`, schemastore `$schema`, nowy slug repo) w brickach + checku doctora + testach; kryterium: świeży `utopia create` → `claude` → `/utopia-hooks` działa.
2. **(M) BrickLocator:** `PUB_CACHE` env + package_config fallback + match `utopia_cli-$packageVersion`; job Windows w CI z e2e `create`/`add`.
3. **(M) Uczciwe wyniki:** non-zero exit przy porażce postGenerate; doctor: `--fail-on=<severity>`, reguły error-severity, error na nieistniejącym roocie, `check.crashed` jako finding, ujednolicenie ścieżek do project-root-relative + pole `package`; dogfood doctora we własnym CI; `--human` na stderr.
4. **(S) Honest scaffold + higiena publish:** naprawić/udokumentować ścieżkę localization (albo wyciąć z bricka domyślnie), usunąć `.gitkeep`, 6. topic, `.pubignore` dla PLAN/REVIEW/wewnętrznych nazw, poprawić README (`.utopia.yaml` — wpiąć albo wyciąć z docs), zsynchronizować describe_schema.md z implementacją (albo `confidence` zaczyna mówić prawdę, albo znika).
5. **(M) Unifikacja powierzchni:** `add screen --json` transakcyjny + delegacja ze skilla + `doctor --files` dla hooka. Dalej: pomiar 90 dni → decyzja o analyzer v2; MCP frozen.

## Źródła zewnętrzne

- https://code.claude.com/docs/en/settings · https://code.claude.com/docs/en/plugin-marketplaces (schemat settings/marketplaces)
- https://json.schemastore.org/claude-code-settings.json (faktyczny JSON schema)
- https://github.com/anthropics/claude-code/issues/32606 (reliability auto-promptu marketplace)
- https://pub.dev/packages/very_good_cli · https://verygood.ventures/blog/very-good-cli-1-0-flutter-testing-mcp-semantic-versioning/ (konkurencja)
- https://docs.flutter.dev/ai/mcp-server (oficjalny dart mcp-server)
- https://www.anthropic.com/engineering/code-execution-with-mcp · https://www.anthropic.com/engineering/writing-tools-for-agents (MCP-vs-Bash 2026)
- https://pub.dev/publishers/utopiasoft.io/packages (adopcja stacku)
