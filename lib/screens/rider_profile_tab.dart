import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../utils/api_handler.dart';
import '../utils/address_manager.dart';

class RiderProfileTab extends StatefulWidget {
  const RiderProfileTab({super.key});

  @override
  State<RiderProfileTab> createState() => _RiderProfileTabState();
}

class _RiderProfileTabState extends State<RiderProfileTab> {
  int riderId = 0;
  bool isLoading = true;
  Map<String, dynamic> profileData = {
    'name': 'Rider',
    'rider_id': '...',
    'join_date': '...',
    'rating': '0.0',
    'rating_count': 0,
    'total_deliveries': 0,
    'month_earnings': 0,
    'acceptance_rate': 0,
    'wallet_balance': 0,
    'vehicle_number': '',
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
      _fetchProfile();
    } else {
      setState(() => isLoading = false);
    }
  }

  Future<void> _fetchProfile() async {
    setState(() => isLoading = true);
    final response = await ApiHandler.get('rider_profile.php?rider_id=$riderId');
    if (mounted) {
      setState(() {
        isLoading = false;
        if (response != null && response['status'] == true && response['data'] != null) {
          profileData = response['data'];
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text("My Profile", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.primary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
            onPressed: () {},
          )
        ],
      ),
      body: isLoading 
        ? const Center(child: CircularProgressIndicator()) 
        : SingleChildScrollView(
        child: Column(
          children: [
            // Header Profile Info
            Container(
              color: AppTheme.primary,
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.electric_scooter, color: AppTheme.primary, size: 40),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("${profileData['name']}", style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 5),
                            Text("Rider ID: ${profileData['rider_id']} · Since ${profileData['join_date']}", style: const TextStyle(color: Colors.white70, fontSize: 12)),
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                const Icon(Icons.star, color: Colors.amber, size: 14),
                                const Icon(Icons.star, color: Colors.amber, size: 14),
                                const Icon(Icons.star, color: Colors.amber, size: 14),
                                const Icon(Icons.star, color: Colors.amber, size: 14),
                                const Icon(Icons.star, color: Colors.amber, size: 14),
                                const SizedBox(width: 5),
                                Text("${profileData['rating']} (${profileData['rating_count']} ratings)", style: const TextStyle(color: Colors.white, fontSize: 12)),
                              ],
                            )
                          ],
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 25),
                  Row(
                    children: [
                      Expanded(child: _statBox("${profileData['total_deliveries']}", "Deliveries")),
                      const SizedBox(width: 10),
                      Expanded(child: _statBox("₹${profileData['month_earnings']}", "This Month")),
                      const SizedBox(width: 10),
                      Expanded(child: _statBox("${profileData['acceptance_rate']}%", "Acceptance")),
                    ],
                  )
                ],
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                children: [
                  // Badge
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      children: [
                        const Text("🏆", style: TextStyle(fontSize: 30)),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text("Top Rider Badge — June 2026", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                              SizedBox(height: 4),
                              Text("You're in the top 10% of riders this month!", style: TextStyle(color: Colors.green, fontSize: 11)),
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Menu List
                  _menuItem(Icons.person_outline, "Personal Information"),
                  _menuItem(Icons.pedal_bike, "Vehicle Details: ${profileData['vehicle_number']}"),
                  _menuItem(Icons.account_balance_wallet, "Wallet Balance: ₹${profileData['wallet_balance']}"),
                  _menuItem(Icons.account_balance, "Bank Account & Payments"),
                  _menuItem(Icons.notifications_outlined, "Notifications", trailing: "2 New"),
                  _menuItem(Icons.star_outline, "My Ratings & Reviews"),
                  const SizedBox(height: 20),
                  
                  // Logout Button
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.red,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                          side: const BorderSide(color: Colors.red),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.remove('isLoggedIn');
                        await prefs.remove('userId');
                        await prefs.remove('userName');
                        await prefs.remove('userPhone');
                        await prefs.remove('userEmail');
                        await prefs.remove('userRole');
                        await prefs.remove('vehicleNumber');
                        await prefs.remove('isRiderOnline');
                        AddressManager().clearMemory();
                        if (context.mounted) {
                           Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
                        }
                      },
                      child: const Text("Log Out", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _statBox(String val, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
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

  Widget _menuItem(IconData icon, String title, {String? trailing}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppTheme.primary, size: 20),
          ),
          const SizedBox(width: 15),
          Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600))),
          if (trailing != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(5)),
              child: Text(trailing, style: const TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          const SizedBox(width: 10),
          const Icon(Icons.chevron_right, color: Colors.grey),
        ],
      ),
    );
  }
}
