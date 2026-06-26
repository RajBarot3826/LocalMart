import 'dart:convert';
import 'package:flutter/material.dart';

class Product {
  final String id;
  final String storeId;
  final String name;
  final String price;
  final String category;
  final String description;
  final String imageUrl;
  final IconData icon;
  final int views;
  final Map<String, dynamic> rawData;

  Product({
    required this.id,
    required this.storeId,
    required this.name,
    required this.price,
    required this.category,
    this.description = '',
    required this.imageUrl,
    this.icon = Icons.shopping_bag_outlined,
    this.views = 0,
    required this.rawData,
  });

  /// Parse from your real API response format:
  /// {"id":8,"vendor_id":2,"name":"capsicum","description":"fresh",
  ///  "price":"108.00","image_url":"https://...","image_path":"assets/...","views":2450}
  factory Product.fromJson(Map<String, dynamic> json) {
    int apiViews = int.tryParse(json['views']?.toString() ?? '0') ?? 0;

    String parsedPrice = json['price']?.toString() ?? '0';
    // If live server has not been patched yet (base_price is missing), 
    // dynamically apply 15% markup fallback on the client.
    if (json['base_price'] == null) {
      double base = double.tryParse(parsedPrice) ?? 0.0;
      parsedPrice = (base * 1.15).toStringAsFixed(2);
    }

    return Product(
      id: (json['id'] ?? json['product_id'] ?? '').toString(),
      storeId: (json['vendor_id'] ?? json['store_id'] ?? json['shop_id'] ?? '').toString(),
      name: (json['name'] ?? json['product_name'] ?? 'Product').toString(),
      price: _formatPrice(parsedPrice),
      category: (json['category'] ?? json['product_type'] ?? 'All').toString(),
      description: (json['description'] ?? '').toString(),
      imageUrl: _parseFirstImage(json),
      icon: _getIconForName(
        json['name']?.toString() ?? '',
        json['category']?.toString() ?? '',
      ),
      views: apiViews,
      rawData: json,
    );
  }

  Map<String, dynamic> toJson() {
    return rawData;
  }

  /// Remove trailing .00 from prices like "53000.00" → "53000"
  static String _formatPrice(String price) {
    if (price.endsWith('.00')) {
      return price.substring(0, price.length - 3);
    }
    return price;
  }

  static String _parseFirstImage(Map<String, dynamic> json) {
    if (json['images'] is List && (json['images'] as List).isNotEmpty) {
      return (json['images'] as List).first.toString();
    }
    final imgUrl = json['image_url']?.toString() ?? json['image']?.toString() ?? json['photos']?.toString() ?? json['gallery']?.toString() ?? '';
    if (imgUrl.startsWith('[') && imgUrl.endsWith(']')) {
      try {
        final List<dynamic> parsed = jsonDecode(imgUrl);
        if (parsed.isNotEmpty) return parsed.first.toString();
      } catch (_) {}
    }
    if (imgUrl.contains(',') || imgUrl.contains('|') || imgUrl.contains(';')) {
      return imgUrl.split(RegExp(r'[,|;]')).first.trim();
    }
    return imgUrl;
  }

  static IconData _getIconForName(String name, String category) {
    final combined = '$name $category'.toLowerCase();
    if (combined.contains('grocery') || combined.contains('atta') || combined.contains('oil') || combined.contains('salt')) return Icons.shopping_basket;
    if (combined.contains('fashion') || combined.contains('cloth') || combined.contains('shirt') || combined.contains('jeans')) return Icons.checkroom;
    if (combined.contains('mobile') || combined.contains('phone') || combined.contains('ipad') || combined.contains('macbook') || combined.contains('laptop') || combined.contains('elect')) return Icons.phone_android;
    if (combined.contains('airpod') || combined.contains('earbuds') || combined.contains('headphone') || combined.contains('audio')) return Icons.headphones;
    if (combined.contains('food') || combined.contains('fruit') || combined.contains('vegetable') || combined.contains('capsicum') || combined.contains('tomato') || combined.contains('apple')) return Icons.eco;
    if (combined.contains('medicine') || combined.contains('medical') || combined.contains('tablet')) return Icons.medical_services;
    return Icons.shopping_bag_outlined;
  }
}
