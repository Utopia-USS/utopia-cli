import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../path_utils.dart';
import '../doctor/model.dart';

/// Result of a utopia_hooks convention analysis run.
class HooksAnalyzeReport {
  const HooksAnalyzeReport({
    required this.schemaVersion,
    required this.projectRoot,
    required this.analyzedFiles,
    required this.findings,
  });

  final int schemaVersion;
  final String projectRoot;
  final List<String> analyzedFiles;
  final List<Finding> findings;

  Map<String, dynamic> toJson() => {
        'schema_version': schemaVersion,
        'project_root': projectRoot,
        'analyzed_files': analyzedFiles,
        'findings': findings.map((f) => f.toJson()).toList(),
        'summary': {
          'error_count': findings.where((f) => f.severity == Severity.error).length,
          'warning_count': findings.where((f) => f.severity == Severity.warning).length,
          'info_count': findings.where((f) => f.severity == Severity.info).length,
        },
      };
}

/// Canonical utopia_hooks quality-analysis engine.
///
/// This is intentionally transport-free: Claude hooks, Codex/MCP tools,
/// pre-commit hooks, and CI should all call into this rule set rather than
/// reimplementing the same regex checks in their own adapters.
class HooksAnalyzeEngine {
  const HooksAnalyzeEngine();

  HooksAnalyzeReport analyzeFiles({
    required String projectRoot,
    required Iterable<String> files,
  }) {
    final normalizedRoot = p.normalize(p.absolute(projectRoot));
    final analyzedFiles = <String>{};
    final findings = <Finding>[];

    for (final file in files) {
      final abs = _absoluteFilePath(normalizedRoot, file);
      final result = _analyzeFile(projectRoot: normalizedRoot, filePath: abs);
      if (result == null) continue;
      analyzedFiles.add(toPosix(result.projectRelativePath));
      findings.addAll(result.findings);
    }

    return HooksAnalyzeReport(
      schemaVersion: 1,
      projectRoot: normalizedRoot,
      analyzedFiles: analyzedFiles.toList()..sort(),
      findings: findings,
    );
  }

  HooksAnalyzeReport analyzeAll({required String projectRoot}) {
    final normalizedRoot = p.normalize(p.absolute(projectRoot));
    final rootDir = Directory(normalizedRoot);
    if (!rootDir.existsSync()) {
      return HooksAnalyzeReport(
        schemaVersion: 1,
        projectRoot: normalizedRoot,
        analyzedFiles: const [],
        findings: const [],
      );
    }

    final files = rootDir
        .listSync(recursive: true, followLinks: false)
        .whereType<File>()
        .map((f) => f.path)
        .where((path) => path.endsWith('.dart'))
        .where((path) => !_isIgnoredPath(path));

    return analyzeFiles(projectRoot: normalizedRoot, files: files);
  }

  Future<List<String>> changedFiles({required String projectRoot}) async {
    final normalizedRoot = p.normalize(p.absolute(projectRoot));
    final result = await Process.run(
      'git',
      const ['status', '--porcelain', '--untracked-files=all'],
      workingDirectory: normalizedRoot,
    );
    if (result.exitCode != 0) {
      final stderrText = result.stderr.toString().trim();
      throw StateError(
        stderrText.isEmpty ? 'Unable to read changed files with git status.' : stderrText,
      );
    }

    final files = <String>[];
    for (final raw in const LineSplitter().convert(result.stdout.toString())) {
      if (raw.length < 4) continue;
      final status = raw.substring(0, 2);
      if (status == 'D ' || status == ' D' || status == 'DD') continue;
      var path = raw.substring(3).trim();
      final renameIndex = path.indexOf(' -> ');
      if (renameIndex != -1) path = path.substring(renameIndex + 4);
      path = _unquoteGitPath(path);
      if (path.endsWith('.dart')) files.add(path);
    }
    return files;
  }

