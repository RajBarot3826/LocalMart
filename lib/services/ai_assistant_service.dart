class AIAssistantService {
  static final AIAssistantService _instance = AIAssistantService._internal();
  factory AIAssistantService() => _instance;
  AIAssistantService._internal();

  /// Generates AI-crafted contextual order updates and notifications
  String generateOrderStatusMessage({
    required String status,
    required String storeName,
    String? riderName,
    String? orderId,
  }) {
    final String s = status.toLowerCase().trim();
    final String store = storeName.isEmpty ? 'the store' : storeName;
    final String rider = (riderName != null && riderName.isNotEmpty) ? riderName : 'Our delivery partner';

    switch (s) {
      case 'placed':
      case 'pending':
        return "🛒 Order Received! We've sent your order to $store. Preparing your fresh items now!";
      
      case 'confirmed':
        return "✅ Order Confirmed! $store has accepted your order and is getting everything packed.";
      
      case 'prepared':
        return "📦 Items Packed! Your order at $store is fresh, packed, and ready for pickup.";
      
      case 'accepted':
      case 'assigned':
        return "🚴‍♂️ Rider Assigned! $rider is on the way to $store to pick up your order.";
      
      case 'arrived_store':
        return "📍 At the Store! $rider has arrived at $store to inspect and pick up your package.";
      
      case 'picked_up':
      case 'shipped':
      case 'out for delivery':
        return "🚀 Out for Delivery! $rider has picked up your order from $store and is speeding to your address!";
      
      case 'delivered':
      case 'completed':
        return "🎉 Delivered! $rider has handed over your package. Thank you for shopping local with LocalMart!";
      
      case 'cancelled':
        return "❌ Order Cancelled. Your order at $store was updated. Reach out to support for instant help.";
      
      default:
        return "🔔 Update on your order at $store: Status is now '$status'.";
    }
  }

  /// AI recommendation engine for cart items
  List<String> getSuggestedAddons(List<String> currentItemNames) {
    final List<String> addons = [];
    final String combined = currentItemNames.join(' ').toLowerCase();

    if (combined.contains('milk') || combined.contains('bread') || combined.contains('tea')) {
      addons.add('Sugar (1kg)');
      addons.add('Biscuits & Cookies');
    }
    if (combined.contains('flour') || combined.contains('atta') || combined.contains('rice')) {
      addons.add('Cooking Oil (1L)');
      addons.add('Toor Dal (1kg)');
    }
    if (addons.isEmpty) {
      addons.addAll(['Fresh Bananas (1 Dozen)', 'Amul Butter 100g']);
    }
    return addons;
  }
}
