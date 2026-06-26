import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/api_handler.dart';
import 'package:url_launcher/url_launcher.dart';

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

  @override
  void initState() {
    super.initState();
    _loadData();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) _fetchActiveOrder(silent: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
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
            // It's a ghost order from the old auto-assign system. Ignore it.
            activeOrder = null;
          } else {
            activeOrder = response['order'];
          }
        } else {
          activeOrder = null;
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
      if (response != null && (response['status'] == 'success' || response['status'] == true)) {
        String msg = 'Order status updated to ${newStatus.replaceAll('_', ' ').toUpperCase()}';
        if (newStatus == 'delivered') {
          msg = 'Order Delivered Successfully! ✅';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: Colors.green,
          ),
        );
        _fetchActiveOrder();
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

    double lat = 21.7645;
    double lng = 72.1519;
    if (order['delivery_lat'] != null) lat = double.tryParse(order['delivery_lat'].toString()) ?? lat;
    if (order['delivery_lng'] != null) lng = double.tryParse(order['delivery_lng'].toString()) ?? lng;

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
            height: 220,
            child: FlutterMap(
              options: MapOptions(initialCenter: LatLng(lat, lng), initialZoom: 14.0),
              children: [
                TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.example.localmart'),
                MarkerLayer(
                  markers: [
                    Marker(point: LatLng(lat, lng), child: const Icon(Icons.location_on, color: Colors.red, size: 40)),
                  ],
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
                    const Text("Total Amount", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
