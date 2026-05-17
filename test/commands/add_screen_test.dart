import 'package:mason_logger/mason_logger.dart';
import 'package:test/test.dart';
import 'package:utopia_cli/src/command_runner.dart';

void main() {
  group('AddScreenCommand', () {
    late UtopiaCommandRunner runner;

    setUp(() {
      runner = UtopiaCommandRunner(logger: Logger(level: Level.quiet))..checkForUpdates = false;
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
  });
}
