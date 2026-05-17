import 'dart:io';

import 'create_subcommand.dart';

/// `utopia create flutter_package <name>` — scaffolds a Flutter library.
class CreateFlutterPackageCommand extends CreateSubCommand {
  CreateFlutterPackageCommand({
    required super.logger,
    super.brickLocator,
    super.generatorFromBrick,
  });

  @override
  String get name => 'flutter_package';

  @override
  String get description => 'Generate a Utopia Flutter package.';

  @override
  String get invocation => 'utopia create flutter_package <name> [options]';

  @override
  String get defaultDescription => 'A Utopia Flutter package.';

  @override
  String get brickName => 'utopia_flutter_package';

  @override
  Map<String, dynamic> buildVars({
    required String projectName,
    required String description,
  }) {
    return {
      'project_name': projectName,
      'package_name': projectName,
      'description': description,
      'skills_enabled': skillsEnabled,
      'year': DateTime.now().year.toString(),
    };
  }

  @override
  Future<void> postGenerate({
    required Directory targetDir,
    required String projectName,
  }) async {
    if (gitEnabled) {
      await runShell(
        'git',
        ['init', '--quiet'],
        workingDir: targetDir,
        successMessage: 'Initialized git repository',
        failurePrefix: 'git init failed',
      );
    }
    if (pubGetEnabled) {
      await runShell(
        'flutter',
        ['pub', 'get'],
        workingDir: targetDir,
        successMessage: 'Installed dependencies',
        failurePrefix: 'flutter pub get failed',
      );
    }

    logger
      ..info('')
      ..info('→ cd $projectName')
      ..info('→ flutter test')
      ..info('');
  }
}
