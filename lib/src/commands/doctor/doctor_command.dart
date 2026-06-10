import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:meta/meta.dart';

import '../describe/parser.dart';
import 'check.dart';
import 'checks.dart';
import 'model.dart';

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
  List<String> get include => List<String>.from(argResults['check'] as List? ?? const []);
  List<String> get skip => List<String>.from(argResults['skip'] as List? ?? const []);

  @override
  Future<int> run() async {
    final describe = _parser.parse(projectRoot);
    final selection = CheckSelection(include: include, exclude: skip, strict: strict);
    final activeChecks = _registry.where((c) => selection.shouldRun(c, describe)).toList();

    final findings = <Finding>[];
    for (final check in activeChecks) {
      try {
        findings.addAll(check.run(describe, projectRoot));
      } on Object catch (e) {
        _logger.warn('Check ${check.id} threw: $e');
      }
    }

    final summary = DoctorSummary(
      errorCount: findings.where((f) => f.severity == Severity.error).length,
      warningCount: findings.where((f) => f.severity == Severity.warning).length,
      infoCount: findings.where((f) => f.severity == Severity.info).length,
    );

    final report = DoctorReport(
      schemaVersion: 1,
      projectRoot: projectRoot,
      activeChecks: activeChecks.map((c) => c.id).toList(),
      findings: findings,
      summary: summary,
    );

    final json = report.toJson();
    final encoded = pretty ? (const JsonEncoder.withIndent('  ')).convert(json) : jsonEncode(json);

    if (output == '-') {
      stdout.writeln(encoded);
    } else {
      File(output).writeAsStringSync('$encoded\n');
    }

    if (human) _printHumanSummary(report);

    return summary.hasErrors ? ExitCode.software.code : ExitCode.success.code;
  }

  void _printHumanSummary(DoctorReport report) {
    final s = report.summary;
    if (s.errorCount == 0 && s.warningCount == 0 && s.infoCount == 0) {
      _logger.info('✓ doctor: no findings across ${report.activeChecks.length} active checks');
      return;
    }
    _logger
      ..info('')
      ..info('utopia doctor:')
      ..info('  errors:   ${s.errorCount}')
      ..info('  warnings: ${s.warningCount}')
      ..info('  info:     ${s.infoCount}');

    final byRule = <String, int>{};
    for (final f in report.findings) {
      byRule[f.ruleId] = (byRule[f.ruleId] ?? 0) + 1;
    }
    final sorted = byRule.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    for (final e in sorted.take(10)) {
      _logger.info('  ${e.value.toString().padLeft(4)}  ${e.key}');
    }
    if (sorted.length > 10) {
      _logger.info('  ${(sorted.length - 10).toString().padLeft(4)}  ... (more, see JSON output)');
    }
  }
}
