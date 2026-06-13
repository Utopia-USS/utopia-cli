import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:utopia_cli/src/command_runner.dart';

void main() {
  group('AddScreenCommand', () {
    late UtopiaCommandRunner runner;
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('utopia_add_screen_test_');
      runner = UtopiaCommandRunner(logger: Logger(level: Level.quiet))..checkForUpdates = false;
    });

    tearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    test('rejects invalid screen name (kebab-case)', () async {
      final exitCode = await runner.run(['add', 'screen', 'my-screen']);
      expect(exitCode, ExitCode.usage.code);
    });

    test('rejects missing screen name', () async {
      final exitCode = await runner.run(['add', 'screen']);
      expect(exitCode, ExitCode.usage.code);
    });

    test('rejects duplicate screen names', () async {
      final exitCode = await runner.run(['add', 'screen', 'auth', 'login']);
      expect(exitCode, ExitCode.usage.code);
    });

    test('fails outside a Flutter project', () async {
      final exitCode = await runner.run([
        'add',
        'screen',
        'profile',
        '-d',
        p.join(tempDir.path, 'lib', 'screen'),
      ]);

      expect(exitCode, ExitCode.noInput.code);
    });

    test('--json generates screen files in a Flutter project', () async {
      _writeFile(tempDir, 'pubspec.yaml', '''
name: smoke_app
environment:
  sdk: ">=3.0.0 <4.0.0"
dependencies:
  flutter:
    sdk: flutter
  utopia_arch: ^0.5.1
''');

      final exitCode = await runner.run([
        'add',
        'screen',
        'profile',
        '-d',
        p.join(tempDir.path, 'lib', 'screen'),
        '--json',
      ]);

      expect(exitCode, ExitCode.success.code);
      expect(File(p.join(tempDir.path, 'lib', 'screen', 'profile', 'profile_screen.dart')).existsSync(), isTrue);
      expect(File(p.join(tempDir.path, 'lib', 'screen', 'profile', 'view', 'profile_view.dart')).existsSync(), isTrue);
      expect(
          File(p.join(tempDir.path, 'lib', 'screen', 'profile', 'state', 'profile_state.dart')).existsSync(), isTrue);
    });
  });
}

void _writeFile(Directory root, String relPath, String content) {
  final file = File(p.join(root.path, relPath));
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(content);
}
