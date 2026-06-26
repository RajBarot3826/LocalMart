import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/api_handler.dart';
import '../theme/app_theme.dart';
import 'invoice_screen.dart';
import 'package:url_launcher/url_launcher.dart';

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

  @override
  void initState() {
    super.initState();
    _orderData = widget.orderData;
    _startAutoRefresh();
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
          }
        }
      } catch (e) {
        debugPrint("Auto-refresh error: $e");
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
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

    // Prefer rider_status when main status is empty/corrupted and rider is assigned
    String statusLower = status.toLowerCase();
    if ((statusLower.isEmpty || statusLower == 'placed') && hasRider && riderStatus.isNotEmpty && riderStatus.toLowerCase() != 'pending') {
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
                            const Text('Estimated Delivery: Today', style: TextStyle(color: Colors.white, fontSize: 12)),
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
}
