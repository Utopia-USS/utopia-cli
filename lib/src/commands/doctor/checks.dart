/// Registry of all checks `utopia doctor` knows about.
///
/// Adding a check: append to [allChecks]. Tag taxonomy is locked (see
/// `docs/describe_schema.md` and the plan); tag names appear in user
/// `--check=...` flags and breaking them is a breaking change.
library;

import 'dart:io';
import 'package:path/path.dart' as p;

import '../describe/model.dart' as desc;
import 'check.dart';
import 'model.dart';

/// All known checks, ordered by tag.
final List<Check> allChecks = [
  // --- setup -------------------------------------------------------------
  const Check(
    id: 'setup.lints_not_extended',
    tag: 'setup',
    description: 'analysis_options.yaml should `include: package:utopia_lints/lints.yaml`',
    activationGate: utopiaStackGate,
    run: _setupLintsNotExtended,
  ),
  const Check(
    id: 'setup.utopia_hooks_plugin_not_enabled',
    tag: 'setup',
    description: 'Project does not enable the `utopia-hooks` Claude Code plugin (.claude/settings.json)',
    activationGate: utopiaStackGate,
    run: _setupUtopiaHooksPluginNotEnabled,
  ),
  const Check(
    id: 'setup.claude_settings_missing',
    tag: 'setup',
    description: 'Project has no .claude/settings.json - Claude Code skills not registered',
    activationGate: utopiaStackGate,
    run: _setupClaudeSettingsMissing,
  ),

  // --- conventions (per-file rules applied across the whole repo) --------
  const Check(
    id: 'conventions.state_has_navigator',
    tag: 'conventions',
    description: 'State files must not navigate (no Navigator., context.push/pop, GoRouter)',
    activationGate: utopiaStackGate,
    run: _convStateHasNavigator,
  ),
  const Check(
    id: 'conventions.state_has_buildcontext',
    tag: 'conventions',
    description: 'State files must not depend on BuildContext',
    activationGate: utopiaStackGate,
    run: _convStateHasBuildContext,
  ),
  const Check(
    id: 'conventions.view_uses_hooks',
    tag: 'conventions',
    description: 'View files must be pure StatelessWidgets - no useXxx() calls',
    activationGate: utopiaStackGate,
    run: _convViewUsesHooks,
  ),
  const Check(
    id: 'conventions.screen_extends_stateful',
    tag: 'conventions',
    description: 'Screen files must extend HookWidget, not StatefulWidget',
    activationGate: utopiaStackGate,
    run: _convScreenExtendsStateful,
  ),

  // --- artifacts (conditional on foreign-framework deps) -----------------
  Check(
    id: 'artifacts.bloc',
    tag: 'artifacts',
    subTag: 'bloc',
    description: 'Uses flutter_bloc patterns (Bloc, Cubit, BlocProvider, BlocBuilder, emit)',
    activationGate: gateOnPubspecDep(['flutter_bloc', 'bloc']),
    run: _artifactsByFramework([desc.ForeignFramework.bloc, desc.ForeignFramework.cubit], 'bloc'),
  ),
  Check(
    id: 'artifacts.riverpod',
    tag: 'artifacts',
    subTag: 'riverpod',
    description: 'Uses flutter_riverpod patterns (ConsumerWidget, ref.watch, ref.read)',
    activationGate: gateOnPubspecDep(['flutter_riverpod', 'riverpod', 'hooks_riverpod']),
    run: _artifactsByFramework([desc.ForeignFramework.riverpod], 'riverpod'),
  ),
  Check(
    id: 'artifacts.provider',
    tag: 'artifacts',
    subTag: 'provider',
    description: 'Uses `provider` package patterns (ChangeNotifierProvider, context.watch)',
    activationGate: gateOnPubspecDep(['provider']),
    run: _artifactsByFramework([desc.ForeignFramework.provider], 'provider'),
  ),
  Check(
    id: 'artifacts.mobx',
    tag: 'artifacts',
    subTag: 'mobx',
    description: 'Uses MobX patterns (@observable, Observer)',
    activationGate: gateOnPubspecDep(['mobx', 'flutter_mobx']),
    run: _artifactsByFramework([desc.ForeignFramework.mobx], 'mobx'),
  ),
  Check(
    id: 'artifacts.getx',
    tag: 'artifacts',
    subTag: 'getx',
    description: 'Uses GetX patterns (GetxController, GetX)',
    activationGate: gateOnPubspecDep(['get']),
    run: _artifactsByFramework([desc.ForeignFramework.get_x], 'getx'),
  ),
  Check(
    id: 'artifacts.stateful_widget',
    tag: 'artifacts',
    subTag: 'stateful',
    description: 'Any extends StatefulWidget (Utopia rarely needs it)',
    // StatefulWidget is stdlib - always check; doctor reports as INFO.
    activationGate: alwaysGate,
    run: _artifactsByFramework([desc.ForeignFramework.stateful_widget], 'stateful'),
  ),

  // --- imports -----------------------------------------------------------
  Check(
    id: 'imports.flutter_hooks_direct',
    tag: 'imports',
    description: 'Direct `package:flutter_hooks/` import - must go through utopia_arch/utopia_hooks',
    activationGate: utopiaStackGate,
    run: _artifactsByFramework([desc.ForeignFramework.flutter_hooks_direct], null),
  ),

  // --- structure (cross-file invariants) ---------------------------------
  const Check(
    id: 'structure.orphan_state',
    tag: 'structure',
    description: 'State file is not attached to any screen and not registered as global',
    activationGate: utopiaStackGate,
    run: _structureOrphanState,
  ),
];

