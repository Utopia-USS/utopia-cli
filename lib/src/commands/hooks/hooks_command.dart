import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';

import 'hooks_analyze_command.dart';

/// `utopia hooks <subcommand>` - utopia_hooks-specific tooling.
class HooksCommand extends Command<int> {
  HooksCommand({required Logger logger}) {
    addSubcommand(HooksAnalyzeCommand(logger: logger));
  }

  @override
  String get name => 'hooks';

  @override
  String get description => 'utopia_hooks validation and tooling.';

  @override
  String get invocation => 'utopia hooks <subcommand>';
}
