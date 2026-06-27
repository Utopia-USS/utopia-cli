import 'dart:convert';
import 'dart:io';

import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;

import '../version.dart';

/// Locates an in-repo Mason brick across dev (`dart run`), pub-cache global
/// activation (`dart pub global activate utopia_cli`), and AOT-compiled
/// (`dart compile exe`) invocations.
///
/// Bricks ship under `bricks/<brick_name>/` in the `utopia_cli` package, so
/// the package directory must be found first. We probe in this order:
///
/// 1. Relative to `Platform.script` (works in dev and `dart compile exe`).
/// 2. Package config next to the global executable — covers `path` and `git`
///    global activations where the package sources live outside
///    `global_packages/`.
/// 3. Pub-cache hosted layout — searches `<pub-cache>/hosted/pub.dev/` for a
///    `utopia_cli-*` directory.
/// 4. Pub-cache global_packages layout — `<pub-cache>/global_packages/utopia_cli/`.
/// 5. Current working directory (last-ditch dev fallback).
///
/// Returns the absolute path to the brick directory, or throws if none of
/// the candidates exist.
class BrickLocator {
  const BrickLocator({
    String? scriptPath,
    String? currentDirectory,
    Map<String, String>? environment,
    bool Function(String path)? directoryExists,
    bool Function(String path)? fileExists,
    String Function(String path)? readFile,
    List<String> Function(String path)? listDirectories,
  })  : _scriptPath = scriptPath,
        _currentDirectory = currentDirectory,
        _environment = environment,
        _directoryExists = directoryExists,
        _fileExists = fileExists,
        _readFile = readFile,
        _listDirectories = listDirectories;

  final String? _scriptPath;
  final String? _currentDirectory;
  final Map<String, String>? _environment;
  final bool Function(String path)? _directoryExists;
  final bool Function(String path)? _fileExists;
  final String Function(String path)? _readFile;
  final List<String> Function(String path)? _listDirectories;

  String locate(String brickName) {
    final candidates = _candidates(brickName);
    for (final candidate in candidates) {
      if (_exists(candidate)) return candidate;
    }
    throw BrickNotFoundException(brickName, candidates);
  }

  @visibleForTesting
  List<String> candidatesFor(String brickName) => _candidates(brickName);

  List<String> _candidates(String brickName) {
    final out = <String>[];

    final scriptPath = _scriptPath ?? Platform.script.toFilePath();
    final scriptDir = p.dirname(scriptPath);

    // 1. Sibling to bin/ — works in dev (bin/utopia.dart) and `dart compile exe`.
    out.add(p.join(p.dirname(scriptDir), 'bricks', brickName));

    final packageConfigRoot = _packageRootFromPackageConfig(scriptDir);
    if (packageConfigRoot != null) {
      out.add(p.join(packageConfigRoot, 'bricks', brickName));
    }

    for (final pubCacheRoot in _pubCacheRoots(scriptPath)) {
      final hostedDir = p.join(pubCacheRoot, 'hosted', 'pub.dev');
      out.add(
          p.join(hostedDir, 'utopia_cli-$packageVersion', 'bricks', brickName));
      if (_exists(hostedDir)) {
        final hostedPackages = _listDirs(hostedDir)
            .where((path) => p.basename(path).startsWith('utopia_cli-'))
            .where((path) => !p.basename(path).endsWith('-$packageVersion'))
            .toList()
          ..sort((a, b) => p.basename(b).compareTo(p.basename(a)));
        for (final packageDir in hostedPackages) {
          out.add(p.join(packageDir, 'bricks', brickName));
        }
      }

      // 4. Pub-cache global_packages
      out.add(p.join(
          pubCacheRoot, 'global_packages', 'utopia_cli', 'bricks', brickName));
    }

    // 5. CWD fallback (running tests, ad-hoc).
    out.add(p.join(
        _currentDirectory ?? Directory.current.path, 'bricks', brickName));

    return _dedupe(out);
  }

  List<String> _pubCacheRoots(String scriptPath) {
    final env = _environment ?? Platform.environment;
    final roots = <String>[];

    final explicit = env['PUB_CACHE'];
    if (explicit != null && explicit.isNotEmpty) roots.add(explicit);

    final inferred = _inferPubCacheRoot(scriptPath);
    if (inferred != null) roots.add(inferred);

    final localAppData = env['LOCALAPPDATA'];
    if (localAppData != null && localAppData.isNotEmpty) {
      roots.add(p.join(localAppData, 'Pub', 'Cache'));
    }

    final home = env['HOME'];
    if (home != null && home.isNotEmpty) {
      roots.add(p.join(home, '.pub-cache'));
    }

    return _dedupe(roots);
  }

  String? _inferPubCacheRoot(String scriptPath) {
    final pubCacheIndex = scriptPath.indexOf('.pub-cache');
    if (pubCacheIndex != -1) {
      return scriptPath.substring(0, pubCacheIndex + '.pub-cache'.length);
    }

    final normalized = scriptPath.replaceAll(r'\', '/');
    final windowsCacheIndex = normalized.toLowerCase().indexOf('/pub/cache');
    if (windowsCacheIndex != -1) {
      return normalized.substring(0, windowsCacheIndex + '/Pub/Cache'.length);
    }
    return null;
  }

  bool _exists(String path) =>
      _directoryExists?.call(path) ?? Directory(path).existsSync();

  bool _fileExistsAt(String path) =>
      _fileExists?.call(path) ?? File(path).existsSync();

  String _readFileAt(String path) =>
      _readFile?.call(path) ?? File(path).readAsStringSync();

  List<String> _listDirs(String path) {
    final injected = _listDirectories;
    if (injected != null) return injected(path);
    return Directory(path)
        .listSync()
        .whereType<Directory>()
        .map((entry) => entry.path)
        .toList();
  }

  List<String> _dedupe(List<String> input) {
    final seen = <String>{};
    final out = <String>[];
    for (final item in input) {
      if (seen.add(item)) out.add(item);
    }
    return out;
  }

  String? _packageRootFromPackageConfig(String startDirectory) {
    for (final configPath in _packageConfigCandidates(startDirectory)) {
      if (!_fileExistsAt(configPath)) continue;
      try {
        final json =
            jsonDecode(_readFileAt(configPath)) as Map<String, dynamic>;
        final packages = json['packages'];
        if (packages is! List) continue;
        Map<String, dynamic>? package;
        for (final entry in packages) {
          if (entry is Map<String, dynamic> && entry['name'] == 'utopia_cli') {
            package = entry;
            break;
          }
        }
        final rootUri = package?['rootUri'];
        if (rootUri is! String || rootUri.isEmpty) continue;

        final configUri = File(configPath).absolute.uri;
        final packageUri = configUri.resolve(rootUri);
        return p.normalize(packageUri.toFilePath());
      } on Object {
        // Ignore malformed package configs and continue probing other layouts.
      }
    }
    return null;
  }

  List<String> _packageConfigCandidates(String startDirectory) {
    final out = <String>[];
    var current = p.normalize(startDirectory);
    while (true) {
      out.add(p.join(current, '.dart_tool', 'package_config.json'));
      final parent = p.dirname(current);
      if (parent == current) break;
      current = parent;
    }
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
