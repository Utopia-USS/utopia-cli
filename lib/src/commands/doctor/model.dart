/// Data model for `utopia doctor`.
///
/// Doctor consumes `Describe` (from `commands/describe/parser.dart`) plus
/// raw filesystem reads, and emits structured [Finding] entries.
library;

/// Root output of `utopia doctor`.
class DoctorReport {
  const DoctorReport({
    required this.schemaVersion,
    required this.projectRoot,
    required this.activeChecks,
    required this.findings,
    required this.summary,
  });

  /// Doctor's report schema is independent of describe's. Bumped on changes.
  final int schemaVersion;

  final String projectRoot;

  /// IDs of checks that ran (some may have been skipped by activation gate).
  final List<String> activeChecks;

  final List<Finding> findings;
  final DoctorSummary summary;

  Map<String, dynamic> toJson() => {
        'schema_version': schemaVersion,
        'project_root': projectRoot,
        'active_checks': activeChecks,
        'findings': findings.map((f) => f.toJson()).toList(),
        'summary': summary.toJson(),
      };
}

class DoctorSummary {
  const DoctorSummary({
    required this.errorCount,
    required this.warningCount,
    required this.infoCount,
  });

  final int errorCount;
  final int warningCount;
  final int infoCount;

  bool get hasErrors => errorCount > 0;

  Map<String, dynamic> toJson() => {
        'error_count': errorCount,
        'warning_count': warningCount,
        'info_count': infoCount,
      };
}

/// A single rule violation.
class Finding {
  const Finding({
    required this.ruleId,
    required this.tag,
    this.subTag,
    required this.severity,
    required this.message,
    this.package,
    this.file,
    this.line,
    this.fix,
    this.context = const {},
  });

  /// Stable identifier (e.g. `setup.utopia_arch_missing`).
  final String ruleId;

  /// Top-level category (`setup`, `conventions`, `artifacts`, `imports`, `structure`).
  final String tag;

  /// Optional sub-tag (`artifacts:bloc`).
  final String? subTag;

  final Severity severity;
  final String message;

  /// Name of the package the finding belongs to (matches describe's
  /// `packages[].name`). Null for project-root-level findings.
  final String? package;

  /// Path relative to project root.
  final String? file;
  final int? line;

  /// Optional suggested fix (free-form).
  final String? fix;

  /// Free-form structured context.
  final Map<String, dynamic> context;

  Map<String, dynamic> toJson() => {
        'rule_id': ruleId,
        'tag': tag,
        'sub_tag': subTag,
        'severity': severity.name,
        'message': message,
        'package': package,
        'file': file,
        'line': line,
        'fix': fix,
        'context': context,
      };
}

enum Severity { error, warning, info }
