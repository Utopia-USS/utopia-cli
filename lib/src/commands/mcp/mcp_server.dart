import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'package:dart_mcp/server.dart';
import 'package:dart_mcp/stdio.dart';
import 'package:meta/meta.dart';

import '../describe/parser.dart';
import '../describe/routes_view.dart';
import '../doctor/checks.dart' as doctor_checks;
import '../doctor/report_builder.dart';
import '../hooks/hooks_analyze_engine.dart';
import '../../version.dart';

/// MCP server exposing `utopia describe` and `utopia doctor` as MCP tools.
///
/// **Scoping principle (see `doc/describe_schema.md` and the plan):**
/// Only operational tools that earn their keep on the MCP-vs-Bash test
/// are exposed - i.e. tools called multiple times per session with
/// structured output the agent reasons over. One-shot generators
/// (`utopia create *`, `utopia add screen`) stay as Bash invocations.
///
/// Tools exposed:
/// - `describe` - full project structure as JSON
/// - `describe_routes` - just the routes view
/// - `doctor` - repo-wide audit with tag-based selection
/// - `analyze_hooks_files` - fast utopia_hooks analysis gate for files
/// - `analyze_hooks_changed` - fast utopia_hooks analysis gate for changed files
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
    registerTool(_analyzeHooksFilesTool, _runAnalyzeHooksFiles);
    registerTool(_analyzeHooksChangedTool, _runAnalyzeHooksChanged);
  }

  // --- describe ------------------------------------------------------------

  final _describeTool = Tool(
    name: 'describe',
    description: 'Emit project structure (screens, routes, global states, services, '
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
      final view = describeRoutesView(describe);
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
    description: 'Repo-wide audit. Returns structured findings { rule_id, tag, '
        'severity, file, line, message, fix } across setup / conventions / '
        'artifacts / imports / structure tags. Use after refactors or '
        'before commit to catch drift.',
    inputSchema: Schema.object(
      properties: {
        'project_root': Schema.string(
          description: 'Project (or workspace) root. Defaults to CWD if omitted.',
        ),
        'check': Schema.list(
          description: 'Tags / sub-tags / rule IDs to run ONLY (allowlist). E.g. '
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
    if (!io.Directory(root).existsSync()) {
      return CallToolResult(
        isError: true,
        content: [TextContent(text: 'doctor failed: project root not found: $root')],
      );
    }
    final include = _stringListArg(request, 'check') ?? const <String>[];
    final exclude = _stringListArg(request, 'skip') ?? const <String>[];
    final strict = (request.arguments?['strict'] as bool?) ?? false;

    try {
      final describe = const DescribeParser().parse(root);
      final report = buildDoctorReport(
        describe: describe,
        projectRoot: root,
        registry: doctor_checks.allChecks,
        include: include,
        exclude: exclude,
        strict: strict,
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

  // --- analyze_hooks --------------------------------------------------------

  final _analyzeHooksFilesTool = Tool(
    name: 'analyze_hooks_files',
    description: 'Fast utopia_hooks convention analysis for Dart files. Returns the same '
        'structured report as `utopia hooks analyze --file ... --format=json`.',
    inputSchema: Schema.object(
      properties: {
        'project_root': Schema.string(
          description: 'Project (or workspace) root. Defaults to CWD if omitted.',
        ),
        'files': Schema.list(
          description: 'Dart file paths, absolute or relative to project_root.',
          items: Schema.string(),
        ),
      },
    ),
  );

  FutureOr<CallToolResult> _runAnalyzeHooksFiles(CallToolRequest request) async {
    final root = _stringArg(request, 'project_root') ?? io.Directory.current.path;
    final files = _stringListArg(request, 'files');
    if (files == null || files.isEmpty) {
      return CallToolResult(
        isError: true,
        content: [TextContent(text: 'analyze_hooks_files failed: missing required argument `files`')],
      );
    }

    try {
      final report = const HooksAnalyzeEngine().analyzeFiles(
        projectRoot: root,
        files: files,
      );
      final json = const JsonEncoder.withIndent('  ').convert(report.toJson());
      return CallToolResult(content: [TextContent(text: json)]);
    } on Object catch (e, st) {
      return CallToolResult(
        isError: true,
        content: [TextContent(text: 'analyze_hooks_files failed: $e\n$st')],
      );
    }
  }

  final _analyzeHooksChangedTool = Tool(
    name: 'analyze_hooks_changed',
    description: 'Fast utopia_hooks convention analysis for changed git Dart files. Returns '
        'the same structured report as `utopia hooks analyze --format=json`.',
    inputSchema: Schema.object(
      properties: {
        'project_root': Schema.string(
          description: 'Project (or workspace) root. Defaults to CWD if omitted.',
        ),
      },
    ),
  );

  FutureOr<CallToolResult> _runAnalyzeHooksChanged(CallToolRequest request) async {
    final root = _stringArg(request, 'project_root') ?? io.Directory.current.path;
    try {
      final engine = const HooksAnalyzeEngine();
      final files = await engine.changedFiles(projectRoot: root);
      final report = engine.analyzeFiles(projectRoot: root, files: files);
      final json = const JsonEncoder.withIndent('  ').convert(report.toJson());
      return CallToolResult(content: [TextContent(text: json)]);
    } on Object catch (e, st) {
      return CallToolResult(
        isError: true,
        content: [TextContent(text: 'analyze_hooks_changed failed: $e\n$st')],
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
