import 'package:flutter/foundation.dart';
import 'package:utopia_arch/utopia_arch.dart';

/// View-facing state for the Counter screen.
///
/// Demonstrates the Utopia Screen/State/View pattern:
///   * a hook builds the state (`useCounterState`)
///   * the state is a plain value class (this)
///   * the view receives the state and never owns it (`CounterView`)
@immutable
class CounterState {
  const CounterState({required this.count, required this.increment});

  final int count;
  final VoidCallback increment;
}

CounterState useCounterState() {
  final count = useState(0);
  return CounterState(
    count: count.value,
    increment: () => count.value = count.value + 1,
  );
}
