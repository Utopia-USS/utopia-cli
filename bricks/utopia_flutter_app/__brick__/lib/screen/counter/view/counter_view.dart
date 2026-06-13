import 'package:flutter/material.dart';
import 'package:{{package_name}}/screen/counter/state/counter_state.dart';

/// Pure view — does not own state, does not call hooks. Receives a
/// [CounterState] and renders it. This is the View half of the
/// Screen/State/View triad.
class CounterView extends StatelessWidget {
  const CounterView({super.key, required this.state});

  final CounterState state;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Counter')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('You have pushed the button this many times:'),
            const SizedBox(height: 8),
            Text(
              '${state.count}',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: state.increment,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
