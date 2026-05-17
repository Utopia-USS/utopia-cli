import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:test/test.dart';
import 'package:utopia_cli/src/command_runner.dart';

void main() {
  group('InitSkillsCommand', () {
    late Directory tempDir;
    late UtopiaCommandRunner runner;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('utopia_init_skills_test_');
      runner = UtopiaCommandRunner(
        logger: Logger(level: Level.quiet),
        disableUpdateCheck: true,
      );
    });

    tearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    test('writes .claude/settings.json + README.md', () async {
      final exitCode = await runner.run(['init', 'skills', '-d', tempDir.path]);
      expect(exitCode, ExitCode.success.code);

      final settings = File('${tempDir.path}/.claude/settings.json');
      final readme = File('${tempDir.path}/.claude/README.md');
      expect(settings.existsSync(), isTrue);
      expect(readme.existsSync(), isTrue);

      final body = settings.readAsStringSync();
      expect(body, contains('Utopia-USS/utopia-flutter-skills'));
      expect(body, contains('utopia-hooks'));
    });

    test('refuses to overwrite existing settings.json without --force', () async {
      // First run — succeeds.
      var exitCode = await runner.run(['init', 'skills', '-d', tempDir.path]);
      expect(exitCode, ExitCode.success.code);

      // Second run without --force — refuses.
      exitCode = await runner.run(['init', 'skills', '-d', tempDir.path]);
      expect(exitCode, ExitCode.cantCreate.code);
    });

    test('overwrites existing settings.json with --force', () async {
      // Seed an existing settings.json with garbage content.
      final claudeDir = Directory('${tempDir.path}/.claude')..createSync();
      final settings = File('${claudeDir.path}/settings.json')..writeAsStringSync('{"garbage": true}');

      final exitCode = await runner.run(['init', 'skills', '-d', tempDir.path, '--force']);
      expect(exitCode, ExitCode.success.code);
      expect(settings.readAsStringSync(), contains('utopia-flutter-skills'));
    });
  });
}
