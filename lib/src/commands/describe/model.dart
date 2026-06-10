/// Data model for `utopia describe`'s JSON output.
///
/// Schema is versioned via [Describe.schemaVersion]. Any change to field
/// names, types, or semantics must bump the schema version. See
/// `docs/describe_schema.md` for the contract.
library;

/// Root output of `utopia describe`.
class Describe {
  const Describe({
    required this.schemaVersion,
    required this.workspace,
    required this.packages,
    this.discoveryNotes = const [],
    required this.stats,
  });

  /// Schema version. Bump on any breaking change to the shape.
  final int schemaVersion;

  /// Workspace info (monorepo vs single package).
  final Workspace workspace;

  /// One entry per package. Single-package projects emit `[<single>]`.
  final List<Package> packages;

  /// Top-level discovery notes (issues spanning packages).
  final List<DiscoveryNote> discoveryNotes;

  /// Aggregate counts across all packages.
  final DescribeStats stats;

  Map<String, dynamic> toJson() => {
        'schema_version': schemaVersion,
        'workspace': workspace.toJson(),
        'packages': packages.map((p) => p.toJson()).toList(),
        'discovery_notes': discoveryNotes.map((n) => n.toJson()).toList(),
        'stats': stats.toJson(),
      };
}

/// Aggregate counts.
class DescribeStats {
  const DescribeStats({
    required this.packageCount,
    required this.screenCount,
    required this.routeCount,
    required this.globalStateCount,
    required this.serviceCount,
    required this.foreignArtifactCount,
  });

  final int packageCount;
  final int screenCount;
  final int routeCount;
  final int globalStateCount;
  final int serviceCount;
  final int foreignArtifactCount;

  Map<String, dynamic> toJson() => {
        'package_count': packageCount,
        'screen_count': screenCount,
        'route_count': routeCount,
        'global_state_count': globalStateCount,
        'service_count': serviceCount,
        'foreign_artifact_count': foreignArtifactCount,
      };
}

/// Workspace shape.
class Workspace {
  const Workspace({
    required this.type,
    required this.tool,
    required this.rootPath,
    this.packagesGlob = const [],
  });

  /// `monorepo` or `single_package`.
  final WorkspaceType type;

  /// `melos`, `dart_workspace`, or `none`.
  final WorkspaceTool tool;

  /// Absolute path to the workspace root.
  final String rootPath;

  /// Glob patterns that select packages (e.g. `["packages/*"]`).
  /// Empty for single-package workspaces.
  final List<String> packagesGlob;

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'tool': tool.name,
        'root_path': rootPath,
        'packages_glob': packagesGlob,
      };
}

enum WorkspaceType { monorepo, single_package }

enum WorkspaceTool { melos, dart_workspace, none }

/// One package in the workspace.
class Package {
  const Package({
    required this.name,
    required this.path,
    required this.pubspec,
    this.appEntrypoint,
    this.routing,
    this.screens = const [],
    this.globalStates = const [],
    this.services = const [],
    this.foreignArtifacts = const [],
  });

  /// Package name from pubspec.yaml.
  final String name;

  /// Relative path from workspace root. `.` for single-package.
  final String path;

  final Pubspec pubspec;

  /// Path to `main.dart` or equivalent. Null if no entrypoint.
  final String? appEntrypoint;

  /// Routing config. Null if the package has no routing.
  final Routing? routing;

  final List<Screen> screens;
  final List<GlobalState> globalStates;
  final List<Service> services;
  final List<ForeignArtifact> foreignArtifacts;

  Map<String, dynamic> toJson() => {
        'name': name,
        'path': path,
        'pubspec': pubspec.toJson(),
        'app_entrypoint': appEntrypoint,
        'routing': routing?.toJson(),
        'screens': screens.map((s) => s.toJson()).toList(),
        'global_states': globalStates.map((s) => s.toJson()).toList(),
        'services': services.map((s) => s.toJson()).toList(),
        'foreign_artifacts': foreignArtifacts.map((a) => a.toJson()).toList(),
      };
}

