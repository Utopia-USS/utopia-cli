import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:pub_updater/pub_updater.dart';

import 'commands/add/add_command.dart';
import 'commands/create/create_command.dart';
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
    addCommand(UpdateCommand(logger: _logger, pubUpdater: _pubUpdater));
    addCommand(McpCommand());
  }

  final Logger _logger;
  final PubUpdater _pubUpdater;

  /// Whether to check pub.dev for a newer release after each command.
  /// Disabled by tests and by embedders (e.g. the MCP server) that don't
  /// want post-run network calls.
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
    }
  }

  @override
  Future<int?> runCommand(ArgResults topLevelResults) async {
    if (topLevelResults['version'] == true) {
      _logger.info('utopia_cli v$packageVersion');
      return ExitCode.success.code;
    }

    final exitCode = await super.runCommand(topLevelResults);

    if (checkForUpdates && topLevelResults.command?.name != UpdateCommand.commandName) {
      await _checkForUpdates();
    }

    return exitCode;
  }

  Future<void> _checkForUpdates() async {
    try {
      final latest = await _pubUpdater.getLatestVersion(packageName).timeout(const Duration(seconds: 2));
      if (latest != packageVersion) {
        _logger
          ..info('')
          ..info(strings.updateAvailable(latest));
      }
    } on Object catch (_) {
      // Best-effort. Never break a command because the update check failed.
    }
  }
}

/// Flushes stdio then exits with [status]. Used by `bin/utopia.dart`.
Future<void> flushThenExit(int status) {
  return Future.wait<void>([
    stdout.close(),
    stderr.close(),
  ]).then<void>((_) => exit(status));
}
