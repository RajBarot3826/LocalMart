import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../utils/api_handler.dart';
import '../services/location_service.dart';
import 'rider_main_screen.dart';

class RiderHomeTab extends StatefulWidget {
  const RiderHomeTab({super.key});

  @override
  State<RiderHomeTab> createState() => _RiderHomeTabState();
}

class _RiderHomeTabState extends State<RiderHomeTab> {
  bool isOnline = false;
  String riderName = 'Rider';
  int riderId = 0;
  bool isLoading = true;
  
  Map<String, dynamic> todayMetrics = {"orders": 0, "earn": 0, "distance": 0};
  Map<String, dynamic> yesterdayMetrics = {"orders": 0, "earn": 0, "rating": "0.0"};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('userEmail') ?? 'rider@localmart.com';
    riderId = prefs.getInt('userId') ?? 0;
    
    setState(() {
      isOnline = prefs.getBool('isRiderOnline') ?? false;
      riderName = email.split('@')[0].replaceAll('_', ' ');
      if (riderName.isNotEmpty) {
        riderName = riderName[0].toUpperCase() + riderName.substring(1);
      }
    });

    if (riderId > 0) {
      _fetchDashboard();
      if (isOnline) {
        LocationService().startTracking();
        _startOrderPolling();
      }
    } else {
      setState(() => isLoading = false);
    }
  }

  Timer? _pollTimer;
  List<dynamic> availableOrders = [];

  void _startOrderPolling() {
    _pollTimer?.cancel();
    _fetchAvailableOrders(); // fetch immediately
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _fetchAvailableOrders());
  }

  void _stopOrderPolling() {
    _pollTimer?.cancel();
    setState(() {
      availableOrders.clear();
    });
  }

  Future<void> _fetchAvailableOrders() async {
    if (!isOnline) return;
    try {
      final response = await ApiHandler.get('get_available_orders.php');
      if (mounted && response != null && (response['status'] == true || response['success'] == true)) {
        setState(() {
          availableOrders = response['available_orders'] ?? [];
        });
      }
    } catch (e) {
      debugPrint("Error fetching available orders: $e");
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchDashboard() async {
    setState(() => isLoading = true);
    final response = await ApiHandler.get('rider_dashboard.php?rider_id=$riderId');
    if (mounted) {
      setState(() {
        isLoading = false;
        if (response != null && (response['status'] == true || response['status'] == 'success' || response['success'] == true)) {
          todayMetrics = response['today'] ?? todayMetrics;
          yesterdayMetrics = response['yesterday'] ?? yesterdayMetrics;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.grey.shade50,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Good morning,", style: TextStyle(color: Colors.grey, fontSize: 13)),
            Text("$riderName 👋", style: const TextStyle(color: AppTheme.dark, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 15),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 5)],
            ),
            child: IconButton(
              icon: const Icon(Icons.notifications_none, color: AppTheme.dark),
              onPressed: () {},
            ),
          )
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchDashboard,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(15),
          child: Column(
          children: [
            // Online/Offline Toggle Box
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 5))],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(isOnline ? "You're Online" : "You're Offline", 
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isOnline ? AppTheme.primary : Colors.grey.shade700)),
                        const SizedBox(height: 5),
                        Text(
                          isOnline ? "Waiting for new delivery requests..." : "Toggle to start accepting orders",
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: isOnline,
                    activeThumbColor: AppTheme.primary,
                    onChanged: (val) async {
                      setState(() {
                        isOnline = val;
                      });
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('isRiderOnline', val);
                      
                      if (val) {
                        LocationService().startTracking();
                        _startOrderPolling();
                      } else {
                        LocationService().stopTracking();
                        _stopOrderPolling();
                      }
                      // Notify server of status change
                      if (riderId > 0) {
                        await ApiHandler.post('toggle_rider_status.php', {
                          'rider_id': riderId.toString(),
                          'status': val ? 'online' : 'offline',
                        });
                      }
                    },
                  )
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Today's Metrics
            if (isLoading)
              const Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())
            else
              Row(
                children: [
                  Expanded(child: _metricCard("${todayMetrics['orders']}", "Today's Orders")),
                  const SizedBox(width: 10),
                  Expanded(child: _metricCard("₹${todayMetrics['earn']}", "Today's Earn")),
                  const SizedBox(width: 10),
                  Expanded(child: _metricCard("${todayMetrics['distance']} km", "Distance")),
                ],
              ),
            const SizedBox(height: 20),

            // Main Status Area
            if (isOnline && availableOrders.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Available Orders", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 15),
                  ...availableOrders.map((order) => _buildAvailableOrderCard(order)),
                ],
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    Icon(
                      isOnline ? Icons.radar : Icons.electric_scooter, 
                      size: 80, 
                      color: isOnline ? AppTheme.primary : Colors.grey.shade300
                    ),
                    const SizedBox(height: 20),
                    Text(
                      isOnline ? "Finding Orders..." : "You're currently offline",
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.dark),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      isOnline ? "Searching for nearby prepared orders. They will appear here." : "Toggle the switch above to go online and start receiving delivery orders from nearby stores.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade500, height: 1.5),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),

            // Yesterday's Summary
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Yesterday's Summary", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      TextButton(
                        style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(50, 30), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                        onPressed: () {}, 
                        child: const Text("View all", style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold))
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(15)),
                          child: Column(
                            children: [
                              Text("${yesterdayMetrics['orders']}", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green)),
                              Text("Orders", style: TextStyle(fontSize: 12, color: Colors.green.shade700)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(15)),
                          child: Column(
                            children: [
                              Text("₹${yesterdayMetrics['earn']}", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green)),
                              Text("Earned", style: TextStyle(fontSize: 12, color: Colors.green.shade700)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(15)),
                          child: Column(
                            children: [
                              Text("${yesterdayMetrics['rating']}★", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green)),
                              Text("Rating", style: TextStyle(fontSize: 12, color: Colors.green.shade700)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _metricCard(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.dark)),
          const SizedBox(height: 5),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  Widget _buildAvailableOrderCard(dynamic order) {
    final storeName = order['store_name']?.toString() ?? 'Store';
    final storeAddress = order['store_address']?.toString() ?? 'Address not available';
    final storePhone = order['store_phone']?.toString() ?? '';
    final deliveryAddress = order['delivery_address']?.toString() ?? order['customer_address']?.toString() ?? 'Address not available';
    final amount = order['total_amount']?.toString() ?? '0';
    final items = order['items'] as List? ?? [];
    
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(storeName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text("₹$amount", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.store, size: 16, color: Colors.grey),
              const SizedBox(width: 5),
              Expanded(child: Text(storeAddress, style: TextStyle(color: Colors.grey.shade600, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis)),
            ],
          ),
          if (storePhone.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.phone, size: 16, color: Colors.grey),
                const SizedBox(width: 5),
                Text("Shop Phone: $storePhone", style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              ],
            ),
          ],
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.location_on, size: 16, color: Colors.red),
              const SizedBox(width: 5),
              Expanded(child: Text(deliveryAddress, style: TextStyle(color: Colors.grey.shade600, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis)),
            ],
          ),
          if (items.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Divider(),
            const Text("Items to deliver:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 5),
            ...items.map<Widget>((item) {
              final name = item['product_name'] ?? item['name'] ?? 'Item';
              final qty = item['quantity'] ?? 1;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    const Icon(Icons.subdirectory_arrow_right, size: 14, color: Colors.grey),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        "$name x $qty",
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
          const SizedBox(height: 15),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
                final response = await ApiHandler.post('accept_order.php', {
                  'rider_id': riderId.toString(),
                  'order_id': order['id'].toString(),
                });
                if (mounted) Navigator.pop(context); // close loader
                
                if (response != null && (response['status'] == true || response['success'] == true)) {
                  _stopOrderPolling();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Order Accepted! Redirecting..."), backgroundColor: Colors.green));
                    // Push replacement to restart RiderMainScreen on tab 1
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const RiderMainScreen(initialIndex: 1)),
                    );
                  }
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(response?['message'] ?? "Failed to accept order"), backgroundColor: Colors.red));
                  }
                  _fetchAvailableOrders(); // refresh list
                }
              },
              child: const Text("Accept Order", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }
}
