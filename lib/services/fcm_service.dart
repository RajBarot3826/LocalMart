import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/api_handler.dart';
import 'notification_service.dart';

/// Firebase Cloud Messaging service — handles push notifications
/// even when the app is closed, killed, or phone screen is off.
class FcmService {
  static final FcmService _instance = FcmService._internal();
  factory FcmService() => _instance;
  FcmService._internal();

  FirebaseMessaging? get _messaging => kIsWeb ? null : FirebaseMessaging.instance;
  bool _isInitialized = false;

  /// Initialize FCM — call after Firebase.initializeApp()
  Future<void> init() async {
    if (kIsWeb) {
      debugPrint("ℹ️ FCM skipped on Web platform.");
      return;
    }
    if (_isInitialized) return;

    final msg = _messaging;
    if (msg == null) return;

    // 1. Request notification permission (iOS + Android 13+)
    NotificationSettings settings = await msg.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    debugPrint("🔔 FCM Permission: ${settings.authorizationStatus}");

    // 2. Get FCM device token and save to backend
    await _getAndSaveToken();

    // 3. Listen for token refresh (token can change over time)
    msg.onTokenRefresh.listen((newToken) {
      debugPrint("🔄 FCM Token refreshed: $newToken");
      _saveTokenToBackend(newToken);
    });

    // 4. Handle foreground messages — show as local notification
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint("🔔 FCM Foreground message: ${message.notification?.title}");
      _showLocalNotification(message);
    });

    // 5. Handle notification tap when app was in background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint("📱 FCM Notification tapped (background): ${message.data}");
      // Could navigate to order screen here if needed
    });

    // 6. Check if app was opened from a terminated state notification
    RemoteMessage? initialMessage = await msg.getInitialMessage();
    if (initialMessage != null) {
      debugPrint("🚀 App opened from terminated notification: ${initialMessage.data}");
    }

    _isInitialized = true;
    debugPrint("✅ FCM Service initialized successfully.");
  }

  /// Force fetch and save the FCM token (e.g., after login)
  Future<void> updateToken() async {
    await _getAndSaveToken();
  }

  /// Get the FCM device token and save it to backend
  Future<void> _getAndSaveToken() async {
    if (kIsWeb) return;
    try {
      final msg = _messaging;
      if (msg == null) return;
      String? token = await msg.getToken();
      if (token != null) {
        debugPrint("🔑 FCM Token: $token");
        await _saveTokenToBackend(token);
      } else {
        debugPrint("⚠️ FCM Token is null");
      }
    } catch (e) {
      debugPrint("❌ Error getting FCM token: $e");
    }
  }

  /// Save FCM token to your PHP backend so server can send push notifications
  Future<void> _saveTokenToBackend(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final phone = prefs.getString('userPhone') ?? '';
      final userId = prefs.getInt('userId') ?? 0;
      final userRole = prefs.getString('userRole') ?? 'customer';

      if (phone.isEmpty && userId == 0) {
        debugPrint("⚠️ No user logged in, skipping FCM token save.");
        return;
      }

      // Save token locally
      await prefs.setString('fcm_token', token);

      // Send to backend
      final response = await ApiHandler.post('save_fcm_token.php', {
        'phone': phone,
        'user_id': userId.toString(),
        'fcm_token': token,
        'role': userRole,
        'platform': 'android',
      });

      if (response != null && (response['status'] == true || response['success'] == true)) {
        debugPrint("✅ FCM token saved to backend successfully.");
      } else {
        debugPrint("⚠️ Backend FCM token save response: $response");
      }
    } catch (e) {
      debugPrint("❌ Error saving FCM token to backend: $e");
    }
  }

  /// Convert FCM message to local notification (for foreground display)
  void _showLocalNotification(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    NotificationService().showNotification(
      id: message.hashCode.abs() % 100000,
      title: notification.title ?? '📦 LocalMart',
      body: notification.body ?? 'You have a new update!',
      payload: message.data['order_id']?.toString() ?? '',
    );
  }

  /// Get the current FCM token (useful for debugging)
  Future<String?> getToken() async {
    if (kIsWeb) return null;
    final msg = _messaging;
    return await msg?.getToken();
  }
}
