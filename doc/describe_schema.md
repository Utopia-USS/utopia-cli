# `utopia describe` - JSON schema v1

This document defines the public output contract for `utopia describe`.
Once shipped (especially via MCP exposure), the shape becomes pinned by
skills, agent prompts, and downstream tooling. **Schema changes after
v1 publication are breaking and require a `schema_version` bump.**

## Why a schema doc

The 4 real Utopia projects analyzed for this design (`habicy`,
`jolly-phonics-apps/classroom`, `qbt-black-phone`, `madrosc-tlumu`)
differ dramatically in:

- Naming convention (`*_screen.dart` vs `*_page.dart` vs
  `_sheet.dart` vs `_dialog.dart`)
- Folder layout (`lib/screen/` vs `lib/ui/pages/`)
- Routing strategy (static-const-on-class + aggregator map vs
  `auto_route` code-gen vs computed paths with helpers + conditional
  branches)
- Workspace shape (single package vs Melos monorepo with cross-package
  state imports)
- Multiplicity per screen (1 state, multiple states, 4 hook files
  for camera, no state at all for splash)

The schema must handle real diversity, not the idealised case the
brick generates.

## Design principles

1. **Versioned from day one.** `"schema_version": 1` is the first
   field in the root object. Tooling MUST refuse to parse an unknown
   version.
2. **Workspace-aware always.** Single packages report as
   `packages: [<single entry>]`, never flat. Monorepo is the common
   case, not the exception.
3. **Optional everything below `name` and `file`.** A screen may have
   no state, no view, no route. A package may have no routing config.
   A monorepo may have packages with no screens. Schema fields default
   to `null` or empty arrays rather than being absent.
4. **Discriminated unions for ambiguous shapes.** Screen `kind` and
   routing `strategy` are enums; consumers branch on them.
5. **Discovery notes are first-class.** When parsing can't resolve
   something (cross-file route reference, computed path, auto_route
   gen file missing), the schema records *why*, not silently omits.
6. **Heuristics are explicit.** Route and foreign-artifact discoveries
   include `confidence: "high" | "medium" | "low"`. The current v1 parser
   emits `high` only for matched route constants and line-level foreign
   artifact matches; `medium` and `low` are reserved for future, less direct
   heuristics without changing the enum.

## Top-level structure

```json
{
  "schema_version": 1,
  "workspace": {
    "type": "monorepo" | "single_package",
    "tool": "melos" | "dart_workspace" | "none",
    "root_path": "/abs/path/to/workspace/root",
    "packages_glob": ["packages/*"]
  },
  "packages": [ /* Package[] - see below */ ],
  "discovery_notes": [ /* unresolved-during-parse items */ ],
  "stats": {
    "package_count": 4,
    "screen_count": 21,
    "route_count": 22,
    "global_state_count": 17,
    "service_count": 7,
    "foreign_artifact_count": 0
  }
}
```

All relative paths in the output (`packages[].path`, `file`,
`config_file`, etc.) use forward slashes on every platform, Windows
included. Only `workspace.root_path` is an absolute host-native path.

## `Package` object

```json
{
  "name": "app",
  "path": "packages/app",
  "pubspec": {
    "name": "madrosctlumu",
    "version": "0.0.1+1",
    "dart_sdk": "^3.11.0",
    "flutter_sdk": ">=3.35.0",
    "deps": {
      "utopia_arch": "^0.5.1+17",
      "flutter_bloc": "^8.1.0"
    },
    "dev_deps": { "utopia_lints": "^0.0.1+1" }
  },
  "app_entrypoint": "lib/main.dart",
  "routing": { /* Routing object, see below */ },
  "screens": [ /* Screen[] */ ],
  "global_states": [ /* GlobalState[] */ ],
  "services": [ /* Service[] */ ],
  "foreign_artifacts": [ /* ForeignArtifact[] - info only, doctor enforces */ ]
}
```

## `Screen` object

```json
{
  "name": "HomeScreen",
  "kind": "routed_screen",
  "file": "lib/screen/home/home_screen.dart",
  "widget_base": "HookWidget",
  "states": [
    {
      "file": "lib/screen/home/state/home_screen_state.dart",
      "class": "HomeScreenState",
      "hook": "useHomeScreenState",
      "is_also_global": false
    }
  ],
  "views": [
    {
      "file": "lib/screen/home/view/home_screen_view.dart",
      "class": "HomeScreenView"
    }
  ],
  "route": {
    "path": "/home",
    "registered_in": "lib/app/app_routing.dart",
    "config_builder": "RouteConfig.material",
    "confidence": "high"
  },
  "presented_via": null
}
```

