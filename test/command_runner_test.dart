import 'package:mason_logger/mason_logger.dart';
import 'package:test/test.dart';
import 'package:utopia_cli/src/command_runner.dart';
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

    test('exposes create, update, add, migrate subcommands', () {
      final runner = UtopiaCommandRunner();
      expect(runner.commands.keys, containsAll(['create', 'update', 'add', 'migrate']));
    });
  });
}