// =============================================================================
// Check implementations.
// =============================================================================

// --- setup -------------------------------------------------------------------

List<Finding> _setupLintsNotExtended(desc.Describe describe, String projectRoot) {
  final findings = <Finding>[];
  for (final pkg in describe.packages) {
    final analysisFile = File(p.join(projectRoot, pkg.path == '.' ? '' : pkg.path, 'analysis_options.yaml'));
    if (!analysisFile.existsSync()) {
      findings.add(Finding(
        ruleId: 'setup.lints_not_extended',
        tag: 'setup',
        severity: Severity.warning,
        message: 'No analysis_options.yaml found in package "${pkg.name}"',
        file: p.join(pkg.path, 'analysis_options.yaml'),
        fix: 'Create analysis_options.yaml with `include: package:utopia_lints/lints.yaml`',
      ));
      continue;
    }
    final content = analysisFile.readAsStringSync();
    if (!content.contains('utopia_lints')) {
      findings.add(Finding(
        ruleId: 'setup.lints_not_extended',
        tag: 'setup',
        severity: Severity.warning,
        message: 'analysis_options.yaml in "${pkg.name}" does not extend utopia_lints',
        file: p.relative(analysisFile.path, from: projectRoot),
        fix: 'Add `include: package:utopia_lints/lints.yaml` at the top',
      ));
    }
  }
  return findings;
}

List<Finding> _setupUtopiaHooksPluginNotEnabled(desc.Describe describe, String projectRoot) {
  final settingsFile = File(p.join(projectRoot, '.claude', 'settings.json'));
  if (!settingsFile.existsSync()) return const []; // handled by claude_settings_missing
  final content = settingsFile.readAsStringSync();
  // Simple substring check is fine - if someone disables this, they know
  // what they're doing and can --skip this check.
  if (content.contains('"utopia-hooks"')) return const [];
  return [
    const Finding(
      ruleId: 'setup.utopia_hooks_plugin_not_enabled',
      tag: 'setup',
      severity: Severity.info,
      message: '.claude/settings.json does not enable the `utopia-hooks` plugin',
      file: '.claude/settings.json',
      fix: 'Add `"utopia-hooks"` to `enabledPlugins` and the Utopia-USS marketplace to `marketplaces`',
    )
  ];
}

List<Finding> _setupClaudeSettingsMissing(desc.Describe describe, String projectRoot) {
  final settingsFile = File(p.join(projectRoot, '.claude', 'settings.json'));
  if (settingsFile.existsSync()) return const [];
  return [
    const Finding(
      ruleId: 'setup.claude_settings_missing',
      tag: 'setup',
      severity: Severity.info,
      message: 'No .claude/settings.json - Claude Code skills not registered for this project',
      fix: 'Run `utopia init skills` to register the Utopia marketplace',
    )
  ];
}

// --- conventions -------------------------------------------------------------

final _navigatorRegExp = RegExp(
  r'\b(Navigator\.|context\.(push|pop|go|replace)|GoRouter\b|AutoRouter\.of)',
);
final _buildContextRegExp = RegExp(r'\bBuildContext\b');
final _extensionOnBuildContextRegExp = RegExp(r'\bextension\b.*\bon\s+BuildContext\b');
final _useHookCallRegExp = RegExp(r'\buse[A-Z]\w*\s*\(');

