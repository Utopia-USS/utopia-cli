import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';

import 'init_agents_command.dart';
import 'init_skills_command.dart';

/// `utopia init <thing>` — one-time setup steps for an existing project.
class InitCommand extends Command<int> {
  InitCommand({required Logger logger}) {
    addSubcommand(InitAgentsCommand(logger: logger));
    addSubcommand(InitSkillsCommand(logger: logger));
  }

  @override
  String get name => 'init';

  @override
  String get description => 'Set up a piece of Utopia infrastructure in an existing project.';

  @override
  String get invocation => 'utopia init <subcommand>';
}
