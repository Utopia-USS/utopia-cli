import 'dart:io';

import 'package:test/test.dart';
import 'package:utopia_cli/src/generators/brick_locator.dart';

void main() {
  group('BrickLocator', () {
    test('finds bricks present in the repo (dev mode)', () {
      // When running tests, CWD is the package root, so the
      // current-dir candidate matches.
      final result = const BrickLocator().locate('utopia_flutter_app');
      expect(Directory(result).existsSync(), isTrue);
      expect(result.endsWith('utopia_flutter_app'), isTrue);
    });

    test('throws BrickNotFoundException with searched paths for unknown brick', () {
      expect(
        () => const BrickLocator().locate('does_not_exist'),
        throwsA(isA<BrickNotFoundException>()
            .having((e) => e.brickName, 'brickName', 'does_not_exist')
            .having((e) => e.searchedPaths, 'searchedPaths', isNotEmpty)),
      );
    });
  });
}
