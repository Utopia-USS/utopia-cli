/// Check definition + base interfaces for `utopia doctor`.
///
/// Each check declares its tag(s) and an activation gate, and emits
/// [Finding]s. Checks run against the [Describe] from the describe
/// parser plus the project root for filesystem queries.
library;

import '../describe/model.dart';
import 'model.dart';

/// Function that decides if a check should run on this project by default.
///
/// Returns `true` to run. Used for smart conditional activation:
/// - `setup` and `conventions` checks always pass the gate
/// - `artifacts:bloc` activates only if `flutter_bloc` is in pubspec
/// - etc.
typedef CheckActivationGate = bool Function(Describe describe);

/// Function that executes the check and returns findings.
typedef CheckRunner = List<Finding> Function(Describe describe, String projectRoot);

class Check {
  const Check({
    required this.id,
    required this.tag,
    this.subTag,
    required this.description,
    required this.activationGate,
    required this.run,
  });

  /// Stable identifier (`setup.utopia_arch_missing`).
  final String id;

  /// Top-level tag (`setup`, `conventions`, `artifacts`, `imports`, `structure`).
  final String tag;

  /// Optional sub-tag (`bloc`, `riverpod`, `provider`, etc.).
  /// Full tag string is `<tag>:<subTag>` (e.g. `artifacts:bloc`).
  final String? subTag;

  final String description;

  final CheckActivationGate activationGate;
  final CheckRunner run;

  /// `artifacts:bloc` or just `setup`.
  String get fullTag => subTag == null ? tag : '$tag:$subTag';
}

/// Selection rules for which checks to run.
class CheckSelection {
  const CheckSelection({
    this.include = const [],
    this.exclude = const [],
    this.strict = false,
  });

  /// If non-empty, ONLY these tags / IDs run (overrides activation gates).
  final List<String> include;

  /// Tags / IDs that are excluded even if their gate would have passed.
  final List<String> exclude;

  /// If true, ignore activation gates and run every check that isn't
  /// explicitly excluded.
  final bool strict;

  bool shouldRun(Check check, Describe describe) {
    final tags = [check.tag, check.fullTag, check.id];

    if (exclude.any(tags.contains)) return false;
    if (include.isNotEmpty) return include.any(tags.contains);
    if (strict) return true;
    return check.activationGate(describe);
  }
}

// Helpers ---------------------------------------------------------------------

/// Default activation gate: always run.
bool alwaysGate(Describe _) => true;

/// Gate: run only if any package's pubspec declares one of [foreignDeps]
/// (e.g. `['flutter_bloc']`).
CheckActivationGate gateOnPubspecDep(List<String> foreignDeps) {
  return (Describe describe) {
    for (final pkg in describe.packages) {
      for (final dep in foreignDeps) {
        if (pkg.pubspec.deps.containsKey(dep)) return true;
        if (pkg.pubspec.devDeps.containsKey(dep)) return true;
      }
    }
    return false;
  };
}

/// Gate: run if any package declares `utopia_arch` OR `utopia_hooks` as a
/// dep. Used for `conventions` checks - they only apply to utopia stacks.
bool utopiaStackGate(Describe describe) {
  for (final pkg in describe.packages) {
    if (pkg.pubspec.deps.containsKey('utopia_arch')) return true;
    if (pkg.pubspec.deps.containsKey('utopia_hooks')) return true;
  }
  return false;
}
