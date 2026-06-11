import 'dart:convert';
import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:utopia_cli/src/command_runner.dart';

/// Smoke tests for `utopia describe` against synthetic fixtures.
///
/// These tests build a tiny on-disk Flutter-shaped project per case
/// and assert the schema's structural invariants. Real-world projects
/// (habicy, jolly, qbt, madrosc) are covered manually - see
/// `doc/describe_schema.md`.
void main() {
  group('utopia describe', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('utopia_describe_test_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('emits schema_version 1 on single-package project', () async {
      _writeFile(tempDir, 'pubspec.yaml', '''
name: smoke_app
environment:
  sdk: ">=3.0.0 <4.0.0"
dependencies:
  utopia_arch: ^0.5.1
''');
      _writeFile(tempDir, 'lib/main.dart', 'void main() {}');

      final json = await _runDescribe(tempDir);
      expect(json['schema_version'], 1);
      expect(json['workspace']['type'], 'single_package');
      expect(json['workspace']['tool'], 'none');
      expect(json['packages'], isA<List<dynamic>>());
      expect((json['packages'] as List<dynamic>).length, 1);
      expect(json['packages'][0]['name'], 'smoke_app');
    });

    test('detects Melos monorepo and lists all packages', () async {
      _writeFile(tempDir, 'melos.yaml', '''
name: smoke_workspace
packages:
  - packages/*
''');
      _writeFile(tempDir, 'packages/app/pubspec.yaml', '''
name: app
environment:
  sdk: ">=3.0.0 <4.0.0"
dependencies:
  utopia_arch: ^0.5.1
''');
      _writeFile(tempDir, 'packages/core/pubspec.yaml', '''
name: core
environment:
  sdk: ">=3.0.0 <4.0.0"
''');
      _writeFile(tempDir, 'packages/app/lib/main.dart', 'void main() {}');
      _writeFile(tempDir, 'packages/core/lib/core.dart', '');

      final json = await _runDescribe(tempDir);
      expect(json['workspace']['type'], 'monorepo');
      expect(json['workspace']['tool'], 'melos');
      final packages = json['packages'] as List;
      expect(packages.length, 2);
      expect(packages.map((p) => p['name']).toSet(), {'app', 'core'});
    });

    test('discovers screen + state + view + route in canonical layout', () async {
      _writeFile(tempDir, 'pubspec.yaml', _basicPubspec);
      _writeFile(tempDir, 'lib/screen/home/home_screen.dart', '''
import 'package:utopia_arch/utopia_arch.dart';
class HomeScreen extends HookWidget {
  static const route = '/home';
  static final routeConfig = RouteConfig.material(HomeScreen.new);
  @override Widget build(BuildContext context) => HomeScreenView(state: useHomeScreenState());
}
''');
      _writeFile(tempDir, 'lib/screen/home/state/home_screen_state.dart', '''
class HomeScreenState {}
HomeScreenState useHomeScreenState() => HomeScreenState();
''');
      _writeFile(tempDir, 'lib/screen/home/view/home_screen_view.dart', '''
import 'package:flutter/material.dart';
class HomeScreenView extends StatelessWidget {
  const HomeScreenView({required this.state});
  final dynamic state;
  @override Widget build(BuildContext context) => const SizedBox();
}
''');
      _writeFile(tempDir, 'lib/app/app_routing.dart', '''
class AppRouting {
  static final routes = <String, RouteConfig>{
    HomeScreen.route: HomeScreen.routeConfig,
  };
  static const initialRoute = HomeScreen.route;
}
''');

      final json = await _runDescribe(tempDir);
      final pkg = (json['packages'] as List).first as Map;
      final screens = pkg['screens'] as List;
      expect(screens.length, 1);
      final home = screens.first as Map;
      expect(home['name'], 'HomeScreen');
      expect(home['kind'], 'routed_screen');
      expect((home['states'] as List).length, 1);
      expect((home['views'] as List).length, 1);
      expect(home['route']['path'], '/home');
      expect(home['route']['registered_in'], contains('app_routing.dart'));
      expect(pkg['routing']['strategy'], 'static_const_aggregator');
      expect(pkg['routing']['initial_route'], '/home');
    });

    test('classifies sheet vs dialog vs bare screen', () async {
      _writeFile(tempDir, 'pubspec.yaml', _basicPubspec);
      _writeFile(tempDir, 'lib/screen/auth/auth_sheet.dart', '''
class AuthSheet extends HookWidget {
  static Future<void> show(BuildContext context) async {}
  @override Widget build(BuildContext context) => const SizedBox();
}
''');
      _writeFile(tempDir, 'lib/screen/error/error_dialog.dart', '''
class ErrorDialog extends StatelessWidget {
  static Future<void> show(BuildContext context) async {}
  @override Widget build(BuildContext context) => const SizedBox();
}
''');
      _writeFile(tempDir, 'lib/screen/splash/splash_screen.dart', '''
class SplashScreen extends HookWidget {
  static const route = '/splash';
  @override Widget build(BuildContext context) => const SizedBox();
}
''');

      final json = await _runDescribe(tempDir);
      final screens = (json['packages'][0]['screens'] as List<dynamic>).cast<Map<String, dynamic>>();
      final byName = {for (final s in screens) s['name'] as String: s};
      expect(byName['AuthSheet']!['kind'], 'sheet');
      expect(byName['ErrorDialog']!['kind'], 'dialog');
      expect(byName['SplashScreen']!['kind'], 'bare_screen');
    });

    test('detects foreign artefacts (provider / bloc / stateful)', () async {
      _writeFile(tempDir, 'pubspec.yaml', _basicPubspec);
      _writeFile(tempDir, 'lib/screen/legacy/legacy_screen.dart', '''
import 'package:flutter_bloc/flutter_bloc.dart';
class LegacyScreen extends StatefulWidget {
  @override State<LegacyScreen> createState() => _LegacyScreenState();
}
class _LegacyScreenState extends State<LegacyScreen> {
  final bloc = BlocProvider.of(context);
  @override Widget build(BuildContext context) => Container();
}
''');

      final json = await _runDescribe(tempDir);
      final artefacts = (json['packages'][0]['foreign_artifacts'] as List<dynamic>).cast<Map<String, dynamic>>();
      final frameworks = artefacts.map((a) => a['framework'] as String).toSet();
      expect(frameworks, containsAll(['stateful_widget', 'bloc']));
    });

    test('skips files in lib/common/ (utility widgets are not screens)', () async {
      _writeFile(tempDir, 'pubspec.yaml', _basicPubspec);
      _writeFile(tempDir, 'lib/common/widget/adaptive_sheet.dart', '''
class AdaptiveSheetHandle extends StatelessWidget {
  @override Widget build(BuildContext context) => const SizedBox();
}
''');

      final json = await _runDescribe(tempDir);
      final screens = json['packages'][0]['screens'] as List<dynamic>;
      expect(screens, isEmpty);
    });

    // Regression: BUG 1 from verification workflow - function-based dialogs
    // (top-level showXxx() with no matching widget class) were dropped.
    test('detects function-based dialog (showXxx, no matching class)', () async {
      _writeFile(tempDir, 'pubspec.yaml', _basicPubspec);
      _writeFile(tempDir, 'lib/screen/upsell/upsell_dialog.dart', '''
import 'package:flutter/material.dart';
Future<void> showUpsellDialog(BuildContext context) {
  return showGeneralDialog(context: context, pageBuilder: (_, __, ___) => const UpsellDialogView());
}
''');
      _writeFile(tempDir, 'lib/screen/upsell/view/upsell_dialog_view.dart', '''
import 'package:flutter/material.dart';
class UpsellDialogView extends StatelessWidget {
  const UpsellDialogView();
  @override Widget build(BuildContext context) => const SizedBox();
}
''');
      final json = await _runDescribe(tempDir);
      final screens = (json['packages'][0]['screens'] as List<dynamic>).cast<Map<String, dynamic>>();
      final upsell = screens.where((s) => s['name'] == 'UpsellDialog').toList();
      expect(upsell, hasLength(1), reason: 'function-based dialog should be detected');
      expect(upsell.first['kind'], 'dialog');
      expect((upsell.first['views'] as List<dynamic>).length, 1);
    });

    // Regression: BUG 2 - a screen-state registered in the providers map
    // (hoisted to global) must appear in global_states even though it lives
    // under lib/screen/.../state/ rather than lib/(app/)?state/.
    test('includes hoisted screen-state registered in providers map as global', () async {
      _writeFile(tempDir, 'pubspec.yaml', _basicPubspec);
      _writeFile(tempDir, 'lib/screen/home/state/tile_state.dart', '''
class TileState {}
TileState useTileState() => TileState();
''');
      _writeFile(tempDir, 'lib/app/app.dart', '''
Map<Type, Object? Function()> _buildProviders() => {
  TileState: useTileState,
};
''');
      final json = await _runDescribe(tempDir);
      final pkg = json['packages'][0] as Map<String, dynamic>;
      final globals = (pkg['global_states'] as List<dynamic>).cast<Map<String, dynamic>>();
      final tile = globals.where((g) => g['name'] == 'TileState').toList();
      expect(tile, hasLength(1), reason: 'hoisted screen-state in providers map should be global');
      expect(tile.first['registered_in'], isNotNull);
    });

    // Regression: BUG 3 - Provider.of<>() must be detected as a provider
    // artefact, and patterns inside comments must NOT be detected.
    test('detects Provider.of and skips patterns in comments', () async {
      _writeFile(tempDir, 'pubspec.yaml', _basicPubspec);
      _writeFile(tempDir, 'lib/screen/x/x_screen.dart', '''
import 'package:provider/provider.dart';
class XScreen extends HookWidget {
  static const route = '/x';
  @override Widget build(BuildContext context) {
    // This comment mentions extends StatefulWidget but must NOT be flagged.
    final t = Provider.of<Foo>(context);
    return const SizedBox();
  }
}
''');
      final json = await _runDescribe(tempDir);
      final artefacts = (json['packages'][0]['foreign_artifacts'] as List<dynamic>).cast<Map<String, dynamic>>();
      final providers = artefacts.where((a) => a['framework'] == 'provider').toList();
      expect(providers, isNotEmpty, reason: 'Provider.of<> should be detected');
      // The comment line mentioning StatefulWidget must not produce an artefact.
      final statefulInComment = artefacts.where((a) => a['framework'] == 'stateful_widget').toList();
      expect(statefulInComment, isEmpty, reason: 'pattern in comment must be skipped');
    });

    // Regression: re-verify round - a parameterized (arg-taking) hook in the
    // conventional state/ dir that is NOT registered is a helper, not a global.
    // A no-arg unregistered conventional state (cross-package global pattern)
    // IS still a global.
    test('excludes parameterized unregistered state, keeps no-arg', () async {
      _writeFile(tempDir, 'pubspec.yaml', _basicPubspec);
      // Parameterized hook, not in any providers map -> NOT a global.
      _writeFile(tempDir, 'lib/app/state/deal/deal_state.dart', '''
class DealState {}
DealState useDealState(String? id) => DealState();
''');
      // No-arg hook, not registered here (could be a cross-package global) -> global.
      _writeFile(tempDir, 'lib/app/state/color/color_state.dart', '''
class ColorState {}
ColorState useColorState() => ColorState();
''');
      final json = await _runDescribe(tempDir);
      final globals = (json['packages'][0]['global_states'] as List<dynamic>).cast<Map<String, dynamic>>();
      final names = globals.map((g) => g['name'] as String).toSet();
      expect(names, contains('ColorState'), reason: 'no-arg conventional state is a plausible global');
      expect(names, isNot(contains('DealState')), reason: 'parameterized unregistered state is a helper, not a global');
    });

    test('emits error note + non-zero exit on missing project root', () async {
      final missing = p.join(tempDir.path, 'nope');
      final outFile = File(p.join(tempDir.path, '__d.json'));
      final runner = UtopiaCommandRunner(logger: Logger(level: Level.quiet), disableUpdateCheck: true);
      final exitCode = await runner.run(['describe', '-C', missing, '-o', outFile.path]);
      expect(exitCode, isNot(0));
      final json = jsonDecode(outFile.readAsStringSync()) as Map<String, dynamic>;
      final notes = (json['discovery_notes'] as List<dynamic>).cast<Map<String, dynamic>>();
      expect(notes.any((n) => n['kind'] == 'project_root_not_found' && n['level'] == 'error'), isTrue);
    });

    test('emits warning note when dir has no package (no pubspec)', () async {
      final emptyDir = Directory(p.join(tempDir.path, 'empty'))..createSync();
      final json = await _runDescribe(emptyDir);
      final notes = (json['discovery_notes'] as List<dynamic>).cast<Map<String, dynamic>>();
      expect(notes.any((n) => n['kind'] == 'no_package_found' && n['level'] == 'warning'), isTrue);
      expect(json['packages'], isEmpty);
    });

    test('--routes-only outputs only schema_version and routes view', () async {
      _writeFile(tempDir, 'pubspec.yaml', _basicPubspec);
      _writeFile(tempDir, 'lib/screen/foo/foo_screen.dart', '''
class FooScreen extends HookWidget {
  static const route = '/foo';
  @override Widget build(BuildContext context) => const SizedBox();
}
''');

      final json = await _runDescribe(tempDir, args: ['--routes-only']);
      expect(json['schema_version'], 1);
      expect(json.containsKey('workspace'), isFalse);
      final packages = json['packages'] as List<dynamic>;
      expect(packages, hasLength(1));
      final pkg = packages.first as Map<String, dynamic>;
      expect(pkg['routes'], isA<List<dynamic>>());
      expect((pkg['routes'] as List<dynamic>).length, 1);
      final route = (pkg['routes'] as List).first as Map<String, dynamic>;
      expect(route['path'], '/foo');
      expect(route['confidence'], 'high');
    });
  });
}

const _basicPubspec = '''
name: smoke_app
environment:
  sdk: ">=3.0.0 <4.0.0"
dependencies:
  utopia_arch: ^0.5.1
''';

void _writeFile(Directory root, String relPath, String content) {
  final file = File(p.join(root.path, relPath));
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(content);
}

Future<Map<String, dynamic>> _runDescribe(Directory tempDir, {List<String> args = const []}) async {
  // Write output to a file (avoid mixing with logger noise on stdout).
  final outFile = File(p.join(tempDir.path, '__describe.json'));
  final runner = UtopiaCommandRunner(
    logger: Logger(level: Level.quiet),
    disableUpdateCheck: true,
  );
  final exitCode = await runner.run(['describe', '-C', tempDir.path, '-o', outFile.path, ...args]);
  if (exitCode != 0) {
    throw StateError('describe exited with $exitCode');
  }
  final content = outFile.readAsStringSync();
  return jsonDecode(content) as Map<String, dynamic>;
}
