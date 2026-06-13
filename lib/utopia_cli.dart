/// Public entrypoint for `utopia_cli` — re-exports the command runner for
/// tests and downstream tooling. End users should invoke the `utopia`
/// executable, not import this library.
library utopia_cli;

export 'src/command_runner.dart';
export 'src/version.dart';