/// True if [line] is a single-line comment or block-comment continuation.
/// Line-level heuristic - avoids the common "matched a keyword in a doc
/// comment" false positive without full lexer state.
bool _isCommentLine(String line) {
  final t = line.trimLeft();
  return t.startsWith('//') || t.startsWith('*') || t.startsWith('/*');
}

List<Finding> _convStateHasNavigator(desc.Describe describe, String projectRoot) {
  final findings = <Finding>[];
  for (final pkg in describe.packages) {
    final pkgRoot = pkg.path == '.' ? projectRoot : p.join(projectRoot, pkg.path);
    for (final stateFile in _allStateFilesForPackage(pkg)) {
      final f = File(p.join(pkgRoot, stateFile));
      if (!f.existsSync()) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (_isCommentLine(lines[i])) continue;
        final m = _navigatorRegExp.firstMatch(lines[i]);
        if (m != null) {
          findings.add(Finding(
            ruleId: 'conventions.state_has_navigator',
            tag: 'conventions',
            severity: Severity.warning,
            message: 'State file calls `${m.group(0)}` - navigation belongs in screens, not state',
            file: stateFile,
            line: i + 1,
            fix: 'Move navigation to the screen widget; pass a callback into state if needed',
          ));
        }
      }
    }
  }
  return findings;
}

List<Finding> _convStateHasBuildContext(desc.Describe describe, String projectRoot) {
  final findings = <Finding>[];
  for (final pkg in describe.packages) {
    final pkgRoot = pkg.path == '.' ? projectRoot : p.join(projectRoot, pkg.path);
    for (final stateFile in _allStateFilesForPackage(pkg)) {
      final f = File(p.join(pkgRoot, stateFile));
      if (!f.existsSync()) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        // Skip comments (doc/inline) and `extension X on BuildContext`
        // declarations - these are not the state itself depending on context.
        if (_isCommentLine(line)) continue;
        if (_extensionOnBuildContextRegExp.hasMatch(line)) continue;
        if (_buildContextRegExp.hasMatch(line)) {
          findings.add(Finding(
            ruleId: 'conventions.state_has_buildcontext',
            tag: 'conventions',
            severity: Severity.warning,
            message: 'State file references BuildContext - state should be context-free',
            file: stateFile,
            line: i + 1,
          ));
          break; // one is enough; don't spam
        }
      }
    }
  }
  return findings;
}

List<Finding> _convViewUsesHooks(desc.Describe describe, String projectRoot) {
  final findings = <Finding>[];
  for (final pkg in describe.packages) {
    final pkgRoot = pkg.path == '.' ? projectRoot : p.join(projectRoot, pkg.path);
    for (final screen in pkg.screens) {
      for (final view in screen.views) {
        final f = File(p.join(pkgRoot, view.file));
        if (!f.existsSync()) continue;
        final lines = f.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final m = _useHookCallRegExp.firstMatch(lines[i]);
          if (m != null && !lines[i].trimLeft().startsWith('//')) {
            findings.add(Finding(
              ruleId: 'conventions.view_uses_hooks',
              tag: 'conventions',
              severity: Severity.warning,
              message: 'View calls `${m.group(0)}` - views should be pure StatelessWidgets',
              file: view.file,
              line: i + 1,
              fix: 'Move the hook call to the screen; pass result down via state',
            ));
            break;
          }
        }
      }
    }
  }
  return findings;
}

List<Finding> _convScreenExtendsStateful(desc.Describe describe, String projectRoot) {
  final findings = <Finding>[];
  for (final pkg in describe.packages) {
    for (final screen in pkg.screens) {
      if (screen.widgetBase != null && screen.widgetBase!.startsWith('StatefulWidget')) {
        findings.add(Finding(
          ruleId: 'conventions.screen_extends_stateful',
          tag: 'conventions',
          severity: Severity.warning,
          message: 'Screen "${screen.name}" extends StatefulWidget - should extend HookWidget',
          file: screen.file,
          fix: 'Convert to HookWidget and move state into a useXxxState() hook',
        ));
      }
    }
  }
  return findings;
}

// --- artifacts ---------------------------------------------------------------

