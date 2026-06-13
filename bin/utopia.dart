import 'package:utopia_cli/src/command_runner.dart';

Future<void> main(List<String> args) async {
  final exitCode = await UtopiaCommandRunner().run(args);
  await flushThenExit(exitCode);
}
