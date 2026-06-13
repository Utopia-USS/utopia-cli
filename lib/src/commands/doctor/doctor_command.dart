import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:meta/meta.dart';

import '../describe/parser.dart';
import '../hooks/hooks_analyze_engine.dart';
import 'check.dart';
import 'checks.dart';
import 'model.dart';
import 'report_builder.dart';

/// `utopia doctor` - repo-wide audit complementing the per-file
/// PostToolUse hook in the `utopia-hooks` skill.
///
/// Tag-based check selection: `--check=setup,artifacts:bloc`,
/// `--skip=structure`. Smart default activates checks based on what
/// the project declares in its pubspec (`artifacts:bloc` only runs if
/// `flutter_bloc` is in deps). `--strict` bypasses activation gates.
class DoctorCommand extends Command<int> {
  DoctorCommand({
    required Logger logger,
    DescribeParser? parser,
    List<Check>? checkRegistry,
  })  : _logger = logger,
        _parser = parser ?? const DescribeParser(),
        _registry = checkRegistry ?? allChecks {
    argParser
      ..addOption(
        'project-root',
        abbr: 'C',
        help: 'Project (or workspace) root to scan. Defaults to CWD.',
      )
      ..addOption(
        'output',
        abbr: 'o',
        help: 'Write JSON report to a file. "-" for stdout (default).',
        defaultsTo: '-',
      )
      ..addMultiOption(
        'check',
        help: 'Run only the specified tags / sub-tags / rule IDs '
            '(e.g. setup, artifacts:bloc, structure.orphan_state). '
            'Comma-separated or repeated.',
        splitCommas: true,
      )
      ..addMultiOption(
        'skip',
        help: 'Exclude the specified tags / sub-tags / rule IDs. '
            'Applied after --check.',
        splitCommas: true,
      )
      ..addMultiOption(
        'file',
        abbr: 'f',
        help: 'Run the shared per-file hooks analysis for these Dart files. '
            'Repeat or comma-separate. Useful for editor hooks and agent per-edit checks.',
        splitCommas: true,
      )
      ..addFlag(
        'strict',
        negatable: false,
        help: 'Bypass activation gates and run every non-skipped check.',
      )
      ..addFlag(
        'pretty',
        defaultsTo: true,
        help: 'Pretty-print JSON. --no-pretty for compact.',
      )
      ..addFlag(
        'human',
        defaultsTo: false,
        negatable: false,
        help: 'Print a human-readable summary to stderr alongside JSON output.',
      )
      ..addOption(
        'fail-on',
        allowed: ['error', 'warning', 'info', 'never'],
        defaultsTo: 'error',
        help: 'Return non-zero when findings at this severity or higher exist.',
      );
  }

  final Logger _logger;
  final DescribeParser _parser;
  final List<Check> _registry;

  @visibleForTesting
  ArgResults? argResultsOverride;

  @override
  ArgResults get argResults => argResultsOverride ?? super.argResults!;

  @override
  String get name => 'doctor';

  @override
  String get description => 'Repo-wide audit (setup, conventions, artifacts, imports, structure).';

  @override
  String get invocation => 'utopia doctor [options]';

  String get projectRoot => (argResults['project-root'] as String?) ?? Directory.current.path;
  String get output => argResults['output'] as String? ?? '-';
  bool get pretty => argResults['pretty'] as bool? ?? true;
  bool get strict => argResults['strict'] as bool? ?? false;
  bool get human => argResults['human'] as bool? ?? false;
  FailOn get failOn => FailOn.fromName(argResults['fail-on'] as String? ?? 'error');
  List<String> get include => List<String>.from(argResults['check'] as List? ?? const []);
  List<String> get skip => List<String>.from(argResults['skip'] as List? ?? const []);
  List<String> get files => List<String>.from(argResults['file'] as List? ?? const []);

  @override
  Future<int> run() async {
    final root = Directory(projectRoot);
    if (!root.existsSync()) {
      _logger.err('Project root does not exist: $projectRoot');
      return ExitCode.noInput.code;
    }

    final report = files.isNotEmpty
        ? _buildFilesReport(root.path)
        : buildDoctorReport(
            describe: _parser.parse(projectRoot),
            projectRoot: projectRoot,
            registry: _registry,
            include: include,
            exclude: skip,
            strict: strict,
          );

    final json = report.toJson();
    final encoded = pretty ? (const JsonEncoder.withIndent('  ')).convert(json) : jsonEncode(json);

    if (output == '-') {
      stdout.writeln(encoded);
    } else {
      File(output).writeAsStringSync('$encoded\n');
    }

    if (human) _printHumanSummary(report);

    return failOn.shouldFail(report.summary) ? ExitCode.software.code : ExitCode.success.code;
  }

  DoctorReport _buildFilesReport(String root) {
    final hooksReport = const HooksAnalyzeEngine().analyzeFiles(projectRoot: root, files: files);
    final summary = DoctorSummary(
      errorCount: hooksReport.findings.where((finding) => finding.severity == Severity.error).length,
      warningCount: hooksReport.findings.where((finding) => finding.severity == Severity.warning).length,
      infoCount: hooksReport.findings.where((finding) => finding.severity == Severity.info).length,
    );
    return DoctorReport(
      schemaVersion: 1,
      projectRoot: hooksReport.projectRoot,
      activeChecks: const ['hooks.analyze_files'],
      findings: hooksReport.findings,
      summary: summary,
    );
  }

  void _printHumanSummary(DoctorReport report) {
    final s = report.summary;
    if (s.errorCount == 0 && s.warningCount == 0 && s.infoCount == 0) {
      stderr.writeln('doctor: no findings across ${report.activeChecks.length} active checks');
      return;
    }
    stderr
      ..writeln('')
      ..writeln('utopia doctor:')
      ..writeln('  errors:   ${s.errorCount}')
      ..writeln('  warnings: ${s.warningCount}')
      ..writeln('  info:     ${s.infoCount}');

    final byRule = <String, int>{};
    for (final f in report.findings) {
      byRule[f.ruleId] = (byRule[f.ruleId] ?? 0) + 1;
    }
    final sorted = byRule.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    for (final e in sorted.take(10)) {
      stderr.writeln('  ${e.value.toString().padLeft(4)}  ${e.key}');
    }
    if (sorted.length > 10) {
      stderr.writeln('  ${(sorted.length - 10).toString().padLeft(4)}  ... (more, see JSON output)');
    }
  }
}

enum FailOn {
  error,
  warning,
  info,
  never;

  static FailOn fromName(String name) => FailOn.values.singleWhere((value) => value.name == name);

  bool shouldFail(DoctorSummary summary) {
    return switch (this) {
      FailOn.error => summary.errorCount > 0,
      FailOn.warning => summary.errorCount > 0 || summary.warningCount > 0,
      FailOn.info => summary.errorCount > 0 || summary.warningCount > 0 || summary.infoCount > 0,
      FailOn.never => false,
    };
  }
}
