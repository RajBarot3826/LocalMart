import 'package:flutter_test/flutter_test.dart';
import 'package:localmart/utils/api_handler.dart';

void main() {
  test('Inspect Coordinates and Orders on Server', () async {
    print('===========================================================');
    print('          LOCALMART COORDINATES INSPECTOR');
    print('===========================================================');
    
    try {
      final String ts = DateTime.now().millisecondsSinceEpoch.toString();
      
      // 1. Fetch inspect.php to get recent orders details
      final Map<String, dynamic> inspectRes = await ApiHandler.get('inspect.php?rand=$ts') as Map<String, dynamic>;
      final List<dynamic> recent = inspectRes['recent_orders'] ?? [];
      print('=== RECENT ORDERS STATUS ===');
      for (final order in recent) {
        print('Order: ${order['order_id']} | Status: ${order['status']} | Dist: ${order['distance_km']} km | Delivery Fee: ₹${order['delivery_fee']} | Total: ₹${order['total_amount']}');
      }
      print('============================');
    } catch (e) {
      print('Error: $e');
    }
    print('===========================================================');
  });
}
