import 'dart:async';

import 'package:args/command_runner.dart';
import 'package:dart_mcp/server.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';
import 'package:utopia_cli/src/command_runner.dart';
import 'package:utopia_cli/src/commands/mcp/mcp_command.dart';

void main() {
  group('McpCommand', () {
    test('is registered on the command runner', () {
      final runner = UtopiaCommandRunner(
        logger: Logger(level: Level.quiet),
        disableUpdateCheck: true,
      );
      expect(runner.commands.keys, contains('mcp'));
      expect(runner.commands['mcp'], isA<McpCommand>());
    });

    test('factory overrides are invoked when running the command', () async {
      var channelFactoryCalled = false;
      var serverFactoryCalled = false;

      // Closed channel so the test server completes immediately.
      final controller = StreamChannelController<String>();
      unawaited(controller.local.sink.close());

      final command = McpCommand(
        channelFactory: () {
          channelFactoryCalled = true;
          return controller.foreign;
        },
        serverFactory: ({required channel}) {
          serverFactoryCalled = true;
          return _DoneImmediatelyServer(channel: channel);
        },
      );

      final runner = CommandRunner<int>('test', 'mcp test')..addCommand(command);
      final exitCode = await runner.run(['mcp']);

      expect(exitCode, ExitCode.success.code);
      expect(channelFactoryCalled, isTrue);
      expect(serverFactoryCalled, isTrue);
    }, timeout: const Timeout(Duration(seconds: 10)));
  });
}

/// Test double for an MCP server — uses the channel only to satisfy the
/// base constructor; the channel is expected to be closed by the test so
/// `done` resolves promptly.
final class _DoneImmediatelyServer extends MCPServer {
  _DoneImmediatelyServer({required StreamChannel<String> channel})
      : super.fromStreamChannel(
          channel,
          implementation: Implementation(name: 'test', version: '0.0.0'),
        );
}
