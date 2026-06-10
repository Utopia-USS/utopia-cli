import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:dart_mcp/stdio.dart';
import 'package:mason_logger/mason_logger.dart';

import 'mcp_server.dart';

/// `utopia mcp` - boot a Model Context Protocol server over stdio.
///
/// Scoping: only operational tools (`describe`, `describe_routes`,
/// `doctor`) - generators stay as Bash invocations. See
/// `lib/src/commands/mcp/mcp_server.dart` for rationale.
class McpCommand extends Command<int> {
  McpCommand();

  @override
  String get name => 'mcp';

  @override
  String get description => 'Boot an MCP server over stdio exposing `describe` and `doctor`.';

  @override
  String get invocation => 'utopia mcp';

  @override
  Future<int> run() async {
    // Start the server. Lives until stdin closes.
    final server = UtopiaMcpServer(stdioChannel(input: stdin, output: stdout));
    // Wait until the server's underlying channel closes (peer disconnects).
    await server.done;
    return ExitCode.success.code;
  }
}
