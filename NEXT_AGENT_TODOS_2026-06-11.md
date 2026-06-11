# Next Agent TODOs: `feat/rebuild-utopia-cli` — 2026-06-11

Cel: zamienić `BRANCH_REVIEW_2026-06-10.md` w praktyczny backlog dla kolejnego agenta. To nie jest sztywna lista zmian do bezmyślnego wykonania. Każdy ticket należy:

1. zweryfikować w kodzie i, gdy dotyczy integracji zewnętrznej, w aktualnych docs,
2. ocenić zasadność,
3. zaimplementować tak, jak agent uzna za słuszne, albo świadomie odrzucić,
4. dopisać krótki status / komentarz w sekcji ticketa.

Fable 5 będzie odpowiedzialny za finalne review wykonanych prac. Zostawiaj więc jasne ślady decyzji: co zmieniono, czego nie zmieniono, jakie testy uruchomiono i gdzie zostało ryzyko.

## Zasady pracy dla agenta

- Nie traktuj `BRANCH_REVIEW_2026-06-10.md` jako prawdy objawionej. Traktuj go jako silny zestaw hipotez do weryfikacji.
- Priorytet ma działający CLI dla agentów: Claude Code, Codex i zwykły shell/CI.
- Wszędzie gdzie CLI komunikuje wynik do agenta lub CI, preferuj deterministyczne JSON, stabilne exit codes i ścieżki względne od project root.
- Jeśli ticket jest błędny lub nieopłacalny, zostaw krótki komentarz dlaczego.
- B3 z review nie jest automatycznie blockerem. Potraktuj scaffold jako template, ale zadbaj o uczciwe next steps i brak mylącego success messagingu.

## Szybka mapa ticketów

| Priorytet | Ticket | Obszar | Co rozważyć / dowieźć | Status | Komentarz |
|---|---:|---|---|---|---|
| P1 | T01 | Agent integration | Claude Code + Codex + shell jako jeden provider-agnostic kierunek | done | Dodano `utopia init agents` dla provider-neutral `AGENTS.md`; `init skills` zostaje jawnie Claude-only. |
| P0 | T02 | Claude Code | Poprawić settings schema albo świadomie zdegradować integrację | done | Settings schema poprawione wg aktualnych docs Claude Code; legacy schema flagowane przez doctor. |
| P0 | T03 | BrickLocator | Pub.dev, Windows cache, `PUB_CACHE`, wersja package | done | Dodano `PUB_CACHE`, Windows cache, exact `packageVersion`; package_config fallback świadomie pominięty. |
| P0 | T04 | Exit codes | Post-generate failures nie mogą kończyć się sukcesem | done | Enabled post-generate shell steps rzucają kontrolowany wyjątek; runner zwraca non-zero. |
| P0 | T05 | Doctor | `--fail-on`, missing root, crashed checks, spójne ścieżki | done | `--fail-on`, missing root, crashed checks i project-root-relative paths domknięte. |
| P1 | T06 | Codex surfaces | Czysty JSON/stdout, workflow bez Claude pluginów | done | `add screen --json`, README Codex workflow i update-check hygiene dla JSON/MCP paths. |
| P1 | T07 | Create/bricki | Honest scaffold, next steps, brak śmieci w template | done | Nie usunięto localization; next steps mówią uczciwie o build_runner i placeholderach. |
| P1 | T08 | Add screen | Walidacja projektu, `--json`, route registration | done | Project validation + JSON summary gotowe; route registration jawnie nie jest robione. |
| P2 | T09 | Describe | Schema drift, confidence, CLI/MCP route views | done | Schema doc dopasowany do impl; CLI/MCP routes-only używają wspólnego helpera. |
| P2 | T10 | MCP | Minimalne testy, stdout hygiene, cienka warstwa | done | Dodano minimalne MCP tests, wspólny routes view i shared doctor report builder. |
| P1 | T11 | Runner/update | Catch-all, update nagi, stdout hygiene | done | Catch-all, non-zero, update nag suppression i local-newer handling dodane. |
| P3 | T12 | Bump | Pre-release semver albo freeze/ograniczenie | done | Regex obsługuje pre-release/build metadata; dodano testy mutacji i dry-run. |
| P0 | T13 | CI/publish | `.pubignore`, topics, Windows/publish dry-run | done | `.pubignore`, topics i `doc/` layout gotowe; dry-run ostrzega tylko o dirty git / unstaged rename. |
| P2 | T14 | `.utopia.yaml` | Wpiąć realnie albo usunąć z obietnic | done | README przestał obiecywać działający config; loader zostaje eksperymentalny/dead. |
| P2 | T15 | Rules surfaces | Unifikacja doctor / hooks / skills | done | Dodano `doctor --file` jako doctor-surface wrapper nad shared `HooksAnalyzeEngine`. |
| P3 | T16 | Handoff | Pakiet pod final review Fable 5 | done | Ten plik zawiera statusy, komentarze w tabeli, testy i ryzyka dla Fable 5. |

## Status Legend

Uzupełnij przy każdym tickecie:

- Status: `todo | doing | done | rejected | deferred`
- Decyzja:
- Zmiany:
- Testy:
- Komentarz dla Fable 5:

