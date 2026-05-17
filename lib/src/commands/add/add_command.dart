import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';

import '../stub_commands.dart';
import 'add_screen_command.dart';

/// `utopia add <thing>` — scaffold a Screen, State, or other building
/// block into an existing project.
class AddCommand extends Command<int> {
  AddCommand({required Logger logger}) {
    addSubcommand(AddScreenCommand(logger: logger));
    addSubcommand(StubSubcommand(
      logger: logger,
      cmdName: 'state',
      cmdDescription: 'Scaffold a new global state hook (planned).',
      fullName: 'add state',
    ));
  }

  @override
  String get name => 'add';

  @override
  String get description =>
      'Add a Screen, State, or other building block to an existing project.';

  @override
  String get invocation => 'utopia add <subcommand> <name>';
}
