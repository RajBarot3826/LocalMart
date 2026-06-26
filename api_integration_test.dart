import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main() async {
  print("--- STARTING END-TO-END API INTEGRATION TEST ---\n");
  final baseUrl = "http://localmart.free.nf/api";
  final testPhone = "9999999999";

  try {
    // 1. Fetch Shops
    print("1. Fetching Shops...");
    final shopsResponse = await http.get(Uri.parse('$baseUrl/shops.php'));
    print("   Status Code: ${shopsResponse.statusCode}");
    if (shopsResponse.statusCode != 200) throw Exception("Failed to load shops");
    final List<dynamic> shops = json.decode(shopsResponse.body);
    print("   Found ${shops.length} shops.");
    if (shops.isEmpty) throw Exception("No shops available to test");
    
    final shop = shops.first;
    final storeId = shop['id'] ?? shop['store_id'];
    final storeName = shop['name'] ?? 'Test Store';
    print("   Selected Store: $storeName (ID: $storeId)");

    // 2. Place an Order
    print("\n2. Placing an Order...");
    final orderPayload = {
      "user_phone": testPhone,
      "user_name": "Senior Tester",
      "store_id": storeId.toString(),
      "store_name": storeName,
      "delivery_address": "123 Test Street, Developer City",
      "subtotal": "150.00",
      "delivery_fee": "0.00",
      "total_amount": "150.00",
      "payment_method": "COD",
      "items": [
        {
          "product_id": "1",
          "product_name": "Test Item",
          "quantity": 2,
          "price": "75.00"
        }
      ]
    };
    
    final placeOrderResponse = await http.post(
      Uri.parse('$baseUrl/place_order.php'),
      headers: {"Content-Type": "application/json"},
      body: json.encode(orderPayload),
    );
    print("   Status Code: ${placeOrderResponse.statusCode}");
    print("   Response: ${placeOrderResponse.body}");
    
    if (placeOrderResponse.statusCode != 200) {
      throw Exception("Failed to place order.");
    }
    
    // 3. Fetch Orders for the user
    print("\n3. Fetching Orders for phone $testPhone...");
    final getOrdersResponse = await http.get(Uri.parse('$baseUrl/get_orders.php?phone=$testPhone'));
    print("   Status Code: ${getOrdersResponse.statusCode}");
    print("   Response Body length: ${getOrdersResponse.body.length} bytes");
    
    if (getOrdersResponse.statusCode != 200) {
       throw Exception("Failed to fetch orders.");
    }
    
    final getOrdersData = json.decode(getOrdersResponse.body);
    if (getOrdersData is Map && getOrdersData['status'] == 'error') {
       print("   Error fetching orders: ${getOrdersData['message']}");
    } else if (getOrdersData is List) {
       print("   Found ${getOrdersData.length} orders.");
       if (getOrdersData.isNotEmpty) {
         final latestOrder = getOrdersData.first;
         print("   Latest Order Details:");
         print("   - Order ID: ${latestOrder['order_id'] ?? latestOrder['id']}");
         print("   - Status: ${latestOrder['status']}");
         print("   - Total: ${latestOrder['total_amount']}");
         print("   - Date: ${latestOrder['created_at']}");
       }
    } else {
       print("   Unexpected response format: $getOrdersData");
    }

    print("\n--- TEST COMPLETED SUCCESSFULLY ---");

  } catch (e) {
    print("\n!!! TEST FAILED !!!");
    print(e.toString());
  }
}
