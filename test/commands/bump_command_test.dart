import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;
import 'package:process/process.dart';
import 'package:pub_updater/pub_updater.dart';
import 'package:test/test.dart';
import 'package:utopia_cli/src/commands/bump_command.dart';

void main() {
  group('BumpCommand', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('utopia_bump_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    test('bumps stable and pre-release utopia dependency constraints', () async {
      _writePubspec(tempDir, '''
name: smoke_app
dependencies:
  utopia_arch: ^0.2.0-dev.6
  utopia_hooks: 0.1.0+2
  flutter:
    sdk: flutter
dev_dependencies:
  utopia_lints: ^0.0.1
''');

      final runner = _runner(_FakePubUpdater({
        'utopia_arch': '0.2.0-dev.7',
        'utopia_hooks': '0.1.1',
        'utopia_lints': '0.0.2',
      }));

      final exitCode = await runner.run(['bump', '-C', tempDir.path]);

      expect(exitCode, ExitCode.success.code);
      final updated = File(p.join(tempDir.path, 'pubspec.yaml')).readAsStringSync();
      expect(updated, contains('  utopia_arch: ^0.2.0-dev.7'));
      expect(updated, contains('  utopia_hooks: ^0.1.1'));
      expect(updated, contains('  utopia_lints: ^0.0.2'));
      expect(updated, contains('  flutter:\n    sdk: flutter'));
    });

    test('--dry-run leaves pubspec unchanged', () async {
      const original = '''
name: smoke_app
dependencies:
  utopia_arch: ^0.2.0-dev.6
''';
      _writePubspec(tempDir, original);

      final runner = _runner(_FakePubUpdater({'utopia_arch': '0.2.0-dev.7'}));

      final exitCode = await runner.run(['bump', '-C', tempDir.path, '--dry-run']);

      expect(exitCode, ExitCode.success.code);
      expect(File(p.join(tempDir.path, 'pubspec.yaml')).readAsStringSync(), original);
    });
  });
}

CommandRunner<int> _runner(PubUpdater pubUpdater) {
  return CommandRunner<int>('utopia', 'test')
    ..addCommand(BumpCommand(
      logger: Logger(level: Level.quiet),
      pubUpdater: pubUpdater,
    ));
}

void _writePubspec(Directory root, String content) {
  File(p.join(root.path, 'pubspec.yaml')).writeAsStringSync(content);
}

class _FakePubUpdater implements PubUpdater {
  _FakePubUpdater(this.latestVersions);

  final Map<String, String> latestVersions;

  @override
  Future<String> getLatestVersion(String packageName) async {
    final latest = latestVersions[packageName];
    if (latest == null) throw StateError('No fake version for $packageName');
    return latest;
  }

  @override
  Future<bool> isUpToDate({
    required String packageName,
    required String currentVersion,
  }) async =>
      latestVersions[packageName] == currentVersion;

  @override
  Future<ProcessResult> update({
    required String packageName,
    String? versionConstraint,
    ProcessManager processManager = const LocalProcessManager(),
  }) async {
    throw UnsupportedError('Not used by bump tests');
  }
}
