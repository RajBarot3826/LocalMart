import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/api_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import '../services/location_service.dart';

class RiderActiveTab extends StatefulWidget {
  const RiderActiveTab({super.key});

  @override
  State<RiderActiveTab> createState() => _RiderActiveTabState();
}

class _RiderActiveTabState extends State<RiderActiveTab> {
  int riderId = 0;
  bool isLoading = true;
  bool isUpdating = false;
  Map<String, dynamic>? activeOrder;
  Timer? _refreshTimer;
  LatLng? _riderPosition;
  StreamSubscription? _locationSub;
  final MapController _mapController = MapController();

  double _safeParseDouble(dynamic val, double fallback) {
    if (val == null) return fallback;
    final d = double.tryParse(val.toString());
    if (d == null || !d.isFinite) return fallback;
    return d;
  }

  double? _safeParseNullableDouble(dynamic val) {
    if (val == null) return null;
    final d = double.tryParse(val.toString());
    if (d == null || !d.isFinite) return null;
    return d;
  }

  @override
  void initState() {
    super.initState();
    _loadData();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) _fetchActiveOrder(silent: true);
    });
    // Listen for live GPS updates from LocationService
    _locationSub = LocationService().positionStream.listen((pos) {
      if (mounted) {
        setState(() {
          _riderPosition = LatLng(pos.latitude, pos.longitude);
        });
        // Smoothly pan the map to rider's new position
        try {
          _mapController.move(_riderPosition!, _mapController.camera.zoom);
        } catch (_) {}
      }
    });
    // Use cached position if available, otherwise grab GPS directly
    final lastPos = LocationService().lastPosition;
    if (lastPos != null) {
      _riderPosition = LatLng(lastPos.latitude, lastPos.longitude);
    } else {
      _getImmediatePosition();
    }
  }

  /// Get GPS position directly so rider marker shows instantly
  Future<void> _getImmediatePosition() async {
    try {
      // Check permission first to avoid silent failures
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        debugPrint("📍 GPS permission not granted, skipping immediate position.");
        return;
      }

      Position? pos = await Geolocator.getLastKnownPosition();
      pos ??= await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      ).timeout(const Duration(seconds: 4));

      final position = pos;
      if (mounted) {
        setState(() {
          _riderPosition = LatLng(position.latitude, position.longitude);
        });
        try {
          _mapController.move(_riderPosition!, _mapController.camera.zoom);
        } catch (_) {}
      }
    } catch (e) {
      debugPrint("Could not get immediate GPS: $e");
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _locationSub?.cancel();
    LocationService().stopTracking();
    super.dispose();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    riderId = prefs.getInt('userId') ?? 0;
    if (riderId > 0) {
      _fetchActiveOrder();
    } else {
      setState(() => isLoading = false);
    }
  }

  Future<void> _fetchActiveOrder({bool silent = false}) async {
    if (!silent) setState(() => isLoading = true);
    final response = await ApiHandler.get('rider_active_order.php?rider_id=$riderId');
    if (mounted) {
      setState(() {
        isLoading = false;
        if (response != null && (response['status'] == true || response['status'] == 'success' || response['success'] == true) && response['order'] != null) {
          final String orderStatus = response['order']['status']?.toString().toLowerCase() ?? '';
          if (orderStatus == 'prepared' || orderStatus == 'pending' || orderStatus == 'confirmed') {
            activeOrder = null;
            LocationService().stopTracking();
          } else {
            activeOrder = response['order'];
            LocationService().startTracking();
          }
        } else {
          activeOrder = null;
          LocationService().stopTracking();
        }
      });
    }
  }

  Future<void> _updateOrderStatus(String newStatus) async {
    if (activeOrder == null || isUpdating) return;
    setState(() => isUpdating = true);

    final response = await ApiHandler.post('update_delivery_status.php', {
      'rider_id': riderId.toString(),
      'order_id': activeOrder!['id'].toString(),
      'status': newStatus,
    });

    if (mounted) {
      setState(() => isUpdating = false);
      if (response != null && (response['status'] == 'success' || response['status'] == true || response['success'] == true)) {
        if (newStatus == 'delivered') {
          final earnedAmount = response['rider_payout']?.toString() ?? activeOrder!['rider_payout']?.toString() ?? '0';
          final collectedAmount = response['total_amount']?.toString() ?? activeOrder!['total_amount']?.toString() ?? '0';
          _showDeliverySuccessDialog(earnedAmount, collectedAmount);
        } else {
          String msg = 'Order status updated to ${newStatus.replaceAll('_', ' ').toUpperCase()}';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg),
              backgroundColor: Colors.green,
            ),
          );
          _fetchActiveOrder();
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response?['message'] ?? 'Failed to update status'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showDeliverySuccessDialog(String earnedAmount, String collectedAmount) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle),
              child: const Icon(Icons.check_circle, color: Colors.green, size: 60),
            ),
            const SizedBox(height: 15),
            const Text(
              "Order Delivered!",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.dark),
            ),
            const SizedBox(height: 8),
            Text(
              "Order has been successfully marked as delivered.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Collected Cash:", style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                      Text("₹$collectedAmount", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const Divider(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Your Earnings:", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.green)),
                      Text("₹$earnedAmount", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  _fetchActiveOrder();
                },
                child: const Text("Awesome!", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _callCustomer() async {
    final phone = activeOrder?['customer_phone']?.toString() ?? activeOrder?['user_phone']?.toString();
    if (phone != null && phone.trim().isNotEmpty) {
      final uri = Uri.parse('tel:${phone.trim()}');
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open phone dialer: $e')),
          );
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Customer phone number not available')),
        );
      }
    }
  }

  String _getOrderStatus() {
    // Prefer rider_status (always updated correctly) over status (may be empty from old ENUM corruption)
    String riderSt = activeOrder?['rider_status']?.toString().toLowerCase() ?? '';
    String mainSt = activeOrder?['status']?.toString().toLowerCase() ?? '';
    
    // Use rider_status if it has a meaningful value
    if (riderSt.isNotEmpty && riderSt != 'pending' && riderSt != 'assigned') {
      return riderSt;
    }
    // Fall back to main status
    if (mainSt.isNotEmpty) return mainSt;
    // If rider_status is 'assigned', treat as accepted
    if (riderSt == 'assigned') return 'accepted';
    // Ultimate fallback
    return 'accepted';
  }

  Map<String, String>? _getNextAction() {
    final status = _getOrderStatus();
    switch (status) {
      case 'prepared':
      case 'assigned':
        return {'label': 'Accept Order', 'status': 'accepted'};
      case 'accepted':
        return {'label': 'Arrived at Store', 'status': 'arrived_store'};
      case 'arrived_store':
      case 'shipped': // Fallback if vendor marks shipped
        return {'label': 'Confirm Pick Up', 'status': 'picked_up'};
      case 'picked_up':
      case 'out_for_delivery':
        return {'label': 'Arrived at Customer', 'status': 'arrived_customer'};
      case 'arrived_customer':
        return {'label': 'Mark Delivered', 'status': 'delivered'};
      default:
        return null;
    }
  }

  int _getProgressIndex() {
    final status = _getOrderStatus();
    switch (status) {
      case 'prepared':
      case 'assigned':
        return 0; // Accept Order
      case 'accepted':
        return 1; // Heading to store
      case 'arrived_store':
      case 'shipped':
        return 2; // At store
      case 'picked_up':
      case 'out_for_delivery':
        return 3; // On the way to customer
      case 'arrived_customer':
        return 4; // At customer
      case 'delivered':
        return 5;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text("Active Delivery", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.primary,
        elevation: 0,
        actions: [
          if (activeOrder != null)
            IconButton(
              icon: const Icon(Icons.call, color: Colors.white),
              onPressed: _callCustomer,
            ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => _fetchActiveOrder(),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : activeOrder == null
              ? _buildNoOrderView()
              : _buildActiveOrderView(),
    );
  }

  Widget _buildNoOrderView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 80, color: Colors.green.shade300),
            const SizedBox(height: 20),
            const Text("No Active Orders", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text(
              "You're all caught up! Make sure you are Online to receive new delivery assignments.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, height: 1.5),
            ),
            const SizedBox(height: 30),
            OutlinedButton.icon(
              onPressed: () => _fetchActiveOrder(),
              icon: const Icon(Icons.refresh),
              label: const Text("Refresh"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveOrderView() {
    final order = activeOrder!;
    final customerName = order['customer_name']?.toString() ?? order['user_name']?.toString() ?? 'Customer';
    final customerPhone = order['customer_phone']?.toString() ?? order['user_phone']?.toString() ?? '';
    final customerAddress = order['delivery_address']?.toString() ?? order['customer_address']?.toString() ?? 'Address not available';
    final storeName = order['store_name']?.toString() ?? 'Store';
    final storeAddress = order['store_address']?.toString() ?? '';
    final paymentMethod = order['payment_method']?.toString() ?? 'COD';
    final totalAmount = order['total_amount']?.toString() ?? '0';
    final items = order['items'] as List? ?? [];
    final nextAction = _getNextAction();
    final progressIndex = _getProgressIndex();

    double lat = _safeParseDouble(order['delivery_lat'], 21.7645);
    double lng = _safeParseDouble(order['delivery_lng'], 72.1519);

    double? storeLat = _safeParseNullableDouble(order['store_lat']);
    double? storeLng = _safeParseNullableDouble(order['store_lng']);

    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            color: AppTheme.primary,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Order #${order['id']}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                  child: Text(_getOrderStatus().replaceAll('_', ' ').toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),

          SizedBox(
            height: 250,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _riderPosition ?? (storeLat != null && storeLng != null ? LatLng(storeLat, storeLng) : LatLng(lat, lng)),
                    initialZoom: 14.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}&key=AIzaSyALWv_81PZ-LV1QMDTm1cGC7KkALKepVPM',
                      userAgentPackageName: 'com.example.localmart',
                    ),
                    // Dotted Route Lines (Rider -> Store -> Customer)
                    PolylineLayer(
                      polylines: [
                        // Rider to Store
                        if (_riderPosition != null && storeLat != null && storeLng != null && progressIndex < 3)
                          Polyline(
                            points: [_riderPosition!, LatLng(storeLat, storeLng)],
                            color: Colors.blue,
                            strokeWidth: 4.0,
                          ),
                        // Store to Customer
                        if (storeLat != null && storeLng != null)
                          Polyline(
                            points: [LatLng(storeLat, storeLng), LatLng(lat, lng)],
                            color: Colors.orange,
                            strokeWidth: 4.0,
                          ),
                        // Rider to Customer (if already picked up)
                        if (_riderPosition != null && progressIndex >= 3)
                          Polyline(
                            points: [_riderPosition!, LatLng(lat, lng)],
                            color: Colors.green,
                            strokeWidth: 4.0,
                          ),
                      ],
                    ),
                    MarkerLayer(
                      markers: [
                        // 1. Store Marker (Blue bag icon)
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
                              child: const Icon(Icons.store, color: Colors.white, size: 16),
                            ),
                          ),
                        // 2. Customer Destination Marker (Red pin icon)
                        Marker(
                          point: LatLng(lat, lng),
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                            ),
                            child: const Icon(Icons.person_pin_circle, color: Colors.white, size: 16),
                          ),
                        ),
                        // 3. Live Rider Scooter Marker (Green bike icon)
                        if (_riderPosition != null)
                          Marker(
                            point: _riderPosition!,
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
                      ],
                    ),
                  ],
                ),
                // Live tracking badge
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _riderPosition != null ? Colors.green : Colors.orange,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_riderPosition != null ? Icons.gps_fixed : Icons.gps_not_fixed, color: Colors.white, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          _riderPosition != null ? "LIVE TRACKING" : "GPS LOADING...",
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          Container(
            margin: const EdgeInsets.all(15),
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Delivery Progress", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 15),
                _progressStep("Available Order", 0, progressIndex),
                _progressStep("Accepted & Heading to Store", 1, progressIndex),
                _progressStep("Arrived at Store", 2, progressIndex),
                _progressStep("Picked Up — On the Way", 3, progressIndex),
                _progressStep("Arrived at Customer", 4, progressIndex),
                _progressStep("Delivered", 5, progressIndex),
                if (nextAction != null) ...[
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _callCustomer,
                          icon: const Icon(Icons.call, size: 18),
                          label: const Text("Call Customer"),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, padding: const EdgeInsets.symmetric(vertical: 14)),
                          onPressed: isUpdating ? null : () => _updateOrderStatus(nextAction['status']!),
                          child: isUpdating
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : Text(nextAction['label']!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          Container(
            margin: const EdgeInsets.symmetric(horizontal: 15),
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
            child: Column(
              children: [
                _routePoint(Icons.store, storeName, storeAddress, Colors.blue),
                Padding(
                  padding: const EdgeInsets.only(left: 11),
                  child: Column(
                    children: List.generate(3, (_) => Container(width: 2, height: 6, margin: const EdgeInsets.symmetric(vertical: 2), color: Colors.grey.shade300)),
                  ),
                ),
                _routePoint(Icons.location_on, customerName, customerAddress, Colors.red),
              ],
            ),
          ),
          const SizedBox(height: 10),

          Container(
            margin: const EdgeInsets.symmetric(horizontal: 15),
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("ORDER ITEMS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                      child: Text(paymentMethod.toUpperCase(), style: TextStyle(color: Colors.green.shade700, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...items.map<Widget>((item) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text("${item['product_name'] ?? item['name']} × ${item['quantity']}", style: const TextStyle(fontSize: 14))),
                        Text("₹${item['price'] ?? ''}", style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  );
                }),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Cash to Collect from Customer", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text("₹$totalAmount", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green)),
                  ],
                ),
              ],
            ),
          ),

          if (customerPhone.isNotEmpty)
            Container(
              margin: const EdgeInsets.all(15),
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                    child: const Icon(Icons.person, color: AppTheme.primary),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(customerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 4),
                        Text(customerPhone, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _callCustomer,
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle),
                      child: const Icon(Icons.call, color: Colors.green, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _progressStep(String label, int stepIndex, int currentIndex) {
    final isDone = stepIndex <= currentIndex;
    final isCurrent = stepIndex == currentIndex;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 24, height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDone ? Colors.green : Colors.grey.shade300,
            ),
            child: isDone
                ? const Icon(Icons.check, color: Colors.white, size: 14)
                : Center(child: Text('${stepIndex + 1}', style: TextStyle(color: Colors.grey.shade600, fontSize: 11))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                color: isDone ? Colors.green.shade700 : Colors.grey.shade500,
                fontSize: isCurrent ? 14 : 13,
              ),
            ),
          ),
          if (isCurrent)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
              child: Text("Current", style: TextStyle(color: Colors.orange.shade700, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  Widget _routePoint(IconData icon, String title, String subtitle, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              if (subtitle.isNotEmpty)
                Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 12, height: 1.3)),
            ],
          ),
        ),
      ],
    );
  }
}
