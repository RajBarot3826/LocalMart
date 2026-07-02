import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product_model.dart';
import '../models/cart_item_model.dart';
import 'address_manager.dart';
import 'api_handler.dart';

class CartManager extends ChangeNotifier {
  static final CartManager _instance = CartManager._internal();
  factory CartManager() => _instance;
  CartManager._internal();

  List<CartItem> _items = [];
  String? _currentStoreId;
  String? _currentStoreName;
  String? _currentStoreAddress;
  double? _storeLatitude;
  double? _storeLongitude;
  
  // Delivery info from shop
  bool _deliveryEnabled = false;
  String _deliveryFeeType = 'free'; // 'free' or 'paid'
  double _deliveryFee = 0.0;
  double _deliveryFeePerKm = 9.0; // Default rate fallback
  String _adminUpiId = '9409630896@upi'; // Dynamic Admin UPI ID
  String _razorpayKeyId = 'rzp_test_5g2YvI0VjR4H2n'; // Dynamic Razorpay Key ID
 
  List<CartItem> get items => _items;
  String? get currentStoreId => _currentStoreId;
  String? get currentStoreName => _currentStoreName;
  String? get currentStoreAddress => _currentStoreAddress;
  double? get storeLatitude => _storeLatitude;
  double? get storeLongitude => _storeLongitude;
  bool get deliveryEnabled => _deliveryEnabled;
  String get deliveryFeeType => _deliveryFeeType;
  String get adminUpiId => _adminUpiId;
  String get razorpayKeyId => _razorpayKeyId;
  double get deliveryFeePerKm => _deliveryFeePerKm;
  
  double get estimatedDistanceKm {
    final selectedAddr = AddressManager().selectedAddress;
    if (selectedAddr == null) {
      return 3.0;
    }

    // 1. If GPS coordinates are available, calculate exact distance using Haversine formula
    if (_storeLatitude != null && _storeLongitude != null &&
        selectedAddr.latitude != null && selectedAddr.longitude != null) {
      final double distance = _calculateHaversineDistance(
        _storeLatitude!,
        _storeLongitude!,
        selectedAddr.latitude!,
        selectedAddr.longitude!,
      );
      return distance < 1.0 ? 1.5 : distance;
    }

    // 2. Fallback to pincode-based distance calculation
    if (_currentStoreAddress == null || _currentStoreAddress!.isEmpty) {
      return 3.0;
    }
    
    final storeAddr = _currentStoreAddress!.toLowerCase();
    final custAddr = selectedAddr.fullAddress.toLowerCase();
    
    final RegExp pinReg = RegExp(r'\b\d{6}\b');
    final storeMatch = pinReg.firstMatch(storeAddr);
    final custMatch = pinReg.firstMatch(custAddr);
    
    if (storeMatch != null && custMatch != null) {
      final p1 = int.tryParse(storeMatch.group(0)!) ?? 0;
      final p2 = int.tryParse(custMatch.group(0)!) ?? 0;
      if (p1 > 0 && p2 > 0) {
        final diff = (p1 - p2).abs();
        if (diff > 50) {
          return 5.0;
        }
        return diff == 0 ? 3.0 : 3.0 + (diff * 2.5);
      }
    }
    return 3.0;
  }

  double get deliveryFee {
    if (_currentStoreId == null || _items.isEmpty) return 0.0;
    return estimatedDistanceKm * _deliveryFeePerKm;
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
    await fetchSystemSettings();
  }

  Future<void> fetchSystemSettings() async {
    try {
      final response = await ApiHandler.get('get_settings.php');
      if (response != null && response['status'] == 'success') {
        final settings = response['settings'];
        if (settings != null) {
          final prefs = await SharedPreferences.getInstance();
          
          if (settings['delivery_fee_per_km'] != null) {
            final double? rate = double.tryParse(settings['delivery_fee_per_km'].toString());
            if (rate != null && rate > 0) {
              _deliveryFeePerKm = rate;
              await prefs.setDouble('localmart_delivery_fee_per_km', rate);
            }
          }
          
          if (settings['admin_upi_id'] != null) {
            final String upi = settings['admin_upi_id'].toString().trim();
            if (upi.isNotEmpty) {
              _adminUpiId = upi;
              await prefs.setString('localmart_admin_upi_id', upi);
            }
          }
          
          if (settings['razorpay_key_id'] != null) {
            final String rzKey = settings['razorpay_key_id'].toString().trim();
            if (rzKey.isNotEmpty) {
              _razorpayKeyId = rzKey;
              await prefs.setString('localmart_razorpay_key_id', rzKey);
            }
          }
          
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint("Error fetching system settings: $e");
    }
  }

  void setStoreInfo({
    required String storeId,
    required String storeName,
    required String storeAddress,
    required bool deliveryEnabled,
    required String deliveryFeeType,
    required double deliveryFee,
    double? latitude,
    double? longitude,
  }) {
    // If the cart has items and is already associated with a store, do not overwrite it
    if (_items.isNotEmpty && _currentStoreId != null && _currentStoreId != storeId) {
      return;
    }

    _currentStoreId = storeId;
    _currentStoreName = storeName;
    _currentStoreAddress = storeAddress;
    _deliveryEnabled = deliveryEnabled;
    _deliveryFeeType = deliveryFeeType;
    _deliveryFee = deliveryFee;
    _storeLatitude = latitude;
    _storeLongitude = longitude;
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
      _currentStoreAddress = null;
      _storeLatitude = null;
      _storeLongitude = null;
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
    _currentStoreAddress = null;
    _storeLatitude = null;
    _storeLongitude = null;
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
      if (_storeLatitude != null) {
        await prefs.setDouble('localmart_cart_store_lat', _storeLatitude!);
      } else {
        await prefs.remove('localmart_cart_store_lat');
      }
      if (_storeLongitude != null) {
        await prefs.setDouble('localmart_cart_store_lng', _storeLongitude!);
      } else {
        await prefs.remove('localmart_cart_store_lng');
      }
      await prefs.setBool('localmart_delivery_enabled', _deliveryEnabled);
      await prefs.setString('localmart_delivery_fee_type', _deliveryFeeType);
      await prefs.setDouble('localmart_delivery_fee', _deliveryFee);
      await prefs.setDouble('localmart_delivery_fee_per_km', _deliveryFeePerKm);
      await prefs.setString('localmart_admin_upi_id', _adminUpiId);
      await prefs.setString('localmart_razorpay_key_id', _razorpayKeyId);
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
      _storeLatitude = prefs.getDouble('localmart_cart_store_lat');
      _storeLongitude = prefs.getDouble('localmart_cart_store_lng');
      _deliveryEnabled = prefs.getBool('localmart_delivery_enabled') ?? false;
      _deliveryFeeType = prefs.getString('localmart_delivery_fee_type') ?? 'free';
      _deliveryFee = prefs.getDouble('localmart_delivery_fee') ?? 0.0;
      _deliveryFeePerKm = prefs.getDouble('localmart_delivery_fee_per_km') ?? 9.0;
      _adminUpiId = prefs.getString('localmart_admin_upi_id') ?? '9409630896@upi';
      _razorpayKeyId = prefs.getString('localmart_razorpay_key_id') ?? 'rzp_test_5g2YvI0VjR4H2n';
      
      if (cartStrings != null) {
        _items = cartStrings.map((s) => CartItem.fromJson(json.decode(s))).toList();
      }
      notifyListeners();
    } catch (e) {
      debugPrint("Error loading cart: $e");
    }
  }

  double _calculateHaversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295; // PI / 180
    final a = 0.5 - cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) *
        (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a)); // 2 * R; R = 6371 km
  }
}
