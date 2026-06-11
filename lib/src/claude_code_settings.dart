import 'dart:convert';

import 'strings.dart' as strings;

Map<String, dynamic>? tryDecodeClaudeSettings(String content) {
  try {
    final decoded = jsonDecode(content);
    if (decoded is Map<String, dynamic>) return decoded;
  } on FormatException {
    return null;
  }
  return null;
}

bool hasUtopiaClaudeSettings(Map<String, dynamic> settings) {
  final enabledPlugins = settings['enabledPlugins'];
  final marketplaces = settings['extraKnownMarketplaces'];

  final pluginEnabled = enabledPlugins is Map &&
      (enabledPlugins[strings.utopiaHooksPluginKey] == true || enabledPlugins[strings.utopiaHooksPluginKey] == 'true');
  final marketplaceRegistered = marketplaces is Map &&
      marketplaces[strings.utopiaSkillsMarketplaceName] is Map &&
      ((marketplaces[strings.utopiaSkillsMarketplaceName] as Map)['source'] as Map?)?['repo'] ==
          strings.utopiaSkillsMarketplaceSlug;

  return pluginEnabled && marketplaceRegistered;
}

bool usesLegacyClaudeSettings(Map<String, dynamic> settings) {
  return settings['marketplaces'] is List || settings['enabledPlugins'] is List;
}
