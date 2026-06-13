import 'dart:async';

import 'package:{{package_name}}/app/state/initialization/initialization_state.dart';
import 'package:{{package_name}}/screen/counter/counter_screen.dart';
import 'package:flutter/material.dart';
import 'package:utopia_arch/utopia_arch.dart';

class SplashScreen extends HookWidget {
  const SplashScreen({super.key});

  static const route = '/splash';
  static final routeConfig = RouteConfig.material(SplashScreen.new);

  @override
  Widget build(BuildContext context) {
    final initializationState = useProvided<InitializationState>();

    useEffect(() {
      if (initializationState.isInitialized) {
        // Sample wiring: jump to the counter feature once init completes.
        // Replace with your real first screen.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          unawaited(Navigator.of(context).pushReplacementNamed(CounterScreen.route));
        });
      }
      return null;
    }, [initializationState.isInitialized]);

    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
