import 'package:mason_logger/mason_logger.dart';
import 'package:test/test.dart';
import 'package:utopia_cli/src/command_runner.dart';

void main() {
  group('CreateFlutterAppCommand', () {
    late UtopiaCommandRunner runner;

    setUp(() {
      runner = UtopiaCommandRunner(logger: Logger(level: Level.quiet))
        ..checkForUpdates = false;
    });

    test('rejects invalid project name (kebab-case)', () async {
      final exitCode = await runner.run(['create', 'flutter_app', 'my-app']);
      expect(exitCode, ExitCode.usage.code);
    });

    test('rejects invalid org name (single segment)', () async {
      final exitCode = await runner.run([
        'create',
        'flutter_app',
        'my_app',
        '--org=utopiasoft',
        '--no-pub-get',
        '--no-git',
      ]);
      expect(exitCode, ExitCode.usage.code);
    });

    test('rejects missing project name', () async {
      final exitCode = await runner.run(['create', 'flutter_app']);
      expect(exitCode, ExitCode.usage.code);
    });
  });
}
