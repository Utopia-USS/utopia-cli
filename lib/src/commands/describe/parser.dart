/// Project parser for `utopia describe`.
///
/// Regex + path-heuristics first pass. Handles the patterns observed in
/// the 4 reference projects (habicy, jolly-phonics-apps/classroom,
/// qbt-black-phone, madrosc-tlumu) - see `doc/describe_schema.md` for
/// the contract.
///
/// Cross-file resolution (e.g. `<Screen>.route` from `app_routing.dart`
/// back to the screen file's `static const route = '/x'`) IS done at v1.
/// Full Dart analyzer-backed resolution is deferred.
library;

import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../../path_utils.dart';
import 'model.dart';

/// Parses a project at [rootPath] and returns a [Describe].
///
/// [rootPath] must point at either a single Dart/Flutter package or
/// a Melos workspace root.
class DescribeParser {
  const DescribeParser();

  /// Entry point.
  Describe parse(String rootPath) {
    final notes = <DiscoveryNote>[];
    final absRoot = p.absolute(rootPath);

    // Honest failure: if the root doesn't exist, say so loudly instead of
    // returning a silently-empty result that reads like "empty project".
    if (!Directory(absRoot).existsSync()) {
      notes.add(DiscoveryNote(
        kind: DiscoveryNoteKind.project_root_not_found,
        level: DiscoveryLevel.error,
        message: 'Project root does not exist: $absRoot',
        context: {'project_root': absRoot},
      ));
    }

    final workspace = _detectWorkspace(rootPath, notes);
    final packagePaths = _findPackagePaths(workspace, notes);

    final packages = <Package>[];
    for (final packagePath in packagePaths) {
      final pkg = _parsePackage(packagePath, workspace.rootPath, notes);
      if (pkg != null) packages.add(pkg);
    }

    // If we resolved no packages and didn't already flag a missing root,
    // record why - the directory exists but has no pubspec / workspace.
    if (packages.isEmpty && Directory(absRoot).existsSync()) {
      notes.add(DiscoveryNote(
        kind: DiscoveryNoteKind.no_package_found,
        level: DiscoveryLevel.warning,
        message: 'No Dart/Flutter package found at $absRoot '
            '(no pubspec.yaml, and not a recognised workspace).',
        context: {'project_root': absRoot},
      ));
    }

    return Describe(
      schemaVersion: 1,
      workspace: workspace,
      packages: packages,
      discoveryNotes: notes,
      stats: DescribeStats(
        packageCount: packages.length,
        screenCount: packages.fold(0, (acc, p) => acc + p.screens.length),
        routeCount: packages.fold(0, (acc, p) => acc + p.screens.where((s) => s.route != null).length),
        globalStateCount: packages.fold(0, (acc, p) => acc + p.globalStates.length),
        serviceCount: packages.fold(0, (acc, p) => acc + p.services.length),
        foreignArtifactCount: packages.fold(0, (acc, p) => acc + p.foreignArtifacts.length),
      ),
    );
  }

  // --- Workspace detection -------------------------------------------------

  Workspace _detectWorkspace(String rootPath, List<DiscoveryNote> notes) {
    final abs = p.absolute(rootPath);
    final melosFile = File(p.join(abs, 'melos.yaml'));
    final rootPubspec = File(p.join(abs, 'pubspec.yaml'));

    if (melosFile.existsSync()) {
      List<String> glob = const [];
      try {
        final melosYaml = loadYaml(melosFile.readAsStringSync());
        if (melosYaml is YamlMap && melosYaml['packages'] is YamlList) {
          glob = (melosYaml['packages'] as YamlList).map((e) => e.toString()).toList();
        }
      } on Object catch (e) {
        notes.add(DiscoveryNote(
          kind: DiscoveryNoteKind.workspace_detect_failed,
          level: DiscoveryLevel.warning,
          message: 'Failed to parse melos.yaml: $e',
        ));
      }
      return Workspace(
        type: WorkspaceType.monorepo,
        tool: WorkspaceTool.melos,
        rootPath: abs,
        packagesGlob: glob,
      );
    }

    // Detect Dart workspace via `workspace:` field in root pubspec.
    if (rootPubspec.existsSync()) {
      try {
        final yaml = loadYaml(rootPubspec.readAsStringSync());
        if (yaml is YamlMap && yaml['workspace'] is YamlList) {
          final members = (yaml['workspace'] as YamlList).map((e) => e.toString()).toList();
          return Workspace(
            type: WorkspaceType.monorepo,
            tool: WorkspaceTool.dart_workspace,
            rootPath: abs,
            packagesGlob: members,
          );
        }
      } on Object catch (_) {
        // Fall through to single-package.
      }
    }

    return Workspace(
      type: WorkspaceType.single_package,
      tool: WorkspaceTool.none,
      rootPath: abs,
      packagesGlob: const [],
    );
  }