  _FileAnalyzeResult? _analyzeFile({
    required String projectRoot,
    required String filePath,
  }) {
    final file = File(filePath);
    if (!file.existsSync()) return null;
    if (!filePath.endsWith('.dart')) return null;
    if (_isIgnoredPath(filePath)) return null;

    final packageRoot = _findPackageRoot(filePath);
    if (packageRoot == null) return null;
    if (!_declaresUtopiaHooks(packageRoot)) return null;

    final packageRelativePath = p.relative(filePath, from: packageRoot);
    if (!p.split(packageRelativePath).contains('lib')) return null;
    if (!packageRelativePath.startsWith('lib${p.separator}') && packageRelativePath != 'lib') {
      return null;
    }

    final projectRelativePath = p.isWithin(projectRoot, filePath) || p.equals(projectRoot, filePath)
        ? p.relative(filePath, from: projectRoot)
        : packageRelativePath;

    final lines = file.readAsLinesSync();
    final content = lines.join('\n');
    final findings = <Finding>[];
    final classifier = _FileClassifier(packageRelativePath);

    void add(
      String ruleId,
      String message, {
      int? line,
      String? fix,
      Severity severity = Severity.warning,
      Map<String, dynamic> context = const {},
    }) {
      findings.add(Finding(
        ruleId: ruleId,
        tag: 'hooks',
        severity: severity,
        message: message,
        file: toPosix(projectRelativePath),
        line: line,
        fix: fix,
        context: context,
      ));
    }

    final flutterHooksLine = _firstMatchingLine(lines, RegExp(r'''^import\s+['"]package:flutter_hooks/'''));
    if (flutterHooksLine != null) {
      add(
        'hooks.imports_flutter_hooks',
        'imports package:flutter_hooks - utopia_hooks is a separate package, not flutter_hooks',
        line: flutterHooksLine,
        fix: "Import 'package:utopia_hooks/utopia_hooks.dart' or the project-level utopia_arch export instead.",
      );
    }

    final equatableLine = _firstMatchingLine(lines, RegExp(r'\bextends\s+Equatable\b'));
    if (equatableLine != null) {
      add(
        'hooks.extends_equatable',
        'uses extends Equatable - utopia_hooks state classes should be plain classes with final fields',
        line: equatableLine,
      );
    }

    if (classifier.isState) {
      final copyWithLine = _firstMatchingLine(lines, RegExp(r'\bcopyWith\s*\('));
      if (copyWithLine != null) {
        add(
          'hooks.state_uses_copy_with',
          'state file uses copyWith() - use one useState per mutable field instead',
          line: copyWithLine,
        );
      }

      final uiApiLine = _firstMatchingLine(
        lines,
        RegExp(
            r'\b(BuildContext|Navigator\.|GoRouter|context\.(push|pop|go)|Overlay\.|MediaQuery\.|ScaffoldMessenger)\b'),
      );
      if (uiApiLine != null) {
        add(
          'hooks.state_references_ui_api',
          'state file references BuildContext / Navigator / UI APIs - navigation and UI must be injected as callbacks from the Screen',
          line: uiApiLine,
        );
      }

      final topLevelMutableLine = _firstMatchingLine(
        lines,
        RegExp(r'^final\s+(Map|List|Set)\b|^(int|bool|double|String|DateTime\??)\s+[a-zA-Z_]\w*\s*='),
      );
      if (topLevelMutableLine != null) {
        add(
          'hooks.state_has_top_level_mutable_state',
          'state file has top-level mutable state - use useInjected service or _providers global state instead',
          line: topLevelMutableLine,
        );
      }

      final mutableCollectionLine = _firstMatchingLine(lines, RegExp(r'^\s+final\s+(Map|List|Set)<'));
      if (mutableCollectionLine != null) {
        add(
          'hooks.state_declares_mutable_collection',
          'state file declares mutable List/Map/Set field - use IList/IMap/ISet from fast_immutable_collections',
          line: mutableCollectionLine,
        );
      }

      final emitLine = _firstMatchingLine(lines, RegExp(r'\bvoid\s+emit\s*\('));
      if (emitLine != null) {
        add(
          'hooks.state_defines_emit_wrapper',
          'state file defines an emit() wrapper - mutate useState fields directly',
          line: emitLine,
        );
      }
    }

    if (classifier.isScreen) {
      final statefulLine = _firstMatchingLine(lines, RegExp(r'\bextends\s+StatefulWidget\b'));
      if (statefulLine != null) {
        add(
          'hooks.screen_extends_stateful_widget',
          'screen uses StatefulWidget - use HookWidget with useEffect / useStreamSubscription instead',
          line: statefulLine,
        );
      }

      final forbiddenHookLine = _firstMatchingLine(lines, _forbiddenScreenHookRegExp);
      if (forbiddenHookLine != null) {
        add(
          'hooks.screen_calls_forbidden_hook',
          'screen calls a forbidden hook - Screen must only call useXScreenState(...); services, state, and effects belong in the state hook',
          line: forbiddenHookLine,
        );
      }
    }

    if (classifier.isView) {
      final hookWidgetLine = _firstMatchingLine(lines, RegExp(r'\bextends\s+HookWidget\b'));
      if (hookWidgetLine != null) {
        add(
          'hooks.view_extends_hook_widget',
          'view extends HookWidget - View must be StatelessWidget',
          line: hookWidgetLine,
        );
      }

      final hookCallLine = _firstMatchingLine(lines, RegExp(r'\buse[A-Z][A-Za-z0-9_]*\s*\('));
      if (hookCallLine != null) {
        add(
          'hooks.view_calls_hook',
          'view file calls hooks - View must be StatelessWidget with no hooks',
          line: hookCallLine,
        );
      }
    }

    final navigatorProviderLine = _firstMatchingLine(lines, RegExp(r'\buseProvided\s*<\s*NavigatorKey\b'));
    if (navigatorProviderLine != null) {
      add(
        'hooks.injects_navigator_key',
        'useProvided<NavigatorKey> is forbidden - navigation flows Screen -> State -> View as callbacks',
        line: navigatorProviderLine,
      );
    }

    final routerInjectionLine = _firstMatchingLine(lines, RegExp(r'\buseInjected\s*<\s*(App)?Router\b'));
    if (routerInjectionLine != null) {
      add(
        'hooks.injects_router',
        'useInjected<Router> is forbidden - navigation flows Screen -> State -> View as callbacks',
        line: routerInjectionLine,
      );
    }

    final textControllerMemoizedLine = _firstMatchingLine(
      lines,
      RegExp(r'\buseMemoized\s*\([^)]*TextEditingController'),
    );
    if (textControllerMemoizedLine != null) {
      add(
        'hooks.memoizes_text_editing_controller',
        'useMemoized(TextEditingController...) is forbidden - use useFieldState + TextEditingControllerWrapper',
        line: textControllerMemoizedLine,
      );
    }

    if (classifier.isState && !content.contains('TextEditingControllerWrapper')) {
      final syncControllerTextLine = _firstMatchingLine(lines, RegExp(r'\.text\s*=\s*[A-Za-z_]'));
      if (syncControllerTextLine != null && content.contains(RegExp(r'\buseEffect\b'))) {
        add(
          'hooks.state_syncs_controller_text',
          'state file appears to sync controller.text via useEffect - use useFieldState + TextEditingControllerWrapper instead',
          line: syncControllerTextLine,
        );
      }
    }

    final lineCount = lines.length;
    if (classifier.isState) {
      if (lineCount > 400) {
        add(
          'hooks.state_file_too_large_red_flag',
          'state file is $lineCount lines (RED FLAG >400) - decompose into sub-hooks immediately',
          context: {'line_count': lineCount, 'budget': 400},
        );
      } else if (lineCount > 300) {
        add(
          'hooks.state_file_too_large',
          'state file is $lineCount lines (budget: 300) - consider decomposing into sub-hooks',
          context: {'line_count': lineCount, 'budget': 300},
        );
      }
    }

    if (classifier.isScreen) {
      if (lineCount > 200) {
        add(
          'hooks.screen_file_too_large_red_flag',
          'screen file is $lineCount lines (RED FLAG >200) - screen should be a coordinator; move UI to view and logic to state',
          context: {'line_count': lineCount, 'budget': 200},
        );
      } else if (lineCount > 100) {
        add(
          'hooks.screen_file_too_large',
          'screen file is $lineCount lines (budget: 100) - screen should be a thin coordinator calling hook + passing to View',
          context: {'line_count': lineCount, 'budget': 100},
        );
      }
    }

    if (classifier.isView) {
      if (lineCount > 400) {
        add(
          'hooks.view_file_too_large_red_flag',
          'view file is $lineCount lines (RED FLAG >400) - extract sub-widgets immediately',
          context: {'line_count': lineCount, 'budget': 400},
        );
      } else if (lineCount > 300) {
        add(
          'hooks.view_file_too_large',
          'view file is $lineCount lines (budget: 300) - extract sub-widgets into separate files',
          context: {'line_count': lineCount, 'budget': 300},
        );
      }
    }

    if (classifier.isState) {
      final hookCallCount = lines.where((line) => _stateHookCallBudgetRegExp.hasMatch(line)).length;
      if (hookCallCount > 10) {
        add(
          'hooks.state_hook_call_budget_exceeded',
          'hook uses $hookCallCount useX calls (budget: 10) - decompose into sub-hooks',
          context: {'hook_call_count': hookCallCount, 'budget': 10},
        );
      }
    }

    if (classifier.isState && !content.contains('usePaginatedComputedState')) {
      final cursorState = RegExp(
        r'\buseState<(int|String\??)>\s*\(.*\).*(cursor|pageToken|page|offset)',
        caseSensitive: false,
      ).hasMatch(content);
      final hasMore = RegExp(r'\b(hasMore|nextPageToken|nextCursor)\b').hasMatch(content);
      final loadMore = RegExp(r'\bloadMore\b', caseSensitive: false).hasMatch(content);
      if (cursorState && hasMore && loadMore) {
        add(
          'hooks.state_hand_rolls_pagination',
          'state file hand-rolls pagination (cursor + hasMore + loadMore) - use usePaginatedComputedState + PaginatedComputedStateWrapper',
        );
      }
    }

    return _FileAnalyzeResult(
      projectRelativePath: projectRelativePath,
      findings: findings,
    );
  }

