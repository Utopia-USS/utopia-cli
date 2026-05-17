import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:process/process.dart';
import 'package:pub_updater/pub_updater.dart';
import 'package:test/test.dart';
import 'package:utopia_cli/src/commands/update_command.dart';
import 'package:utopia_cli/src/version.dart';

class _FakePubUpdater implements PubUpdater {
  _FakePubUpdater({required this.latest});

  final String latest;
  bool updateCalled = false;

  @override
  Future<String> getLatestVersion(String packageName) async => latest;

  @override
  Future<bool> isUpToDate({
    required String packageName,
    required String currentVersion,
  }) async =>
      currentVersion == latest;

  @override
  Future<ProcessResult> update({
    required String packageName,
    String? versionConstraint,
    ProcessManager processManager = const LocalProcessManager(),
  }) async {
    updateCalled = true;
    return ProcessResult(0, 0, '', '');
  }
}

void main() {
  group('UpdateCommand', () {
    test('exits success when already up to date', () async {
      final updater = _FakePubUpdater(latest: packageVersion);
      final runner = CommandRunner<int>('utopia', 'test')
        ..addCommand(UpdateCommand(
          logger: Logger(level: Level.quiet),
          pubUpdater: updater,
        ));
      final exitCode = await runner.run(['update']);
      expect(exitCode, ExitCode.success.code);
      expect(updater.updateCalled, isFalse);
    });

    test('calls pub_updater.update when a newer version is available', () async {
      final updater = _FakePubUpdater(latest: '99.0.0');
      final runner = CommandRunner<int>('utopia', 'test')
        ..addCommand(UpdateCommand(
          logger: Logger(level: Level.quiet),
          pubUpdater: updater,
        ));
      final exitCode = await runner.run(['update']);
      expect(exitCode, ExitCode.success.code);
      expect(updater.updateCalled, isTrue);
    });
  });
}
