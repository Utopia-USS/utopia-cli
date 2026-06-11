import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:pub_updater/pub_updater.dart';

import 'commands/add/add_command.dart';
import 'commands/bump_command.dart';
import 'commands/create/create_command.dart';
import 'commands/describe/describe_command.dart';
import 'commands/doctor/doctor_command.dart';
import 'commands/hooks/hooks_command.dart';
import 'commands/init/init_command.dart';
import 'commands/mcp/mcp_command.dart';
import 'commands/update_command.dart';
import 'strings.dart' as strings;
import 'version.dart';

/// Pub.dev package name. Used by `utopia update`.
const packageName = 'utopia_cli';

/// Root command runner for the `utopia` executable.
class UtopiaCommandRunner extends CommandRunner<int> {
  UtopiaCommandRunner({
    Logger? logger,
    PubUpdater? pubUpdater,
    bool disableUpdateCheck = false,
  })  : _logger = logger ?? Logger(),
        _pubUpdater = pubUpdater ?? PubUpdater(),
        checkForUpdates = !disableUpdateCheck,
        super('utopia', '🦄 Utopia CLI — scaffold Flutter apps the Utopia way.') {
    argParser
      ..addFlag(
        'version',
        abbr: 'v',
        negatable: false,
        help: 'Print the current version.',
      )
      ..addFlag(
        'verbose',
        negatable: false,
        help: 'Noisy logging, including all shell commands executed.',
      );

    addCommand(CreateCommand(logger: _logger));
    addCommand(AddCommand(logger: _logger));
    addCommand(InitCommand(logger: _logger));
    addCommand(DescribeCommand(logger: _logger));
    addCommand(DoctorCommand(logger: _logger));
    addCommand(HooksCommand(logger: _logger));
    addCommand(McpCommand());
    addCommand(BumpCommand(logger: _logger, pubUpdater: _pubUpdater));
    addCommand(UpdateCommand(logger: _logger, pubUpdater: _pubUpdater));
  }

  final Logger _logger;
  final PubUpdater _pubUpdater;

  /// Whether to check pub.dev for a newer release after each command.
  /// Disabled by tests that don't want post-run network calls.
  bool checkForUpdates;

  @override
  Future<int> run(Iterable<String> args) async {
    try {
      final results = parse(args);
      if (results['verbose'] == true) _logger.level = Level.verbose;
      return await runCommand(results) ?? ExitCode.success.code;
    } on FormatException catch (e) {
      _logger
        ..err(e.message)
        ..info('')
        ..info(usage);
      return ExitCode.usage.code;
    } on UsageException catch (e) {
      _logger
        ..err(e.message)
        ..info('')
        ..info(e.usage);
      return ExitCode.usage.code;
    } on Object catch (e, stackTrace) {
      _logger.err('Unexpected error: $e');
      _logger.detail(stackTrace.toString());
      return ExitCode.software.code;
    }
  }

  @override
  Future<int?> runCommand(ArgResults topLevelResults) async {
    if (topLevelResults['version'] == true) {
      _logger.info('utopia_cli v$packageVersion');
      return ExitCode.success.code;
    }

    final exitCode = await super.runCommand(topLevelResults);

    if (checkForUpdates &&
        (exitCode ?? ExitCode.success.code) == ExitCode.success.code &&
        _allowsUpdateCheck(topLevelResults)) {
      await _checkForUpdates();
    }

    return exitCode;
  }

  Future<void> _checkForUpdates() async {
    try {
      final latest = await _pubUpdater.getLatestVersion(packageName).timeout(const Duration(seconds: 2));
      if (_isNewerVersion(latest, packageVersion)) {
        _logger
          ..info('')
          ..info(strings.updateAvailable(latest));
      }
    } on Object catch (_) {
      // Best-effort. Never break a command because the update check failed.
    }
  }
}

bool _allowsUpdateCheck(ArgResults topLevelResults) {
  final command = topLevelResults.command;
  if (command == null) return true;
  if (command.name == UpdateCommand.commandName) return false;
  if (const {'describe', 'doctor', 'mcp', 'hooks'}.contains(command.name)) {
    return false;
  }
  if (command.name == 'add' && command.command?.name == 'screen' && command.command?['json'] == true) {
    return false;
  }
  return true;
}

bool _isNewerVersion(String latest, String current) {
  final latestParts = _versionCore(latest);
  final currentParts = _versionCore(current);
  for (var i = 0; i < 3; i++) {
    final diff = latestParts[i].compareTo(currentParts[i]);
    if (diff != 0) return diff > 0;
  }
  if (!current.contains('-') && latest.contains('-')) return false;
  if (current.contains('-') && !latest.contains('-')) return true;
  return latest != current;
}

List<int> _versionCore(String version) {
  final core = version.split('-').first;
  final parts = core.split('.').map((part) => int.tryParse(part) ?? 0).toList();
  while (parts.length < 3) {
    parts.add(0);
  }
  return parts.take(3).toList();
}

/// Flushes stdio then exits with [status]. Used by `bin/utopia.dart`.
Future<void> flushThenExit(int status) {
  return Future.wait<void>([
    stdout.close(),
    stderr.close(),
  ]).then<void>((_) => exit(status));
}
