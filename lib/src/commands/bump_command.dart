import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
import 'package:pub_updater/pub_updater.dart';

/// `utopia bump` - atomically bump all `utopia_*` deps in pubspec.yaml.
///
/// Reads pubspec.yaml, fetches the latest pub.dev version of every
/// `utopia_*` package declared in `dependencies`/`dev_dependencies`,
/// and rewrites the constraints to `^<latest>`. The original line
/// formatting is preserved (minimal-diff edits).
///
/// Workspace-aware: in Melos monorepos, runs against the package at
/// the working directory or one explicitly named via `--package`.
class BumpCommand extends Command<int> {
  BumpCommand({
    required Logger logger,
    PubUpdater? pubUpdater,
  })  : _logger = logger,
        _pubUpdater = pubUpdater ?? PubUpdater() {
    argParser
      ..addOption(
        'project-root',
        abbr: 'C',
        help: 'Package root containing the pubspec.yaml to bump. Defaults to CWD.',
      )
      ..addFlag(
        'dry-run',
        negatable: false,
        help: 'Show what would change without writing.',
      );
  }

  final Logger _logger;
  final PubUpdater _pubUpdater;

  @visibleForTesting
  ArgResults? argResultsOverride;

  @override
  ArgResults get argResults => argResultsOverride ?? super.argResults!;

  @override
  String get name => 'bump';

  @override
  String get description => 'Bump all utopia_* deps in pubspec.yaml to their latest pub.dev versions.';

  @override
  String get invocation => 'utopia bump [options]';

  String get projectRoot => (argResults['project-root'] as String?) ?? Directory.current.path;
  bool get dryRun => argResults['dry-run'] as bool? ?? false;

  /// Pattern: ` utopia_xxx: ^1.2.3-dev.4+5` or ` utopia_xxx: 1.2.3` etc.
  /// Captures indent, name, separator, and constraint.
  static final _depLineRegExp = RegExp(
    r'^(\s+)(utopia_[a-z_0-9]+)(\s*:\s*)(\^?\d+(?:\.\d+){0,2}(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?)(\s*)$',
    multiLine: true,
  );

  @override
  Future<int> run() async {
    final pubspecFile = File(p.join(projectRoot, 'pubspec.yaml'));
    if (!pubspecFile.existsSync()) {
      _logger.err('No pubspec.yaml found at $projectRoot');
      return ExitCode.usage.code;
    }

    final original = pubspecFile.readAsStringSync();
    final matches = _depLineRegExp.allMatches(original).toList();

    if (matches.isEmpty) {
      _logger.info('No utopia_* dependencies found in $projectRoot/pubspec.yaml');
      return ExitCode.success.code;
    }

    final progress = _logger.progress('Resolving latest versions');
    final updates = <_DepUpdate>[];
    for (final m in matches) {
      final name = m.group(2)!;
      final current = m.group(4)!;
      try {
        final latest = await _pubUpdater.getLatestVersion(name);
        final desired = '^$latest';
        if (current != desired) {
          updates.add(_DepUpdate(name: name, oldConstraint: current, newConstraint: desired, match: m));
        }
      } on Object catch (e) {
        _logger.warn('Could not resolve latest version for $name: $e');
      }
    }
    progress.complete('Resolved ${matches.length} utopia_* package(s)');

    if (updates.isEmpty) {
      _logger.info('All utopia_* deps already at latest pub.dev versions.');
      return ExitCode.success.code;
    }

    _logger.info('');
    for (final u in updates) {
      _logger.info('  ${u.name}: ${u.oldConstraint} → ${u.newConstraint}');
    }

    if (dryRun) {
      _logger
        ..info('')
        ..info('--dry-run: pubspec.yaml not modified');
      return ExitCode.success.code;
    }

    // Apply edits in reverse offset order to keep offsets valid.
    updates.sort((a, b) => b.match.start.compareTo(a.match.start));
    var modified = original;
    for (final u in updates) {
      final m = u.match;
      final replacement = '${m.group(1)}${u.name}${m.group(3)}${u.newConstraint}${m.group(5)}';
      modified = modified.substring(0, m.start) + replacement + modified.substring(m.end);
    }

    pubspecFile.writeAsStringSync(modified);
    _logger
      ..info('')
      ..info('Wrote ${updates.length} bump(s) to ${pubspecFile.path}')
      ..info('Run `dart pub get` (or `flutter pub get`) to sync.');
    return ExitCode.success.code;
  }
}

class _DepUpdate {
  _DepUpdate({
    required this.name,
    required this.oldConstraint,
    required this.newConstraint,
    required this.match,
  });

  final String name;
  final String oldConstraint;
  final String newConstraint;
  final RegExpMatch match;
}
