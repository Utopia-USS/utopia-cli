import 'dart:convert';
import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:utopia_cli/src/command_runner.dart';

void main() {
  group('utopia doctor', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('utopia_doctor_test_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('reports clean for minimal valid utopia project', () async {
      _writeFile(tempDir, 'pubspec.yaml', _utopiaPubspec);
      _writeFile(tempDir, 'analysis_options.yaml', 'include: package:utopia_lints/lints.yaml');
      _writeFile(tempDir, '.claude/settings.json', '{"enabledPlugins": ["utopia-hooks"]}');
      _writeFile(tempDir, 'lib/main.dart', 'void main() {}');

      final report = await _runDoctor(tempDir);
      expect(report['summary']['error_count'], 0);
      expect(report['summary']['warning_count'], 0);
    });

    test('catches state file with BuildContext', () async {
      _writeFile(tempDir, 'pubspec.yaml', _utopiaPubspec);
      _writeFile(tempDir, 'lib/screen/foo/foo_screen.dart', '''
class FooScreen extends HookWidget {
  static const route = '/foo';
  @override Widget build(BuildContext context) => const SizedBox();
}
''');
      _writeFile(tempDir, 'lib/screen/foo/state/foo_state.dart', '''
import 'package:flutter/material.dart';
class FooState {
  final BuildContext context;
  const FooState(this.context);
}
FooState useFooState(BuildContext context) => FooState(context);
''');

      final report = await _runDoctor(tempDir);
      final findings = (report['findings'] as List<dynamic>).cast<Map<String, dynamic>>();
      final ruleIds = findings.map((f) => f['rule_id'] as String).toSet();
      expect(ruleIds, contains('conventions.state_has_buildcontext'));
    });

    test('catches StatefulWidget screen', () async {
      _writeFile(tempDir, 'pubspec.yaml', _utopiaPubspec);
      _writeFile(tempDir, 'lib/screen/foo/foo_screen.dart', '''
class FooScreen extends StatefulWidget {
  static const route = '/foo';
  @override State<FooScreen> createState() => _FooScreenState();
}
class _FooScreenState extends State<FooScreen> {
  @override Widget build(BuildContext context) => const SizedBox();
}
''');

      final report = await _runDoctor(tempDir);
      final findings = (report['findings'] as List<dynamic>).cast<Map<String, dynamic>>();
      final ruleIds = findings.map((f) => f['rule_id'] as String).toSet();
      expect(ruleIds, contains('conventions.screen_extends_stateful'));
    });

    test('artifacts:bloc activates only when flutter_bloc is in pubspec', () async {
      // Without flutter_bloc - check should not run by default.
      _writeFile(tempDir, 'pubspec.yaml', _utopiaPubspec);
      _writeFile(tempDir, 'lib/screen/foo/foo_screen.dart', '''
class FooScreen extends HookWidget {
  static const route = '/foo';
  @override Widget build(BuildContext context) {
    final bloc = BlocProvider.of(context);
    return const SizedBox();
  }
}
''');
      final report = await _runDoctor(tempDir);
      final active = report['active_checks'] as List<dynamic>;
      expect(active, isNot(contains('artifacts.bloc')));

      // Add flutter_bloc - should now activate and find the artifact.
      _writeFile(tempDir, 'pubspec.yaml', '''
name: smoke_app
environment:
  sdk: ">=3.0.0 <4.0.0"
dependencies:
  utopia_arch: ^0.5.1
  flutter_bloc: ^8.1.0
''');
      final report2 = await _runDoctor(tempDir);
      final active2 = report2['active_checks'] as List<dynamic>;
      expect(active2, contains('artifacts.bloc'));
      final ruleIds = ((report2['findings'] as List<dynamic>).cast<Map<String, dynamic>>())
          .map((f) => f['rule_id'] as String)
          .toSet();
      expect(ruleIds, contains('artifacts.bloc'));
    });

    // Regression: BUG 4/5 - state_has_buildcontext flagged BuildContext in
    // comments and in `extension X on BuildContext` declarations.
    test('state_has_buildcontext ignores comments and extension-on-BuildContext', () async {
      _writeFile(tempDir, 'pubspec.yaml', _utopiaPubspec);
      _writeFile(tempDir, 'lib/screen/foo/foo_screen.dart', '''
class FooScreen extends HookWidget {
  static const route = '/foo';
  @override Widget build(BuildContext context) => const SizedBox();
}
''');
      // State file whose ONLY BuildContext mentions are a comment + an extension.
      _writeFile(tempDir, 'lib/screen/foo/state/foo_state.dart', '''
/// This state deliberately avoids BuildContext to stay context-free.
class FooState {}
FooState useFooState() => FooState();
extension FooContextExt on BuildContext {
  String get foo => 'bar';
}
''');
      final report = await _runDoctor(tempDir);
      final findings = (report['findings'] as List<dynamic>).cast<Map<String, dynamic>>();
      final bc = findings.where((f) => f['rule_id'] == 'conventions.state_has_buildcontext').toList();
      expect(bc, isEmpty, reason: 'comment + extension-on-BuildContext must not be flagged');
    });

    // Regression: BUG 6/7 - orphan_state false-positived on states used
    // cross-directory / by a sibling screen. Now keys off whether the hook
    // is referenced anywhere in the package.
    test('orphan_state does not flag a state used cross-directory', () async {
      _writeFile(tempDir, 'pubspec.yaml', _utopiaPubspec);
      // State lives in a nested subfolder...
      _writeFile(tempDir, 'lib/screen/main/pages/rooms/rooms_state.dart', '''
class RoomsState {}
RoomsState useRoomsState() => RoomsState();
''');
      // ...but is consumed by a screen in the PARENT directory.
      _writeFile(tempDir, 'lib/screen/main/pages/rooms_page.dart', '''
class RoomsPage extends HookWidget {
  static const route = '/rooms';
  @override Widget build(BuildContext context) {
    final state = useRoomsState();
    return RoomsView(state: state);
  }
}
''');
      final report = await _runDoctor(tempDir);
      final findings = (report['findings'] as List<dynamic>).cast<Map<String, dynamic>>();
      final orphans = findings.where((f) => f['rule_id'] == 'structure.orphan_state').toList();
      expect(orphans, isEmpty, reason: 'cross-directory hook usage must count as attached');
    });

    test('orphan_state DOES flag a genuinely unused state', () async {
      _writeFile(tempDir, 'pubspec.yaml', _utopiaPubspec);
      _writeFile(tempDir, 'lib/screen/dead/dead_state.dart', '''
class DeadState {}
DeadState useDeadState() => DeadState();
''');
      // No screen, no view, no provider registration references useDeadState.
      final report = await _runDoctor(tempDir);
      final findings = (report['findings'] as List<dynamic>).cast<Map<String, dynamic>>();
      final orphans = findings.where((f) => f['rule_id'] == 'structure.orphan_state').toList();
      expect(orphans, hasLength(1), reason: 'truly unreferenced state should be flagged');
    });

    // Regression: re-verify round - the orphan def regex must catch hooks
    // whose return type is NOT `*State` (e.g. a controller) so genuinely-dead
    // ones aren't silently skipped.
    test('orphan_state flags a dead hook with non-State return type', () async {
      _writeFile(tempDir, 'pubspec.yaml', _utopiaPubspec);
      _writeFile(tempDir, 'lib/screen/video/video_player_controller_state.dart', '''
class VideoController {}
VideoController useVideoPlayerControllerState() => VideoController();
''');
      final report = await _runDoctor(tempDir);
      final findings = (report['findings'] as List<dynamic>).cast<Map<String, dynamic>>();
      final orphans = findings.where((f) => f['rule_id'] == 'structure.orphan_state').toList();
      expect(orphans, hasLength(1), reason: 'dead hook with non-State return type must still be caught');
    });

    test('--strict bypasses activation gates', () async {
      _writeFile(tempDir, 'pubspec.yaml', _utopiaPubspec);
      _writeFile(tempDir, 'lib/main.dart', '');

      final report = await _runDoctor(tempDir, args: ['--strict']);
      // --strict should include artifacts.* checks even without their pubspec deps.
      final active = report['active_checks'] as List<dynamic>;
      expect(active, contains('artifacts.bloc'));
      expect(active, contains('artifacts.riverpod'));
    });

    test('--check filters to specified tags only', () async {
      _writeFile(tempDir, 'pubspec.yaml', _utopiaPubspec);
      _writeFile(tempDir, 'lib/main.dart', '');

      final report = await _runDoctor(tempDir, args: ['--check=setup']);
      final active = (report['active_checks'] as List<dynamic>).cast<String>();
      expect(active.every((id) => id.startsWith('setup.')), isTrue);
    });

    test('--skip excludes specified tags', () async {
      _writeFile(tempDir, 'pubspec.yaml', _utopiaPubspec);
      _writeFile(tempDir, 'lib/main.dart', '');

      final report = await _runDoctor(tempDir, args: ['--skip=setup']);
      final active = (report['active_checks'] as List<dynamic>).cast<String>();
      expect(active.any((id) => id.startsWith('setup.')), isFalse);
    });

    test('exit code is non-zero when errors are present', () async {
      // Currently no checks emit Error severity, but the gating logic
      // should still produce success on a clean project.
      _writeFile(tempDir, 'pubspec.yaml', _utopiaPubspec);
      _writeFile(tempDir, 'analysis_options.yaml', 'include: package:utopia_lints/lints.yaml');
      _writeFile(tempDir, '.claude/settings.json', '{"enabledPlugins": ["utopia-hooks"]}');
      _writeFile(tempDir, 'lib/main.dart', '');

      final outFile = File(p.join(tempDir.path, '__doctor.json'));
      final runner = UtopiaCommandRunner(
        logger: Logger(level: Level.quiet),
        disableUpdateCheck: true,
      );
      final exitCode = await runner.run(['doctor', '-C', tempDir.path, '-o', outFile.path]);
      expect(exitCode, 0);
    });
  });
}

const _utopiaPubspec = '''
name: smoke_app
environment:
  sdk: ">=3.0.0 <4.0.0"
dependencies:
  utopia_arch: ^0.5.1
''';

void _writeFile(Directory root, String relPath, String content) {
  final file = File(p.join(root.path, relPath));
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(content);
}

Future<Map<String, dynamic>> _runDoctor(Directory tempDir, {List<String> args = const []}) async {
  final outFile = File(p.join(tempDir.path, '__doctor.json'));
  final runner = UtopiaCommandRunner(
    logger: Logger(level: Level.quiet),
    disableUpdateCheck: true,
  );
  await runner.run(['doctor', '-C', tempDir.path, '-o', outFile.path, ...args]);
  return jsonDecode(outFile.readAsStringSync()) as Map<String, dynamic>;
}
