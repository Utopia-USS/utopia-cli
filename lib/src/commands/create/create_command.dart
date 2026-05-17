import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';

import 'flutter_app_command.dart';
import 'flutter_package_command.dart';

/// `utopia create <subcommand> <project-name>` — top-level create command.
class CreateCommand extends Command<int> {
  CreateCommand({required Logger logger}) {
    addSubcommand(CreateFlutterAppCommand(logger: logger));
    addSubcommand(CreateFlutterPackageCommand(logger: logger));
  }

  @override
  String get name => 'create';

  @override
  String get description => 'Create a new Utopia Flutter project.';

  @override
  String get invocation => 'utopia create <subcommand> <project-name> [options]';
}
