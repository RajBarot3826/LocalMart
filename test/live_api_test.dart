import 'package:flutter_test/flutter_test.dart';
import 'package:localmart/utils/api_handler.dart';

void main() {
  test('Test Live LocalMart Rider APIs', () async {
    print('--- LOCALMART LIVE API TEST ---');
    
    // 1. Register a test rider
    final uniqueExt = DateTime.now().millisecondsSinceEpoch.toString().substring(8);
    final testPass = '123456';
    
    final regRes = await ApiHandler.post('rider_register.php', {
      'name': 'Test Rider $uniqueExt',
      'phone': '99999$uniqueExt',
      'email': 'test$uniqueExt@test.com',
      'password': testPass,
      'address': 'Test Address',
      'vehicle_number': 'GJ-TEST-$uniqueExt',
    });
    
    final loginId = regRes?['rider_id'];

    // 2. Login as the new rider
    final loginRes = await ApiHandler.post('app_login.php', {
      'phone': loginId,
      'email': loginId,
      'password': testPass,
    });
    
    final userId = loginRes?['user']['id'];

    // 3. Toggle Online Status
    final toggleRes = await ApiHandler.post('toggle_rider_status.php', {
      'rider_id': userId.toString(),
      'status': 'online',
    });
    print('Toggle Online Status: $toggleRes');

    // 4. Check Active Order
    final orderRes = await ApiHandler.get('rider_active_order.php?rider_id=$userId');
    print('Active Order: $orderRes');

    // 5. Check Dashboard
    final dashRes = await ApiHandler.get('rider_dashboard.php?rider_id=$userId');
    print('Dashboard: $dashRes');

    // 6. Check Earnings
    final earnRes = await ApiHandler.get('rider_earnings.php?rider_id=$userId&filter=today');
    print('Earnings: $earnRes');
    
    // 7. Check History
    final histRes = await ApiHandler.get('rider_history.php?rider_id=$userId&filter=all');
    print('History: $histRes');

    // 8. Check Profile
    final profRes = await ApiHandler.get('rider_profile.php?rider_id=$userId');
    print('Profile: $profRes');
  });
}
