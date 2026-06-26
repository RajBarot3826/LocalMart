import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../utils/address_manager.dart';

class RiderHomeScreen extends StatefulWidget {
  const RiderHomeScreen({super.key});

  @override
  State<RiderHomeScreen> createState() => _RiderHomeScreenState();
}

class _RiderHomeScreenState extends State<RiderHomeScreen> {
  bool isOnline = false;
  String riderName = "Rider";
  String vehicleNumber = "";

  @override
  void initState() {
    super.initState();
    _loadRiderData();
  }

  Future<void> _loadRiderData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      riderName = prefs.getString('userName') ?? "Rider";
      vehicleNumber = prefs.getString('vehicleNumber') ?? "";
    });
    // In a real app, we'd also fetch current online status from API here
  }

  Future<void> _toggleOnlineStatus(bool value) async {
    setState(() {
      isOnline = value;
    });

    // Simulated API call to update status
    // await ApiHandler.post('toggle_rider_status.php', {'is_online': value ? 1 : 0});
    
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isOnline ? "You are now ONLINE. Waiting for orders..." : "You are OFFLINE."),
        backgroundColor: isOnline ? AppTheme.primary : Colors.grey.shade800,
      ),
    );
  }

  Future<void> _logout() async {
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
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Welcome, $riderName", style: const TextStyle(color: Colors.white, fontSize: 16)),
            Text(vehicleNumber, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _logout,
          )
        ],
      ),
      body: Column(
        children: [
          // Header Status Area
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isOnline ? "ONLINE" : "OFFLINE",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isOnline ? AppTheme.primary : Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 15),
                      Switch(
                        value: isOnline,
                        onChanged: _toggleOnlineStatus,
                        activeThumbColor: AppTheme.primary,
                        activeTrackColor: AppTheme.primary.withValues(alpha: 0.3),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 15),
                Text(
                  isOnline ? "Searching for nearby orders..." : "Go Online to start receiving orders",
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: isOnline ? _buildActiveOrders() : _buildOfflineState(),
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bedtime, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 20),
          Text("You are offline", style: TextStyle(fontSize: 22, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildActiveOrders() {
    // Simulated active order (would be fetched from API in reality)
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text("Active Orders", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.dark)),
        const SizedBox(height: 15),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(8)),
                      child: Text("NEW", style: TextStyle(color: Colors.orange.shade800, fontWeight: FontWeight.bold)),
                    ),
                    const Text("2.5 km away", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 15),
                const Row(
                  children: [
                    Icon(Icons.store, color: AppTheme.primary),
                    SizedBox(width: 10),
                    Expanded(child: Text("Shriji Supermarket (Pickup)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 11, top: 5, bottom: 5),
                  child: Container(height: 20, width: 2, color: Colors.grey),
                ),
                const Row(
                  children: [
                    Icon(Icons.person_pin_circle, color: Colors.red),
                    SizedBox(width: 10),
                    Expanded(child: Text("Rahul Sharma (Dropoff)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 45,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      // Accept order logic
                    },
                    child: const Text("Accept Order", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
