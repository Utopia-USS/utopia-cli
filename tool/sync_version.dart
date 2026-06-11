// Regenerates lib/src/version.dart from pubspec.yaml.
// Usage: dart run tool/sync_version.dart

import 'dart:io';

void main() {
  final pubspec = File('pubspec.yaml').readAsStringSync();
  final match = RegExp(r'^version:\s*(.+)$', multiLine: true).firstMatch(pubspec);
  if (match == null) {
    stderr.writeln('Could not find version: in pubspec.yaml');
    exit(1);
  }
  final version = match.group(1)!.trim();
  final file = File('lib/src/version.dart');

  // Idempotent: leave the file untouched when already in sync, so the CI
  // gate's `git status` check stays clean regardless of platform line
  // endings (Windows checkouts may use CRLF).
  if (file.existsSync() && file.readAsStringSync().contains("const packageVersion = '$version';")) {
    stdout.writeln('lib/src/version.dart already at $version');
    return;
  }

  final out = '// GENERATED - keep in sync with pubspec.yaml. Run tool/sync_version.dart\n'
      '// after bumping the pubspec version.\n'
      "const packageVersion = '$version';\n";
  file.writeAsStringSync(out);
  stdout.writeln('Wrote version $version to lib/src/version.dart');
}