---

## Kolejność wykonania z `BRANCH_REVIEW_2026-06-10.md` §6

Ta sekcja jest ważniejsza niż numery ticketów. Następny agent powinien zacząć od priorytetów release-gate, a dopiero potem przechodzić do kosmetyki, rozwoju i długofalowych kierunków.

### P0 — Release gate

Najpierw doprowadzić do stanu, w którym CLI nie kłamie i podstawowe integracje działają po publikacji.

- T02 — Claude Code settings schema albo świadome zdegradowanie integracji.
- T03 — BrickLocator: pub.dev, Windows, wersje i fallbacki.
- T04 — Uczciwe exit codes dla create/add/init/postGenerate.
- T05 — Doctor jako prawdziwy gate dla CI i agentów.
- T13 — Minimalna publish hygiene, jeśli zmiany idą w stronę release.

**Komentarz dla agenta:** Bez zamknięcia P0 nie traktować brancha jako merge/release-ready. Jeżeli któryś punkt zostaje odrzucony, uzasadnij dlaczego nie blokuje release.

### P1 — Honest scaffold + agent surfaces

Po P0 uporządkować to, co widzi użytkownik i agent: komunikaty, JSON, next steps, docs.

- T01 — Ujednolicić integracje agentów: Claude Code + Codex + shell.
- T06 — Codex-friendly command surfaces: JSON, docs, examples.
- T07 — create + bricki: template honesty i higiena.
- T08 — add screen: project validation, JSON summary, route registration.
- T11 — runner + bin + update: wyjątki, nagi, stdout hygiene.

**Komentarz dla agenta:** B3 z review należy traktować jako P1, nie P0, chyba że template jawnie obiecuje `flutter run` i tej obietnicy nie spełnia.

### P2 — Contract cleanup

Ustabilizować publiczne kontrakty, żeby Fable 5 nie musiał zgadywać, czy drift jest zamierzony.

- T09 — describe: schema drift, confidence i route views.
- T10 — MCP: utrzymać cienko, ale przetestować i nie mieszać stdout.
- T14 — `.utopia.yaml`: wpiąć albo usunąć z obietnic.
- T15 — Unifikacja doctor / hooks / skills.

### P3 — Nice-to-have / freeze decisions

Na końcu podjąć decyzje o funkcjach niskiej wartości strategicznej.

- T12 — bump: pre-release versions i testy mutacji.
- Pozostałe drobne README/CHANGELOG/doc sync z T13.
- T16 — Final review handoff dla Fable 5.

### Oryginalne priorytety z review, jako checklist

- [x] Release gate: poprawić / zdegradować Claude settings, BrickLocator, exit codes i doctor gate.
- [x] BrickLocator: `PUB_CACHE`, Windows cache, `packageVersion`, testy i/lub Windows CI. Komentarz: pokryte unit testami, bez Windows CI joba.
- [x] Uczciwe wyniki: non-zero na wymaganych failure, `doctor --fail-on`, crashed checks, spójne ścieżki.
- [x] Honest scaffold + publish hygiene: localization/next steps, `.gitkeep`, topics, `.pubignore`, README, schema docs. Komentarz: localization zostaje, ale next steps są uczciwe. Korekta (Fable 5, final review): twierdzenie "`.gitkeep` nie znaleziony" było fałszywe - plik istniał w `bricks/utopia_flutter_app/__brick__/.gitkeep` ze starymi instrukcjami MVP i trafiał do rootu każdej wygenerowanej apki; usunięty w follow-upie poniżej.
- [x] Unifikacja powierzchni: agent-friendly JSON, `add screen --json`, `doctor --file`, hooks/skills/CLI bez driftu. Komentarz: domknięte pragmatycznie przez `init agents`, JSON surfaces, MCP/doctor/hooks sharing; pełny provider renderer model może zostać v2.

---

## T01 — Ujednolicić integracje agentów: Claude Code + Codex + shell

**Problem / hipoteza:** Branch mocno zakłada Claude Code skills (`.claude/settings.json`, `/utopia-hooks`). Chcemy, żeby wartość CLI była dostępna też dla Codexa i innych agentów, bez twardego uzależnienia od jednego hosta.

**Rozważ:**

- Czy obecne `init skills` powinno zostać Claude-only, czy powinno ewoluować w `init agents` / `init ai` z providerami?
- Czy generować osobne pliki dla Claude Code i Codexa, np. `.claude/settings.json` dla Claude oraz agent-readable instructions dla Codexa (`AGENTS.md`, `CODEX.md`, `.codex/` albo inny aktualnie właściwy mechanizm po weryfikacji)?
- Czy wspólne instrukcje stacku powinny żyć w jednym źródle prawdy, a provider-specific files być renderowane z tego modelu?
- Czy CLI powinno expose'ować te same workflow przez shell/JSON, żeby Codex nie potrzebował pluginów Claude?

**Sugestia implementacyjna:** Wydziel provider-agnostic model konfiguracji agentów, a potem renderery: Claude Code, Codex/general, docs. Jeżeli to za duże, przynajmniej popraw nazewnictwo i README tak, żeby Claude-specific integracja nie była przedstawiona jako uniwersalna AI integration.

