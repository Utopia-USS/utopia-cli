import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';

import '../strings.dart' as strings;

/// `utopia add <thing>` — Phase-2 placeholder for screen/state scaffolding.
class AddCommand extends Command<int> {
  AddCommand({required Logger logger}) : _logger = logger {
    addSubcommand(_StubSubcommand(
      logger: _logger,
      cmdName: 'screen',
      cmdDescription: 'Scaffold a new Screen/State/View triad (planned).',
      fullName: 'add screen',
    ));
    addSubcommand(_StubSubcommand(
      logger: _logger,
      cmdName: 'state',
      cmdDescription: 'Scaffold a new global state hook (planned).',
      fullName: 'add state',
    ));
  }

  final Logger _logger;

  @override
  String get name => 'add';

  @override
  String get description => 'Add a Screen, State, or other building block to an existing project.';

  @override
  String get invocation => 'utopia add <subcommand> <name>';
}

/// `utopia migrate <thing>` — Phase-2 placeholder for the BLoC migration.
class MigrateCommand extends Command<int> {
  MigrateCommand({required Logger logger}) : _logger = logger {
    addSubcommand(_StubSubcommand(
      logger: _logger,
      cmdName: 'bloc',
      cmdDescription: 'Migrate BLoC/Cubit code to utopia_hooks (planned).',
      fullName: 'migrate bloc',
    ));
  }

  final Logger _logger;

  @override
  String get name => 'migrate';

  @override
  String get description => 'Run a migration codemod over an existing project.';

  @override
  String get invocation => 'utopia migrate <subcommand>';
}

class _StubSubcommand extends Command<int> {
  _StubSubcommand({
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
    _logger.info(strings.comingSoon(fullName));
    return ExitCode.unavailable.code;
  }
}
