import 'dart:async';
import 'dart:io' show stderr;

import 'package:args/command_runner.dart';
import 'package:dart_mcp/server.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:stream_channel/stream_channel.dart';

import '../../command_runner.dart';
import '../../version.dart';

/// MCP server exposing the Utopia CLI surface as tools. Agents (e.g.
/// Claude Code) can scaffold projects and screens via JSON-RPC instead of
/// shelling out.
///
/// Tools registered (matches `utopia --help`):
///   • `create_flutter_app` — `utopia create flutter_app <name> ...`
///   • `create_flutter_package` — `utopia create flutter_package <name> ...`
///   • `add_screen` — `utopia add screen <name> ...`
///
/// Each tool simply parses MCP arguments back into CLI flags and runs
/// `UtopiaCommandRunner.run(...)`. That keeps the MCP surface 1:1 with the
/// CLI surface — no second source of truth.
final class UtopiaMcpServer extends MCPServer with ToolsSupport {
  UtopiaMcpServer({
    required StreamChannel<String> channel,
    Logger? logger,
    UtopiaCommandRunner? commandRunner,
  })  : _commandRunner = commandRunner ??
            UtopiaCommandRunner(
              logger: logger ?? Logger(),
              disableUpdateCheck: true,
            ),
        super.fromStreamChannel(
          channel,
          implementation: Implementation(
            name: 'utopia_cli',
            version: packageVersion,
          ),
          instructions:
              'Utopia CLI MCP server — scaffold Flutter projects built on '
              'utopia_arch + utopia_hooks. Tools mirror the `utopia` '
              'executable. Run `utopia --help` for the full surface.',
        );

  final UtopiaCommandRunner _commandRunner;

  @override
  FutureOr<InitializeResult> initialize(InitializeRequest request) async {
    final result = await super.initialize(request);
    _registerTools();
    return result;
  }

  void _registerTools() {
    registerTool(
      Tool(
        name: 'create_flutter_app',
        description:
            'Scaffold a new Utopia Flutter app at <output_directory>/<name>. '
            'Wraps `utopia create flutter_app <name>`. Generates a runnable '
            'project with utopia_arch + utopia_hooks, a sample counter '
            'Screen/State/View feature, and `.claude/` registering the '
            'Utopia-USS/utopia-flutter-skills marketplace (unless skills=false).',
        inputSchema: ObjectSchema(
          properties: {
            'name': StringSchema(
              description: 'Dart package name in snake_case (e.g. "my_app").',
            ),
            'org': StringSchema(
              description:
                  'Organization in reverse-domain notation (default: io.utopiasoft).',
            ),
            'platforms': StringSchema(
              description:
                  'Comma-separated Flutter platforms, e.g. "android,ios,web" '
                  '(default: "android,ios").',
            ),
            'output_directory': StringSchema(
              description: 'Parent directory for the project (default: ".").',
            ),
            'application_id': StringSchema(
              description: 'iOS bundle / Android app id (default: <org>.<name>).',
            ),
            'description': StringSchema(
              description: 'Project description.',
            ),
            'skills': BooleanSchema(
              description:
                  'Whether to generate the .claude/ skills marketplace config '
                  '(default: true).',
            ),
            'pub_get': BooleanSchema(
              description:
                  'Run `flutter pub get` after generation (default: true).',
            ),
            'git': BooleanSchema(
              description:
                  'Initialize a git repository (default: true).',
            ),
          },
          required: ['name'],
        ),
      ),
      _handleCreateFlutterApp,
    );

    registerTool(
      Tool(
        name: 'create_flutter_package',
        description:
            'Scaffold a Utopia Flutter package (reusable library). '
            'Wraps `utopia create flutter_package <name>`.',
        inputSchema: ObjectSchema(
          properties: {
            'name': StringSchema(
              description: 'Dart package name in snake_case.',
            ),
            'description': StringSchema(description: 'Package description.'),
            'output_directory': StringSchema(
              description: 'Parent directory for the package (default: ".").',
            ),
            'skills': BooleanSchema(
              description:
                  'Whether to generate the .claude/ skills config (default: true).',
            ),
            'pub_get': BooleanSchema(
              description: 'Run `flutter pub get` after generation (default: true).',
            ),
            'git': BooleanSchema(description: 'Initialize git (default: true).'),
          },
          required: ['name'],
        ),
      ),
      _handleCreateFlutterPackage,
    );

    registerTool(
      Tool(
        name: 'add_screen',
        description:
            'Scaffold a Screen/State/View triad at <output_directory>/<name>/. '
            'Wraps `utopia add screen <name>`. Run this from the root of an '
            'existing Utopia Flutter project.',
        inputSchema: ObjectSchema(
          properties: {
            'name': StringSchema(
              description:
                  'Screen name in snake_case (e.g. "auth_login").',
            ),
            'route': StringSchema(
              description:
                  'Route path served by this screen (default: "/<name>").',
            ),
            'output_directory': StringSchema(
              description: 'Parent directory (default: "lib/screen").',
            ),
          },
          required: ['name'],
        ),
      ),
      _handleAddScreen,
    );
  }

