import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:meta/meta.dart';

import 'model.dart';
import 'parser.dart';
import 'routes_view.dart';

/// `utopia describe` - emit project structure as JSON.
///
/// Output contract is documented at `doc/describe_schema.md`. Schema is
/// versioned via `schema_version`; downstream tooling (skills, MCP) pins
/// to a version.
class DescribeCommand extends Command<int> {
  DescribeCommand({
    required Logger logger,
    DescribeParser? parser,
  })  : _logger = logger,
        _parser = parser ?? const DescribeParser() {
    argParser
      ..addOption(
        'project-root',
        abbr: 'C',
        help: 'Project (or workspace) root to scan. Defaults to CWD.',
      )
      ..addOption(
        'output',
        abbr: 'o',
        help: 'Write JSON to a file instead of stdout. Use "-" for stdout.',
        defaultsTo: '-',
      )
      ..addFlag(
        'pretty',
        defaultsTo: true,
        help: 'Pretty-print JSON output (default on; --no-pretty for compact).',
      )
      ..addFlag(
        'routes-only',
        negatable: false,
        help: 'Emit only the routes section. Equivalent to piping through `jq` for routes.',
      );
  }

  final Logger _logger;
  final DescribeParser _parser;

  @visibleForTesting
  ArgResults? argResultsOverride;

  @override
  ArgResults get argResults => argResultsOverride ?? super.argResults!;

  @override
  String get name => 'describe';

  @override
  String get description => 'Emit project structure (screens, routes, states, services, deps) as JSON.';

  @override
  String get invocation => 'utopia describe [options]';

  String get projectRoot => (argResults['project-root'] as String?) ?? Directory.current.path;

  String get output => argResults['output'] as String? ?? '-';

  bool get pretty => argResults['pretty'] as bool? ?? true;

  bool get routesOnly => argResults['routes-only'] as bool? ?? false;

  @override
  Future<int> run() async {
    final describe = _parser.parse(projectRoot);

    final json = routesOnly ? describeRoutesView(describe) : describe.toJson();
    final encoded = pretty ? (const JsonEncoder.withIndent('  ')).convert(json) : jsonEncode(json);

    if (output == '-') {
      stdout.writeln(encoded);
    } else {
      File(output).writeAsStringSync('$encoded\n');
      _logger.info('Wrote describe output to $output');
    }

    // Signal a genuine usage error (e.g. bad project root) with a non-zero
    // exit so shell / CI callers notice. Warnings (e.g. no package found)
    // do not fail - the JSON's discovery_notes carry the detail.
    final hasError = describe.discoveryNotes.any((n) => n.level == DiscoveryLevel.error);
    return hasError ? ExitCode.usage.code : ExitCode.success.code;
  }
}
