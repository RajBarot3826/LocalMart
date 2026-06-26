import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/api_handler.dart';
import '../theme/app_theme.dart';
import 'rider_home_tab.dart';
import 'rider_active_tab.dart';
import 'rider_earnings_tab.dart';
import 'rider_history_tab.dart';
import 'rider_profile_tab.dart';

class RiderMainScreen extends StatefulWidget {
  final int initialIndex;
  const RiderMainScreen({super.key, this.initialIndex = 0});

  @override
  State<RiderMainScreen> createState() => _RiderMainScreenState();
}

class _RiderMainScreenState extends State<RiderMainScreen> {
  late int _currentIndex;
  Timer? _timer;

  final List<Widget> _tabs = [
    const RiderHomeTab(),
    const RiderActiveTab(),
    const RiderEarningsTab(),
    const RiderHistoryTab(),
    const RiderProfileTab(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _startGlobalPolling();
  }

  void _startGlobalPolling() {
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      // Only poll if on Home tab
      if (_currentIndex != 0) return;
      
      final prefs = await SharedPreferences.getInstance();
      final riderId = prefs.getInt('userId') ?? 0;
      final isOnline = prefs.getBool('isRiderOnline') ?? false;
      
      if (riderId > 0 && isOnline) {
        final response = await ApiHandler.get('rider_active_order.php?rider_id=$riderId');
        if (response != null && (response['status'] == true || response['status'] == 'success' || response['success'] == true) && response['order'] != null) {
          final String orderStatus = response['order']['status']?.toString().toLowerCase() ?? '';
          if (orderStatus != 'prepared' && orderStatus != 'placed' && orderStatus != 'confirmed' && orderStatus != 'pending') {
            if (mounted) {
              setState(() {
                _currentIndex = 1; // Switch to Active Tab
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('🔔 Active order found!'),
                  backgroundColor: AppTheme.primary,
                  duration: Duration(seconds: 3),
                ),
              );
            }
          }
        }
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
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: _tabs[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5))
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: AppTheme.primary,
          unselectedItemColor: Colors.grey.shade400,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
          unselectedLabelStyle: const TextStyle(fontSize: 10),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.delivery_dining_outlined), activeIcon: Icon(Icons.delivery_dining), label: 'Active'),
            BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_outlined), activeIcon: Icon(Icons.account_balance_wallet), label: 'Earnings'),
            BottomNavigationBarItem(icon: Icon(Icons.receipt_long_outlined), activeIcon: Icon(Icons.receipt_long), label: 'History'),
            BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}
