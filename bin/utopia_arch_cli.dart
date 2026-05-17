// Deprecated entrypoint — `utopia_arch_cli` was renamed to `utopia` in
// version 0.2.0. This shim prints a one-time deprecation notice and
// forwards to the new entrypoint. To be removed in 0.3.0.

import 'dart:io';

import 'package:utopia_cli/src/command_runner.dart';
import 'package:utopia_cli/src/strings.dart' as strings;

Future<void> main(List<String> args) async {
  stderr.writeln(strings.deprecatedExecutableNotice);
  stderr.writeln();
  final exitCode = await UtopiaCommandRunner().run(args);
  await flushThenExit(exitCode);
}
