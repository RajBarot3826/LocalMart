import 'package:flutter/material.dart';

import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/store_screen.dart';
import 'screens/rider_home_screen.dart';
import 'screens/rider_main_screen.dart';
import 'screens/splash_screen.dart';
import 'utils/locale_provider.dart';
import 'utils/cart_manager.dart';
import 'utils/address_manager.dart';
import 'utils/view_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocaleProvider.instance.load();
  await CartManager().init();
  await AddressManager().init();
  await ViewManager.init();
  runApp(const LocalMartApp());
}

class LocalMartApp extends StatefulWidget {
  const LocalMartApp({super.key});

  @override
  State<LocalMartApp> createState() => _LocalMartAppState();
}

class _LocalMartAppState extends State<LocalMartApp> {
  @override
  void initState() {
    super.initState();
    LocaleProvider.instance.addListener(_onLocaleChanged);
  }

  @override
  void dispose() {
    LocaleProvider.instance.removeListener(_onLocaleChanged);
    super.dispose();
  }

  void _onLocaleChanged() {
    setState(() {}); // Rebuilds the entire MaterialApp
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'LocalMart',

      theme: ThemeData(
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: Colors.white,
      ),

      initialRoute: '/',

      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/home': (context) => const HomeScreen(),
        '/stores': (context) => const StoreScreen(),
        '/rider_home': (context) => const RiderHomeScreen(),
        '/rider_main': (context) => const RiderMainScreen(),
      },
    );
  }
}

