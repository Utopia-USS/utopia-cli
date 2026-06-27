import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:utopia_cli/src/generators/brick_locator.dart';
import 'package:utopia_cli/src/version.dart';

String _posix(String path) => path.replaceAll(r'\', '/');

void main() {
  group('BrickLocator', () {
    test('finds bricks present in the repo (dev mode)', () {
      // When running tests, CWD is the package root, so the
      // current-dir candidate matches.
      final result = const BrickLocator().locate('utopia_flutter_app');
      expect(Directory(result).existsSync(), isTrue);
      expect(result.endsWith('utopia_flutter_app'), isTrue);
    });

    test('throws BrickNotFoundException with searched paths for unknown brick',
        () {
      expect(
        () => const BrickLocator().locate('does_not_exist'),
        throwsA(isA<BrickNotFoundException>()
            .having((e) => e.brickName, 'brickName', 'does_not_exist')
            .having((e) => e.searchedPaths, 'searchedPaths', isNotEmpty)),
      );
    });

    test('uses PUB_CACHE before inferred/default cache roots', () {
      final locator = BrickLocator(
        scriptPath: '/opt/utopia/bin/utopia.dart',
        currentDirectory: '/workspace/utopia_cli',
        environment: const {
          'PUB_CACHE': '/custom/pub-cache',
          'HOME': '/home/me'
        },
        directoryExists: (path) =>
            _posix(path) == '/custom/pub-cache/hosted/pub.dev',
        listDirectories: (path) => const [],
      );

      // Candidates are built with the host platform's separators - normalize
      // so the same expectations hold on Windows CI.
      final candidates = locator.candidatesFor('screen').map(_posix).toList();
      expect(
        candidates,
        contains(
            '/custom/pub-cache/hosted/pub.dev/utopia_cli-$packageVersion/bricks/screen'),
      );
      expect(
        candidates.indexOf(
            '/custom/pub-cache/hosted/pub.dev/utopia_cli-$packageVersion/bricks/screen'),
        lessThan(candidates.indexOf(
            '/home/me/.pub-cache/hosted/pub.dev/utopia_cli-$packageVersion/bricks/screen')),
      );
    });

    test('models the Windows Pub Cache layout', () {
      final locator = BrickLocator(
        scriptPath:
            r'C:\Users\me\AppData\Local\Pub\Cache\global_packages\utopia_cli\bin\utopia.dart',
        currentDirectory: r'C:\repo\utopia_cli',
        environment: const {'LOCALAPPDATA': r'C:\Users\me\AppData\Local'},
        directoryExists: (path) =>
            _posix(path) ==
            'C:/Users/me/AppData/Local/Pub/Cache/hosted/pub.dev',
        listDirectories: (path) => const [],
      );

      final normalized = locator.candidatesFor('screen').map(_posix).toList();
      expect(
        normalized,
        contains(
            'C:/Users/me/AppData/Local/Pub/Cache/hosted/pub.dev/utopia_cli-$packageVersion/bricks/screen'),
      );
    });

    test('prefers the exact package version before other hosted versions', () {
      final locator = BrickLocator(
        scriptPath:
            '/home/me/.pub-cache/global_packages/utopia_cli/bin/utopia.dart',
        currentDirectory: '/workspace/utopia_cli',
        environment: const {},
        directoryExists: (path) =>
            _posix(path) == '/home/me/.pub-cache/hosted/pub.dev',
        listDirectories: (path) => const [
          '/home/me/.pub-cache/hosted/pub.dev/utopia_cli-0.1.0',
          '/home/me/.pub-cache/hosted/pub.dev/utopia_cli-9.9.9',
        ],
      );

      final candidates =
          locator.candidatesFor('utopia_flutter_app').map(_posix).toList();
      expect(candidates[1],
          '/home/me/.pub-cache/hosted/pub.dev/utopia_cli-$packageVersion/bricks/utopia_flutter_app');
      expect(candidates[2],
          '/home/me/.pub-cache/hosted/pub.dev/utopia_cli-9.9.9/bricks/utopia_flutter_app');
    });

    test('uses package_config source root for global path or git activations',
        () {
      final temp =
          Directory.systemTemp.createTempSync('utopia_cli_brick_locator_test_');
      addTearDown(() {
        if (temp.existsSync()) temp.deleteSync(recursive: true);
      });

      final globalPackage = Directory(p.join(
        temp.path,
        '.pub-cache',
        'global_packages',
        'utopia_cli',
      ))
        ..createSync(recursive: true);
      final sourcePackage = Directory(p.join(temp.path, 'git', 'utopia_cli'))
        ..createSync(recursive: true);
      final brick = Directory(p.join(
        sourcePackage.path,
        'bricks',
        'utopia_flutter_app',
      ))
        ..createSync(recursive: true);
      Directory(p.join(globalPackage.path, 'bin')).createSync(recursive: true);
      final packageConfigDir =
          Directory(p.join(globalPackage.path, '.dart_tool'))
            ..createSync(recursive: true);
      File(p.join(packageConfigDir.path, 'package_config.json'))
          .writeAsStringSync('''
{
  "configVersion": 2,
  "packages": [
    {
      "name": "utopia_cli",
      "rootUri": "${sourcePackage.absolute.uri}"
    }
  ]
}
''');

      final locator = BrickLocator(
        scriptPath: p.join(globalPackage.path, 'bin', 'utopia.dart'),
        currentDirectory: p.join(temp.path, 'workspace'),
        environment: const {},
      );

      expect(locator.locate('utopia_flutter_app'), p.normalize(brick.path));
    });
  });
}
