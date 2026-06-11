import 'dart:convert';
import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:utopia_cli/src/command_runner.dart';

void main() {
  group('utopia hooks analyze', () {
    late Directory tempDir;
    late UtopiaCommandRunner runner;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('utopia_hooks_analyze_test_');
      runner = UtopiaCommandRunner(
        logger: Logger(level: Level.quiet),
        disableUpdateCheck: true,
      );
    });

    tearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    test('reports clean for a valid Screen/State/View triad', () async {
      _writeFile(tempDir, 'pubspec.yaml', _utopiaPubspec);
      _writeFile(tempDir, 'lib/screen/foo/foo_screen.dart', '''
class FooScreen extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final state = useFooState();
    return FooView(state: state);
  }
}
''');
      _writeFile(tempDir, 'lib/screen/foo/state/foo_state.dart', '''
class FooState {
  const FooState({required this.count});
  final int count;
}

FooState useFooState() => const FooState(count: 0);
''');
      _writeFile(tempDir, 'lib/screen/foo/view/foo_view.dart', '''
class FooView extends StatelessWidget {
  const FooView({required this.state});
  final FooState state;
}
''');

      final report = File(p.join(tempDir.path, 'hooks.json'));
      final exitCode = await runner.run([
        'hooks',
        'analyze',
        '-C',
        tempDir.path,
        '--all',
        '--format=json',
        '-o',
        report.path,
      ]);

      expect(exitCode, ExitCode.success.code);
      final json = _readJson(report);
      expect(json['analyzed_files'], hasLength(3));
      expect(json['findings'], isEmpty);
    });

    test('catches state-file quality violations', () async {
      _writeFile(tempDir, 'pubspec.yaml', _utopiaPubspec);
      _writeFile(tempDir, 'lib/screen/foo/state/foo_state.dart', '''
import 'package:flutter/material.dart';

class FooState extends Equatable {
  final BuildContext context;
  const FooState(this.context);

  FooState copyWith() => this;
}
''');

      final report = File(p.join(tempDir.path, 'hooks.json'));
      final exitCode = await runner.run([
        'hooks',
        'analyze',
        '-C',
        tempDir.path,
        '--file',
        'lib/screen/foo/state/foo_state.dart',
        '--format=json',
        '-o',
        report.path,
      ]);

      expect(exitCode, 1);
      final findings = (_readJson(report)['findings'] as List<dynamic>).cast<Map<String, dynamic>>();
      final ruleIds = findings.map((f) => f['rule_id'] as String).toSet();
      expect(ruleIds, contains('hooks.extends_equatable'));
      expect(ruleIds, contains('hooks.state_references_ui_api'));
      expect(ruleIds, contains('hooks.state_uses_copy_with'));
    });

    test('catches screen and view violations', () async {
      _writeFile(tempDir, 'pubspec.yaml', _utopiaPubspec);
      _writeFile(tempDir, 'lib/screen/foo/foo_screen.dart', '''
class FooScreen extends StatefulWidget {
  @override
  State<FooScreen> createState() => _FooScreenState();
}

class _FooScreenState extends State<FooScreen> {
  @override
  Widget build(BuildContext context) {
    final service = useInjected<FooService>();
    return FooView(service: service);
  }
}
''');
      _writeFile(tempDir, 'lib/screen/foo/view/foo_view.dart', '''
class FooView extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final value = useState(0);
    return Text('\${value.value}');
  }
}
''');

      final report = File(p.join(tempDir.path, 'hooks.json'));
      final exitCode = await runner.run([
        'hooks',
        'analyze',
        '-C',
        tempDir.path,
        '--all',
        '--format=json',
        '-o',
        report.path,
      ]);

      expect(exitCode, 1);
      final findings = (_readJson(report)['findings'] as List<dynamic>).cast<Map<String, dynamic>>();
      final ruleIds = findings.map((f) => f['rule_id'] as String).toSet();
      expect(ruleIds, contains('hooks.screen_extends_stateful_widget'));
      expect(ruleIds, contains('hooks.screen_calls_forbidden_hook'));
      expect(ruleIds, contains('hooks.view_extends_hook_widget'));
      expect(ruleIds, contains('hooks.view_calls_hook'));
    });

    test('accepts multiple positional paths for batch analysis', () async {
      _writeFile(tempDir, 'pubspec.yaml', _utopiaPubspec);
      _writeFile(tempDir, 'lib/screen/foo/state/foo_state.dart', '''
class FooState {
  FooState copyWith() => this;
}
''');
      _writeFile(tempDir, 'lib/screen/bar/view/bar_view.dart', '''
class BarView extends HookWidget {
  @override
  Widget build(BuildContext context) => Text('\${useState(0).value}');
}
''');

      final report = File(p.join(tempDir.path, 'hooks.json'));
      final exitCode = await runner.run([
        'hooks',
        'analyze',
        '-C',
        tempDir.path,
        'lib/screen/foo/state/foo_state.dart',
        'lib/screen/bar/view/bar_view.dart',
        '--format=json',
        '-o',
        report.path,
      ]);

      expect(exitCode, 1);
      final json = _readJson(report);
      expect(json['analyzed_files'], contains('lib/screen/foo/state/foo_state.dart'));
      expect(json['analyzed_files'], contains('lib/screen/bar/view/bar_view.dart'));
      final findings = (json['findings'] as List<dynamic>).cast<Map<String, dynamic>>();
      final ruleIds = findings.map((f) => f['rule_id'] as String).toSet();
      expect(ruleIds, contains('hooks.state_uses_copy_with'));
      expect(ruleIds, contains('hooks.view_extends_hook_widget'));
      expect(ruleIds, contains('hooks.view_calls_hook'));
    });

    test('defaults to analyzing changed git files', () async {
      final init = await Process.run('git', const ['init'], workingDirectory: tempDir.path);
      expect(init.exitCode, ExitCode.success.code);

      _writeFile(tempDir, 'pubspec.yaml', _utopiaPubspec);
      _writeFile(tempDir, 'lib/screen/foo/state/foo_state.dart', '''
class FooState {
  FooState copyWith() => this;
}
''');

      final report = File(p.join(tempDir.path, 'hooks.json'));
      final exitCode = await runner.run([
        'hooks',
        'analyze',
        '-C',
        tempDir.path,
        '--format=json',
        '-o',
        report.path,
      ]);

      expect(exitCode, 1);
      final json = _readJson(report);
      expect(json['analyzed_files'], contains('lib/screen/foo/state/foo_state.dart'));
      final findings = (json['findings'] as List<dynamic>).cast<Map<String, dynamic>>();
      expect(findings.map((f) => f['rule_id']), contains('hooks.state_uses_copy_with'));
    });
  });
}

Map<String, dynamic> _readJson(File file) => jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;

void _writeFile(Directory root, String relativePath, String content) {
  final file = File(p.join(root.path, relativePath));
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(content);
}

const _utopiaPubspec = '''
name: smoke_app
environment:
  sdk: ">=3.0.0 <4.0.0"
dependencies:
  utopia_arch: ^0.5.1
''';