  String _absoluteFilePath(String projectRoot, String file) {
    final path = p.isAbsolute(file) ? file : p.join(projectRoot, file);
    return p.normalize(p.absolute(path));
  }

  String? _findPackageRoot(String filePath) {
    var dir = Directory(p.dirname(filePath));
    while (true) {
      if (File(p.join(dir.path, 'pubspec.yaml')).existsSync()) return p.normalize(dir.path);
      final parent = dir.parent;
      if (p.equals(parent.path, dir.path)) return null;
      dir = parent;
    }
  }

  bool _declaresUtopiaHooks(String packageRoot) {
    final pubspec = File(p.join(packageRoot, 'pubspec.yaml'));
    if (!pubspec.existsSync()) return false;
    return RegExp(r'^\s*(utopia_hooks|utopia_arch)\s*:', multiLine: true).hasMatch(pubspec.readAsStringSync());
  }

  bool _isIgnoredPath(String path) {
    final parts = p.split(path);
    return parts.contains('.dart_tool') ||
        parts.contains('build') ||
        parts.contains('.git') ||
        path.endsWith('.g.dart') ||
        path.endsWith('.freezed.dart');
  }

  String _unquoteGitPath(String path) {
    if (path.length >= 2 && path.startsWith('"') && path.endsWith('"')) {
      return path.substring(1, path.length - 1);
    }
    return path;
  }
}