/// pubspec.yaml summary.
class Pubspec {
  const Pubspec({
    required this.name,
    this.version,
    this.dartSdk,
    this.flutterSdk,
    this.deps = const {},
    this.devDeps = const {},
  });

  final String name;
  final String? version;
  final String? dartSdk;
  final String? flutterSdk;

  /// Package name -> version constraint as string.
  final Map<String, String> deps;
  final Map<String, String> devDeps;

  Map<String, dynamic> toJson() => {
        'name': name,
        'version': version,
        'dart_sdk': dartSdk,
        'flutter_sdk': flutterSdk,
        'deps': deps,
        'dev_deps': devDeps,
      };
}

/// Routing configuration.
class Routing {
  const Routing({
    required this.strategy,
    this.configFile,
    this.initialRoute,
    this.autoRouteGenFile,
    required this.routeCount,
    this.notes = const [],
  });

  final RoutingStrategy strategy;
  final String? configFile;
  final String? initialRoute;
  final String? autoRouteGenFile;
  final int routeCount;
  final List<String> notes;

  Map<String, dynamic> toJson() => {
        'strategy': strategy.name,
        'config_file': configFile,
        'initial_route': initialRoute,
        'auto_route_gen_file': autoRouteGenFile,
        'route_count': routeCount,
        'notes': notes,
      };
}

enum RoutingStrategy {
  static_const_aggregator,
  auto_route,
  go_router,
  imperative_only,
  unknown,
}

/// A screen (or sheet, dialog, fragment).
class Screen {
  const Screen({
    required this.name,
    required this.kind,
    required this.file,
    this.widgetBase,
    this.states = const [],
    this.views = const [],
    this.route,
    this.presentedVia,
  });

  /// Class name (`HomeScreen`, `AuthSheet`).
  final String name;

  /// What this screen is.
  final ScreenKind kind;

  /// Path to the file declaring the screen class.
  final String file;

  /// Base class detected (`HookWidget`, `StatelessWidget`, etc.). May be null.
  final String? widgetBase;

  /// State files / hooks. Always plural; may be empty.
  final List<ScreenState> states;

  /// View files / classes. Always plural; may be empty.
  final List<ScreenView> views;

  /// Route this screen is registered for. Null if not routed or
  /// route could not be resolved (see [DiscoveryNote]).
  final ScreenRoute? route;

  /// For non-routed presentation (`AdaptiveSheet.show`, `showGeneralDialog`).
  /// Free-form for now; descriptive.
  final String? presentedVia;

  Map<String, dynamic> toJson() => {
        'name': name,
        'kind': kind.name,
        'file': file,
        'widget_base': widgetBase,
        'states': states.map((s) => s.toJson()).toList(),
        'views': views.map((v) => v.toJson()).toList(),
        'route': route?.toJson(),
        'presented_via': presentedVia,
      };
}

enum ScreenKind {
  /// Has `static const route` AND is in the routes map.
  routed_screen,

  /// Presented via `*Sheet.show()` / `AdaptiveSheet`.
  sheet,

  /// Presented via `*Dialog.show()` / `showGeneralDialog`.
  dialog,

  /// Full Screen/State/View triple, no route, mounted as inner widget.
  non_routed_page,

  /// State+view exists, no top-level Dart file (embedded fragment).
  subscreen_fragment,

  /// Routed but no state or view files.
  bare_screen,

  /// Annotated with `@RoutePage`, route via code-gen.
  auto_route_page,
}

/// State file/hook tied to a screen.
class ScreenState {
  const ScreenState({
    required this.file,
    required this.className,
    required this.hook,
    this.isAlsoGlobal = false,
  });

  final String file;

  /// Class name (e.g. `HomeScreenState`).
  final String className;

  /// Hook function name (e.g. `useHomeScreenState`).
  final String hook;

  /// True if also registered as a global state (e.g. DailyPackTileState
  /// in madrosc-tlumu).
  final bool isAlsoGlobal;

  Map<String, dynamic> toJson() => {
        'file': file,
        'class': className,
        'hook': hook,
        'is_also_global': isAlsoGlobal,
      };
}

/// View file/class tied to a screen.
class ScreenView {
  const ScreenView({required this.file, required this.className});

  final String file;
  final String className;

