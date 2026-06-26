import 'package:flutter_test/flutter_test.dart';
import 'package:localmart/utils/api_handler.dart';

void main() {
  test('View Platform Owner Profit Dashboard', () async {
    print('===========================================================');
    print('          LOCALMART PLATFORM OWNER PROFIT DASHBOARD');
    print('===========================================================');
    
    final passcode = 'localmart_owner_3826';
    
    try {
      final response = await ApiHandler.get('admin_reports.php?passcode=$passcode');
      if (response == null) {
        print('❌ Failed to get response. Make sure the patch has been uploaded and executed.');
        return;
      }
      
      if (response['status'] == true && response['summary'] != null) {
        final summary = response['summary'];
        print('\n📈 PLATFORM SUMMARY:');
        print('-----------------------------------------------------------');
        print('  Total Delivered Orders: ${summary['total_orders']}');
        print('  Total Platform Sales:   ₹${summary['total_sales']}');
        print('  Vendor Payouts (85%):   ₹${summary['total_vendor_payout']}');
        print('  Rider Payouts (7/km):   ₹${summary['total_rider_payout']}');
        print('-----------------------------------------------------------');
        print('  Store Commission (+15%): ₹${summary['total_item_commission']}');
        print('  Delivery profit (+2/km): ₹${summary['total_delivery_commission']}');
        print('  ---------------------------------------------------------');
        print('  🔥 NET OWNER PROFIT:     ₹${summary['total_owner_profit']}');
        print('-----------------------------------------------------------');
        
        final List orders = response['orders'] as List? ?? [];
        if (orders.isNotEmpty) {
          print('\n📋 RECENT ORDER DETAILS:');
          for (var o in orders) {
            print('  - Order ID: ${o['order_id']} | Store: ${o['store_name']}');
            print('    Customer Paid: ₹${o['total_amount']} | Store Payout: ₹${o['vendor_payout']} | Rider: ₹${o['rider_payout']} (${o['distance_km']} km)');
            print('    Profits -> Store Commission: ₹${o['owner_item_commission']} | Delivery: ₹${o['owner_delivery_commission']} | Total Profit: ₹${o['owner_total_profit']}');
            print('    Date: ${o['created_at']}');
            print('    -----------------------------------------------------');
          }
        }
      } else {
        print('❌ Error fetching dashboard: ${response['message'] ?? 'Unknown error'}');
      }
    } catch (e) {
      print('Exception querying admin_reports.php: $e');
    }
    
    print('===========================================================');
  });
}
