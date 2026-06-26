import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../utils/api_handler.dart';

class RiderHistoryTab extends StatefulWidget {
  const RiderHistoryTab({super.key});

  @override
  State<RiderHistoryTab> createState() => _RiderHistoryTabState();
}

class _RiderHistoryTabState extends State<RiderHistoryTab> {
  String selectedFilter = 'All';
  int riderId = 0;
  bool isLoading = true;
  List<dynamic> historyData = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    riderId = prefs.getInt('userId') ?? 0;
    
    if (riderId > 0) {
      _fetchHistory();
    } else {
      setState(() => isLoading = false);
    }
  }

  Future<void> _fetchHistory() async {
    setState(() => isLoading = true);
    
    String filterParam = 'all';
    if (selectedFilter == 'Completed') filterParam = 'completed';
    if (selectedFilter == 'Cancelled') filterParam = 'cancelled';

    final response = await ApiHandler.get('rider_history.php?rider_id=$riderId&filter=$filterParam');
    if (mounted) {
      setState(() {
        isLoading = false;
        if (response != null && response['status'] == true && response['history'] != null) {
          historyData = response['history'];
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text("Delivery History", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.primary,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.search, color: Colors.white), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: AppTheme.primary,
            padding: const EdgeInsets.fromLTRB(15, 0, 15, 20),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(child: _filterBtn('All')),
                  Expanded(child: _filterBtn('Completed')),
                  Expanded(child: _filterBtn('Cancelled')),
                ],
              ),
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : historyData.isEmpty
                    ? Center(child: Text("No $selectedFilter deliveries found", style: TextStyle(color: Colors.grey.shade500)))
                    : ListView.builder(
                        padding: const EdgeInsets.all(15),
                        itemCount: historyData.length + 1, // +1 for the count header
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 15),
                              child: Text(
                                "Showing ${historyData.length} $selectedFilter deliveries", 
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 12)
                              ),
                            );
                          }
                          
                          final item = historyData[index - 1];
                          final isCancelled = item['status'] == 'cancelled';
                          
                          return _historyItem(
                            id: "Order #${item['id']}", 
                            date: item['date'] ?? '', 
                            route: "${item['store_name']} → ${item['customer_name']}", 
                            distance: "${item['distance']} km", 
                            earned: isCancelled ? "Cancelled by customer" : "+₹${item['earned']} earned", 
                            status: isCancelled ? "Cancelled" : "Delivered", 
                            rating: isCancelled ? "₹0" : "${item['rating']} rating",
                            isCancelled: isCancelled
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _filterBtn(String text) {
    bool isSelected = selectedFilter == text;
    return GestureDetector(
      onTap: () {
        setState(() => selectedFilter = text);
        _fetchHistory();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.dark : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade700,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _historyItem({required String id, required String date, required String route, required String distance, required String earned, required String status, required String rating, required bool isCancelled}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10)],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(id, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(date, style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isCancelled ? Colors.red.shade50 : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  status, 
                  style: TextStyle(color: isCancelled ? Colors.red : Colors.green, fontWeight: FontWeight.bold, fontSize: 11)
                ),
              )
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.directions_bike, size: 16, color: Colors.grey.shade400),
              const SizedBox(width: 8),
              Expanded(child: Text(route, style: TextStyle(fontSize: 13, color: Colors.grey.shade700))),
            ],
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              Icon(Icons.place, size: 16, color: Colors.grey.shade400),
              const SizedBox(width: 8),
              Text(distance, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                earned, 
                style: TextStyle(fontWeight: FontWeight.bold, color: isCancelled ? Colors.red : Colors.green, fontSize: 14)
              ),
              if (!isCancelled)
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 16),
                    const SizedBox(width: 4),
                    Text(rating, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  ],
                )
              else
                Text(rating, style: TextStyle(color: Colors.grey.shade600, fontSize: 12))
            ],
          )
        ],
      ),
    );
  }
}
