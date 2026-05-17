import 'package:flutter/material.dart';

import '../state/{{{name}}}_state.dart';

class {{{name.pascalCase()}}}View extends StatelessWidget {
  const {{{name.pascalCase()}}}View({super.key, required this.state});

  final {{{name.pascalCase()}}}State state;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('{{{name.pascalCase()}}}')),
      body: const Center(child: Text('{{{name.pascalCase()}}} screen')),
    );
  }
}
