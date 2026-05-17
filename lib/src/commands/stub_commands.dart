import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';

import 'strings_helper.dart';

/// `utopia migrate <thing>` — Phase-2 placeholder for the BLoC migration.
class MigrateCommand extends Command<int> {
  MigrateCommand({required Logger logger}) {
    addSubcommand(StubSubcommand(
      logger: logger,
      cmdName: 'bloc',
      cmdDescription: 'Migrate BLoC/Cubit code to utopia_hooks (planned).',
      fullName: 'migrate bloc',
    ));
  }

  @override
  String get name => 'migrate';

  @override
  String get description =>
      'Run a migration codemod over an existing project.';

  @override
  String get invocation => 'utopia migrate <subcommand>';
}

/// Generic "coming soon" subcommand — used for Phase-2 placeholders that
/// should appear in `--help` but aren't implemented yet.
class StubSubcommand extends Command<int> {
  StubSubcommand({
    required Logger logger,
    required String cmdName,
    required String cmdDescription,
    required this.fullName,
  })  : _logger = logger,
        _name = cmdName,
        _description = cmdDescription;

  final Logger _logger;
  final String _name;
  final String _description;
  final String fullName;

  @override
  String get name => _name;

  @override
  String get description => _description;

  @override
  Future<int> run() async {
    _logger.info(comingSoonMessage(fullName));
    return ExitCode.unavailable.code;
  }
}