  List<String> _findPackagePaths(Workspace workspace, List<DiscoveryNote> notes) {
    if (workspace.type == WorkspaceType.single_package) {
      return [workspace.rootPath];
    }

    final paths = <String>[];
    for (final glob in workspace.packagesGlob) {
      paths.addAll(_expandGlob(workspace.rootPath, glob));
    }
    // Dedup + keep only those with a pubspec.yaml.
    final unique = paths.toSet().where((path) => File(p.join(path, 'pubspec.yaml')).existsSync()).toList()..sort();
    if (unique.isEmpty) {
      notes.add(const DiscoveryNote(
        kind: DiscoveryNoteKind.workspace_detect_failed,
        level: DiscoveryLevel.warning,
        message: 'Workspace declared packages but none resolved to a pubspec.yaml',
      ));
    }
    return unique;
  }

  /// Expands a simple glob (`packages/*`, `apps/*`, etc.) under [root].
  /// Only supports trailing `/*` and exact paths. Nested globs not supported.
  List<String> _expandGlob(String root, String glob) {
    if (!glob.contains('*')) {
      final candidate = p.join(root, glob);
      return Directory(candidate).existsSync() ? [candidate] : [];
    }
    if (!glob.endsWith('/*')) return [];
    final parent = Directory(p.join(root, glob.substring(0, glob.length - 2)));
    if (!parent.existsSync()) return [];
    return parent.listSync().whereType<Directory>().map((d) => d.path).toList();
  }

  // --- Package parsing -----------------------------------------------------

  Package? _parsePackage(String packagePath, String workspaceRoot, List<DiscoveryNote> notes) {
    final pubspecFile = File(p.join(packagePath, 'pubspec.yaml'));
    if (!pubspecFile.existsSync()) return null;

    Pubspec pubspec;
    try {
      pubspec = _parsePubspec(pubspecFile);
    } on Object catch (e) {
      notes.add(DiscoveryNote(
        kind: DiscoveryNoteKind.pubspec_parse_error,
        level: DiscoveryLevel.error,
        message: 'Failed to parse pubspec at ${pubspecFile.path}: $e',
        context: {'package_path': packagePath},
      ));
      return null;
    }

    final libDir = Directory(p.join(packagePath, 'lib'));
    if (!libDir.existsSync()) {
      // Pure metadata package (workspace root, etc.). Emit minimal.
      return Package(
        name: pubspec.name,
        path: _relativeToWorkspace(packagePath, workspaceRoot),
        pubspec: pubspec,
      );
    }

    final entrypoint = _findAppEntrypoint(libDir);
    final screens = _findScreens(libDir, packagePath, notes);
    final routing = _detectRouting(libDir, screens, notes);
    final globalStates = _findGlobalStates(libDir, pubspec.name, packagePath);
    final services = _findServices(libDir);
    final foreignArtifacts = _scanForeignArtifacts(libDir);

    // Cross-reference: which screen states are also globals?
    final globalHookNames = globalStates.map((s) => s.hook).toSet();
    final routingConfigFile = routing?.configFile;
    final patchedScreens = screens.map((s) {
      final patchedStates = s.states.map((st) {
        return ScreenState(
          file: st.file,
          className: st.className,
          hook: st.hook,
          isAlsoGlobal: globalHookNames.contains(st.hook),
        );
      }).toList();
      // If the screen has a route and routing config is known, fill in
      // `registered_in` so agents can find where to add new routes.
      final patchedRoute = s.route == null
          ? null
          : ScreenRoute(
              path: s.route!.path,
              registeredIn: routingConfigFile,
              configBuilder: s.route!.configBuilder,
              confidence: s.route!.confidence,
            );
      return Screen(
        name: s.name,
        kind: s.kind,
        file: s.file,
        widgetBase: s.widgetBase,
        states: patchedStates,
        views: s.views,
        route: patchedRoute,
        presentedVia: s.presentedVia,
      );
    }).toList();

    return Package(
      name: pubspec.name,
      path: _relativeToWorkspace(packagePath, workspaceRoot),
      pubspec: pubspec,
      appEntrypoint: entrypoint != null ? posixRelative(entrypoint, from: packagePath) : null,
      routing: routing,
      screens: patchedScreens,
      globalStates: globalStates,
      services: services,
      foreignArtifacts: foreignArtifacts,
    );
  }