/// Generic check that emits one finding per matching foreign artifact
/// already detected by the describe parser.
CheckRunner _artifactsByFramework(List<desc.ForeignFramework> frameworks, String? subTag) {
  return (desc.Describe describe, String projectRoot) {
    final findings = <Finding>[];
    for (final pkg in describe.packages) {
      for (final artefact in pkg.foreignArtifacts) {
        if (!frameworks.contains(artefact.framework)) continue;
        // stateful is info; everything else warning.
        final severity = artefact.framework == desc.ForeignFramework.stateful_widget
            ? Severity.info
            : Severity.warning;
        findings.add(Finding(
          ruleId: subTag == null ? 'imports.${artefact.framework.name}' : 'artifacts.$subTag',
          tag: subTag == null ? 'imports' : 'artifacts',
          subTag: subTag,
          severity: severity,
          message: '${artefact.framework.name} pattern detected: ${artefact.pattern}',
          file: artefact.file,
          line: artefact.line,
        ));
      }
    }
    return findings;
  };
}

// --- structure ---------------------------------------------------------------

final _stateHookDefRegExp = RegExp(r'\b(use\w+State)\s*\(', multiLine: true);

/// A state is orphaned only if its hook (`useXxxState`) is DEFINED but never
/// CALLED anywhere else in the package's lib/. This is robust against
/// cross-directory and cross-screen attachment (e.g. a state in `rooms/`
/// consumed by a screen in the parent `pages/` dir, or a state consumed by a
/// sibling screen's view) - the directory-based heuristic produced false
/// positives there.
List<Finding> _structureOrphanState(desc.Describe describe, String projectRoot) {
  final findings = <Finding>[];
  for (final pkg in describe.packages) {
    final libDir = Directory(p.join(projectRoot, pkg.path == '.' ? '' : pkg.path, 'lib'));
    if (!libDir.existsSync()) continue;
    final pkgRootForRel = p.join(projectRoot, pkg.path == '.' ? '' : pkg.path);

    // Index every dart file's content once, and build a global set of hook
    // CALL sites (hook name -> set of files where it's referenced, excluding
    // its own definition file).
    final dartFiles = libDir
        .listSync(recursive: true, followLinks: false)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('.g.dart') && !f.path.endsWith('.freezed.dart'))
        .toList();

    // hook name -> list of files that reference it at all.
    final hookReferences = <String, Set<String>>{};
    final fileContents = <String, String>{};
    for (final f in dartFiles) {
      final content = f.readAsStringSync();
      fileContents[f.path] = content;
      for (final m in _stateHookDefRegExp.allMatches(content)) {
        final hook = m.group(1)!;
        hookReferences.putIfAbsent(hook, () => <String>{}).add(f.path);
      }
    }

    // Global states are never orphans (they're registered in the providers map).
    final globalHooks = pkg.globalStates.map((g) => g.hook).toSet();

    for (final f in dartFiles) {
      if (!f.path.endsWith('_state.dart')) continue;
      final content = fileContents[f.path]!;
      // Find the hook this state file DEFINES. Anchor to line start (top-level
      // declaration) and allow ANY return type - not just `*State`. This
      // catches hooks returning a controller / non-State type
      // (e.g. `VideoPlayerController useVideoPlayerControllerState()`), which
      // the old `\w+State`-return regex silently skipped.
      final defMatch =
          RegExp(r'^([\w<>,.]+)\s+(use\w+State)\s*\(', multiLine: true).firstMatch(content);
      if (defMatch == null) continue; // not a hook-based state file
      final hook = defMatch.group(2)!;
      if (globalHooks.contains(hook)) continue; // registered global - not orphan

      // Referenced anywhere OTHER than its own definition file?
      final refs = hookReferences[hook] ?? <String>{};
      final referencedElsewhere = refs.any((path) => path != f.path);
      if (referencedElsewhere) continue;

      final rel = p.relative(f.path, from: pkgRootForRel);
      findings.add(Finding(
        ruleId: 'structure.orphan_state',
        tag: 'structure',
        severity: Severity.warning,
        message: 'State hook `$hook` in package "${pkg.name}" is defined but never called - '
            'not attached to any screen or registered as global',
        file: rel,
        fix: 'Either use it from a screen/view, register as global in the providers map, or delete',
      ));
    }
  }
  return findings;
}

// --- helpers -----------------------------------------------------------------

/// All state files in this package - screen-level + global.
List<String> _allStateFilesForPackage(desc.Package pkg) {
  final files = <String>{};
  for (final screen in pkg.screens) {
    for (final st in screen.states) {
      files.add(st.file);
    }
  }
  for (final gs in pkg.globalStates) {
    files.add(gs.file);
  }
  return files.toList();
}
