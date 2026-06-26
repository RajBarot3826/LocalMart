import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../utils/api_handler.dart';

class RiderEarningsTab extends StatefulWidget {
  const RiderEarningsTab({super.key});

  @override
  State<RiderEarningsTab> createState() => _RiderEarningsTabState();
}

class _RiderEarningsTabState extends State<RiderEarningsTab> {
  String selectedFilter = 'This Week';
  int riderId = 0;
  bool isLoading = true;
  Map<String, dynamic> earningsData = {
    'total': 0,
    'deliveries': 0,
    'rating': '0.0',
    'per_order': 0,
    'delivery_fees': 0,
    'tips': 0,
    'platform_fee': 0,
    'orders': [],
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    riderId = prefs.getInt('userId') ?? 0;
    
    if (riderId > 0) {
      _fetchEarnings();
    } else {
      setState(() => isLoading = false);
    }
  }

  Future<void> _fetchEarnings() async {
    setState(() => isLoading = true);
    
    String filterParam = 'week';
    if (selectedFilter == 'Today') filterParam = 'today';
    if (selectedFilter == 'This Month') filterParam = 'month';

    final response = await ApiHandler.get('rider_earnings.php?rider_id=$riderId&filter=$filterParam');
    if (mounted) {
      setState(() {
        isLoading = false;
        if (response != null && response['status'] == true && response['data'] != null) {
          earningsData = response['data'];
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text("Earnings", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.primary,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.outbox, color: Colors.white), onPressed: () {}),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Top Green Banner
            Container(
              width: double.infinity,
              color: AppTheme.primary,
              padding: const EdgeInsets.only(left: 20, right: 20, bottom: 30),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 25),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        Text(isLoading ? "..." : "₹${earningsData['total']}", style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white)),
                        const SizedBox(height: 5),
                        Text("$selectedFilter's Total", style: const TextStyle(color: Colors.white70)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(child: _statBox("${earningsData['deliveries']}", "Deliveries")),
                      const SizedBox(width: 10),
                      Expanded(child: _statBox("${earningsData['rating']}★", "Rating")),
                      const SizedBox(width: 10),
                      Expanded(child: _statBox("₹${earningsData['per_order']}", "Per Order")),
                    ],
                  ),
                ],
              ),
            ),
            
            // Filters
            Container(
              margin: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                children: [
                  Expanded(child: _filterBtn('Today')),
                  Expanded(child: _filterBtn('This Week')),
                  Expanded(child: _filterBtn('This Month')),
                ],
              ),
            ),

            if (isLoading)
              const Padding(padding: EdgeInsets.all(50), child: CircularProgressIndicator())
            else ...[
              // Breakdown
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 15),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("${selectedFilter.toUpperCase()}'S BREAKDOWN", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
                        const Text("Details", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 15),
                    Text("Delivery Fees (${earningsData['deliveries']} orders)", style: const TextStyle(fontSize: 14)),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Tips Received", style: TextStyle(color: Colors.green)),
                        Text("+₹${earningsData['tips']}", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Platform Fee", style: TextStyle(color: Colors.grey)),
                        Text("-₹${earningsData['platform_fee']}", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const Divider(height: 30),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(""),
                        Text("₹${earningsData['total']}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
                      ],
                    ),
                  ],
                ),
              ),

              // Recent Orders
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("RECENT ORDERS", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
                    const SizedBox(height: 15),
                    ...(earningsData['orders'] as List? ?? []).map<Widget>((o) {
                      return _orderItem("Order #${o['id']}", "${o['date']}", "+₹${o['earned']}", o['is_cancelled'] ? "Cancelled" : "Fee + Tip");
                    }),
                    if ((earningsData['orders'] as List? ?? []).isEmpty)
                      const Text("No orders found for this period", style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _statBox(String val, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(val, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 5),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _filterBtn(String text) {
    bool isSelected = selectedFilter == text;
    return GestureDetector(
      onTap: () {
        setState(() => selectedFilter = text);
        _fetchEarnings();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(15),
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _orderItem(String title, String subtitle, String price, String subprice) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 5),
              Text(subtitle, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(price, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
              const SizedBox(height: 2),
              Text(subprice, style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}
