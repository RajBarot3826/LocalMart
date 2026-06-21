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
  });

  /// Parse from your real API response format:
  /// {"id":2,"shop_name":"gajananad grocery shop","owner_name":"rakesh parmar",
  ///  "email":"g@gmail.com","shop_description":"all grocery iteams...",
  ///  "address":"123,abc,bhavnager.","store_type":"Grocery",
  ///  "contact_number":"9512667374","qr_code_token":"shop_398dea31dff2",
  ///  "logo_url":"https://...","logo_path":"assets/..."}
  factory Shop.fromJson(Map<String, dynamic> json) {
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
    );
  }
}
