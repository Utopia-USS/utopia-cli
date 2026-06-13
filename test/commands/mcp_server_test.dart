import 'dart:convert';
import 'dart:io';

import 'package:dart_mcp/server.dart';
import 'package:path/path.dart' as p;
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';
import 'package:utopia_cli/src/commands/mcp/mcp_server.dart';

void main() {
  group('UtopiaMcpServer', () {
    late StreamChannelController<String> channel;
    late UtopiaMcpServer server;
    late Directory tempDir;

    setUp(() {
      channel = StreamChannelController<String>();
      server = UtopiaMcpServer(channel.local);
      tempDir = Directory.systemTemp.createTempSync('utopia_mcp_test_');
    });

    tearDown(() async {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      await server.shutdown();
      await channel.foreign.sink.close();
    });

    test('registers the expected tools', () async {
      final result = await server.listTools();
      final names = result.tools.map((tool) => tool.name).toSet();

      expect(
        names,
        containsAll({
          'describe',
          'describe_routes',
          'doctor',
          'analyze_hooks_files',
          'analyze_hooks_changed',
        }),
      );
    });

    test('describe_routes uses the CLI routes-only shape', () async {
      _writeFile(tempDir, 'pubspec.yaml', _basicPubspec);
      _writeFile(tempDir, 'lib/screen/foo/foo_screen.dart', '''
class FooScreen extends HookWidget {
  static const route = '/foo';
  @override Widget build(BuildContext context) => const SizedBox();
}
''');

      final result = await server.callTool(CallToolRequest(
        name: 'describe_routes',
        arguments: {'project_root': tempDir.path},
      ));

      expect(result.isError, isNot(true));
      final payload = _jsonContent(result);
      final route = ((payload['packages'] as List<dynamic>).single as Map<String, dynamic>)['routes'] as List<dynamic>;
      expect(route.single, containsPair('confidence', 'high'));
    });

    test('doctor reports missing project root as a tool error', () async {
      final missing = p.join(tempDir.path, 'missing');

      final result = await server.callTool(CallToolRequest(
        name: 'doctor',
        arguments: {'project_root': missing},
      ));

      expect(result.isError, isTrue);
      expect((result.content.single as TextContent).text, contains('project root not found'));
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

Map<String, dynamic> _jsonContent(CallToolResult result) {
  final text = (result.content.single as TextContent).text;
  return jsonDecode(text) as Map<String, dynamic>;
}
