import 'dart:io';

import '../../strings.dart' as strings;
import 'create_subcommand.dart';

const _defaultOrg = 'io.utopiasoft';

/// `utopia create flutter_app <name>` — scaffolds a Utopia Flutter app.
class CreateFlutterAppCommand extends CreateSubCommand {
  CreateFlutterAppCommand({
    required super.logger,
    super.brickLocator,
    super.generatorFromBrick,
  }) {
    argParser
      ..addOption(
        'org',
        abbr: 'o',
        help: 'Organization in reverse-domain notation.',
        defaultsTo: _defaultOrg,
      )
      ..addOption(
        'platforms',
        abbr: 'p',
        help: 'Comma-separated Flutter platforms to enable.',
        defaultsTo: 'android,ios',
      )
      ..addOption(
        'application-id',
        help: 'iOS bundle / Android application id (defaults to <org>.<name>).',
      );
  }

  @override
  String get name => 'flutter_app';

  @override
  String get description => 'Generate a Utopia Flutter application.';

  @override
  String get invocation => 'utopia create flutter_app <name> [options]';

  @override
  String get defaultDescription => 'A Utopia Flutter project.';

  @override
  String get brickName => 'utopia_flutter_app';

  String get org => validatedOrg(argResults['org'] as String? ?? _defaultOrg);
  String get platforms => argResults['platforms'] as String? ?? 'android,ios';
  String get applicationId => (argResults['application-id'] as String?) ?? '$org.$projectName';

  @override
  Map<String, dynamic> buildVars({
    required String projectName,
    required String description,
  }) {
    return {
      'project_name': projectName,
      'package_name': projectName,
      'dart_package_name': projectName, // brick backward compatibility
      'org_name': org,
      'description': description,
      'platforms': platforms,
      'application_id': applicationId,
      'skills_enabled': skillsEnabled,
      'year': DateTime.now().year.toString(),
    };
  }

  @override
  Future<void> postGenerate({
    required Directory targetDir,
    required String projectName,
  }) async {
    // Run `flutter create` over the generated tree to fill in android/, ios/,
    // etc. The brick provides everything under lib/ and the project config;
    // `flutter create .` then adds platform scaffolding without overwriting
    // existing files when invoked with `--platforms` and a project name.
    await _flutterCreate(targetDir);

    // `flutter create` injects test/widget_test.dart that references a
    // `MyApp` class which doesn't exist in the Utopia template. Drop it
    // so the project analyzes cleanly out of the box.
    final staleWidgetTest = File('${targetDir.path}/test/widget_test.dart');
    if (staleWidgetTest.existsSync()) staleWidgetTest.deleteSync();

    if (gitEnabled) await _gitInit(targetDir);
    if (pubGetEnabled) await _pubGet(targetDir);

    logger.info('');
    logger.info(strings.createNextSteps(
      projectName: projectName,
      skillsEnabled: skillsEnabled,
    ));
  }

  Future<void> _flutterCreate(Directory targetDir) async {
    final args = [
      'create',
      '--project-name=$projectName',
      '--org=$org',
      '--platforms=$platforms',
      '.',
    ];
    await runShell(
      'flutter',
      args,
      workingDir: targetDir,
      successMessage: 'Added Flutter platform scaffolding',
      failurePrefix: 'flutter create failed',
    );
  }

  Future<void> _gitInit(Directory targetDir) async {
    await runShell(
      'git',
      ['init', '--quiet'],
      workingDir: targetDir,
      successMessage: 'Initialized git repository',
      failurePrefix: 'git init failed',
    );
  }

  Future<void> _pubGet(Directory targetDir) async {
    await runShell(
      'flutter',
      ['pub', 'get'],
      workingDir: targetDir,
      successMessage: 'Installed dependencies',
      failurePrefix: 'flutter pub get failed',
    );
  }
}
