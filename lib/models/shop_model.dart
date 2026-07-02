class Shop {
  final String id;
  final String name;
  final String category;
  final String rating;
  final String distance;
  final bool isOpen;
  final String owner;
  final String phone;
  final String address;
  final String description;
  final String qrCodeToken;
  final String? logoUrl;
  final String email;
  final int views;
  final bool deliveryEnabled;
  final String deliveryFeeType; // 'free' or 'paid'
  final double deliveryFee;
  final double? latitude;
  final double? longitude;

  Shop({
    required this.id,
    required this.name,
    required this.category,
    required this.rating,
    required this.distance,
    required this.isOpen,
    required this.owner,
    required this.phone,
    required this.address,
    this.description = '',
    this.qrCodeToken = '',
    this.logoUrl,
    this.email = '',
    this.views = 0,
    this.deliveryEnabled = false,
    this.deliveryFeeType = 'free',
    this.deliveryFee = 0.0,
    this.latitude,
    this.longitude,
  });

  /// Parse from your real API response format
  factory Shop.fromJson(Map<String, dynamic> json) {
    int apiViews = int.tryParse(json['views']?.toString() ?? '0') ?? 0;

    return Shop(
      id: (json['id'] ?? json['store_id'] ?? '').toString(),
      name: (json['shop_name'] ?? json['store_name'] ?? json['name'] ?? 'Store').toString(),
      category: (json['store_type'] ?? json['category'] ?? 'General').toString(),
      rating: (json['rating'] ?? '4.5').toString(),
      distance: (json['distance'] ?? '').toString(),
      isOpen: true,
      owner: (json['owner_name'] ?? json['owner'] ?? 'Owner').toString(),
      phone: (json['contact_number'] ?? json['owner_number'] ?? json['phone'] ?? '').toString(),
      address: (json['address'] ?? json['full_address'] ?? '').toString(),
      description: (json['shop_description'] ?? json['description'] ?? '').toString(),
      qrCodeToken: (json['qr_code_token'] ?? '').toString(),
      logoUrl: json['logo_url']?.toString(),
      email: (json['email'] ?? '').toString(),
      views: apiViews,
      deliveryEnabled: json['delivery_enabled'] == 1 || json['delivery_enabled'] == true || json['delivery_enabled'] == '1',
      deliveryFeeType: (json['delivery_fee_type'] ?? 'free').toString(),
      deliveryFee: double.tryParse(json['delivery_fee']?.toString() ?? '0') ?? 0.0,
      latitude: double.tryParse(json['latitude']?.toString() ?? ''),
      longitude: double.tryParse(json['longitude']?.toString() ?? ''),
    );
  }
}
