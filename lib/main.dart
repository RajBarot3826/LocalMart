import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

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
import 'services/notification_service.dart';
import 'services/fcm_service.dart';

/// Top-level background message handler for FCM
/// Must be a top-level function (not a class method) for Firebase to call it
/// when the app is completely killed/terminated.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kIsWeb) return;
  await Firebase.initializeApp();
  debugPrint("🔔 FCM Background message received: ${message.notification?.title}");
  // The notification is automatically shown by the system when app is in background/terminated
  // No need to show local notification here — Android handles it automatically
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb) {
    try {
      // Initialize Firebase FIRST (required for FCM)
      await Firebase.initializeApp();

      // Register the background message handler for when app is killed
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    } catch (e) {
      debugPrint("⚠️ Firebase init skipped or failed: $e");
    }
  }

  await LocaleProvider.instance.load();
  await CartManager().init();
  await AddressManager().init();
  await ViewManager.init();

  if (!kIsWeb) {
    try {
      await NotificationService().init();
      // Initialize FCM push notifications (token + listeners)
      await FcmService().init();
    } catch (e) {
      debugPrint("⚠️ Mobile services init skipped or failed: $e");
    }
  }

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
