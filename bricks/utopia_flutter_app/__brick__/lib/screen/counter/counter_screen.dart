import 'package:{{package_name}}/screen/counter/state/counter_state.dart';
import 'package:{{package_name}}/screen/counter/view/counter_view.dart';
import 'package:flutter/widgets.dart';
import 'package:utopia_arch/utopia_arch.dart';

/// Sample feature — demonstrates the Utopia Screen/State/View pattern.
/// Delete this once you've copied the pattern into your own first screen.
class CounterScreen extends HookWidget {
  const CounterScreen({super.key});

  static const route = '/counter';
  static final routeConfig = RouteConfig.material(CounterScreen.new);

  @override
  Widget build(BuildContext context) {
    final state = useCounterState();
    return CounterView(state: state);
  }
}
