import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:mason/mason.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;

import '../../generators/brick_locator.dart';
import '../../strings.dart' as strings;

final _packageNameRegExp = RegExp(r'^[a-z_][a-z0-9_]*$');
final _orgNameRegExp = RegExp(r'^[a-zA-Z][\w-]*(\.[a-zA-Z][\w-]*)+$');

/// Test seam — `MasonGenerator.fromBrick`.
typedef MasonGeneratorFromBrick = Future<MasonGenerator> Function(Brick);

/// Base for `utopia create <thing>` subcommands. Owns positional name
/// parsing, common flags, brick resolution, and the generation lifecycle.
abstract class CreateSubCommand extends Command<int> {
  CreateSubCommand({
    required this.logger,
    BrickLocator? brickLocator,
    MasonGeneratorFromBrick? generatorFromBrick,
  })  : _brickLocator = brickLocator ?? const BrickLocator(),
        _generatorFromBrick = generatorFromBrick ?? MasonGenerator.fromBrick {
    argParser
      ..addOption(
        'output-directory',
        abbr: 'd',
        help: 'Where to create the project (defaults to current directory).',
      )
      ..addOption(
        'description',
        help: 'Description for the new project.',
        defaultsTo: defaultDescription,
      )
      ..addFlag(
        'skills',
        help: 'Generate .claude/ skills marketplace config in the new project.',
        defaultsTo: true,
      )
      ..addFlag(
        'pub-get',
        help: 'Run `flutter pub get` after generation.',
        defaultsTo: true,
      )
      ..addFlag(
        'git',
        help: 'Initialize a git repository in the new project.',
        defaultsTo: true,
      );
  }

  final Logger logger;
  final BrickLocator _brickLocator;
  final MasonGeneratorFromBrick _generatorFromBrick;

  @visibleForTesting
  ArgResults? argResultsOverride;

  @override
  ArgResults get argResults => argResultsOverride ?? super.argResults!;

  /// Default project description if `--description` is not provided.
  String get defaultDescription;

  /// Name of the Mason brick under `bricks/` to use for this subcommand.
  String get brickName;

  /// Build the template variable map from CLI args.
  Map<String, dynamic> buildVars({
    required String projectName,
    required String description,
  });

  /// Hook called after generation finishes — used for post-gen actions
  /// (git init, pub get) that aren't part of the brick.
  Future<void> postGenerate({
    required Directory targetDir,
    required String projectName,
  }) async {}

  String get projectName {
    final args = argResults.rest;
    if (args.isEmpty) usageException('Missing project name.');
    if (args.length > 1) usageException('Multiple project names specified.');
    final name = args.first;
    if (!_packageNameRegExp.hasMatch(name)) {
      usageException(
        '"$name" is not a valid Dart package name. Use snake_case '
        '(lowercase letters, digits, underscores only).',
      );
    }
    return name;
  }

  Directory get outputDirectory {
    final dir = argResults['output-directory'] as String?;
    final parent = dir != null ? Directory(dir) : Directory.current;
    return Directory(p.join(parent.path, projectName));
  }

  String get projectDescription => argResults['description'] as String? ?? defaultDescription;
  bool get skillsEnabled => argResults['skills'] as bool? ?? true;
  bool get pubGetEnabled => argResults['pub-get'] as bool? ?? true;
  bool get gitEnabled => argResults['git'] as bool? ?? true;

  @override
  Future<int> run() async {
    final name = projectName;
    final target = outputDirectory;

    if (target.existsSync() && target.listSync().isNotEmpty) {
      logger.err('Directory "${target.path}" already exists and is not empty.');
      return ExitCode.cantCreate.code;
    }

    logger.info(strings.banner);
    logger.info('');
    logger.info('Creating $name');

    final brickPath = _brickLocator.locate(brickName);
    final generator = await _generatorFromBrick(Brick.path(brickPath));
    final vars = buildVars(projectName: name, description: projectDescription);

    final genProgress = logger.progress('Generating project');
    final files = await generator.generate(
      DirectoryGeneratorTarget(target),
      vars: vars,
      logger: logger,
    );
    genProgress.complete('Generated ${files.length} file(s)');

    await postGenerate(targetDir: target, projectName: name);

    return ExitCode.success.code;
  }

  /// Helper for subclasses — runs a shell command, surfaces failures via
  /// the logger but does not throw (post-gen steps are best-effort).
  @protected
  Future<void> runShell(
    String executable,
    List<String> args, {
    required Directory workingDir,
    required String successMessage,
    required String failurePrefix,
  }) async {
    final progress = logger.progress(successMessage);
    try {
      final result = await Process.run(
        executable,
        args,
        workingDirectory: workingDir.path,
        runInShell: true,
      );
      if (result.exitCode == 0) {
        progress.complete(successMessage);
      } else {
        progress.fail('$failurePrefix (${result.exitCode})');
        logger.detail((result.stderr as String?) ?? '');
      }
    } on ProcessException catch (e) {
      progress.fail('$failurePrefix: ${e.message}');
    }
  }

  void _validateOrgName(String name) {
    if (!_orgNameRegExp.hasMatch(name)) {
      usageException(
        '"$name" is not a valid org name. Use reverse-domain notation '
        '(e.g. io.utopiasoft).',
      );
    }
  }

  @protected
  String validatedOrg(String value) {
    _validateOrgName(value);
    return value;
  }
}
