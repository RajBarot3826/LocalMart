import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import '../utils/api_handler.dart';
import '../theme/app_theme.dart';
import 'invoice_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/notification_service.dart';
import '../services/location_service.dart';
import 'package:firebase_database/firebase_database.dart';

class TrackOrderScreen extends StatefulWidget {
  final Map<String, dynamic> orderData;

  const TrackOrderScreen({super.key, required this.orderData});

  @override
  State<TrackOrderScreen> createState() => _TrackOrderScreenState();
}

class _TrackOrderScreenState extends State<TrackOrderScreen> {
  late Map<String, dynamic> _orderData;
  Timer? _timer;
  bool _isCancelling = false;
  LatLng? _riderLatLng;
  LatLng? _customerLatLng;
  final MapController _riderMapController = MapController();
  StreamSubscription<Position>? _customerLocationSub;
  StreamSubscription<DatabaseEvent>? _riderLocationSub;
  bool _hasRequestedPermission = false;
  bool _mapBoundsFitted = false;

  // ───────────────────────────────────────────
  // Haversine distance calculation (km)
  // ───────────────────────────────────────────
  double _haversineKm(LatLng a, LatLng b) {
    const R = 6371.0; // Earth radius in km
    final dLat = _degToRad(b.latitude - a.latitude);
    final dLng = _degToRad(b.longitude - a.longitude);
    final sinLat = sin(dLat / 2);
    final sinLng = sin(dLng / 2);
    final h = sinLat * sinLat +
        cos(_degToRad(a.latitude)) * cos(_degToRad(b.latitude)) * sinLng * sinLng;
    return 2 * R * asin(sqrt(h));
  }

  double _degToRad(double deg) => deg * (pi / 180);

  /// Estimate ETA in minutes (assuming avg 20 km/h for city delivery)
  int _estimateEtaMinutes(double distanceKm) {
    if (distanceKm <= 0.05) return 1; // Very close
    return max(1, (distanceKm / 20.0 * 60).ceil());
  }

