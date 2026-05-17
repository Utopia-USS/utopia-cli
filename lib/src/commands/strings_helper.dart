import '../strings.dart' as strings;

/// Re-exposed helper so files inside lib/src/commands/ can produce a
/// "coming soon" message without each importing `strings.dart` under
/// a different alias.
String comingSoonMessage(String commandName) => strings.comingSoon(commandName);
