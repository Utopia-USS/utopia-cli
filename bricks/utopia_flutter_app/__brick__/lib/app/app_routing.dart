import 'package:{{package_name}}/screen/counter/counter_screen.dart';
import 'package:{{package_name}}/screen/splash/splash_screen.dart';
import 'package:utopia_arch/utopia_arch.dart';


class AppRouting {
  static final routes = <String, RouteConfig>{
    SplashScreen.route: SplashScreen.routeConfig,
    CounterScreen.route: CounterScreen.routeConfig,
  };

  static const initialRoute = SplashScreen.route;
}