  String _relativeToWorkspace(String packagePath, String workspaceRoot) {
    if (packagePath == workspaceRoot) return '.';
    return posixRelative(packagePath, from: workspaceRoot);
  }

  Pubspec _parsePubspec(File f) {
    final yaml = loadYaml(f.readAsStringSync());
    if (yaml is! YamlMap) throw const FormatException('pubspec root is not a map');
    return Pubspec(
      name: (yaml['name'] ?? 'unknown').toString(),
      version: yaml['version']?.toString(),
      dartSdk: _readSdkConstraint(yaml, 'sdk'),
      flutterSdk: _readSdkConstraint(yaml, 'flutter'),
      deps: _readDepsMap(yaml['dependencies']),
      devDeps: _readDepsMap(yaml['dev_dependencies']),
    );
  }

  String? _readSdkConstraint(YamlMap yaml, String key) {
    final env = yaml['environment'];
    if (env is YamlMap && env[key] != null) return env[key].toString();
    return null;
  }

  Map<String, String> _readDepsMap(dynamic deps) {
    if (deps is! YamlMap) return const {};
    final out = <String, String>{};
    for (final entry in deps.entries) {
      final key = entry.key.toString();
      final value = entry.value;
      if (value is String) {
        out[key] = value;
      } else if (value is YamlMap) {
        // sdk: flutter / path: ../foo / git: ...
        if (value['sdk'] != null) {
          out[key] = 'sdk:${value['sdk']}';
        } else if (value['path'] != null) {
          out[key] = 'path:${value['path']}';
        } else if (value['git'] != null) {
          out[key] = 'git';
        } else {
          out[key] = 'any';
        }
      } else if (value == null) {
        out[key] = 'any';
      } else {
        out[key] = value.toString();
      }
    }
    return out;
  }

  // --- Entrypoint ----------------------------------------------------------

  String? _findAppEntrypoint(Directory libDir) {
    final candidates = ['main.dart'];
    for (final name in candidates) {
      final f = File(p.join(libDir.path, name));
      if (f.existsSync()) return f.path;
    }
    return null;
  }

  // --- Screen discovery ----------------------------------------------------

  static final _screenSuffixes = ['_screen.dart', '_page.dart', '_sheet.dart', '_dialog.dart'];

  /// Patterns we consider "screen-like" file locations.
  /// Returns a list of candidate file paths under [libDir].
  List<File> _findScreenCandidates(Directory libDir) {
    final out = <File>[];
    final allDarts = libDir
        .listSync(recursive: true, followLinks: false)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('.g.dart') && !f.path.endsWith('.freezed.dart'));

