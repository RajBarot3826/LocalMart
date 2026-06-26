import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Status parsing logic', () {
    String getOrderStatus(Map<String, dynamic>? activeOrder) {
      String riderSt = activeOrder?['rider_status']?.toString().toLowerCase() ?? '';
      String mainSt = activeOrder?['status']?.toString().toLowerCase() ?? '';
      
      if (riderSt.isNotEmpty && riderSt != 'pending' && riderSt != 'assigned') {
        return riderSt;
      }
      if (mainSt.isNotEmpty) return mainSt;
      if (riderSt == 'assigned') return 'accepted';
      return 'accepted';
    }

    final order15 = {'status': '', 'rider_status': 'arrived_store'};
    final result15 = getOrderStatus(order15);
    print("Order 15 Status resolved to: $result15");

    final order14 = {'status': '', 'rider_status': 'assigned'};
    final result14 = getOrderStatus(order14);
    print("Order 14 Status resolved to: $result14");
    
    String getTrackOrder(Map<String, dynamic> orderData) {
      String status = orderData['status']?.toString() ?? 'Placed';
      final String riderStatus = orderData['rider_status']?.toString() ?? '';
      final hasRider = true;

      String statusLower = status.toLowerCase();
      if ((statusLower.isEmpty || statusLower == 'placed') && hasRider && riderStatus.isNotEmpty && riderStatus.toLowerCase() != 'pending') {
        statusLower = riderStatus.toLowerCase();
      }
      if (statusLower == 'pending') statusLower = 'placed';
      if (statusLower == 'shipped') statusLower = 'picked_up';
      if (statusLower == 'out for delivery') statusLower = 'picked_up';
      if (statusLower == 'assigned') statusLower = 'accepted';
      
      return statusLower;
    }
    
    print("Track Order 15 resolved to: ${getTrackOrder(order15)}");
    print("Track Order 14 resolved to: ${getTrackOrder(order14)}");
  });
}
