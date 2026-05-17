import 'dart:io';

import 'package:yaml/yaml.dart';

/// Optional project-level config loaded from `.utopia.yaml` in the current
/// directory or any parent. Used to provide defaults for CLI flags without
/// polluting `$HOME`.
///
/// Schema (all keys optional):
///
/// ```yaml
/// # .utopia.yaml
/// org: io.utopiasoft
/// platforms: android,ios
/// skills: true
/// lints: utopia_lints   # or: very_good_analysis, flutter_lints
/// ```
class UtopiaConfig {
  const UtopiaConfig({
    this.org,
    this.platforms,
    this.skills,
    this.lints,
  });

  final String? org;
  final String? platforms;
  final bool? skills;
  final String? lints;

  static const empty = UtopiaConfig();

  /// Walks up from [start] looking for `.utopia.yaml`. Returns [empty] if
  /// none is found or the file fails to parse.
  static UtopiaConfig load({Directory? start}) {
    var dir = start ?? Directory.current;
    for (var i = 0; i < 12; i++) {
      final file = File('${dir.path}/.utopia.yaml');
      if (file.existsSync()) return _parse(file.readAsStringSync());
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }
    return empty;
  }

  static UtopiaConfig _parse(String contents) {
    try {
      final doc = loadYaml(contents);
      if (doc is! YamlMap) return empty;
      return UtopiaConfig(
        org: doc['org'] as String?,
        platforms: doc['platforms'] as String?,
        skills: doc['skills'] as bool?,
        lints: doc['lints'] as String?,
      );
    } on Object {
      return empty;
    }
  }
}