    for (final file in allDarts) {
      final base = p.basename(file.path);
      if (_screenSuffixes.any(base.endsWith)) {
        out.add(file);
      }
    }
    return out;
  }

  List<Screen> _findScreens(Directory libDir, String packagePath, List<DiscoveryNote> notes) {
    final out = <Screen>[];
    for (final file in _findScreenCandidates(libDir)) {
      final screen = _parseScreenFile(file, libDir, packagePath, notes);
      if (screen != null) out.add(screen);
    }
    out.sort((a, b) => a.name.compareTo(b.name));
    return out;
  }

  /// Regex: class declaration matching the file's expected class name.
  static final _classDeclRegExp = RegExp(r'class\s+(\w+)\s+extends\s+([\w<>.,\s]+?)\s*\{', multiLine: true);
  static final _routeConstRegExp = RegExp(r'''static\s+const\s+route\s*=\s*['"]([^'"]+)['"]''', multiLine: true);
  static final _routePageAnnotRegExp = RegExp(r'@RoutePage\(\)', multiLine: true);
  static final _routeConfigRegExp = RegExp(r'static\s+final\s+routeConfig\s*=\s*([\w.<>(),\s_]+);', multiLine: true);

  /// Directories under `lib/` whose files are generic widgets, not screens.
  /// Files here are excluded from screen discovery even if their name matches
  /// a screen suffix (e.g. `lib/common/widget/adaptive_sheet.dart` is a
  /// reusable widget, not a sheet screen).
  static const _nonScreenLibDirs = ['common', 'util', 'utils', 'widget', 'widgets', 'core'];

  Screen? _parseScreenFile(File file, Directory libDir, String packagePath, List<DiscoveryNote> notes) {
    final relPath = posixRelative(file.path, from: packagePath);

    // Skip files in known non-screen directories.
    final segments = p.split(relPath);
    if (segments.length >= 2 && segments[0] == 'lib' && _nonScreenLibDirs.contains(segments[1])) {
      return null;
    }

    final content = file.readAsStringSync();
    final base = p.basename(file.path);
    final suffix = _screenSuffixes.firstWhere(base.endsWith, orElse: () => '');

    final filePart = base.substring(0, base.length - '.dart'.length);
    final expectedPascal = _snakeToPascal(filePart);

    // Find class declarations.
    final matches = _classDeclRegExp.allMatches(content).toList();

    // Require a class whose name matches the file basename (PascalCase). This
    // filters out files like `adaptive_sheet.dart` that contain only
    // `AdaptiveSheetDragHandle` - those are utility widgets, not screens.
    String? widgetBase;
    var foundMatch = false;
    for (final m in matches) {
      if (m.group(1) == expectedPascal) {
        widgetBase = m.group(2)?.trim();
        foundMatch = true;
        break;
      }
    }

    // Function-based dialog/sheet fallback: files like
    // `deck_upsell_dialog.dart` expose only a top-level `showXxx()` /
    // `openXxx()` function (no matching widget class) but ARE a dialog/sheet.
    // Accept them when the suffix is _dialog/_sheet and such a function or a
    // sibling view/ dir is present. Mirrors how WeeklyDealDialog (class-based)
    // is treated, for consistency.
    final isImperativeSuffix = suffix == '_dialog.dart' || suffix == '_sheet.dart';
    if (!foundMatch) {
      final hasShowFn = _topLevelShowFnRegExp.hasMatch(content);
      final hasSiblingView = Directory(p.join(p.dirname(file.path), 'view')).existsSync();
      if (!(isImperativeSuffix && (hasShowFn || hasSiblingView))) {
        // No matching class and not a recognised function-based dialog/sheet.
        return null;
      }
      // Accept as function-based; no widget base class.
      widgetBase = null;
    }
    final name = expectedPascal;

    // Detect @RoutePage annotation (auto_route).
    final hasRoutePageAnnotation = _routePageAnnotRegExp.hasMatch(content);
    // Detect static const route.
    final routeMatch = _routeConstRegExp.firstMatch(content);
    final routePath = routeMatch?.group(1);
    final hasRouteConfig = _routeConfigRegExp.hasMatch(content);

    // Find sibling state/ and view/ directories.
    final screenDir = Directory(p.dirname(file.path));
    final states = _findScreenStates(screenDir, packagePath);
    final views = _findScreenViews(screenDir, packagePath, file);

    // Detect screen kind.
    final ScreenKind kind = _inferScreenKind(
      suffix: suffix,
      widgetBase: widgetBase,
      hasRoutePageAnnotation: hasRoutePageAnnotation,
      hasRouteConst: routePath != null,
      hasRouteConfig: hasRouteConfig,
      hasStates: states.isNotEmpty,
      hasViews: views.isNotEmpty,
    );

    // Multi-RoutePage warning.
    final routePageCount = _routePageAnnotRegExp.allMatches(content).length;
    if (routePageCount > 1) {
      notes.add(DiscoveryNote(
        kind: DiscoveryNoteKind.multiple_route_pages_per_file,
        level: DiscoveryLevel.warning,
        message: 'File declares $routePageCount @RoutePage annotations',
        context: {'file': relPath, 'count': routePageCount},
      ));
    }

    ScreenRoute? route;
    if (routePath != null) {
      route = ScreenRoute(
        path: routePath,
        registeredIn: null, // Routing detection fills this in cross-pass.
        configBuilder: null,
        confidence: Confidence.high,
      );
    }

    String? presentedVia;
    if (kind == ScreenKind.sheet) {
      presentedVia = _detectShowMethod(content);
    } else if (kind == ScreenKind.dialog) {
      presentedVia = _detectShowMethod(content);
    }

    return Screen(
      name: name,
      kind: kind,
      file: relPath,
      widgetBase: widgetBase,
      states: states,
      views: views,
      route: route,
      presentedVia: presentedVia,
    );
  }

  ScreenKind _inferScreenKind({
    required String suffix,
    String? widgetBase,
    required bool hasRoutePageAnnotation,
    required bool hasRouteConst,
    required bool hasRouteConfig,
    required bool hasStates,
    required bool hasViews,
  }) {
    if (hasRoutePageAnnotation) return ScreenKind.auto_route_page;
    if (suffix == '_sheet.dart') return ScreenKind.sheet;
    if (suffix == '_dialog.dart') return ScreenKind.dialog;
    // _screen.dart or _page.dart from here on.
    if (hasRouteConst && !hasStates && !hasViews) return ScreenKind.bare_screen;
    if (hasRouteConst) return ScreenKind.routed_screen;
    if (!hasRouteConst && (hasStates || hasViews)) return ScreenKind.non_routed_page;
    return ScreenKind.routed_screen; // best guess
  }

  static final _showMethodRegExp = RegExp(r'static\s+\w[\w<>?]*\s+(show|open)\s*\(', multiLine: true);
  // Top-level `Future<void> showDeckUpsellDialog(...)` / `void openX(...)` etc.
  static final _topLevelShowFnRegExp =
      RegExp(r'^\s*(?:Future<[^>]*>|void|\w+)\s+(show|open)[A-Z]\w*\s*\(', multiLine: true);
  String? _detectShowMethod(String content) {
    final m = _showMethodRegExp.firstMatch(content);
    if (m != null) return m.group(1);
    final fn = _topLevelShowFnRegExp.firstMatch(content);
    if (fn != null) return fn.group(1);
    return null;
  }

  static final _hookFnRegExp = RegExp(r'(\w+State)\s+(use\w+State)\s*\(', multiLine: true);
  static final _stateClassRegExp = RegExp(r'class\s+(\w+State)\b', multiLine: true);

  List<ScreenState> _findScreenStates(Directory screenDir, String packagePath) {
    final stateDir = Directory(p.join(screenDir.path, 'state'));
    if (!stateDir.existsSync()) return const [];
    final out = <ScreenState>[];
    for (final f in stateDir.listSync(recursive: false).whereType<File>()) {
      if (!f.path.endsWith('.dart') || f.path.endsWith('.g.dart') || f.path.endsWith('.freezed.dart')) continue;
      final content = f.readAsStringSync();
      final hookMatch = _hookFnRegExp.firstMatch(content);
      final classMatch = _stateClassRegExp.firstMatch(content);
      if (hookMatch == null && classMatch == null) continue;
      out.add(ScreenState(
        file: posixRelative(f.path, from: packagePath),
        className: hookMatch?.group(1) ?? classMatch?.group(1) ?? 'Unknown',
        hook: hookMatch?.group(2) ?? 'use${classMatch?.group(1) ?? 'Unknown'}',
      ));
    }
    return out;
  }

  List<ScreenView> _findScreenViews(Directory screenDir, String packagePath, File screenFile) {
    final viewDir = Directory(p.join(screenDir.path, 'view'));
    if (!viewDir.existsSync()) return const [];
    final out = <ScreenView>[];
    for (final f in viewDir.listSync(recursive: false).whereType<File>()) {
      if (!f.path.endsWith('.dart') || f.path.endsWith('.g.dart') || f.path.endsWith('.freezed.dart')) continue;
      final content = f.readAsStringSync();
      final classMatch = _classDeclRegExp.firstMatch(content);
      if (classMatch == null) continue;
      out.add(ScreenView(
        file: posixRelative(f.path, from: packagePath),
        className: classMatch.group(1) ?? 'Unknown',
      ));
    }
    return out;
  }

  // --- Routing detection ---------------------------------------------------

  static final _autoRouterConfigRegExp = RegExp(r'@AutoRouterConfig\b');
  static final _goRouterCtorRegExp = RegExp(r'\bGoRouter\s*\(');
  // Match both `Map<String, RouteConfig>` and the literal generic
  // `<String, RouteConfig>{` form used by `static final routes = <...>`.
  static final _routeMapRegExp = RegExp(r'(Map\s*<|<)\s*String\s*,\s*RouteConfig\s*>');

  Routing? _detectRouting(Directory libDir, List<Screen> screens, List<DiscoveryNote> notes) {
    // Look for `app_routing.dart` or `*_routing.dart` anywhere under lib/app/.
    final routingCandidates = _findRoutingFile(libDir);
    final autoRouteCandidates = _findAutoRouterFile(libDir);

    for (final candidate in routingCandidates) {
      final content = candidate.readAsStringSync();
      if (_routeMapRegExp.hasMatch(content)) {
        return Routing(
          strategy: RoutingStrategy.static_const_aggregator,
          configFile: posixRelative(candidate.path, from: libDir.parent.path),
          initialRoute: _extractInitialRoute(content, screens),
          routeCount: screens.where((s) => s.route != null).length,
        );
      }
    }

    if (autoRouteCandidates.isNotEmpty) {
      final main = autoRouteCandidates.first;
      final content = main.readAsStringSync();
      if (_autoRouterConfigRegExp.hasMatch(content)) {
        final genFile = File(main.path.replaceFirst('.dart', '.gr.dart'));
        if (!genFile.existsSync()) {
          notes.add(DiscoveryNote(
            kind: DiscoveryNoteKind.auto_route_gen_missing,
            level: DiscoveryLevel.warning,
            message: 'auto_route config detected but generated file not found',
            context: {'expected': posixRelative(genFile.path, from: libDir.parent.path)},
          ));
        }
        return Routing(
          strategy: RoutingStrategy.auto_route,
          configFile: posixRelative(main.path, from: libDir.parent.path),
          autoRouteGenFile: genFile.existsSync() ? posixRelative(genFile.path, from: libDir.parent.path) : null,
          routeCount: screens.where((s) => s.kind == ScreenKind.auto_route_page).length,
        );
      }
    }

    // Check for go_router anywhere.
    for (final f in libDir.listSync(recursive: true).whereType<File>().take(200)) {
      if (!f.path.endsWith('.dart')) continue;
      if (_goRouterCtorRegExp.hasMatch(f.readAsStringSync())) {
        return Routing(
          strategy: RoutingStrategy.go_router,
          configFile: posixRelative(f.path, from: libDir.parent.path),
          routeCount: 0,
        );
      }
    }

    if (screens.isEmpty) return null;
    return const Routing(
      strategy: RoutingStrategy.imperative_only,
      configFile: null,
      routeCount: 0,
    );
  }

  /// Find files matching `*_routing.dart` under `lib/app/` recursively, plus
  /// `lib/app_routing.dart` at top level. Common locations:
  /// - `lib/app/app_routing.dart` (madrosc)
  /// - `lib/app/arch/app_routing.dart` (habicy)
  /// - `lib/app_routing.dart` (rare, top-level)
  List<File> _findRoutingFile(Directory libDir) {
    final out = <File>[];
    final appDir = Directory(p.join(libDir.path, 'app'));
    if (appDir.existsSync()) {
      for (final f in appDir.listSync(recursive: true).whereType<File>()) {
        if (f.path.endsWith('_routing.dart') && !f.path.endsWith('.g.dart')) {
          out.add(f);
        }
      }
    }
    final topLevel = File(p.join(libDir.path, 'app_routing.dart'));
    if (topLevel.existsSync()) out.add(topLevel);
    // Prefer shorter paths (closer to lib/app/ root) first.
    out.sort((a, b) => a.path.length.compareTo(b.path.length));
    return out;
  }

  List<File> _findAutoRouterFile(Directory libDir) {
    final candidates = <File>[];
    final navDir = Directory(p.join(libDir.path, 'app', 'navigation'));
    if (navDir.existsSync()) {
      for (final f in navDir.listSync().whereType<File>()) {
        if (f.path.endsWith('_router.dart')) candidates.add(f);
      }
    }
    // Also scan top-level *_router.dart in lib/.
    for (final f in libDir.listSync().whereType<File>()) {
      if (f.path.endsWith('_router.dart')) candidates.add(f);
    }
    return candidates;
  }

  static final _initialRouteRegExp = RegExp(r'initialRoute\s*=\s*(\w+)\.route');
  String? _extractInitialRoute(String content, List<Screen> screens) {
    final m = _initialRouteRegExp.firstMatch(content);
    if (m == null) return null;
    final screenName = m.group(1);
    final s = screens.where((s) => s.name == screenName).firstOrNull;
    return s?.route?.path;
  }

  // --- Global state discovery ---------------------------------------------

  /// Global states are:
  /// 1. Any `*_state.dart` under `lib/(app/)?state/` (conventional location), AND
  /// 2. Any other `*_state.dart` ANYWHERE in lib/ whose hook appears in the
  ///    providers map - e.g. a screen state hoisted to global (madrosc-tlumu's
  ///    `DailyPackTileState` lives in `screen/home/state/` but is registered in
  ///    `app.dart`'s providers map).
  List<GlobalState> _findGlobalStates(Directory libDir, String packageName, String packagePath) {
    final providerMapFile = _findProviderMapFile(libDir);
    final providerContent = providerMapFile?.readAsStringSync() ?? '';
    final registeredIn = providerMapFile != null ? posixRelative(providerMapFile.path, from: packagePath) : null;

    final byFile = <String, GlobalState>{};

    // Conventional state directories - always treated as global.
    final conventionalDirs = <Directory>[
      Directory(p.join(libDir.path, 'app', 'state')),
      Directory(p.join(libDir.path, 'state')),
    ].where((d) => d.existsSync());

    final conventionalPaths = <String>{};
    for (final dir in conventionalDirs) {
      for (final f in dir.listSync(recursive: true, followLinks: false).whereType<File>()) {
        conventionalPaths.add(f.path);
      }
    }

    void consider(File f, {required bool conventional}) {
      if (!f.path.endsWith('_state.dart')) return;
      if (f.path.endsWith('.g.dart') || f.path.endsWith('.freezed.dart')) return;
      final content = f.readAsStringSync();
      final hookMatch = _hookFnRegExp.firstMatch(content);
      final classMatch = _stateClassRegExp.firstMatch(content);
      if (hookMatch == null && classMatch == null) return;
      final hook = hookMatch?.group(2) ?? 'use${classMatch?.group(1) ?? 'Unknown'}';
      final className = hookMatch?.group(1) ?? classMatch?.group(1) ?? 'Unknown';
      final isRegistered = providerContent.contains(hook);

      // A providers-map entry is a NO-ARG tear-off (`Map<Type, Object? Function()>`),
      // so a hook that takes arguments cannot be a global provider - it's a
      // parameterized state helper that merely lives in the state/ dir
      // (e.g. madrosc's useWeeklyDealDismissalState(String? id)). Detect no-arg
      // by an empty-parens declaration. Cross-package globals like ColorState
      // are no-arg even when not registered in THIS package's map, so they stay.
      final isNoArgHook = RegExp('\\b[\\w<>,.]+\\s+$hook\\s*\\(\\s*\\)').hasMatch(content);

      if (conventional) {
        // Conventional-dir state counts as global if it's registered OR is a
        // plausible no-arg provider. Parameterized + unregistered = not global.
        if (!isRegistered && !isNoArgHook) return;
      } else {
        // Non-conventional location: only a registered hook is a global.
        if (!isRegistered) return;
      }

      final rel = posixRelative(f.path, from: packagePath);
      byFile[rel] = GlobalState(
        name: className,
        file: rel,
        package: packageName,
        hook: hook,
        registeredIn: isRegistered ? registeredIn : null,
        registrationKind: RegistrationKind.inline_app_dart,
      );
    }

    // Pass 1: conventional dirs.
    for (final pth in conventionalPaths) {
      consider(File(pth), conventional: true);
    }

    // Pass 2: any other *_state.dart in lib/ that's registered in the map
    // (hoisted screen state). Skip files already covered in pass 1.
    for (final f in libDir.listSync(recursive: true, followLinks: false).whereType<File>()) {
      if (conventionalPaths.contains(f.path)) continue;
      consider(f, conventional: false);
    }

    final out = byFile.values.toList()..sort((a, b) => a.name.compareTo(b.name));
    return out;
  }

  /// Find the file containing the `_buildProviders` map or `Map<Type, ...>`
  /// registration. Best-effort: looks at `lib/<name>_app.dart` or `lib/app.dart`
  /// or `lib/app/app.dart`.
  File? _findProviderMapFile(Directory libDir) {
    final candidates = [
      File(p.join(libDir.path, 'app', 'app.dart')),
      File(p.join(libDir.path, 'app.dart')),
    ];
    // Also any file matching *_app.dart at top level.
    for (final f in libDir.listSync().whereType<File>()) {
      if (f.path.endsWith('_app.dart')) candidates.add(f);
    }
    for (final f in candidates) {
      if (f.existsSync() && f.readAsStringSync().contains(RegExp(r'Map\s*<\s*Type\s*,'))) {
        return f;
      }
    }
    return null;
  }

  // --- Services -----------------------------------------------------------

  static final _serviceClassRegExp = RegExp(r'class\s+(\w+Service)\b', multiLine: true);

  List<Service> _findServices(Directory libDir) {
    final serviceDir = Directory(p.join(libDir.path, 'service'));
    if (!serviceDir.existsSync()) return const [];

    // Find injector file.
    final injectorCandidates = [
      File(p.join(libDir.path, 'app', 'app_injector.dart')),
      File(p.join(libDir.path, 'app_injector.dart')),
    ];
    // Also any *_injector.dart at top level.
    for (final f in libDir.listSync().whereType<File>()) {
      if (f.path.endsWith('_injector.dart')) injectorCandidates.add(f);
    }
    final injectorFile = injectorCandidates.where((f) => f.existsSync()).firstOrNull;
    final injectorContent = injectorFile?.readAsStringSync() ?? '';

    final out = <Service>[];
    for (final f in serviceDir.listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart') || f.path.endsWith('.g.dart')) continue;
      final content = f.readAsStringSync();
      final m = _serviceClassRegExp.firstMatch(content);
      if (m == null) continue;
      final name = m.group(1)!;
      ServiceRegistrationKind kind = ServiceRegistrationKind.unknown;
      if (injectorContent.contains(RegExp('register.noarg\\(.*$name'))) {
        kind = ServiceRegistrationKind.noarg;
      } else if (injectorContent.contains(RegExp('register\\(.*$name'))) {
        kind = ServiceRegistrationKind.with_deps;
      } else if (injectorContent.contains(name)) {
        kind = ServiceRegistrationKind.instance;
      }
      out.add(Service(
        name: name,
        file: posixRelative(f.path, from: libDir.parent.path),
        registeredIn: injectorFile != null ? posixRelative(injectorFile.path, from: libDir.parent.path) : null,
        serviceRegistrationKind: kind,
      ));
    }
    out.sort((a, b) => a.name.compareTo(b.name));
    return out;
  }

  // --- Foreign artifacts --------------------------------------------------

  /// Patterns that signal use of a competing framework. Tied to a
  /// [ForeignFramework] for grouping in `doctor`.
  static const _foreignPatterns = <_ForeignPattern>[
    _ForeignPattern(ForeignFramework.bloc, r'extends\s+Bloc<'),
    _ForeignPattern(ForeignFramework.cubit, r'extends\s+Cubit<'),
    _ForeignPattern(ForeignFramework.bloc, r'\bBlocProvider\b'),
    _ForeignPattern(ForeignFramework.bloc, r'\bBlocBuilder\b'),
    _ForeignPattern(ForeignFramework.bloc, r'\bBlocListener\b'),
    _ForeignPattern(ForeignFramework.riverpod, r'\bConsumerWidget\b'),
    _ForeignPattern(ForeignFramework.riverpod, r'\bConsumerStatefulWidget\b'),
    _ForeignPattern(ForeignFramework.riverpod, r'ref\.watch'),
    _ForeignPattern(ForeignFramework.riverpod, r'ref\.read'),
    _ForeignPattern(ForeignFramework.provider, r'\bChangeNotifierProvider\b'),
    _ForeignPattern(ForeignFramework.provider, r'context\.watch<'),
    _ForeignPattern(ForeignFramework.provider, r'context\.read<'),
    _ForeignPattern(ForeignFramework.provider, r'\bProvider\.of<'),
    _ForeignPattern(ForeignFramework.provider, r'\bMultiProvider\b'),
    _ForeignPattern(ForeignFramework.stateful_widget, r'extends\s+StatefulWidget'),
    _ForeignPattern(ForeignFramework.flutter_hooks_direct, r'''import\s+['"]package:flutter_hooks/'''),
    _ForeignPattern(ForeignFramework.get_x, r'\bGetxController\b'),
    _ForeignPattern(ForeignFramework.mobx, r'@observable'),
  ];

  List<ForeignArtifact> _scanForeignArtifacts(Directory libDir) {
    final out = <ForeignArtifact>[];
    for (final f in libDir.listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      if (f.path.endsWith('.g.dart') || f.path.endsWith('.freezed.dart')) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (isCommentLine(line)) continue; // don't match patterns in comments
        for (final pat in _foreignPatterns) {
          if (RegExp(pat.regex).hasMatch(line)) {
            out.add(ForeignArtifact(
              framework: pat.framework,
              pattern: pat.regex,
              file: posixRelative(f.path, from: libDir.parent.path),
              line: i + 1,
              confidence: Confidence.high,
            ));
            break; // one match per line is enough; avoid duplicates
          }
        }
      }
    }
    return out;
  }
}

class _ForeignPattern {
  const _ForeignPattern(this.framework, this.regex);
  final ForeignFramework framework;
  final String regex;
}

/// snake_case → PascalCase. `home_screen` → `HomeScreen`.
String _snakeToPascal(String snake) =>
    snake.split('_').where((p) => p.isNotEmpty).map((p) => p[0].toUpperCase() + p.substring(1)).join();

/// True if [line] is a single-line comment or a block-comment continuation.
/// Best-effort line-level heuristic (doesn't track multi-line block state or
/// distinguish patterns inside string literals) - enough to avoid the common
/// "matched a keyword in a doc comment" false positive.
bool isCommentLine(String line) {
  final t = line.trimLeft();
  return t.startsWith('//') || t.startsWith('*') || t.startsWith('/*');
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
