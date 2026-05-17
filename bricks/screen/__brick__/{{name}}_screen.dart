import 'package:flutter/widgets.dart';
import 'package:utopia_arch/utopia_arch.dart';

import 'state/{{{name}}}_state.dart';
import 'view/{{{name}}}_view.dart';

class {{{name.pascalCase()}}}Screen extends HookWidget {
  const {{{name.pascalCase()}}}Screen({super.key});

  static const route = '{{{route}}}';
  static final routeConfig = RouteConfig.material({{{name.pascalCase()}}}Screen.new);

  @override
  Widget build(BuildContext context) {
    final state = use{{{name.pascalCase()}}}State();
    return {{{name.pascalCase()}}}View(state: state);
  }
}
