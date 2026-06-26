import 'cart_item_model.dart';

class OrderModel {
  final String orderId;
  final String date;
  final String storeName;
  final String status; // "Placed", "Confirmed", "Prepared", "Shipped", "Out For Delivery", "Delivered"
  final double totalAmount;
  final List<CartItem> items;

  OrderModel({
    required this.orderId,
    required this.date,
    required this.storeName,
    required this.status,
    required this.totalAmount,
    required this.items,
  });
}

// Dummy data for testing UI
List<OrderModel> dummyOrders = [
  OrderModel(
    orderId: "OD1234567890",
    date: "24 Jun 2026",
    storeName: "Shreeji Supermart",
    status: "Shipped",
    totalAmount: 1450.0,
    items: [],
  ),
  OrderModel(
    orderId: "OD0987654321",
    date: "10 Jun 2026",
    storeName: "Local Grocery Outlet",
    status: "Delivered",
    totalAmount: 320.0,
    items: [],
  ),
];
