import 'model.dart';

Map<String, dynamic> describeRoutesView(Describe describe) {
  return {
    'schema_version': describe.schemaVersion,
    'packages': describe.packages.map((pkg) {
      final routes = pkg.screens
          .where((screen) => screen.route != null)
          .map((screen) => {
                'screen': screen.name,
                'kind': screen.kind.name,
                'file': screen.file,
                'path': screen.route!.path,
                'config_builder': screen.route!.configBuilder,
                'confidence': screen.route!.confidence.name,
              })
          .toList();
      return {
        'name': pkg.name,
        'routing': pkg.routing?.toJson(),
        'routes': routes,
      };
    }).toList(),
  };
}
