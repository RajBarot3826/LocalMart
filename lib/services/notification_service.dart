import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/api_handler.dart';
import 'ai_assistant_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  
  bool _isInitialized = false;
  Timer? _backgroundSyncTimer;
  final Map<String, String> _lastKnownOrderStatus = {};

  /// Initialize notification plugin and create high priority channel
  Future<void> init() async {
    if (_isInitialized) return;

    // Request Android 13+ Notification Permission
    try {
      if (await Permission.notification.isDenied) {
        await Permission.notification.request();
      }
    } catch (e) {
      debugPrint("Notification permission request error: $e");
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        debugPrint("🔔 Notification clicked with payload: ${details.payload}");
      },
    );

    _isInitialized = true;
    startBackgroundOrderSync();
    debugPrint("✅ NotificationService initialized successfully.");
  }

  /// Starts continuous global order notification syncing across the app lifecycle
  void startBackgroundOrderSync() {
    _backgroundSyncTimer?.cancel();
    _backgroundSyncTimer = Timer.periodic(const Duration(seconds: 8), (timer) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final phone = prefs.getString('userPhone') ?? '';
        if (phone.isEmpty) return;

        final response = await ApiHandler.get('get_orders.php?phone=$phone');
        if (response != null) {
          List<dynamic> ordersList = [];
          if (response is Map && response.containsKey('orders')) {
            ordersList = response['orders'] ?? [];
          } else if (response is List) {
            ordersList = response;
          }

          for (var o in ordersList) {
            if (o is Map) {
              await checkAndNotifyOrderUpdate(Map<String, dynamic>.from(o));
            }
          }
        }
      } catch (e) {
        debugPrint("Background order sync error: $e");
      }
    });
    debugPrint("🔔 Background order notifier activated (8s interval).");
  }

  /// Trigger a heads-up status bar notification with sound and vibration
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_isInitialized) await init();

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'localmart_orders_channel', // channelId
      'LocalMart Order Updates', // channelName
      channelDescription: 'Real-time push notifications for order updates and live rider tracking.',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'LocalMart Order Update',
      playSound: true,
      enableVibration: true,
      styleInformation: BigTextStyleInformation(''),
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true, presentBadge: true),
    );

    await _flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      platformChannelSpecifics,
      payload: payload,
    );
  }

  /// Automatically inspects an updated order and sends a push notification if status changed
  Future<void> checkAndNotifyOrderUpdate(Map<String, dynamic> orderData) async {
    final String orderId = orderData['order_id']?.toString() ?? '';
    if (orderId.isEmpty) return;

    final String currentStatus = orderData['status']?.toString() ?? 'Placed';
    final String riderStatus = orderData['rider_status']?.toString() ?? '';
    final String storeName = orderData['store_name']?.toString() ?? 'Store';
    final String? riderName = orderData['rider_name']?.toString();

    // Determine active status key
    String effectiveStatus = currentStatus;
    if ((effectiveStatus.toLowerCase() == 'placed' || effectiveStatus.isEmpty) &&
        riderStatus.isNotEmpty &&
        riderStatus.toLowerCase() != 'pending') {
      effectiveStatus = riderStatus;
    }

    final String? previousStatus = _lastKnownOrderStatus[orderId];

    // Initialize first observation
    if (previousStatus == null) {
      _lastKnownOrderStatus[orderId] = effectiveStatus;
      return;
    }

    // If status changed
    if (previousStatus != effectiveStatus) {
      _lastKnownOrderStatus[orderId] = effectiveStatus;

      final String aiMessage = AIAssistantService().generateOrderStatusMessage(
        status: effectiveStatus,
        storeName: storeName,
        riderName: riderName,
        orderId: orderId,
      );

      final int notificationId = orderId.hashCode.abs() % 100000;
      await showNotification(
        id: notificationId,
        title: "📦 Order Update #$orderId",
        body: aiMessage,
        payload: orderId,
      );
      debugPrint("🔔 Triggered Order Notification for $orderId: $effectiveStatus");
    }
  }
}
