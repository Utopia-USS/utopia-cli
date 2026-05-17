import 'dart:io';

import 'package:path/path.dart' as p;

/// Locates an in-repo Mason brick across dev (`dart run`), pub-cache global
/// activation (`dart pub global activate utopia_cli`), and AOT-compiled
/// (`dart compile exe`) invocations.
///
/// Bricks ship under `bricks/<brick_name>/` in the `utopia_cli` package, so
/// the package directory must be found first. We probe in this order:
///
/// 1. Relative to `Platform.script` (works in dev and `dart compile exe`).
/// 2. Pub-cache hosted layout — searches `<pub-cache>/hosted/pub.dev/` for a
///    `utopia_cli-*` directory.
/// 3. Pub-cache global_packages layout — `<pub-cache>/global_packages/utopia_cli/`.
/// 4. Current working directory (last-ditch dev fallback).
///
/// Returns the absolute path to the brick directory, or throws if none of
/// the candidates exist.
class BrickLocator {
  const BrickLocator();

  String locate(String brickName) {
    final candidates = _candidates(brickName);
    for (final candidate in candidates) {
      if (Directory(candidate).existsSync()) return candidate;
    }
    throw BrickNotFoundException(brickName, candidates);
  }

  List<String> _candidates(String brickName) {
    final out = <String>[];

    final scriptPath = Platform.script.toFilePath();
    final scriptDir = p.dirname(scriptPath);

    // 1. Sibling to bin/ — works in dev (bin/utopia.dart) and `dart compile exe`.
    out.add(p.join(p.dirname(scriptDir), 'bricks', brickName));

    // 2. Pub-cache hosted: .pub-cache/hosted/pub.dev/utopia_cli-x.y.z/bricks/<name>
    if (scriptPath.contains('.pub-cache')) {
      final pubCacheRoot = scriptPath.split('.pub-cache').first + '.pub-cache';
      final hostedDir = p.join(pubCacheRoot, 'hosted', 'pub.dev');
      if (Directory(hostedDir).existsSync()) {
        for (final entry in Directory(hostedDir).listSync()) {
          if (entry is Directory && p.basename(entry.path).startsWith('utopia_cli-')) {
            out.add(p.join(entry.path, 'bricks', brickName));
          }
        }
      }

      // 3. Pub-cache global_packages
      out.add(p.join(pubCacheRoot, 'global_packages', 'utopia_cli', 'bricks', brickName));
    }

    // 4. CWD fallback (running tests, ad-hoc).
    out.add(p.join(Directory.current.path, 'bricks', brickName));

    return out;
  }
}

class BrickNotFoundException implements Exception {
  BrickNotFoundException(this.brickName, this.searchedPaths);

  final String brickName;
  final List<String> searchedPaths;

  @override
  String toString() {
    return 'Brick "$brickName" not found. Searched:\n'
        '${searchedPaths.map((p) => '  - $p').join('\n')}\n'
        'If you installed utopia_cli from pub.dev, this is a packaging bug. '
        'Please open an issue at https://github.com/Utopia-USS/utopia-cli/issues';
  }
}