  Future<void> _cancelOrder() async {
    final orderId = _orderData['order_id'];
    if (orderId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Order?'),
        content: const Text('Are you sure you want to cancel this order? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No, keep it')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('Yes, Cancel', style: TextStyle(color: Colors.red))
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isCancelling = true);
    try {
      final response = await ApiHandler.post('cancel_order.php', {'order_id': orderId.toString()});
      if (response != null && response['status'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order cancelled successfully'), backgroundColor: Colors.green));
          setState(() {
            _orderData['status'] = 'Cancelled';
          });
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(response?['message'] ?? 'Failed to cancel order'), backgroundColor: Colors.red));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Network error occurred'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  static const List<String> shortStatuses = [
    "Placed",
    "Confirmed",
    "Prepared",
  ];

  static const List<String> fullStatuses = [
    "Placed",
    "Confirmed",
    "Prepared",
    "Accepted",
    "Arrived_Store",
    "Picked_Up",
    "Arrived_Customer",
    "Delivered"
  ];

  static const Map<String, String> statusDescriptions = {
    "Placed": "Your order has been placed",
    "Confirmed": "Vendor accepted your order",
    "Prepared": "Your items are being packed",
    "Accepted": "Rider assigned and heading to store",
    "Arrived_Store": "Rider has reached the store",
    "Picked_Up": "Rider picked up your order",
    "Arrived_Customer": "Rider is nearby!",
    "Delivered": "Order delivered successfully!",
  };

  static const Map<String, IconData> statusIcons = {
    "Placed": Icons.receipt_long,
    "Confirmed": Icons.check_circle,
    "Prepared": Icons.inventory_2,
    "Accepted": Icons.motorcycle,
    "Arrived_Store": Icons.store,
    "Picked_Up": Icons.takeout_dining,
    "Arrived_Customer": Icons.location_on,
    "Delivered": Icons.home,
  };

  void _subscribeToRiderLocation(int riderId) {
    if (_riderLocationSub != null) return; // Already subscribed

    debugPrint("🔥 Subscribing to live Firebase location for rider_$riderId");
    _riderLocationSub = FirebaseDatabase.instance
        .ref()
        .child('riders')
        .child('rider_$riderId')
        .onValue
        .listen((DatabaseEvent event) {
      if (!mounted) return;
      final data = event.snapshot.value;
      if (data is Map) {
        final lat = double.tryParse(data['lat']?.toString() ?? '');
        final lng = double.tryParse(data['lng']?.toString() ?? '');
        if (lat != null && lng != null && lat.isFinite && lng.isFinite && lat != 0 && lng != 0) {
          setState(() {
            _riderLatLng = LatLng(lat, lng);
          });

          // Auto-fit bounds on first valid rider position
          if (!_mapBoundsFitted) {
            _fitMapBounds();
            _mapBoundsFitted = true;
          }
        }
      }
    }, onError: (e) {
      debugPrint("⚠️ Firebase location subscription error: $e");
    });
  }

  @override
  void initState() {
    super.initState();
    _orderData = widget.orderData;
    _startAutoRefresh();

    final initialRiderId = _orderData['rider_id'];
    if (initialRiderId != null) {
      final rId = int.tryParse(initialRiderId.toString()) ?? 0;
      if (rId > 0) {
        _subscribeToRiderLocation(rId);
      }
    }

    // Request customer location permission after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestCustomerLocation();
    });
  }

  /// Ask customer for location permission and start live GPS tracking
  Future<void> _requestCustomerLocation() async {
    if (_hasRequestedPermission || !mounted) return;
    _hasRequestedPermission = true;

    final hasPerm = await LocationService().requestPermissionWithPrompt(context);
    if (!hasPerm || !mounted) return;

    // Try to get an immediate position
    try {
      Position? pos = await Geolocator.getLastKnownPosition();
      pos ??= await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      ).timeout(const Duration(seconds: 4));

      if (mounted && pos.latitude != 0 && pos.longitude != 0) {
        setState(() {
          _customerLatLng = LatLng(pos!.latitude, pos.longitude);
        });
      }
    } catch (e) {
      debugPrint("📍 Could not get immediate customer position: $e");
    }

    // Start continuous tracking stream
    _customerLocationSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update every 10 meters for customer
      ),
    ).listen((Position position) {
      if (mounted && position.latitude != 0 && position.longitude != 0) {
        setState(() {
          _customerLatLng = LatLng(position.latitude, position.longitude);
        });
      }
    }, onError: (e) {
      debugPrint("❌ Customer position stream error: $e");
    });
  }

  void _startAutoRefresh() {
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) async {
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

          final orderId = _orderData['order_id'];
          final updatedOrder = ordersList.firstWhere(
            (o) => o['order_id'] == orderId,
            orElse: () => null,
          );

          if (updatedOrder != null && mounted) {
            setState(() {
              _orderData = Map<String, dynamic>.from(updatedOrder);
            });
            NotificationService().checkAndNotifyOrderUpdate(_orderData);

            // Subscribe to Firebase tracking if rider is newly assigned
            final riderIdVal = _orderData['rider_id'];
            if (riderIdVal != null) {
              final rId = int.tryParse(riderIdVal.toString()) ?? 0;
              if (rId > 0) {
                _subscribeToRiderLocation(rId);
              }
            }
          }
        }
      } catch (e) {
        debugPrint("Auto-refresh error: $e");
      }
    });
  }

  /// Fit map bounds to show all markers (rider, store, customer, destination)
  void _fitMapBounds() {
    final points = <LatLng>[];
    if (_riderLatLng != null) points.add(_riderLatLng!);
    if (_customerLatLng != null) points.add(_customerLatLng!);

    // Add store location
    final storeLat = double.tryParse(_orderData['store_lat']?.toString() ?? '');
    final storeLng = double.tryParse(_orderData['store_lng']?.toString() ?? '');
    if (storeLat != null && storeLng != null && storeLat.isFinite && storeLng.isFinite) {
      points.add(LatLng(storeLat, storeLng));
    }

    // Add delivery destination
    final delLat = double.tryParse(_orderData['delivery_lat']?.toString() ?? '');
    final delLng = double.tryParse(_orderData['delivery_lng']?.toString() ?? '');
    if (delLat != null && delLng != null && delLat.isFinite && delLng.isFinite) {
      points.add(LatLng(delLat, delLng));
    }

    if (points.length < 2) {
      // If only one point, just center on it
      if (points.length == 1) {
        try {
          _riderMapController.move(points.first, 15.0);
        } catch (_) {}
      }
      return;
    }

    try {
      final bounds = LatLngBounds.fromPoints(points);
      _riderMapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(50),
          maxZoom: 16,
        ),
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    _timer?.cancel();
    _customerLocationSub?.cancel();
    _riderLocationSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orderId = _orderData['order_id']?.toString() ?? 'N/A';
    String status = _orderData['status']?.toString() ?? 'Placed';
    final String riderStatus = _orderData['rider_status']?.toString() ?? '';
    final storeName = _orderData['store_name']?.toString() ?? 'Store';
    final totalAmount = _orderData['total_amount']?.toString() ?? '0';
    final items = _orderData['items'];
    final deliveryFee = _orderData['delivery_fee']?.toString() ?? '0';
    final updatedAt = _orderData['updated_at']?.toString() ?? '';
    
    final riderName = _orderData['rider_name'];
    final riderPhone = _orderData['rider_phone'];
    final vehicleNumber = _orderData['vehicle_number'];
    final hasRider = riderName != null && riderName.toString().trim().isNotEmpty;

    final activeStatuses = hasRider ? fullStatuses : shortStatuses;

    // Prefer rider_status when main status is empty/corrupted/in-progress and rider is assigned
    String statusLower = status.toLowerCase();
    if ((statusLower.isEmpty || statusLower == 'placed' || statusLower == 'in progress' || statusLower == 'in_progress') && 
        hasRider && riderStatus.isNotEmpty && riderStatus.toLowerCase() != 'pending') {
      statusLower = riderStatus.toLowerCase();
    }
    if (statusLower == 'pending') statusLower = 'placed';
    if (statusLower == 'shipped') statusLower = 'picked_up';
    if (statusLower == 'out for delivery') statusLower = 'picked_up';
    if (statusLower == 'assigned') statusLower = 'accepted';

    int currentStatusIndex = activeStatuses.indexWhere((s) => s.toLowerCase() == statusLower);
    if (currentStatusIndex == -1) currentStatusIndex = 0;

    bool isCancelled = statusLower == 'cancelled';
    final bool canCancel = ['placed', 'confirmed', 'prepared', 'accepted', 'arrived_store'].contains(statusLower);

    final isHeadingToStore = ['placed', 'confirmed', 'prepared', 'accepted', 'arrived_store'].contains(statusLower);

    double? customerLat;
    double? customerLng;
    if (_orderData['delivery_lat'] != null) {
      final parsed = double.tryParse(_orderData['delivery_lat'].toString());
      if (parsed != null && parsed.isFinite) customerLat = parsed;
    }
    if (_orderData['delivery_lng'] != null) {
      final parsed = double.tryParse(_orderData['delivery_lng'].toString());
      if (parsed != null && parsed.isFinite) customerLng = parsed;
    }

    double? storeLat;
    double? storeLng;
    if (_orderData['store_lat'] != null) {
      final parsed = double.tryParse(_orderData['store_lat'].toString());
      if (parsed != null && parsed.isFinite) storeLat = parsed;
    }
    if (_orderData['store_lng'] != null) {
      final parsed = double.tryParse(_orderData['store_lng'].toString());
      if (parsed != null && parsed.isFinite) storeLng = parsed;
    }

    // ── ETA / Distance calculation ──
    double? riderDistanceKm;
    int? etaMinutes;
    String? etaLabel;
    if (_riderLatLng != null) {
      if (isHeadingToStore && storeLat != null && storeLng != null) {
        riderDistanceKm = _haversineKm(_riderLatLng!, LatLng(storeLat, storeLng));
        etaLabel = "to Store";
      } else if (customerLat != null && customerLng != null) {
        riderDistanceKm = _haversineKm(_riderLatLng!, LatLng(customerLat, customerLng));
        etaLabel = "to You";
      }
      if (riderDistanceKm != null) {
        etaMinutes = _estimateEtaMinutes(riderDistanceKm);
      }
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Track Order', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: AppTheme.primary,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
                decoration: const BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Order ID: $orderId', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 8),
                    if (isCancelled)
                      const Row(
                        children: [
                          Icon(Icons.cancel, color: Colors.redAccent, size: 20),
                          SizedBox(width: 8),
                          Text('Cancelled', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                        ],
                      )
                    else ...[
                      Row(
                        children: [
                          const Icon(Icons.check_box, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          Text(status, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // ── Zomato-style ETA badge ──
                      if (etaMinutes != null && riderDistanceKm != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.schedule, color: Colors.white, size: 14),
                              const SizedBox(width: 6),
                              Text(
                                'ETA ~$etaMinutes min • ${riderDistanceKm.toStringAsFixed(1)} km $etaLabel',
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.schedule, color: Colors.white, size: 14),
                              SizedBox(width: 6),
                              Text('Estimated Delivery: Today', style: TextStyle(color: Colors.white, fontSize: 12)),
                            ],
                          ),
                        ),
                    ],
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (currentStatusIndex >= 1 && !isCancelled)
                      Container(
                        margin: const EdgeInsets.only(bottom: 15),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange.shade100),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
                              child: Icon(Icons.notifications_active, color: Colors.orange.shade700, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(3)),
                                        child: const Text('NEW', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text('Great news! $storeName has confirmed your order. Get ready!', style: const TextStyle(fontSize: 13)),
                                  if (updatedAt.isNotEmpty)
                                    Text(updatedAt, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                    if (hasRider && !isCancelled)
                      Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 5))],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Delivery Partner', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.dark)),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                                  radius: 25,
                                  child: const Icon(Icons.delivery_dining, color: AppTheme.primary, size: 30),
                                ),
                                const SizedBox(width: 15),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(riderName.toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                      const SizedBox(height: 4),
                                      Text('Vehicle: $vehicleNumber', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                                      if (riderPhone != null && riderPhone.toString().trim().isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text('Phone: $riderPhone', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                                      ],
                                    ],
                                  ),
                                ),
                                if (riderPhone != null && riderPhone.toString().isNotEmpty)
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade50,
                                      shape: BoxShape.circle,
                                    ),
                                    child: IconButton(
                                      icon: const Icon(Icons.call, color: Colors.green),
                                      onPressed: () async {
                                        final phoneStr = riderPhone.toString().trim();
                                        if (phoneStr.isNotEmpty) {
                                          final uri = Uri.parse('tel:$phoneStr');
                                          try {
                                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                                          } catch (e) {
                                            if (!context.mounted) return;
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('Could not launch dialer: $e')),
                                            );
                                          }
                                        }
                                      },
                                    ),
                                  ),
                              ],
                            ),

                            // ── Live Map with all markers ──
                            if (_riderLatLng != null || _customerLatLng != null) ...[
                              const SizedBox(height: 15),
                              const Row(
                                children: [
                                  Icon(Icons.my_location, color: Colors.green, size: 16),
                                  SizedBox(width: 6),
                                  Text("Live Tracking on Map", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green)),
                                ],
                              ),

                              // ── ETA/Distance Info Strip ──
                              if (etaMinutes != null && riderDistanceKm != null)
                                Container(
                                  margin: const EdgeInsets.only(top: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Colors.green.shade600, Colors.green.shade400],
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.two_wheeler, color: Colors.white, size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Rider is ${riderDistanceKm.toStringAsFixed(1)} km away $etaLabel',
                                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.25),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '~$etaMinutes min',
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                              const SizedBox(height: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: SizedBox(
                                  height: 250,
                                  width: double.infinity,
                                  child: Stack(
                                    children: [
                                      FlutterMap(
                                        mapController: _riderMapController,
                                        options: MapOptions(
                                          initialCenter: _riderLatLng ?? _customerLatLng ?? const LatLng(21.7645, 72.1519),
                                          initialZoom: 14.0,
                                        ),
                                        children: [
                                          TileLayer(
                                             urlTemplate: 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}&key=AIzaSyALWv_81PZ-LV1QMDTm1cGC7KkALKepVPM',
                                             userAgentPackageName: 'com.example.localmart',
                                           ),
                                          // Route polylines
                                          PolylineLayer(
                                            polylines: [
                                              // Rider to Store
                                              if (_riderLatLng != null && storeLat != null && storeLng != null && isHeadingToStore)
                                                Polyline(
                                                  points: [_riderLatLng!, LatLng(storeLat, storeLng)],
                                                  color: Colors.blue,
                                                  strokeWidth: 4.0,
                                                ),
                                              // Store to Customer Destination
                                              if (storeLat != null && storeLng != null && customerLat != null && customerLng != null)
                                                Polyline(
                                                  points: [LatLng(storeLat, storeLng), LatLng(customerLat, customerLng)],
                                                  color: Colors.orange,
                                                  strokeWidth: 4.0,
                                                ),
                                              // Rider to Customer Destination (after pickup)
                                              if (_riderLatLng != null && customerLat != null && customerLng != null && !isHeadingToStore)
                                                Polyline(
                                                  points: [_riderLatLng!, LatLng(customerLat, customerLng)],
                                                  color: Colors.green,
                                                  strokeWidth: 4.0,
                                                ),
                                            ],
                                          ),
                                          MarkerLayer(
                                            markers: [
                                              // Store Marker (Blue)
                                              if (storeLat != null && storeLng != null)
                                                Marker(
                                                  point: LatLng(storeLat, storeLng),
                                                  child: Container(
                                                    padding: const EdgeInsets.all(5),
                                                    decoration: const BoxDecoration(
                                                      color: Colors.blue,
                                                      shape: BoxShape.circle,
                                                      boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                                                    ),
                                                    child: const Icon(Icons.store, color: Colors.white, size: 14),
                                                  ),
                                                ),
                                              // Customer Destination Marker (Red)
                                              if (customerLat != null && customerLng != null)
                                                Marker(
                                                  point: LatLng(customerLat, customerLng),
                                                  child: Container(
                                                    padding: const EdgeInsets.all(5),
                                                    decoration: const BoxDecoration(
                                                      color: Colors.red,
                                                      shape: BoxShape.circle,
                                                      boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                                                    ),
                                                    child: const Icon(Icons.flag, color: Colors.white, size: 14),
                                                  ),
                                                ),
                                              // Live Rider Marker (Green scooter)
                                              if (_riderLatLng != null)
                                                Marker(
                                                  point: _riderLatLng!,
                                                  child: Container(
                                                    padding: const EdgeInsets.all(5),
                                                    decoration: const BoxDecoration(
                                                      color: Colors.green,
                                                      shape: BoxShape.circle,
                                                      boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6, spreadRadius: 1)],
                                                    ),
                                                    child: const Icon(Icons.two_wheeler, color: Colors.white, size: 18),
                                                  ),
                                                ),
                                              // Customer Live Location Marker (Purple pulsing dot)
                                              if (_customerLatLng != null)
                                                Marker(
                                                  point: _customerLatLng!,
                                                  child: Container(
                                                    padding: const EdgeInsets.all(6),
                                                    decoration: BoxDecoration(
                                                      color: Colors.deepPurple,
                                                      shape: BoxShape.circle,
                                                      boxShadow: [BoxShadow(color: Colors.deepPurple.withValues(alpha: 0.4), blurRadius: 8, spreadRadius: 2)],
                                                    ),
                                                    child: const Icon(Icons.person, color: Colors.white, size: 14),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      // LIVE badge
                                      Positioned(
                                        top: 6,
                                        left: 6,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.green,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.gps_fixed, color: Colors.white, size: 12),
                                              SizedBox(width: 4),
                                              Text("LIVE", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                            ],
                                          ),
                                        ),
                                      ),
                                      // Re-center / Fit all button
                                      Positioned(
                                        top: 6,
                                        right: 6,
                                        child: GestureDetector(
                                          onTap: _fitMapBounds,
                                          child: Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              shape: BoxShape.circle,
                                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 4)],
                                            ),
                                            child: const Icon(Icons.fullscreen, color: AppTheme.primary, size: 18),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // ── Map Legend ──
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Wrap(
                                  spacing: 12,
                                  runSpacing: 4,
                                  children: [
                                    if (_riderLatLng != null) _legendItem(Colors.green, "Rider"),
                                    if (storeLat != null) _legendItem(Colors.blue, "Store"),
                                    if (customerLat != null) _legendItem(Colors.red, "Destination"),
                                    if (_customerLatLng != null) _legendItem(Colors.deepPurple, "You"),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 5))],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.local_shipping, color: AppTheme.primary, size: 20),
                              SizedBox(width: 8),
                              Text('Delivery Progress', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.dark)),
                            ],
                          ),
                          const SizedBox(height: 25),
                          if (isCancelled)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 32, height: 32,
                                  decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                                  child: const Icon(Icons.cancel, size: 16, color: Colors.white),
                                ),
                                const SizedBox(width: 15),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Cancelled', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent, fontSize: 15)),
                                      const SizedBox(height: 4),
                                      Text('This order was cancelled and will not be delivered.', style: TextStyle(color: Colors.red.shade600, fontSize: 14)),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          else
                            ...activeStatuses.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final s = entry.value;
                              final isCompleted = idx <= currentStatusIndex;
                              final isCurrent = idx == currentStatusIndex;
                              final isLast = idx == activeStatuses.length - 1;

                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Column(
                                    children: [
                                      Container(
                                        width: 32, height: 32,
                                        decoration: BoxDecoration(
                                          color: isCompleted ? AppTheme.primary : Colors.grey.shade300,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          statusIcons[s] ?? Icons.circle,
                                          size: 16,
                                          color: Colors.white,
                                        ),
                                      ),
                                      if (!isLast)
                                        Container(
                                          width: 3, height: 40,
                                          color: isCompleted && idx < currentStatusIndex ? AppTheme.primary : Colors.grey.shade300,
                                        ),
                                    ],
                                  ),
                                  const SizedBox(width: 15),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(s.replaceAll('_', ' '), style: TextStyle(
                                            fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                                            color: isCompleted ? AppTheme.dark : Colors.grey.shade500,
                                            fontSize: isCurrent ? 15 : 14,
                                          )),
                                          const SizedBox(height: 2),
                                          Text(
                                            statusDescriptions[s] ?? '',
                                            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                          ),
                                          if (isCurrent && updatedAt.isNotEmpty)
                                            Text('Updated at $updatedAt', style: TextStyle(fontSize: 11, color: Colors.orange.shade700, fontWeight: FontWeight.bold)),
                                          SizedBox(height: isLast ? 0 : 18),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }),
                        ],
                      ),
                    ),

                    const SizedBox(height: 15),

                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Text('📋 ', style: TextStyle(fontSize: 16)),
                              Text('Order Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.dark)),
                            ],
                          ),
                          const Divider(height: 25),
                          if (items is List)
                            ...items.map((item) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        const Text('🛒 ', style: TextStyle(fontSize: 14)),
                                        Expanded(child: Text(item['product_name']?.toString() ?? item['name']?.toString() ?? 'Product', maxLines: 1, overflow: TextOverflow.ellipsis)),
                                      ],
                                    ),
                                  ),
                                  Text('₹${item['price']?.toString() ?? '0'}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                ],
                              ),
                            )),
                          const Divider(height: 25),
                          if (double.tryParse(deliveryFee) != null && double.parse(deliveryFee) > 0)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Delivery Fee'),
                                  Text('₹$deliveryFee'),
                                ],
                              ),
                            ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total Paid', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              Text('₹$totalAmount', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primary)),
                            ],
                          ),
                        ],
                      ),
                    ),

                    if (statusLower == 'delivered') ...[
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => InvoiceScreen(orderData: _orderData)),
                            );
                          },
                          icon: const Icon(Icons.receipt, color: Colors.white),
                          label: const Text('View Invoice', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],

                    if (canCancel && !isCancelled) ...[
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _isCancelling ? null : _cancelOrder,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _isCancelling
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red))
                              : const Text('Cancel Order', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],

                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Map legend item widget
  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10, height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
      ],
    );
  }
}
