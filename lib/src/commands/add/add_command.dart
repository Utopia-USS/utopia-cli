import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';

import 'add_screen_command.dart';

/// `utopia add <thing>` — scaffold a Screen or other building block into
/// an existing project.
class AddCommand extends Command<int> {
  AddCommand({required Logger logger}) {
    addSubcommand(AddScreenCommand(logger: logger));
  }

  @override
  String get name => 'add';

  @override
  String get description =>
      'Add a Screen or other building block to an existing project.';

  @override
  String get invocation => 'utopia add <subcommand> <name>';
}
