import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;

import '../doctor/model.dart';
import 'hooks_analyze_engine.dart';

/// `utopia hooks analyze` - fast utopia_hooks convention analysis.
class HooksAnalyzeCommand extends Command<int> {
  HooksAnalyzeCommand({
    required Logger logger,
    HooksAnalyzeEngine? engine,
  })  : _logger = logger,
        _engine = engine ?? const HooksAnalyzeEngine() {
    argParser
      ..addOption(
        'project-root',
        abbr: 'C',
        help: 'Project (or workspace) root. Defaults to CWD.',
      )
      ..addMultiOption(
        'file',
        abbr: 'f',
        help: 'File(s) to analyze. Repeat or comma-separate. Positional paths are also accepted.',
        splitCommas: true,
      )
      ..addFlag(
        'changed',
        negatable: false,
        help: 'Analyze changed git working-tree files. This is the default when no target is supplied.',
      )
      ..addFlag(
        'all',
        negatable: false,
        help: 'Analyze every Dart file under the project root.',
      )
      ..addFlag(
        'hook-json',
        negatable: false,
        hide: true,
        help: 'Read agent hook JSON from stdin and check tool_input.file_path.',
      )
      ..addOption(
        'format',
        allowed: const ['human', 'json'],
        defaultsTo: 'human',
        help: 'Output format.',
      )
      ..addOption(
        'output',
        abbr: 'o',
        help: 'Write JSON report to this file. "-" writes to stdout.',
        defaultsTo: '-',
      )
      ..addOption(
        'fail-on',
        allowed: const ['error', 'warning', 'info', 'never'],
        defaultsTo: 'warning',
        help: 'Lowest severity that should produce a non-zero exit code.',
      );
  }

  final Logger _logger;
  final HooksAnalyzeEngine _engine;

  @visibleForTesting
  ArgResults? argResultsOverride;

  @override
  ArgResults get argResults => argResultsOverride ?? super.argResults!;

  @override
  String get name => 'analyze';

  @override
  String get description => 'Analyze utopia_hooks Screen/State/View conventions.';

  @override
  String get invocation => 'utopia hooks analyze [paths...] [--file path | --changed | --all]';

  String get projectRoot => (argResults['project-root'] as String?) ?? Directory.current.path;
  List<String> get targetFiles => [
        ...List<String>.from(argResults['file'] as List? ?? const []),
        ...argResults.rest,
      ];
  bool get changed => argResults['changed'] as bool? ?? false;
  bool get all => argResults['all'] as bool? ?? false;
  bool get hookJson => argResults['hook-json'] as bool? ?? false;
  String get format => argResults['format'] as String? ?? 'human';
  String get output => argResults['output'] as String? ?? '-';
  String get failOn => argResults['fail-on'] as String? ?? 'warning';

  @override
  Future<int> run() async {
    final root = p.normalize(p.absolute(projectRoot));
    final explicitTargetCount =
        (targetFiles.isNotEmpty ? 1 : 0) + (changed ? 1 : 0) + (all ? 1 : 0) + (hookJson ? 1 : 0);
    if (explicitTargetCount > 1) {
      usageException('Choose only one target mode: --file, --changed, --all, or --hook-json.');
    }

    final resolvedTargetFiles = await _resolveTargetFiles(root);
    final report = all
        ? _engine.analyzeAll(projectRoot: root)
        : _engine.analyzeFiles(
            projectRoot: root,
            files: resolvedTargetFiles,
          );

    if (format == 'json') {
      _writeJson(report);
    } else {
      _writeHuman(report, quietWhenClean: hookJson);
    }

    if (_hasFailingFindings(report.findings)) {
      if (hookJson && Platform.environment['UTOPIA_HOOKS_MODE'] == 'block') {
        return 2;
      }
      return 1;
    }
    return ExitCode.success.code;
  }

  Future<List<String>> _resolveTargetFiles(String root) async {
    if (hookJson) {
      final payload = await stdin.transform(utf8.decoder).join();
      final file = _fileFromHookPayload(payload);
      return file == null ? const [] : [file];
    }
    if (targetFiles.isNotEmpty) return targetFiles;
    if (all) return const [];
    try {
      return await _engine.changedFiles(projectRoot: root);
    } on StateError catch (e) {
      throw UsageException(e.message, usage);
    }
  }

  String? _fileFromHookPayload(String payload) {
    if (payload.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map<String, dynamic>) return null;
      final toolInput = decoded['tool_input'];
      if (toolInput is! Map<String, dynamic>) return null;
      final file = toolInput['file_path'];
      return file is String && file.isNotEmpty ? file : null;
    } on Object {
      return null;
    }
  }

  void _writeJson(HooksAnalyzeReport report) {
    final encoded = const JsonEncoder.withIndent('  ').convert(report.toJson());
    if (output == '-') {
      stdout.writeln(encoded);
    } else {
      File(output).writeAsStringSync('$encoded\n');
    }
  }

  void _writeHuman(HooksAnalyzeReport report, {required bool quietWhenClean}) {
    if (report.findings.isEmpty) {
      if (!quietWhenClean) {
        _logger.info('✓ utopia hooks analyze: clean (${report.analyzedFiles.length} file(s) checked)');
      }
      return;
    }

    _logger
      ..err('utopia hooks analyze: ${report.findings.length} finding(s) across ${report.analyzedFiles.length} file(s)')
      ..info('');

    for (final finding in report.findings) {
      final location = finding.file == null
          ? ''
          : finding.line == null
              ? '${finding.file}: '
              : '${finding.file}:${finding.line}: ';
      _logger.warn('$location${finding.ruleId}: ${finding.message}');
      if (finding.fix != null) _logger.info('  fix: ${finding.fix}');
    }
  }

  bool _hasFailingFindings(List<Finding> findings) {
    if (failOn == 'never') return false;
    final threshold = _severityRank(failOn);
    return findings.any((f) => _severityRank(f.severity.name) >= threshold);
  }

  int _severityRank(String severity) {
    switch (severity) {
      case 'error':
        return 3;
      case 'warning':
        return 2;
      case 'info':
        return 1;
      case 'never':
        return 4;
      default:
        return 2;
    }
  }
}
