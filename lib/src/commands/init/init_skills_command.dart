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
/// project that pre-registers the Utopia-USS/utopia-skills
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
      vars: const {
        'claude_settings_schema_url': strings.claudeSettingsSchemaUrl,
        'skills_marketplace_name': strings.utopiaSkillsMarketplaceName,
        'skills_repo_slug': strings.utopiaSkillsMarketplaceSlug,
        'utopia_hooks_plugin_key': strings.utopiaHooksPluginKey,
      },
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

    _checkProjectSetup(target);
    return ExitCode.success.code;
  }

  /// Check for missing utopia stack deps + lint extension. Emit hints
  /// only - do NOT mutate the user's pubspec (YAML mutation is fragile;
  /// the user knows their project better).
  void _checkProjectSetup(Directory target) {
    final pubspec = File(p.join(target.path, 'pubspec.yaml'));
    final analysisOptions = File(p.join(target.path, 'analysis_options.yaml'));

    final issues = <String>[];

    if (pubspec.existsSync()) {
      final content = pubspec.readAsStringSync();
      if (!content.contains('utopia_arch')) {
        issues.add('  • pubspec.yaml does not declare `utopia_arch` - add to dependencies');
      }
    }

    if (analysisOptions.existsSync()) {
      if (!analysisOptions.readAsStringSync().contains('utopia_lints')) {
        issues.add('  • analysis_options.yaml does not extend `utopia_lints` - '
            'add `include: package:utopia_lints/lints.yaml` at the top');
      }
    } else if (pubspec.existsSync()) {
      issues.add('  • No analysis_options.yaml - create one with '
          '`include: package:utopia_lints/lints.yaml`');
    }

    if (issues.isEmpty) return;

    _logger
      ..info('')
      ..info('To complete utopia setup in this project:');
    for (final issue in issues) {
      _logger.info(issue);
    }
    _logger.info('Run `utopia doctor` for full setup audit.');
  }
}
