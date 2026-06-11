import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;

import '../../agent_instructions.dart';

/// `utopia init agents` — writes provider-neutral agent instructions.
class InitAgentsCommand extends Command<int> {
  InitAgentsCommand({required Logger logger}) : _logger = logger {
    argParser
      ..addOption(
        'output-directory',
        abbr: 'd',
        help: 'Project root to write AGENTS.md into.',
        defaultsTo: '.',
      )
      ..addFlag(
        'force',
        abbr: 'f',
        negatable: false,
        help: 'Overwrite an existing AGENTS.md.',
      );
  }

  final Logger _logger;

  @visibleForTesting
  ArgResults? argResultsOverride;

  @override
  ArgResults get argResults => argResultsOverride ?? super.argResults!;

  @override
  String get name => 'agents';

  @override
  String get description => 'Write provider-neutral instructions for Codex, shell, and CI agents.';

  @override
  String get invocation => 'utopia init agents [options]';

  String get outputDirectory => argResults['output-directory'] as String? ?? '.';
  bool get force => argResults['force'] as bool? ?? false;

  @override
  Future<int> run() async {
    final target = Directory(outputDirectory);
    final instructions = File(p.join(target.path, agentInstructionsFileName));

    if (instructions.existsSync() && !force) {
      _logger
        ..err('${instructions.path} already exists.')
        ..info('Re-run with --force to overwrite, or delete the file manually.');
      return ExitCode.cantCreate.code;
    }

    if (!target.existsSync()) {
      target.createSync(recursive: true);
    }
    instructions.writeAsStringSync(agentInstructionsMarkdown);

    _logger
      ..success('Wrote ${instructions.path}')
      ..info('')
      ..info('Next:')
      ..info('  • utopia describe -o -')
      ..info('  • utopia doctor --fail-on=warning --human -o -')
      ..info('')
      ..info('Claude Code skills are separate: run `utopia init skills`.');

    return ExitCode.success.code;
  }
}