### `kind` enum

- `routed_screen` - has a `static const route` AND is registered in the routes map
- `sheet` - presented imperatively via `*Sheet.show()` / `AdaptiveSheet`
- `dialog` - presented imperatively via `*Dialog.show()` / `showGeneralDialog`
- `non_routed_page` - full Screen/State/View triple but no route (mounted as inner widget, e.g. `FeedPage`)
- `subscreen_fragment` - state+view exists, no top-level Dart file (e.g. madrosc `paywall/` embedded in carousel)
- `bare_screen` - routed but no state or view files (e.g. `SplashScreen`, `*NoPermissions*`)
- `auto_route_page` - annotated with `@RoutePage`, route resolved via code-gen

### Multiplicity

`states[]` and `views[]` are ALWAYS arrays. Real apps have:

- 0 entries: `bare_screen`, `subscreen_fragment` for views
- 1 entry: canonical case
- 2+ entries: `home_screen.dart` (2 states), `add_habit_screen.dart` (2 states), `camera_screen.dart` (4 state-hook files), `game_screen.dart` (4 view files)

### `route` is nullable

`null` when `kind ∈ {sheet, dialog, non_routed_page, subscreen_fragment}` OR
when route resolution failed (recorded in `discovery_notes`).

## `Routing` object

```json
{
  "strategy": "static_const_aggregator",
  "config_file": "lib/app/app_routing.dart",
  "initial_route": "/splash",
  "auto_route_gen_file": null,
  "route_count": 11,
  "notes": []
}
```

### `strategy` enum

- `static_const_aggregator` - habicy, madrosc: `static const route` on each screen + `Map<String, RouteConfig>` aggregator
- `auto_route` - jolly: `@RoutePage` + generated `*_router.gr.dart`
- `go_router` - reserved for future detection
- `imperative_only` - no routing config; screens pushed via `Navigator.push`
- `unknown` - couldn't determine

## `GlobalState` object

```json
{
  "name": "AuthState",
  "file": "lib/app/state/auth/auth_state.dart",
  "package": "app",
  "hook": "useAuthState",
  "registered_in": "lib/app/app.dart",
  "registration_kind": "inline_app_dart"
}
```

`registration_kind` enum:
- `inline_app_dart` - in a `_buildProviders()` map inside `app.dart` / `<name>_app.dart` (the observed norm in 4/4 projects)
- `providers_dart_file` - in a dedicated `_providers.dart` (documented but not seen in real apps yet)
- `cross_package_import` - state defined in another workspace package (e.g. madrosc `ColorState` from `core`)

## `Service` object

```json
{
  "name": "AuthService",
  "file": "lib/service/auth_service.dart",
  "registered_in": "lib/app/app_injector.dart",
  "registration_kind": "noarg"
}
```

`registration_kind`: `noarg` | `with_deps` | `instance` | `unknown`.

## `ForeignArtifact` object

```json
{
  "framework": "provider",
  "pattern": "context.watch<X>()",
  "file": "lib/ui/lesson/song_widget.dart",
  "line": 17,
  "confidence": "high"
}
```

`framework` enum: `bloc` | `cubit` | `riverpod` | `provider` |
`mobx` | `flutter_hooks_direct` | `stateful_widget` | `get_x`.
Reported as info only - doctor decides severity.

## Routes-only view

`utopia describe --routes-only` and MCP `describe_routes` intentionally
share the same shape:

```json
{
  "schema_version": 1,
  "packages": [
    {
      "name": "app",
      "routing": { "strategy": "static_const_aggregator" },
      "routes": [
        {
          "screen": "HomeScreen",
          "kind": "routed_screen",
          "file": "lib/screen/home/home_screen.dart",
          "path": "/home",
          "config_builder": null,
          "confidence": "high"
        }
      ]
    }
  ]
}
```

## `DiscoveryNote` (top-level + per-package)

```json
{
  "kind": "unresolved_route",
  "level": "warning",
  "message": "Route for ProfileScreen could not be resolved - registered as `ProfileScreen.route` but the const value is in lib/screen/profile/screen/profile_screen.dart:14 and exact value not extractable by regex.",
  "context": {
    "screen": "ProfileScreen",
    "registered_in": "lib/app/app_routing.dart:31"
  }
}
```

