import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../utils/api_handler.dart';
import 'track_order_screen.dart';

class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({super.key});

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fetchOrders();
    _startAutoRefresh();
  }

  void _startAutoRefresh() {
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) {
        _fetchOrdersSilent();
      }
    });
  }

  Future<void> _fetchOrdersSilent() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final phone = prefs.getString('userPhone') ?? '';
      if (phone.isEmpty) return;

      final response = await ApiHandler.get('get_orders.php?phone=$phone');
      if (response != null && mounted) {
        List<dynamic> ordersList = [];
        if (response is Map && response.containsKey('orders')) {
          ordersList = response['orders'] ?? [];
        } else if (response is List) {
          ordersList = response;
        }
        setState(() {
          _orders = ordersList.map((o) => Map<String, dynamic>.from(o)).toList();
        });
      }
    } catch (e) {
      // Silently ignore background fetch errors
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchOrders() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final phone = prefs.getString('userPhone') ?? '';
      if (phone.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      final response = await ApiHandler.get('get_orders.php?phone=$phone');
      if (response != null) {
        List<dynamic> ordersList = [];
        if (response is Map && response.containsKey('orders')) {
          ordersList = response['orders'] ?? [];
        } else if (response is List) {
          ordersList = response;
        }

        setState(() {
          _orders = ordersList.map((o) => Map<String, dynamic>.from(o)).toList();
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("❌ Fetch orders error: $e");
      setState(() => _isLoading = false);
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'placed': return Colors.blue;
      case 'confirmed': return Colors.orange;
      case 'prepared': return Colors.purple;
      case 'shipped': return Colors.indigo;
      case 'out for delivery': return Colors.teal;
      case 'delivered': return AppTheme.primary;
      case 'cancelled': return Colors.red;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('My Orders', style: TextStyle(color: AppTheme.dark, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: AppTheme.dark),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _orders.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shopping_bag_outlined, size: 80, color: Colors.grey.shade300),
                      const SizedBox(height: 15),
                      const Text('No orders yet', style: TextStyle(fontSize: 18, color: Colors.grey)),
                      const SizedBox(height: 5),
                      Text('Your orders will appear here', style: TextStyle(color: Colors.grey.shade400)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchOrders,
                  color: AppTheme.primary,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _orders.length,
                    itemBuilder: (context, index) {
                      final order = _orders[index];
                      final orderId = order['order_id']?.toString() ?? 'N/A';
                      final storeName = order['store_name']?.toString() ?? 'Store';
                      final status = order['status']?.toString() ?? 'Placed';
                      final totalAmount = order['total_amount']?.toString() ?? '0';
                      final date = order['created_at']?.toString() ?? order['date']?.toString() ?? '';
                      final items = order['items'];

                      return InkWell(
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(
                            builder: (_) => TrackOrderScreen(orderData: order),
                          )).then((_) => _fetchOrdersSilent());
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 15),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 5))],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('#$orderId', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  Text(date, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.storefront, size: 16, color: Colors.grey.shade500),
                                  const SizedBox(width: 6),
                                  Text(storeName, style: const TextStyle(fontWeight: FontWeight.w500)),
                                ],
                              ),
                              if (items is List && items.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  items.map((i) => i['product_name']?.toString() ?? i['name']?.toString() ?? '').take(3).join(', ') + (items.length > 3 ? '...' : ''),
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                  maxLines: 1, overflow: TextOverflow.ellipsis,
                                ),
                              ],
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: _statusColor(status).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(status, style: TextStyle(
                                      color: _statusColor(status),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    )),
                                  ),
                                  Text('₹$totalAmount', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
