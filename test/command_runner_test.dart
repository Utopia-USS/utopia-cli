import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:test/test.dart';
import 'package:utopia_cli/src/command_runner.dart';
import 'package:utopia_cli/src/commands/create/create_subcommand.dart';
import 'package:utopia_cli/src/version.dart';

class _RecordingLogger extends Logger {
  _RecordingLogger() : super(level: Level.quiet);

  final lines = <String>[];

  @override
  void info(String? message, {LogStyle? style}) {
    if (message != null) lines.add(message);
  }
}

void main() {
  group('UtopiaCommandRunner', () {
    test('--version prints package version', () async {
      final logger = _RecordingLogger();
      final runner = UtopiaCommandRunner(logger: logger)..checkForUpdates = false;
      final exitCode = await runner.run(['--version']);
      expect(exitCode, ExitCode.success.code);
      expect(logger.lines.any((l) => l.contains(packageVersion)), isTrue);
    });

    test('unknown command exits with usage code', () async {
      final logger = _RecordingLogger();
      final runner = UtopiaCommandRunner(logger: logger)..checkForUpdates = false;
      final exitCode = await runner.run(['no_such_command']);
      expect(exitCode, ExitCode.usage.code);
    });

    test('exposes create, add, init, describe, doctor, mcp, bump, update subcommands', () {
      final runner = UtopiaCommandRunner();
      expect(
        runner.commands.keys,
        containsAll(['create', 'add', 'init', 'describe', 'doctor', 'mcp', 'bump', 'update']),
      );
    });

    test('does not expose dropped migrate / add-state commands', () {
      final runner = UtopiaCommandRunner();
      expect(runner.commands.keys, isNot(contains('migrate')));
      final add = runner.commands['add']!;
      expect(add.subcommands.keys, isNot(contains('state')));
    });

    test('unexpected exceptions return software exit code', () async {
      final runner = UtopiaCommandRunner(logger: Logger(level: Level.quiet))
        ..checkForUpdates = false
        ..addCommand(_ThrowingCommand());

      final exitCode = await runner.run(['throw']);
      expect(exitCode, ExitCode.software.code);
    });

    test('required shell failures throw controlled exceptions', () async {
      final command = _ShellTestCommand(
        shellRunner: (_, __, {required workingDirectory}) async => ProcessResult(123, 70, '', 'boom'),
      );

      expect(
        () => command.runRequiredShell(Directory.current),
        throwsA(isA<ShellCommandException>()
            .having((e) => e.exitCode, 'exitCode', 70)
            .having((e) => e.stderr, 'stderr', contains('boom'))),
      );
    });
  });
}

class _ThrowingCommand extends Command<int> {
  @override
  String get name => 'throw';

  @override
  String get description => 'Throws for runner testing.';

  @override
  Future<int> run() async => throw StateError('boom');
}

class _ShellTestCommand extends CreateSubCommand {
  _ShellTestCommand({required super.shellRunner}) : super(logger: Logger(level: Level.quiet));

  @override
  String get name => 'shell_test';

  @override
  String get description => 'Shell test command.';

  @override
  String get defaultDescription => 'test';

  @override
  String get brickName => 'screen';

  @override
  Map<String, dynamic> buildVars({
    required String projectName,
    required String description,
  }) =>
      const {};

  Future<void> runRequiredShell(Directory workingDir) {
    return runShell(
      'flutter',
      ['pub', 'get'],
      workingDir: workingDir,
      successMessage: 'Installed dependencies',
      failurePrefix: 'flutter pub get failed',
    );
  }
}