`kind` examples (non-exhaustive):
- `unresolved_route` - cross-file reference regex couldn't follow
- `computed_route_path` - path includes `${prefix}` or other dynamic component
- `conditional_route` - route gated by build-flag `if (...)` block
- `auto_route_gen_missing` - `*.gr.dart` not present, route names unresolvable
- `multiple_route_pages_per_file` - one `.dart` declares 2+ `@RoutePage` classes
- `screen_outside_canonical_dir` - screen file not under `lib/screen/` or `lib/ui/pages/`
- `unusual_naming` - file ends in something other than `_screen.dart`, `_page.dart`, `_sheet.dart`, `_dialog.dart`
- `pubspec_parse_error` - package pubspec could not be parsed
- `workspace_detect_failed` - workspace metadata could not be parsed or resolved to packages
- `project_root_not_found` - the given `-C <root>` path does not exist (error level; non-zero exit)
- `no_package_found` - the root exists but has no `pubspec.yaml` and isn't a recognised workspace (warning level)

`level`: `info` | `warning` | `error`.

## Out of scope for v1

- AST-resolved cross-file references (Dart analyzer integration is v2)
- Widget tree analysis (what widgets each screen uses)
- Test coverage per screen
- Documentation extraction (doc comments)
- Generated file detection (`*.g.dart`, `*.freezed.dart`) - filtered out, not reported
- Custom routing strategies beyond the four enums above
- Per-state mutation tracking (which states mutate which)

## Sign-off checklist

Before implementation begins:

- [ ] Workspace shape (`packages[]` always, even for single packages) - OK?
- [ ] Screen `kind` enum covers all real cases observed in 4 repos
- [ ] `states[]` / `views[]` plural mandated even when 0 or 1 entry
- [ ] `route` nullable when not present or not resolvable
- [ ] `confidence` field on every heuristic decision
- [ ] `discovery_notes[]` for unresolved cases instead of silent omission
- [ ] `foreign_artifacts[]` in describe is info-only; `doctor` enforces
- [ ] `schema_version: 1` locked in - changes from here require version bump

## Example outputs

### Canonical case (madrosc `app` package, HomeScreen excerpt)

```json
{
  "name": "HomeScreen",
  "kind": "routed_screen",
  "file": "lib/screen/home/home_screen.dart",
  "states": [
    {"file": "lib/screen/home/state/home_screen_state.dart", "class": "HomeScreenState", "hook": "useHomeScreenState", "is_also_global": false},
    {"file": "lib/screen/home/state/daily_pack_tile_state.dart", "class": "DailyPackTileState", "hook": "useDailyPackTileState", "is_also_global": true}
  ],
  "views": [{"file": "lib/screen/home/view/home_screen_view.dart", "class": "HomeScreenView"}],
  "route": {"path": "/home", "registered_in": "lib/app/app_routing.dart", "config_builder": "RouteConfig.material", "confidence": "high"},
  "presented_via": null
}
```

### Edge: sheet without route (madrosc AuthSheet)

```json
{
  "name": "AuthSheet",
  "kind": "sheet",
  "file": "lib/screen/auth/auth_sheet.dart",
  "states": [{"file": "lib/screen/auth/state/auth_sheet_state.dart", "class": "AuthSheetState", "hook": "useAuthSheetState", "is_also_global": false}],
  "views": [{"file": "lib/screen/auth/view/auth_sheet_view.dart", "class": "AuthSheetView"}],
  "route": null,
  "presented_via": "AdaptiveSheet.show"
}
```

### Edge: auto_route with computed path (jolly classroom DemoLessonRoute)

```json
{
  "name": "DemoLessonPage",
  "kind": "auto_route_page",
  "file": "lib/ui/pages/demo_lesson/demo_lesson_page.dart",
  "states": [/* ... */],
  "views": [/* ... */],
  "route": {
    "path": "/demo-lesson/:courseId/:stepIndex/:groupIndex/:lessonIndex",
    "registered_in": "lib/app/navigation/classroom_router.dart",
    "config_builder": "AutoRoute",
    "confidence": "high"
  }
}
```

### Edge: cross-package state (madrosc ColorState)

```json
{
  "name": "ColorState",
  "file": "packages/core/lib/state/color_state.dart",
  "package": "core",
  "hook": "useColorState",
  "registered_in": "packages/app/lib/app/app.dart",
  "registration_kind": "cross_package_import"
}
```