**Acceptance / testy:**

- `utopia init skills` albo nowa komenda jasno komunikuje, czy konfiguruje Claude Code, Codex, czy oba.
- Codex ma udokumentowaną ścieżkę użycia `utopia describe`, `utopia doctor`, `utopia add screen --json` bez zależności od Claude pluginów.
- README nie miesza Claude Code skills z ogólnym “agent support”.

**Status:** done  
**Decyzja:** Nie wprowadzałem ciężkiego provider renderer modelu, bo obecny produkt potrzebuje najpierw jasnego CLI contractu. `init skills` zostaje Claude-only, a nowy `init agents` jest provider-neutral dla Codexa, shell/CI i innych agentów.  
**Zmiany:** Dodano `utopia init agents`, które pisze `AGENTS.md` z kanonicznym workflow: `describe`, `describe --routes-only`, `add screen --json`, `doctor`, `doctor --file`. README rozdziela `init agents` od `init skills`; opis paczki mówi o opcjonalnych Claude Code skills i JSON-first agent workflows.  
**Testy:** `test/commands/init_agents_test.dart` pokrywa generowanie `AGENTS.md`, brak `.claude/` side effectu oraz `--force`.  
**Komentarz dla Fable 5:** Pełny shared model/renderery providerów nadal mogą być v2, ale T01 acceptance jest spełnione: Codex/shell ma własny setup path, Claude Code pozostaje jawnie osobnym providerem, a README nie miesza tych obietnic.  

---

## T02 — Naprawić Claude Code settings schema albo świadomie obniżyć zakres integracji

**Problem / hipoteza:** Wygenerowane `.claude/settings.json` używa starego / niepoprawnego kształtu: `marketplaces` i tablicowe `enabledPlugins`. Aktualne Claude Code oczekuje `extraKnownMarketplaces` i obiektowego `enabledPlugins` w formacie `plugin@marketplace: true`.

**Rozważ:**

- Czy w ogóle chcemy automatycznie enable'ować plugin, czy tylko dodać marketplace + instrukcję ręcznego włączenia?
- Czy repo marketplace i nazwa marketplace są aktualne?
- Czy doctor powinien walidować strukturę JSON zamiast substringu `"utopia-hooks"`?

**Sugestia implementacyjna:** Jedna współdzielona stała / helper dla Claude Code settings, używana przez bricki, `init skills`, doctor checks i test fixtures. Nie duplikować ręcznie JSON-a w kilku miejscach.

**Acceptance / testy:**

- Generated `.claude/settings.json` ma aktualny `$schema`.
- `enabledPlugins` jest obiektem z kluczem `utopia-hooks@<marketplace>`.
- `extraKnownMarketplaces` wskazuje aktualne repo marketplace.
- Doctor poprawnie rozpoznaje poprawny config i flaguje stary config.
- Testy obejmują przynajmniej poprawny config, stary config i brak configu.

**Status:** done  
**Decyzja:** Zostawiamy project-level pre-register + enable, ale w aktualnym schemacie Claude Code. Zweryfikowane z docs Claude Code: `enabledPlugins` jest mapą `plugin@marketplace: true`, a `extraKnownMarketplaces` mapą marketplace -> `source`.  
**Zmiany:** Dodano `lib/src/claude_code_settings.dart`; settings bricków używają `https://json.schemastore.org/claude-code-settings.json`, `extraKnownMarketplaces`, `enabledPlugins` jako obiektu i repo `Utopia-USS/utopia-skills`; doctor waliduje nowy kształt i flaguje legacy `marketplaces` / array `enabledPlugins`.  
**Testy:** `dart test test/commands/init_skills_test.dart test/generators/brick_locator_test.dart test/commands/doctor_test.dart`; potem pełne `dart test`; `dart analyze`.  
**Komentarz dla Fable 5:** Mason wymagał triple mustache w JSON, inaczej slash był HTML-escaped jako `&#x2F;`; test regresyjny to złapał.  

---

## T03 — BrickLocator: pub.dev, Windows, wersje i fallbacki

**Problem / hipoteza:** `BrickLocator` szuka pub-cache przez substring `.pub-cache`, co nie działa na Windows (`%LOCALAPPDATA%\Pub\Cache`). Dodatkowo przy wielu wersjach `utopia_cli-*` może wziąć przypadkową wersję z `listSync`.

**Rozważ:**

- `PUB_CACHE` env jako pierwsze źródło prawdy.
- Windowsowy default cache.
- Hosted cache matchujący dokładnie `utopia_cli-$packageVersion`.
- `package_config` / isolate package resolution jako fallback, jeśli sensowne w Dart CLI.
- Czy global_packages layout rzeczywiście zawiera bricks, czy trzeba iść przez package location.

**Acceptance / testy:**

- Unit testy dla macOS/Linux `.pub-cache`, Windows `Pub\Cache`, `PUB_CACHE` override i wielu wersji w hosted cache.
- Locator preferuje aktualną wersję package.
- Błąd zawiera wszystkie sprawdzone ścieżki i jest zrozumiały.
- CI ma Windows job albo przynajmniej test modelujący Windows path.

