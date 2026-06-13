import '../describe/model.dart' as desc;
import 'check.dart';
import 'model.dart';

DoctorReport buildDoctorReport({
  required desc.Describe describe,
  required String projectRoot,
  required List<Check> registry,
  List<String> include = const [],
  List<String> exclude = const [],
  bool strict = false,
}) {
  final selection = CheckSelection(include: include, exclude: exclude, strict: strict);
  final activeChecks = registry.where((check) => selection.shouldRun(check, describe)).toList();

  final findings = <Finding>[];
  for (final check in activeChecks) {
    try {
      findings.addAll(check.run(describe, projectRoot));
    } on Object catch (e) {
      findings.add(Finding(
        ruleId: check.id,
        tag: check.tag,
        subTag: check.subTag,
        severity: Severity.error,
        message: 'Check ${check.id} crashed: $e',
        context: {'crashed_check': true, 'exception': e.toString()},
      ));
    }
  }

  final summary = DoctorSummary(
    errorCount: findings.where((f) => f.severity == Severity.error).length,
    warningCount: findings.where((f) => f.severity == Severity.warning).length,
    infoCount: findings.where((f) => f.severity == Severity.info).length,
  );

  return DoctorReport(
    schemaVersion: 1,
    projectRoot: projectRoot,
    activeChecks: activeChecks.map((check) => check.id).toList(),
    findings: findings,
    summary: summary,
  );
}
