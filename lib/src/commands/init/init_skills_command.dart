import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:mason/mason.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;

import '../../generators/brick_locator.dart';
import '../../strings.dart' as strings;

/// Test seam — `MasonGenerator.fromBrick`.
typedef MasonGeneratorFromBrick = Future<MasonGenerator> Function(Brick);

/// `utopia init skills` — writes a `.claude/` directory into the current
/// project that pre-registers the Utopia-USS/utopia-flutter-skills
/// marketplace and enables the `utopia-hooks` plugin.
///
/// Intended for projects created with `utopia create flutter_app --no-skills`,
/// or for any existing Flutter project that wants to opt in.
class InitSkillsCommand extends Command<int> {
  InitSkillsCommand({
    required Logger logger,
    BrickLocator? brickLocator,
    MasonGeneratorFromBrick? generatorFromBrick,
  })  : _logger = logger,
        _brickLocator = brickLocator ?? const BrickLocator(),
        _generatorFromBrick = generatorFromBrick ?? MasonGenerator.fromBrick {
    argParser
      ..addOption(
        'output-directory',
        abbr: 'd',
        help: 'Project root to write `.claude/` into.',
        defaultsTo: '.',
      )
      ..addFlag(
        'force',
        abbr: 'f',
        negatable: false,
        help: 'Overwrite an existing `.claude/settings.json`.',
      );
  }

  final Logger _logger;
  final BrickLocator _brickLocator;
  final MasonGeneratorFromBrick _generatorFromBrick;

  @visibleForTesting
  ArgResults? argResultsOverride;

  @override
  ArgResults get argResults => argResultsOverride ?? super.argResults!;

  @override
  String get name => 'skills';

  @override
  String get description => 'Register the Utopia Claude Code skills marketplace in this project.';

  @override
  String get invocation => 'utopia init skills [options]';

  String get outputDirectory => argResults['output-directory'] as String? ?? '.';
  bool get force => argResults['force'] as bool? ?? false;

  @override
  Future<int> run() async {
    final target = Directory(outputDirectory);
    final settings = File(p.join(target.path, '.claude', 'settings.json'));

    if (settings.existsSync() && !force) {
      _logger
        ..err('${settings.path} already exists.')
        ..info('Re-run with --force to overwrite, or delete the file manually.');
      return ExitCode.cantCreate.code;
    }

    final brickPath = _brickLocator.locate('skills');
    final generator = await _generatorFromBrick(Brick.path(brickPath));

    final progress = _logger.progress('Registering Utopia skills marketplace');
    final files = await generator.generate(
      DirectoryGeneratorTarget(target),
      vars: const {},
      fileConflictResolution: force ? FileConflictResolution.overwrite : FileConflictResolution.prompt,
      logger: _logger,
    );
    progress.complete('Wrote ${files.length} file(s) into ${target.path}/.claude/');

    _logger
      ..info('')
      ..info('Next:')
      ..info('  • npm install -g @anthropic-ai/claude-code   # if you haven\'t')
      ..info('  • claude                                       # from this directory')
      ..info('  • /utopia-hooks                                # try the skill')
      ..info('')
      ..info('Marketplace: ${strings.skillsMarketplaceUrl}');

    return ExitCode.success.code;
  }
}