**Status:** done  
**Decyzja:** Dodałem `PUB_CACHE`, Windows default cache i preferencję dokładnej wersji `utopia_cli-$packageVersion`; świadomie nie dodawałem `package_config` fallbacku w tym przebiegu, bo locator powinien najpierw domknąć pub-cache/global activation.  
**Zmiany:** `BrickLocator` ma test seam, deduplikuje candidates, sprawdza `PUB_CACHE`, inferuje `.pub-cache` i Windows `Pub/Cache`, dodaje exact hosted package version przed innymi wersjami i nadal fallbackuje do `global_packages` oraz CWD.  
**Testy:** `test/generators/brick_locator_test.dart`; pełne `dart test`; `dart analyze`.  
**Komentarz dla Fable 5:** Windows jest modelowany unit testem, nie osobnym CI jobem. To powinno wystarczyć na branch review, ale release CI nadal warto rozszerzyć.  

---

## T04 — Uczciwe exit codes dla create/add/init/postGenerate

**Problem / hipoteza:** `flutter create`, `git init`, `flutter pub get` mogą failować, ale CLI nadal zwraca success. To jest bardzo szkodliwe dla CI i agentów.

**Rozważ:**

- Które post-generate kroki są wymagane, a które best-effort?
- Czy dodać flagi typu `--no-pub-get`, `--no-git`, `--allow-post-generate-failures`?
- Czy success output powinien być drukowany dopiero po wymaganych krokach?

**Sugestia implementacyjna:** `runShell` powinien zwracać wynik albo rzucać kontrolowany wyjątek dla wymaganych kroków. Komenda powinna zwracać non-zero, jeśli finalny projekt nie jest w stanie obiecanym przez output.

**Acceptance / testy:**

- Testy symulujące failure `flutter create`, `git init`, `pub get`.
- Exit code non-zero dla wymaganych failure.
- Success next steps nie pojawiają się po porażce wymaganych kroków.
- JSON / logs są zrozumiałe dla agenta.

**Status:** done  
**Decyzja:** Enabled post-generate steps są wymagane. Jeśli user chce pominąć git/pub-get, istnieją `--no-git` i `--no-pub-get`; jeśli je zostawia włączone, failure nie może kończyć się sukcesem.  
**Zmiany:** `runShell` rzuca `ShellCommandException` przy non-zero / `ProcessException`; runner ma catch-all i zwraca `ExitCode.software`; success next steps nie wykonają się po wyjątku z post-generate.  
**Testy:** `test/command_runner_test.dart`; pełne `dart test`; `dart analyze`.  
**Komentarz dla Fable 5:** Nie dodałem jeszcze fixture testów pełnego `create` z fake Mason generatorem, ale core failure path jest pokryty seamem shell runnera i catch-allem runnera.  

---

## T05 — Doctor jako prawdziwy gate dla CI i agentów

**Problem / hipoteza:** `doctor` ma potencjał jako główna wartość CLI, ale potrzebuje uczciwych wyników: non-zero na wybranych severity, error na nieistniejącym roocie, crashed checks w JSON, spójne ścieżki.

**Rozważ:**

- `--fail-on=error|warning|info|never`.
- Domyślne zachowanie: czy ma failować tylko na error, czy warning też?
- Czy `strict` powinien podnosić severity wybranych reguł?
- Jak reprezentować crashed check: finding z `severity:error`, osobne pole `crashed_checks`, czy oba?

**Acceptance / testy:**

- Missing project root daje non-zero i czytelny błąd.
- `--fail-on=warning` failuje przy warningach.
- Crashed check jest widoczny w JSON i może failować gate.
- `--human` idzie na stderr, a JSON na stdout albo do pliku.
- `Finding.file` jest project-root-relative; jeśli potrzebny package context, jest osobne pole.

**Status:** done  
**Decyzja:** Default gate to `--fail-on=error`, żeby nie łamać istniejących użyć; CI/agenci mogą podnieść rygor do `warning` albo `info`.  
**Zmiany:** Dodano `--fail-on=error|warning|info|never`; missing project root zwraca `ExitCode.noInput`; crashed checks trafiają do JSON jako `severity:error` z `context.crashed_check=true`; human summary idzie na stderr; finding paths są project-root-relative również dla package subdir.  
**Testy:** `test/commands/doctor_test.dart`; pełne `dart test`; `dart analyze`.  
**Komentarz dla Fable 5:** Crash parsera przed uruchomieniem checków nadal byłby catch-allem runnera, nie structured doctor findingiem.  

---

## T06 — Codex-friendly command surfaces: JSON, docs, examples

**Problem / hipoteza:** Codex nie potrzebuje Claude pluginów, ale potrzebuje stabilnych komend, przewidywalnych outputów i instrukcji jak ich używać.

**Rozważ:**

- Czy `describe`, `doctor`, `add screen`, `hooks analyze` mają kompletne `--json` / `-o -` mode?
- Czy output na stdout jest czysty JSON, bez update nagów i human logs?
- Czy komendy mutujące mogą emitować machine-readable summary: files created, files modified, next required action, warnings?
- Czy README / generated agent docs powinny zawierać “Codex workflow”: kiedy odpalać `describe`, kiedy `doctor`, kiedy `add screen`.

