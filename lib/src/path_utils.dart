import 'package:path/path.dart' as p;

/// Paths emitted in JSON contracts (describe, doctor, add screen summaries)
/// are always posix-style, regardless of host platform, so agents and CI
/// parse one deterministic shape.
String posixRelative(String path, {required String from}) => toPosix(p.relative(path, from: from));

String posixJoin(String part1, String part2) => p.posix.join(toPosix(part1), toPosix(part2));

String toPosix(String path) => path.replaceAll(r'\', '/');