  Future<CallToolResult> _handleCreateFlutterApp(CallToolRequest request) async {
    final args = request.arguments ?? const {};
    final cli = <String>['create', 'flutter_app', args['name']! as String];
    _addStringOption(cli, args, key: 'org', flag: '--org');
    _addStringOption(cli, args, key: 'platforms', flag: '--platforms');
    _addStringOption(cli, args, key: 'output_directory', flag: '--output-directory');
    _addStringOption(cli, args, key: 'application_id', flag: '--application-id');
    _addStringOption(cli, args, key: 'description', flag: '--description');
    _addBoolFlag(cli, args, key: 'skills', onFlag: '--skills', offFlag: '--no-skills');
    _addBoolFlag(cli, args, key: 'pub_get', onFlag: '--pub-get', offFlag: '--no-pub-get');
    _addBoolFlag(cli, args, key: 'git', onFlag: '--git', offFlag: '--no-git');
    return _runCli(cli, toolName: 'create_flutter_app');
  }

  Future<CallToolResult> _handleCreateFlutterPackage(CallToolRequest request) async {
    final args = request.arguments ?? const {};
    final cli = <String>['create', 'flutter_package', args['name']! as String];
    _addStringOption(cli, args, key: 'description', flag: '--description');
    _addStringOption(cli, args, key: 'output_directory', flag: '--output-directory');
    _addBoolFlag(cli, args, key: 'skills', onFlag: '--skills', offFlag: '--no-skills');
    _addBoolFlag(cli, args, key: 'pub_get', onFlag: '--pub-get', offFlag: '--no-pub-get');
    _addBoolFlag(cli, args, key: 'git', onFlag: '--git', offFlag: '--no-git');
    return _runCli(cli, toolName: 'create_flutter_package');
  }

  Future<CallToolResult> _handleAddScreen(CallToolRequest request) async {
    final args = request.arguments ?? const {};
    final cli = <String>['add', 'screen', args['name']! as String];
    _addStringOption(cli, args, key: 'route', flag: '--route');
    _addStringOption(cli, args, key: 'output_directory', flag: '--output-directory');
    return _runCli(cli, toolName: 'add_screen');
  }

  void _addStringOption(
    List<String> cli,
    Map<String, Object?> args, {
    required String key,
    required String flag,
  }) {
    final value = args[key];
    if (value is String && value.isNotEmpty) cli.addAll([flag, value]);
  }

  void _addBoolFlag(
    List<String> cli,
    Map<String, Object?> args, {
    required String key,
    required String onFlag,
    required String offFlag,
  }) {
    final value = args[key];
    if (value is bool) cli.add(value ? onFlag : offFlag);
  }

  Future<CallToolResult> _runCli(
    List<String> args, {
    required String toolName,
  }) async {
    final commandLine = 'utopia ${args.join(' ')}';
    try {
      final exitCode = await _commandRunner.run(args);
      if (exitCode == ExitCode.success.code) {
        return CallToolResult(
          content: [TextContent(text: '"$toolName" succeeded.\n$commandLine')],
        );
      }
      final msg = '"$toolName" exited with code $exitCode.\n$commandLine';
      stderr.writeln('[utopia_mcp] $msg');
      return CallToolResult(content: [TextContent(text: msg)], isError: true);
    } on UsageException catch (e) {
      final msg = '"$toolName" usage error: ${e.message}\n$commandLine';
      stderr.writeln('[utopia_mcp] $msg');
      return CallToolResult(content: [TextContent(text: msg)], isError: true);
    } on Exception catch (e, stackTrace) {
      final msg = '"$toolName" threw: $e\n$commandLine';
      stderr
        ..writeln('[utopia_mcp] $msg')
        ..writeln('[utopia_mcp] $stackTrace');
      return CallToolResult(content: [TextContent(text: msg)], isError: true);
    }
  }
}