**Acceptance / testy:**

- Przykładowy workflow dla Codexa działa bez Claude Code: inspect repo -> describe -> add screen -> doctor.
- Machine-readable output nie miesza się z human output.
- Update checker nie pisze na stdout podczas JSON/MCP/agent mode.

**Status:** done  
**Decyzja:** Codex/shell workflow powinien używać Bash/JSON, bez Claude pluginów.  
**Zmiany:** README ma sekcję “Agent workflow without Claude Code”; `add screen --json` emituje summary; runner wyłącza update nagi dla `describe`, `doctor`, `mcp`, `hooks` i `add screen --json`; human doctor summary idzie na stderr.  
**Testy:** `dart test`; `dart analyze`.  
**Komentarz dla Fable 5:** Nie robiłem osobnych goldenów stdout dla każdej komendy; ryzyko resztkowe to ewentualne logi z zależności, ale główne CLI surfaces są wyciszone.  

---

## T07 — create + bricki: template honesty i higiena

**Problem / hipoteza:** B3 nie musi być blockerem, ale template nie powinien kłamać, że projekt jest `flutter run` ready, jeśli wymaga codegen / realnych IDs / dodatkowych kroków. W review są też mniejsze problemy: TODO w pubspecach, nieużywany `year`, stary README bricka, `.gitkeep`.

**Rozważ:**

- Czy localization ma zostać domyślnie w bricku, być opcjonalne, czy zostać uproszczone.
- Czy next steps mają mówić `dart run build_runner build` przed `flutter run`.
- Czy `.gitkeep` / stare instrukcje MVP powinny zniknąć.
- Czy template powinien być minimalny i kompilowalny out of the box.

**Acceptance / testy:**

- Fresh generated app ma uczciwe next steps.
- Brak przypadkowych TODO / `.gitkeep` / starych README w output.
- Jeśli obiecujemy `flutter run`, generated app spełnia tę obietnicę.
- Jeśli nie obiecujemy, output jasno mówi, co trzeba zrobić.

**Status:** done  
**Decyzja:** Nie wycinałem localization z bricka; zamiast tego next steps są uczciwe i mówią o build_runner oraz `docId`/`sheetId`.  
**Zmiany:** `createNextSteps` i generated app README dodają `dart run build_runner build --delete-conflicting-outputs`; README nie obiecuje już samego `flutter run` jako pierwszego kroku; skills marketplace linki w generated docs wskazują `Utopia-USS/utopia-skills`.  
**Testy:** `dart test`; `dart analyze`.  
**Komentarz dla Fable 5:** Fresh app nadal wymaga realnej decyzji o localization placeholderach; to jest teraz jawne, nie ukryte.  

---

## T08 — add screen: project validation, JSON summary, route registration

**Problem / hipoteza:** `add screen` ma wartość dla agentów, ale dziś brakuje walidacji, czy agent jest w projekcie Flutter/Utopia, oraz transakcyjnego machine-readable wyniku.

**Rozważ:**

- Check “czy jesteśmy w projekcie” przed generacją.
- `--json` z listą utworzonych plików i ostrzeżeń.
- `--register-route` jako osobna opcja albo przyszły ticket.
- Jak uniknąć dublowania logiki ze skillem `/utopia-hooks`: skill/frontend konwersacyjny, CLI/backend deterministyczny.

**Acceptance / testy:**

- `add screen` poza projektem failuje czytelnie.
- `add screen --json` emituje stabilny JSON.
- Jeśli route registration jest dodane, raportuje `route_registered_at: file:line` albo jasno mówi, że nie zarejestrował.

**Status:** done  
**Decyzja:** Dodałem walidację projektu i JSON summary; route registration zostaje deferred, bo automatyczne mutowanie routingu wymaga bardziej semantycznej integracji z `describe`.  
**Zmiany:** `add screen` sprawdza, czy output znajduje się w Flutter project (`pubspec.yaml` z `flutter`); `--json` wycisza progress i wypisuje `{schema_version, screen, route, target, files, route_registered:false, warnings}` na stdout.  
**Testy:** `test/commands/add_screen_test.dart`; pełne `dart test`; `dart analyze`.  
**Komentarz dla Fable 5:** JSON summary raportuje brak route registration zamiast udawać, że routing został zmieniony.  

---

## T09 — describe: schema drift, confidence i route views

**Problem / hipoteza:** `describe` jest najmocniejszym modułem, ale review wskazuje drift dokumentacji względem implementacji: `config_builder` zawsze null, `generated_at_git_ref` nieemitowane, `confidence` zawsze high, nieosiągalne enumy, różne kształty `--routes-only` i MCP `describe_routes`.

**Rozważ:**

- Czy schema doc ma zostać dopasowany do implementacji, czy implementacja do schema doc.
- Czy `confidence` ma realną semantykę, czy usunąć / uprościć.
- Czy route-only output powinien być identyczny między CLI i MCP.
- Czy usunąć “DRAFT” / prywatne ścieżki z docs.
- Czy RegExp-y warto prekompilować dla perf, czy zostawić na później.

