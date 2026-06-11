import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:test/test.dart';
import 'package:utopia_cli/src/agent_instructions.dart';
import 'package:utopia_cli/src/command_runner.dart';

void main() {
  group('InitAgentsCommand', () {
    late Directory tempDir;
    late UtopiaCommandRunner runner;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('utopia_init_agents_test_');
      runner = UtopiaCommandRunner(
        logger: Logger(level: Level.quiet),
        disableUpdateCheck: true,
      );
    });

    tearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    test('writes provider-neutral AGENTS.md', () async {
      final exitCode = await runner.run(['init', 'agents', '-d', tempDir.path]);
      expect(exitCode, ExitCode.success.code);

      final instructions = File('${tempDir.path}/$agentInstructionsFileName');
      expect(instructions.existsSync(), isTrue);
      expect(Directory('${tempDir.path}/.claude').existsSync(), isFalse);

      final body = instructions.readAsStringSync();
      expect(body, contains('utopia describe -o -'));
      expect(body, contains('utopia add screen profile --json'));
      expect(body, contains('utopia doctor --fail-on=warning --human -o -'));
      expect(body, contains('utopia init skills'));
      expect(body, contains('Codex and shell/CI agents'));
    });

    test('refuses to overwrite AGENTS.md without --force', () async {
      File('${tempDir.path}/$agentInstructionsFileName').writeAsStringSync('custom instructions');

      final exitCode = await runner.run(['init', 'agents', '-d', tempDir.path]);
      expect(exitCode, ExitCode.cantCreate.code);

      expect(
        File('${tempDir.path}/$agentInstructionsFileName').readAsStringSync(),
        'custom instructions',
      );
    });

    test('overwrites AGENTS.md with --force', () async {
      final instructions = File('${tempDir.path}/$agentInstructionsFileName')..writeAsStringSync('custom instructions');

      final exitCode = await runner.run(['init', 'agents', '-d', tempDir.path, '--force']);
      expect(exitCode, ExitCode.success.code);

      expect(instructions.readAsStringSync(), agentInstructionsMarkdown);
    });
  });
}
