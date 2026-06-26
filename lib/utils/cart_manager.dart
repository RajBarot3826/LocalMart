import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product_model.dart';
import '../models/cart_item_model.dart';
import 'address_manager.dart';

class CartManager extends ChangeNotifier {
  static final CartManager _instance = CartManager._internal();
  factory CartManager() => _instance;
  CartManager._internal();

  List<CartItem> _items = [];
  String? _currentStoreId;
  String? _currentStoreName;
  String? _currentStoreAddress;
  
  // Delivery info from shop
  bool _deliveryEnabled = false;
  String _deliveryFeeType = 'free'; // 'free' or 'paid'
  double _deliveryFee = 0.0;

  List<CartItem> get items => _items;
  String? get currentStoreId => _currentStoreId;
  String? get currentStoreName => _currentStoreName;
  String? get currentStoreAddress => _currentStoreAddress;
  bool get deliveryEnabled => _deliveryEnabled;
  String get deliveryFeeType => _deliveryFeeType;
  
  double get estimatedDistanceKm {
    if (_currentStoreAddress == null || _currentStoreAddress!.isEmpty) {
      return 5.0;
    }
    final selectedAddr = AddressManager().selectedAddress;
    if (selectedAddr == null) {
      return 5.0;
    }
    
    final storeAddr = _currentStoreAddress!.toLowerCase();
    final custAddr = selectedAddr.fullAddress.toLowerCase();
    
    final RegExp pinReg = RegExp(r'364\d{3}');
    final storeMatch = pinReg.firstMatch(storeAddr);
    final custMatch = pinReg.firstMatch(custAddr);
    
    if (storeMatch != null && custMatch != null) {
      final p1 = int.tryParse(storeMatch.group(0)!) ?? 0;
      final p2 = int.tryParse(custMatch.group(0)!) ?? 0;
      if (p1 > 0 && p2 > 0) {
        final diff = (p1 - p2).abs();
        return diff == 0 ? 3.0 : 3.0 + (diff * 2.5);
      }
    }
    return 5.0;
  }

  double get deliveryFee {
    if (!_deliveryEnabled) return 0.0;
    return estimatedDistanceKm * 9.0;
  }

  int get totalItems => _items.fold(0, (sum, item) => sum + item.quantity);

  double get itemsTotal {
    return _items.fold(0.0, (sum, item) {
      double price = double.tryParse(item.product.price) ?? 0.0;
      return sum + (price * item.quantity);
    });
  }

  double get totalAmount {
    return itemsTotal + deliveryFee;
  }

  Future<void> init() async {
    await _loadCart();
  }

  void setStoreInfo({
    required String storeId,
    required String storeName,
    required String storeAddress,
    required bool deliveryEnabled,
    required String deliveryFeeType,
    required double deliveryFee,
  }) {
    _currentStoreId = storeId;
    _currentStoreName = storeName;
    _currentStoreAddress = storeAddress;
    _deliveryEnabled = deliveryEnabled;
    _deliveryFeeType = deliveryFeeType;
    _deliveryFee = deliveryFee;
    _saveCart();
  }

  void addProduct(Product product, {int quantity = 1}) {
    if (_currentStoreId != null && _currentStoreId != product.storeId) {
      throw Exception("DifferentStore");
    }

    _currentStoreId = product.storeId;
    int index = _items.indexWhere((i) => i.product.id == product.id);

    if (index >= 0) {
      _items[index].quantity += quantity;
    } else {
      _items.add(CartItem(product: product, quantity: quantity));
    }

    _saveCart();
    notifyListeners();
  }

  void removeProduct(Product product) {
    _items.removeWhere((i) => i.product.id == product.id);
    if (_items.isEmpty) {
      _currentStoreId = null;
      _currentStoreName = null;
      _deliveryEnabled = false;
      _deliveryFeeType = 'free';
      _deliveryFee = 0.0;
    }
    _saveCart();
    notifyListeners();
  }

  void updateQuantity(Product product, int quantity) {
    if (quantity <= 0) {
      removeProduct(product);
      return;
    }
    
    int index = _items.indexWhere((i) => i.product.id == product.id);
    if (index >= 0) {
      _items[index].quantity = quantity;
      _saveCart();
      notifyListeners();
    }
  }

  int getQuantity(Product product) {
    int index = _items.indexWhere((i) => i.product.id == product.id);
    if (index >= 0) {
      return _items[index].quantity;
    }
    return 0;
  }

  void clearCart() {
    _items.clear();
    _currentStoreId = null;
    _currentStoreName = null;
    _deliveryEnabled = false;
    _deliveryFeeType = 'free';
    _deliveryFee = 0.0;
    _saveCart();
    notifyListeners();
  }

  Future<void> _saveCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> cartStrings = _items.map((i) => json.encode(i.toJson())).toList();
      await prefs.setStringList('localmart_cart', cartStrings);
      if (_currentStoreId != null) {
        await prefs.setString('localmart_cart_store_id', _currentStoreId!);
      } else {
        await prefs.remove('localmart_cart_store_id');
      }
      if (_currentStoreName != null) {
        await prefs.setString('localmart_cart_store_name', _currentStoreName!);
      } else {
        await prefs.remove('localmart_cart_store_name');
      }
      if (_currentStoreAddress != null) {
        await prefs.setString('localmart_cart_store_address', _currentStoreAddress!);
      } else {
        await prefs.remove('localmart_cart_store_address');
      }
      await prefs.setBool('localmart_delivery_enabled', _deliveryEnabled);
      await prefs.setString('localmart_delivery_fee_type', _deliveryFeeType);
      await prefs.setDouble('localmart_delivery_fee', _deliveryFee);
    } catch (e) {
      debugPrint("Error saving cart: $e");
    }
  }

  Future<void> _loadCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String>? cartStrings = prefs.getStringList('localmart_cart');
      _currentStoreId = prefs.getString('localmart_cart_store_id');
      _currentStoreName = prefs.getString('localmart_cart_store_name');
      _currentStoreAddress = prefs.getString('localmart_cart_store_address');
      _deliveryEnabled = prefs.getBool('localmart_delivery_enabled') ?? false;
      _deliveryFeeType = prefs.getString('localmart_delivery_fee_type') ?? 'free';
      _deliveryFee = prefs.getDouble('localmart_delivery_fee') ?? 0.0;
      
      if (cartStrings != null) {
        _items = cartStrings.map((s) => CartItem.fromJson(json.decode(s))).toList();
      }
      notifyListeners();
    } catch (e) {
      debugPrint("Error loading cart: $e");
    }
  }
}