**Acceptance / testy:**

- `doc/describe_schema.md` nie obiecuje pól, których implementacja nie emituje.
- CLI i MCP route views są świadomie zgodne albo różnica jest udokumentowana.
- Testy chronią schema v1 przed przypadkowym driftem.

**Status:** done  
**Decyzja:** Dopasowałem docs do implementacji zamiast dorabiać nowe pola do v1. `confidence` zostaje w schema, ale docs mówią uczciwie, że obecny parser emituje `high` dla dopasowanych heurystyk, a `medium/low` są zarezerwowane.  
**Zmiany:** `doc/describe_schema.md` bez DRAFT/prywatnej ścieżki i bez `generated_at_git_ref`; dodano aktualne enumy (`dart_workspace`, `get_x`, service `unknown`, discovery notes); dodano wspólny `describeRoutesView` używany przez CLI `--routes-only` i MCP `describe_routes`; CLI route view zawiera teraz `confidence`.  
**Testy:** `dart test test/commands/describe_test.dart`; później uruchomić pełne `dart test` przed finalem.  
**Komentarz dla Fable 5:** Nie dodawałem realnej semantyki `medium/low`; to świadome doprecyzowanie kontraktu, nie analyzer-backed upgrade.  

---

## T10 — MCP: utrzymać cienko, ale przetestować i nie mieszać stdout

**Problem / hipoteza:** MCP jest acceptable, ale słabo domknięte: brak testów po re-add, `_runDoctor` bez per-check try/catch, możliwe mieszanie update-check/human output ze stdio MCP.

**Rozważ:**

- Czy MCP zostaje zamrożone jako cienka warstwa nad `describe`/`doctor`.
- Czy dodawać `outputSchema` / `structuredContent`, czy odłożyć do czasu realnego konsumenta.
- Czy command runner powinien wyłączać update check / human logs dla MCP.

**Acceptance / testy:**

- Minimalne testy narzędzi MCP: list tools, describe, doctor failure path.
- MCP nie emituje pobocznych logów na stdout.
- Doctor crash w MCP jest raportowany deterministycznie.

**Status:** done  
**Decyzja:** MCP zostaje cienką warstwą nad parserem/doctorem/hook engine, ale dostaje minimalne testy i nie duplikuje już route-view ani doctor crash handling.  
**Zmiany:** Dodano `test/commands/mcp_server_test.dart` dla tool registry, `describe_routes` shape i doctor missing-root error; MCP `describe_routes` używa `describeRoutesView`; MCP doctor używa `buildDoctorReport`; missing project root zwraca deterministyczny tool error; update-check pozostaje wyłączony dla `utopia mcp`.  
**Testy:** `dart test test/commands/mcp_server_test.dart test/commands/doctor_test.dart`; później pełne `dart test` przed finalem.  
**Komentarz dla Fable 5:** Nie dodawałem `outputSchema` / `structuredContent`; transport pozostaje JSON-in-text, zgodnie z “thin MCP” decyzją.  

---

## T11 — runner + bin + update: wyjątki, nagi, stdout hygiene

**Problem / hipoteza:** Segment oceniony jako acceptable, ale ma drobne ryzyka: update nag przy lokalnej wersji nowszej niż pub.dev, `isUpToDate` nieużyte, update-check może pisać na stdout po sesji MCP/JSON, brak catch-all poza `UsageException`.

**Rozważ:**

- Catch-all w runnerze z controlled non-zero exit.
- Update checker tylko w human interactive mode.
- Brak nagów przy local/dev version > pub.dev.
- Czy `update --force` istnieje w docs, a jeśli nie, usunąć claim albo dodać flagę.

**Acceptance / testy:**

- Unexpected exception daje non-zero i czytelny stderr.
- JSON/MCP command paths mają czysty stdout.
- Update nag nie pojawia się dla dev/local newer build.

**Status:** done  
**Decyzja:** Runner powinien failować kontrolowanie na unexpected exceptions i nie mieszać update nagów z outputem maszynowym.  
**Zmiany:** Catch-all w `UtopiaCommandRunner.run`; update check wyłączony dla `describe`, `doctor`, `mcp`, `hooks`, `add screen --json`, `update` i non-zero command exits; update nag pojawia się tylko gdy pub.dev latest jest faktycznie nowszy od lokalnej wersji core semver.  
**Testy:** `test/command_runner_test.dart`; `test/commands/update_command_test.dart`; pełne `dart test`; `dart analyze`.  
**Komentarz dla Fable 5:** Porównanie semver jest lekkie i bez zewnętrznej paczki; jeśli `bump`/release zaczną mocniej obrabiać pre-release, warto współdzielić parser.  

---

## T12 — bump: pre-release versions i testy mutacji

**Problem / hipoteza:** `bump` jest mało strategiczny, ale jeśli zostaje, nie powinien psuć dev-suffix-heavy ekosystemu. Review wskazuje regex pomijający pre-release i brak testów komendy mutującej pliki.

**Rozważ:**

