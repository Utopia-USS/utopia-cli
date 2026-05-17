import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:pub_updater/pub_updater.dart';

import '../version.dart';

const _packageName = 'utopia_cli';

/// `utopia update` — self-update via pub.dev.
class UpdateCommand extends Command<int> {
  UpdateCommand({
    required Logger logger,
    PubUpdater? pubUpdater,
  })  : _logger = logger,
        _pubUpdater = pubUpdater ?? PubUpdater();

  /// Used by [UtopiaCommandRunner] to suppress the post-run update check
  /// when the user explicitly invoked this command.
  static const commandName = 'update';

  final Logger _logger;
  final PubUpdater _pubUpdater;

  @override
  String get name => commandName;

  @override
  String get description => 'Update the Utopia CLI to the latest version on pub.dev.';

  @override
  Future<int> run() async {
    final progress = _logger.progress('Checking for updates');
    late final String latest;
    try {
      latest = await _pubUpdater.getLatestVersion(_packageName);
    } on Object catch (e) {
      progress.fail('Failed to check pub.dev: $e');
      return ExitCode.unavailable.code;
    }

    if (latest == packageVersion) {
      progress.complete('Already up to date (v$packageVersion).');
      return ExitCode.success.code;
    }

    progress.update('Updating to v$latest');
    try {
      await _pubUpdater.update(packageName: _packageName, versionConstraint: latest);
      progress.complete('Updated to v$latest');
      return ExitCode.success.code;
    } on Object catch (e) {
      progress.fail('Update failed: $e');
      return ExitCode.software.code;
    }
  }
}