class _FileAnalyzeResult {
  const _FileAnalyzeResult({
    required this.projectRelativePath,
    required this.findings,
  });

  final String projectRelativePath;
  final List<Finding> findings;
}

class _FileClassifier {
  _FileClassifier(String packageRelativePath)
      : isState = _isStatePath(packageRelativePath),
        isView = _isViewPath(packageRelativePath),
        isScreen = !_isStatePath(packageRelativePath) &&
            !_isViewPath(packageRelativePath) &&
            _isScreenPath(packageRelativePath);

  final bool isState;
  final bool isScreen;
  final bool isView;

  static bool _isStatePath(String rel) =>
      rel.startsWith('lib/state${p.separator}') ||
      rel.contains('${p.separator}state${p.separator}') ||
      rel.endsWith('_state.dart');

  static bool _isScreenPath(String rel) =>
      rel.startsWith('lib/screens${p.separator}') ||
      rel.contains('${p.separator}screens${p.separator}') ||
      rel.endsWith('_screen.dart') ||
      rel.endsWith('_page.dart');

  static bool _isViewPath(String rel) =>
      rel.startsWith('lib/view${p.separator}') ||
      rel.contains('${p.separator}view${p.separator}') ||
      rel.endsWith('_view.dart');
}

int? _firstMatchingLine(List<String> lines, RegExp regExp) {
  for (var i = 0; i < lines.length; i++) {
    if (regExp.hasMatch(lines[i])) return i + 1;
  }
  return null;
}

final _forbiddenScreenHookRegExp = RegExp(
  r'\b('
  r'useInjected|useProvided|useEffect|useImmediateEffect|useStreamSubscription|'
  r'useAutoComputedState|useComputedState|useSubmitState|useSubmitButtonState|'
  r'useMemoizedStream|useMemoizedStreamData|useStreamData|useStreamController|'
  r'useMemoizedFuture|useMemoizedFutureData|useFutureData|useFieldState|'
  r'useGenericFieldState|usePersistedState|usePreferencesPersistedState|useState|'
  r'useMemoized|useMemoizedIf|useListenable|useValueListenable|'
  r'useListenableListener|useValueListenableListener|useNotifiable|'
  r'useAnimationController|useFocusNode|useScrollController|useAppLifecycleState|'
  r'useDebounced|usePeriodicalSignal|usePreviousValue|usePreviousIfNull|'
  r'useValueChanged|useMap|useIf|useIfNotNull|useKeyed|useIsMounted|'
  r'useCombinedInitializationState'
  r')\b',
);

final _stateHookCallBudgetRegExp = RegExp(
  r'\b('
  r'useState|useAutoComputedState|useSubmitState|useMemoizedStream|'
  r'useStreamSubscription|useEffect|useMemoized|useInjected|useProvided'
  r')\b',
);