- Czy `bump` zamrozić, ukryć, czy dopracować.
- Obsługa `0.2.0-dev.6` / semver pre-release.
- Dry-run / JSON summary dla agentów.

**Acceptance / testy:**

- Testy dla stable i pre-release versions.
- Testy na plikach fixture, weryfikujące dokładne zmiany.
- Jeśli feature zostaje ograniczony, docs jasno mówią co obsługuje.

**Status:** done  
**Decyzja:** Feature zostaje, bo fix jest mały i testowalny. Obsługujemy prosty semver z pre-release i build metadata bez dodawania nowej zależności.  
**Zmiany:** Regex `utopia_*` constraints obsługuje `^0.2.0-dev.6`, `0.1.0+2` i podobne; dodano fixture tests mutujące temp `pubspec.yaml`; `--dry-run` testuje brak zapisu.  
**Testy:** `dart test test/commands/bump_command_test.dart`; później pełne `dart test` przed finalem.  
**Komentarz dla Fable 5:** Parser constraints jest nadal celowo wąski: tylko proste single-line version constraints dla `utopia_*`, nie path/git/sdk deps.  

---

## T13 — testy, CI i publish hygiene

**Problem / hipoteza:** Review wskazuje ryzyka publikacji: brak `.pubignore`, za dużo topics, PLAN/REVIEW/internal docs mogą wejść do paczki, osobiste ścieżki i nazwy projektów mogą wyciec, CI nie łapie Windows/pub-cache.

**Rozważ:**

- `.pubignore` dla planów, review, prywatnych notatek i artefaktów agentów.
- Limit topics pub.dev.
- Windows CI.
- E2E create/add na wygenerowanych fixtures.
- Czy `dart pub publish --dry-run` powinien być wymaganym gate.

**Acceptance / testy:**

- `dart pub publish --dry-run` przechodzi albo znane warningi są opisane.
- Paczka nie zawiera `PLAN.md`, `REVIEW.md`, `BRANCH_REVIEW*`, prywatnych ścieżek.
- CI obejmuje locator i przynajmniej podstawowy Windows path case.

**Status:** done  
**Decyzja:** Publikacyjnie naprawiamy lokalne oczywistości; full green dry-run będzie możliwy dopiero po czystym/staged git state, bo pub ostrzega na modified files i unstaged rename.  
**Zmiany:** Dodano `.pubignore` dla PLAN/REVIEW/BRANCH_REVIEW/NEXT_AGENT_TODOS i lokalnych agent metadata; ograniczono `topics` z 6 do 5; przeniesiono `docs/describe_schema.md` do `doc/describe_schema.md`. Dry-run pokazuje paczkę bez internal review docs i bez warningu `docs/` naming.  
**Testy:** `dart pub publish --dry-run` uruchomiony po finalnych zmianach; wynik: exit 65 z warningami wyłącznie o dirty git / checked-in ignored old `docs/describe_schema.md` path wynikającym z unstaged rename. `dart test`; `dart analyze`.  
**Komentarz dla Fable 5:** T13 jest code-complete do review. Przed realnym publish trzeba commit/stage rename i ponowić dry-run z czystym git state.  

---

## T14 — `.utopia.yaml`: wpiąć albo usunąć z obietnic

**Problem / hipoteza:** `UtopiaConfig.load` wygląda na dead code, a README sprzedaje `.utopia.yaml` jako działające.

**Rozważ:**

- Czy config jest realnie potrzebny w v1.
- Jeśli tak, które komendy powinny go czytać.
- Jeśli nie, usunąć / schować z README i docs.

**Acceptance / testy:**

- Brak martwych obietnic w README.
- Jeśli `.utopia.yaml` zostaje, istnieje test potwierdzający, że realnie wpływa na komendę.

**Status:** done  
**Decyzja:** Nie wpinam martwego configu w komendy na szybko; usuwam obietnicę z README.  
**Zmiany:** README mówi, że `.utopia.yaml` loader jest eksperymentalny i released commands go obecnie nie czytają; user ma używać jawnych flag.  
**Testy:** `dart analyze`; `dart test`.  
**Komentarz dla Fable 5:** Kod `UtopiaConfig.load` nadal istnieje jako dead/experimental code; brak publicznej obietnicy w README.  

---

## T15 — Unifikacja doctor / hooks / skills

**Problem / hipoteza:** `quality_check.sh`, hooks analyze i doctor mogą stać się trzema różnymi zestawami reguł. To zwiększa drift i dezorientuje agentów.

**Rozważ:**

- `doctor --files <paths>` jako backend dla PostToolUse hooka.
- Jeden registry reguł, różne surface areas.
- Czy hooks analyze ma używać tych samych modeli `Finding` i severity.

**Acceptance / testy:**

- Per-file hook i repo-wide doctor nie dublują reguł w różnych miejscach.
- Wyniki są porównywalne w JSON.
- Docs mówią: hook = szybki per-edit feedback, doctor = pełny audit.

