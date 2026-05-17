import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:mason/mason.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;

import '../../generators/brick_locator.dart';

final _packageNameRegExp = RegExp(r'^[a-z_][a-z0-9_]*$');

/// Test seam — `MasonGenerator.fromBrick`.
typedef MasonGeneratorFromBrick = Future<MasonGenerator> Function(Brick);

/// `utopia add screen <name>` — scaffold a Screen/State/View triad at
/// `lib/screen/<name>/`. Uses the in-repo `screen` brick (vendored from
/// `Utopia-USS/utopia-mason`).
class AddScreenCommand extends Command<int> {
  AddScreenCommand({
    required Logger logger,
    BrickLocator? brickLocator,
    MasonGeneratorFromBrick? generatorFromBrick,
  })  : _logger = logger,
        _brickLocator = brickLocator ?? const BrickLocator(),
        _generatorFromBrick = generatorFromBrick ?? MasonGenerator.fromBrick {
    argParser
      ..addOption(
        'route',
        abbr: 'r',
        help: 'Route path served by this screen. Defaults to "/<name>".',
      )
      ..addOption(
        'output-directory',
        abbr: 'd',
        help: 'Parent directory for the new screen folder.',
        defaultsTo: 'lib/screen',
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
  String get name => 'screen';

  @override
  String get description => 'Scaffold a Screen/State/View triad.';

  @override
  String get invocation => 'utopia add screen <name> [options]';

  String get screenName {
    final args = argResults.rest;
    if (args.isEmpty) usageException('Missing screen name.');
    if (args.length > 1) usageException('Multiple screen names specified.');
    final name = args.first;
    if (!_packageNameRegExp.hasMatch(name)) {
      usageException(
        '"$name" is not a valid screen name. Use snake_case '
        '(lowercase letters, digits, underscores only).',
      );
    }
    return name;
  }

  String get route => (argResults['route'] as String?) ?? '/$screenName';
  String get outputParent => argResults['output-directory'] as String? ?? 'lib/screen';

  @override
  Future<int> run() async {
    final name = screenName;
    final target = Directory(p.join(outputParent, name));

    if (target.existsSync() && target.listSync().isNotEmpty) {
      _logger.err('Directory "${target.path}" already exists and is not empty.');
      return ExitCode.cantCreate.code;
    }

    final brickPath = _brickLocator.locate('screen');
    final generator = await _generatorFromBrick(Brick.path(brickPath));

    final progress = _logger.progress('Adding screen "$name"');
    final files = await generator.generate(
      DirectoryGeneratorTarget(target),
      vars: {'name': name, 'route': route},
      logger: _logger,
    );
    progress.complete('Generated ${files.length} file(s) at ${target.path}');

    _printRegistrationHint(name: name, target: target);
    return ExitCode.success.code;
  }

  void _printRegistrationHint({required String name, required Directory target}) {
    final pascal = _pascalCase(name);
    _logger
      ..info('')
      ..info('Next: register the route in lib/app/app_routing.dart')
      ..info('')
      ..info("  import 'package:<your_pkg>/${_relativeImportPath(target)}/${name}_screen.dart';")
      ..info('')
      ..info('  static final routes = <String, RouteConfig>{')
      ..info('    ...')
      ..info('    ${pascal}Screen.route: ${pascal}Screen.routeConfig,')
      ..info('  };');
  }

  String _relativeImportPath(Directory target) {
    // target.path is e.g. "lib/screen/auth" → import path "screen/auth"
    final segments = p.split(target.path);
    final libIndex = segments.indexOf('lib');
    if (libIndex == -1) return target.path;
    return segments.sublist(libIndex + 1).join('/');
  }

  String _pascalCase(String snake) =>
      snake.split('_').map((p) => p.isEmpty ? p : p[0].toUpperCase() + p.substring(1)).join();
}
