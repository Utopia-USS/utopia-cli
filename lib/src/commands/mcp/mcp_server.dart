import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'package:dart_mcp/server.dart';
import 'package:dart_mcp/stdio.dart';
import 'package:meta/meta.dart';

import '../describe/parser.dart';
import '../doctor/check.dart';
import '../doctor/checks.dart' as doctor_checks;
import '../doctor/model.dart' as doctor_model;
import '../../version.dart';

/// MCP server exposing `utopia describe` and `utopia doctor` as MCP tools.
///
/// **Scoping principle (see `docs/describe_schema.md` and the plan):**
/// Only operational tools that earn their keep on the MCP-vs-Bash test
/// are exposed - i.e. tools called multiple times per session with
/// structured output the agent reasons over. One-shot generators
/// (`utopia create *`, `utopia add screen`) stay as Bash invocations.
///
/// Tools exposed:
/// - `describe` - full project structure as JSON
/// - `describe_routes` - just the routes view
/// - `doctor` - repo-wide audit with tag-based selection
base class UtopiaMcpServer extends MCPServer with ToolsSupport {
  UtopiaMcpServer(super.channel)
      : super.fromStreamChannel(
          implementation: Implementation(
            name: 'utopia',
            version: packageVersion,
          ),
          instructions: '''
Utopia CLI MCP server. Exposes project-introspection (`describe`) and
repo-audit (`doctor`) tools for Flutter projects built on utopia_arch
+ utopia_hooks.

Project-bootstrapping commands (`utopia create flutter_app`,
`utopia create flutter_package`, `utopia add screen`, `utopia init
skills`) are intentionally NOT exposed here - invoke them via Bash
instead. See the project's README for rationale (MCP-vs-Bash test).
''',
        ) {
    registerTool(_describeTool, _runDescribe);
    registerTool(_describeRoutesTool, _runDescribeRoutes);
    registerTool(_doctorTool, _runDoctor);
  }

  // --- describe ------------------------------------------------------------

  final _describeTool = Tool(
    name: 'describe',
    description:
        'Emit project structure (screens, routes, global states, services, '
        'deps, foreign-framework artefacts) as versioned JSON. Use to learn '
        'what exists in a project in one call instead of crawling files.',
    inputSchema: Schema.object(
      properties: {
        'project_root': Schema.string(
          description: 'Project (or workspace) root. Defaults to CWD if omitted.',
        ),
      },
    ),
  );

  FutureOr<CallToolResult> _runDescribe(CallToolRequest request) async {
    final root = _stringArg(request, 'project_root') ?? io.Directory.current.path;
    try {
      final describe = const DescribeParser().parse(root);
      final json = const JsonEncoder.withIndent('  ').convert(describe.toJson());
      return CallToolResult(content: [TextContent(text: json)]);
    } on Object catch (e, st) {
      return CallToolResult(
        isError: true,
        content: [TextContent(text: 'describe failed: $e\n$st')],
      );
    }
  }

  // --- describe_routes ----------------------------------------------------

  final _describeRoutesTool = Tool(
    name: 'describe_routes',
    description: 'Like `describe` but emits only the routes view per package. '
        'Use to enumerate paths / detect conflicts cheaply.',
    inputSchema: Schema.object(
      properties: {
        'project_root': Schema.string(
          description: 'Project (or workspace) root. Defaults to CWD if omitted.',
        ),
      },
    ),
  );

  FutureOr<CallToolResult> _runDescribeRoutes(CallToolRequest request) async {
    final root = _stringArg(request, 'project_root') ?? io.Directory.current.path;
    try {
      final describe = const DescribeParser().parse(root);
      final view = <String, dynamic>{
        'schema_version': describe.schemaVersion,
        'packages': describe.packages.map((pkg) {
          final routes = pkg.screens
              .where((s) => s.route != null)
              .map((s) => {
                    'screen': s.name,
                    'kind': s.kind.name,
                    'file': s.file,
                    'path': s.route!.path,
                    'config_builder': s.route!.configBuilder,
                    'confidence': s.route!.confidence.name,
                  })
              .toList();
          return {
            'name': pkg.name,
            'routing': pkg.routing?.toJson(),
            'routes': routes,
          };
        }).toList(),
      };
      final json = const JsonEncoder.withIndent('  ').convert(view);
      return CallToolResult(content: [TextContent(text: json)]);
    } on Object catch (e, st) {
      return CallToolResult(
        isError: true,
        content: [TextContent(text: 'describe_routes failed: $e\n$st')],
      );
    }
  }

  // --- doctor -------------------------------------------------------------

  final _doctorTool = Tool(
    name: 'doctor',
    description:
        'Repo-wide audit. Returns structured findings { rule_id, tag, '
        'severity, file, line, message, fix } across setup / conventions / '
        'artifacts / imports / structure tags. Use after refactors or '
        'before commit to catch drift.',
    inputSchema: Schema.object(
      properties: {
        'project_root': Schema.string(
          description: 'Project (or workspace) root. Defaults to CWD if omitted.',
        ),
        'check': Schema.list(
          description:
              'Tags / sub-tags / rule IDs to run ONLY (allowlist). E.g. '
              '["setup", "artifacts:bloc"]. If omitted, smart default activates '
              'checks based on pubspec deps.',
          items: Schema.string(),
        ),
        'skip': Schema.list(
          description: 'Tags / sub-tags / rule IDs to exclude (denylist).',
          items: Schema.string(),
        ),
        'strict': Schema.bool(
          description: 'Bypass activation gates; run every non-skipped check.',
        ),
      },
    ),
  );

  FutureOr<CallToolResult> _runDoctor(CallToolRequest request) async {
    final root = _stringArg(request, 'project_root') ?? io.Directory.current.path;
    final include = _stringListArg(request, 'check') ?? const <String>[];
    final exclude = _stringListArg(request, 'skip') ?? const <String>[];
    final strict = (request.arguments?['strict'] as bool?) ?? false;

    try {
      final describe = const DescribeParser().parse(root);
      final selection = CheckSelection(include: include, exclude: exclude, strict: strict);
      final activeChecks = doctor_checks.allChecks.where((c) => selection.shouldRun(c, describe)).toList();
      final findings = <doctor_model.Finding>[];
      for (final check in activeChecks) {
        findings.addAll(check.run(describe, root));
      }
      final report = doctor_model.DoctorReport(
        schemaVersion: 1,
        projectRoot: root,
        activeChecks: activeChecks.map((c) => c.id).toList(),
        findings: findings,
        summary: doctor_model.DoctorSummary(
          errorCount: findings.where((f) => f.severity == doctor_model.Severity.error).length,
          warningCount: findings.where((f) => f.severity == doctor_model.Severity.warning).length,
          infoCount: findings.where((f) => f.severity == doctor_model.Severity.info).length,
        ),
      );
      final json = const JsonEncoder.withIndent('  ').convert(report.toJson());
      return CallToolResult(content: [TextContent(text: json)]);
    } on Object catch (e, st) {
      return CallToolResult(
        isError: true,
        content: [TextContent(text: 'doctor failed: $e\n$st')],
      );
    }
  }

  // --- helpers ------------------------------------------------------------

  String? _stringArg(CallToolRequest request, String key) {
    final v = request.arguments?[key];
    return v is String && v.isNotEmpty ? v : null;
  }

  List<String>? _stringListArg(CallToolRequest request, String key) {
    final v = request.arguments?[key];
    if (v is List) return v.map((e) => e.toString()).toList();
    return null;
  }
}

/// Boot the MCP server over stdio.
@visibleForTesting
void runMcpServer({io.Stdin? stdin, io.Stdout? stdout}) {
  UtopiaMcpServer(stdioChannel(input: stdin ?? io.stdin, output: stdout ?? io.stdout));
}