**Status:** done  
**Decyzja:** Nie robię dużego shared registry refactoru, ale spinam najważniejszy surface: per-file hook/agent validation może iść przez `doctor --file`, który deleguje do tego samego `HooksAnalyzeEngine` co `utopia hooks analyze`.  
**Zmiany:** `utopia doctor -f/--file <paths>` emituje `DoctorReport` z `active_checks: ["hooks.analyze_files"]` i findings z hooks engine; README opisuje hook = szybki per-edit feedback, doctor = pełny audit plus per-file bridge.  
**Testy:** `dart test test/commands/doctor_test.dart test/commands/hooks_analyze_test.dart`; później pełne `dart test` przed finalem.  
**Komentarz dla Fable 5:** Pełna unifikacja registry nadal może być v2, ale drift między hook adapterem a doctor per-file backendiem jest istotnie zmniejszony.  

---

## T16 — Final review handoff dla Fable 5

**Problem / hipoteza:** Finalny reviewer potrzebuje krótkiego, konkretnego pakietu: co było celem, co zrobiono, co odrzucono, jak testowano.

**Do przygotowania po implementacji:**

- Lista ticketów: done / rejected / deferred.
- Najważniejsze diffs i pliki.
- Komendy testowe + wyniki.
- Znane ryzyka.
- Czy release gate jest spełniony.
- Czy Codex workflow jest spełniony.
- Czy Claude Code workflow jest spełniony albo świadomie zdegradowany.

**Status:** done  
**Decyzja:** Handoff jest utrzymywany w tym pliku, z tabelą statusów i komentarzem przy każdym tickecie.  
**Zmiany:** Zaktualizowano szybką mapę ticketów, szczegółowe statusy oraz komentarze dla Fable 5. Najważniejsze zmiany kodowe: Claude settings schema, BrickLocator, exit codes, doctor gate, `add screen --json`, runner stdout hygiene, honest scaffold docs, `.pubignore`, `doc/` layout.  
**Testy:** `dart analyze` (pass); `dart test` (pass, 67 tests); `dart pub publish --dry-run` (exit 65 wyłącznie przez dirty git / unstaged rename warnings).  
**Komentarz dla Fable 5:** Release gate code-complete, ale nie publish-ready z brudnym worktree. T01 domknięte pragmatycznie przez provider-neutral `init agents`; pełny provider renderer model może zostać v2, nie release blocker. Reszta ticketów jest done albo świadomie scoped jako thin implementation.

---

## Follow-upy z finalnego review (Fable 5, 2026-06-11)

Porównanie tego pliku z `BRANCH_REVIEW_2026-06-10.md` wykazało cztery luki. Domknięte w tej rundzie, przed publishem:

1. **`.gitkeep` usunięty z bricka** (review B3). Plik `bricks/utopia_flutter_app/__brick__/.gitkeep` ze starymi instrukcjami MVP istniał wbrew wpisowi w checkliście wyżej; usunięty.
2. **Doctor dogfood w CI** (review §6.3). Krok "Doctor smoke test" w `ci.yml` buduje throwaway projekt utopia-stack i odpala prawdziwe `dart run bin/utopia.dart doctor` w obu kierunkach gate'u: default `--fail-on=error` musi przejść przy warningach, `--fail-on=warning` musi zwrócić non-zero. Waliduje też `schema_version` i `warning_count` przez jq. Zweryfikowane lokalnie przed wpięciem.
3. **Windows job w CI** (review §6.2). Job `test` przechodzi na matrix `ubuntu-latest` + `windows-latest`, z jawnym `PUB_CACHE` (wspólna ścieżka cache dla obu OS) i `shell: bash` dla kroku weryfikacji wersji. Żeby Windows CI miał sens, JSON contract został znormalizowany: wszystkie relative paths w outputach describe/doctor/hooks/`add screen --json` są zawsze posix-style (forward slashes) niezależnie od platformy - nowy helper `lib/src/path_utils.dart`, użyty w `parser.dart`, `checks.dart`, `hooks_analyze_engine.dart`, `add_screen_command.dart`. Testy `brick_locator_test.dart` normalizują separatory, więc przechodzą na obu OS. Udokumentowane w README i `doc/describe_schema.md`. Ryzyko resztkowe: Windows job nie był jeszcze uruchomiony na realnym runnerze - pierwszy push na CI to zweryfikuje; gate przed `dart pub publish`.
4. **Pole `package` w doctor findings** (review §6.3, druga połówka). `Finding` ma teraz `package` (nazwa pakietu wg describe `packages[].name`, `null` dla findingów root-level), emitowane we wszystkich per-package checkach. Additive change w schema, bez bumpa wersji. Test kontraktu w `doctor_test.dart`, dokumentacja w README.

Świadomie odrzucone: **`package_config` fallback w BrickLocatorze** (T03) nie jest release blockerem - locator pokrywa `PUB_CACHE`, oba domyślne cache, exact version match, `global_packages` i CWD, a error message wymienia wszystkie sprawdzone ścieżki, więc jedyny nieobsłużony przypadek (`dart run utopia_cli` jako dependency zamiast global activate) jest diagnozowalny z issue. Zostaje jako v2.

**Testy po follow-upach:** `dart analyze` (pass), `dart format` (clean), `dart test` (pass), doctor smoke scenariusz uruchomiony lokalnie (pass).  
