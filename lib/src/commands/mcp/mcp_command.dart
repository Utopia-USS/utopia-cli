import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:dart_mcp/server.dart';
import 'package:dart_mcp/stdio.dart';
import 'package:mason/mason.dart' show ExitCode;
import 'package:stream_channel/stream_channel.dart';

import 'mcp_server.dart';

/// Factory for an [MCPServer] — overridable so tests can swap in a fake.
typedef ServerFactory = MCPServer Function({required StreamChannel<String> channel});

/// Factory for the JSON-line stream channel — defaults to stdio.
typedef ChannelFactory = StreamChannel<String> Function();

StreamChannel<String> _defaultChannelFactory() =>
    stdioChannel(input: stdin, output: stdout);

/// `utopia mcp` — boots a Model Context Protocol server over stdio that
/// exposes `utopia create`, `utopia add screen`, and friends as MCP tools
/// for AI agents (e.g. Claude Code).
class McpCommand extends Command<int> {
  McpCommand({ChannelFactory? channelFactory, ServerFactory? serverFactory})
      : _channelFactory = channelFactory ?? _defaultChannelFactory,
        _serverFactory = serverFactory ?? UtopiaMcpServer.new;

  static const commandName = 'mcp';

  final ChannelFactory _channelFactory;
  final ServerFactory _serverFactory;

  @override
  String get name => commandName;

  @override
  String get description =>
      'Start an MCP (Model Context Protocol) server exposing the Utopia '
      'CLI as tools for AI agents. Runs over stdio. Experimental.';

  @override
  Future<int> run() async {
    try {
      final channel = _channelFactory();
      final server = _serverFactory(channel: channel);
      await server.done;
      return ExitCode.success.code;
    } on Exception catch (e, stackTrace) {
      stderr
        ..writeln('[utopia_mcp] Failed to start MCP server: $e')
        ..writeln('[utopia_mcp] $stackTrace');
      return ExitCode.software.code;
    }
  }
}