  Map<String, dynamic> toJson() => {'file': file, 'class': className};
}

/// Route binding (path -> screen).
class ScreenRoute {
  const ScreenRoute({
    required this.path,
    this.registeredIn,
    this.configBuilder,
    required this.confidence,
  });

  final String path;

  /// Where the route was registered (`lib/app/app_routing.dart`).
  final String? registeredIn;

  /// Builder used (`RouteConfig.material`, `AutoRoute`, `CustomRoute`).
  final String? configBuilder;

  final Confidence confidence;

  Map<String, dynamic> toJson() => {
        'path': path,
        'registered_in': registeredIn,
        'config_builder': configBuilder,
        'confidence': confidence.name,
      };
}

enum Confidence { high, medium, low }

/// A global state hook.
class GlobalState {
  const GlobalState({
    required this.name,
    required this.file,
    required this.package,
    required this.hook,
    this.registeredIn,
    required this.registrationKind,
  });

  /// Class name (`AuthState`).
  final String name;

  final String file;

  /// Package this state lives in. For monorepos, may differ from the
  /// package that registers it.
  final String package;

  /// Hook function name (`useAuthState`).
  final String hook;

  /// Where this state appears in the providers map.
  final String? registeredIn;

  final RegistrationKind registrationKind;

  Map<String, dynamic> toJson() => {
        'name': name,
        'file': file,
        'package': package,
        'hook': hook,
        'registered_in': registeredIn,
        'registration_kind': registrationKind.name,
      };
}

enum RegistrationKind {
  /// In a `_buildProviders()` map inside `app.dart` / `<name>_app.dart`.
  inline_app_dart,

  /// In a dedicated `_providers.dart` file.
  providers_dart_file,

  /// State defined in another workspace package.
  cross_package_import,
}

/// A service (DI-registered, typically in `lib/service/`).
class Service {
  const Service({
    required this.name,
    required this.file,
    this.registeredIn,
    required this.serviceRegistrationKind,
  });

  /// Class name (`AuthService`).
  final String name;

  final String file;

  /// Where the service is registered (`lib/app/app_injector.dart`).
  final String? registeredIn;

  final ServiceRegistrationKind serviceRegistrationKind;

  Map<String, dynamic> toJson() => {
        'name': name,
        'file': file,
        'registered_in': registeredIn,
        'registration_kind': serviceRegistrationKind.name,
      };
}

enum ServiceRegistrationKind { noarg, with_deps, instance, unknown }

/// A detected use of a foreign framework (bloc, riverpod, etc.).
/// Info-only in describe; `doctor` decides severity.
class ForeignArtifact {
  const ForeignArtifact({
    required this.framework,
    required this.pattern,
    required this.file,
    this.line,
    required this.confidence,
  });

  final ForeignFramework framework;

  /// The pattern that matched (`extends Bloc<`, `context.watch`).
  final String pattern;

  final String file;
  final int? line;
  final Confidence confidence;

  Map<String, dynamic> toJson() => {
        'framework': framework.name,
        'pattern': pattern,
        'file': file,
        'line': line,
        'confidence': confidence.name,
      };
}

enum ForeignFramework {
  bloc,
  cubit,
  riverpod,
  provider,
  mobx,
  flutter_hooks_direct,
  stateful_widget,
  get_x,
}

/// A parsing artefact recorded when describe could not resolve something.
class DiscoveryNote {
  const DiscoveryNote({
    required this.kind,
    required this.level,
    required this.message,
    this.context = const {},
  });

  final DiscoveryNoteKind kind;
  final DiscoveryLevel level;
  final String message;

  /// Free-form structured context (screen name, file path, etc.).
  final Map<String, dynamic> context;

  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'level': level.name,
        'message': message,
        'context': context,
      };
}

enum DiscoveryNoteKind {
  unresolved_route,
  computed_route_path,
  conditional_route,
  auto_route_gen_missing,
  multiple_route_pages_per_file,
  screen_outside_canonical_dir,
  unusual_naming,
  pubspec_parse_error,
  workspace_detect_failed,
  project_root_not_found,
  no_package_found,
}

enum DiscoveryLevel { info, warning, error }
